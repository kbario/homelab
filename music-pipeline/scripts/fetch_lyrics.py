#!/usr/bin/env python3
"""Fetch sidecar lyrics from LRCLIB for FLAC files in a music library."""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from mutagen import File as MutagenFile

LRCLIB_BASE = "https://lrclib.net/api"
USER_AGENT = "homelab-music-pipeline/1.0 (local lyrics fetch)"
REQUEST_DELAY_S = 0.3
DURATION_TOLERANCE_S = 2


def tag_first(audio, *keys: str) -> str | None:
    for key in keys:
        value = audio.get(key)
        if value is None:
            continue
        if isinstance(value, list):
            if not value:
                continue
            text = str(value[0]).strip()
        else:
            text = str(value).strip()
        if text:
            return text
    return None


def read_track_meta(path: Path) -> dict[str, object] | None:
    audio = MutagenFile(path.as_posix())
    if audio is None or audio.info is None:
        return None

    title = tag_first(audio, "title", "TITLE", "\xa9nam")
    artist = tag_first(
        audio,
        "artist",
        "ARTIST",
        "albumartist",
        "ALBUMARTIST",
        "\xa9ART",
        "aART",
    )
    album = tag_first(audio, "album", "ALBUM", "\xa9alb")
    duration = int(round(float(audio.info.length)))

    if not title or not artist or not album or duration <= 0:
        return None

    return {
        "title": title,
        "artist": artist,
        "album": album,
        "duration": duration,
    }


def http_get_json(url: str) -> tuple[int, object | None]:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/json",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8")
            if not body:
                return resp.status, None
            return resp.status, json.loads(body)
    except urllib.error.HTTPError as exc:
        retry_after = exc.headers.get("Retry-After") if exc.headers else None
        if exc.code == 429:
            wait_s = int(retry_after) if retry_after and retry_after.isdigit() else 5
            time.sleep(wait_s)
            return http_get_json(url)
        if exc.code == 404:
            return 404, None
        print(f"HTTP {exc.code} for {url}: {exc.reason}", file=sys.stderr)
        return exc.code, None
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        print(f"Request failed for {url}: {exc}", file=sys.stderr)
        return 0, None


def lrclib_get(meta: dict[str, object]) -> dict[str, object] | None:
    query = urllib.parse.urlencode(
        {
            "track_name": meta["title"],
            "artist_name": meta["artist"],
            "album_name": meta["album"],
            "duration": meta["duration"],
        }
    )
    status, payload = http_get_json(f"{LRCLIB_BASE}/get?{query}")
    if status == 200 and isinstance(payload, dict):
        return payload
    return None


def duration_close(candidate: object, target: int) -> bool:
    try:
        return abs(int(round(float(candidate))) - target) <= DURATION_TOLERANCE_S
    except (TypeError, ValueError):
        return False


def lrclib_search(meta: dict[str, object]) -> dict[str, object] | None:
    query = urllib.parse.urlencode(
        {
            "track_name": meta["title"],
            "artist_name": meta["artist"],
            "album_name": meta["album"],
        }
    )
    status, payload = http_get_json(f"{LRCLIB_BASE}/search?{query}")
    if status != 200 or not isinstance(payload, list):
        return None

    target = int(meta["duration"])
    matches = [
        item
        for item in payload
        if isinstance(item, dict) and duration_close(item.get("duration"), target)
    ]
    if not matches:
        return None

    def score(item: dict[str, object]) -> tuple[int, int]:
        has_synced = 1 if item.get("syncedLyrics") else 0
        has_plain = 1 if item.get("plainLyrics") else 0
        return (has_synced, has_plain)

    matches.sort(key=score, reverse=True)
    return matches[0]


def lyrics_payload(record: dict[str, object]) -> tuple[str, str] | None:
    if record.get("instrumental") is True:
        return None
    synced = record.get("syncedLyrics")
    if isinstance(synced, str) and synced.strip():
        return synced.strip() + "\n", ".lrc"
    plain = record.get("plainLyrics")
    if isinstance(plain, str) and plain.strip():
        return plain.strip() + "\n", ".txt"
    return None


def sidecar_exists(flac: Path) -> bool:
    return flac.with_suffix(".lrc").is_file() or flac.with_suffix(".txt").is_file()


def iter_flacs(root: Path) -> list[Path]:
    return sorted(p for p in root.rglob("*.flac") if p.is_file())


def process_library(root: Path) -> int:
    flacs = iter_flacs(root)
    fetched = 0
    skipped = 0
    missing = 0
    bad_tags = 0

    print(f"Scanning {root} ({len(flacs)} FLAC files)...")

    for index, flac in enumerate(flacs):
        if sidecar_exists(flac):
            skipped += 1
            continue

        meta = read_track_meta(flac)
        if meta is None:
            bad_tags += 1
            print(f"  skip (missing tags): {flac.relative_to(root)}")
            continue

        record = lrclib_get(meta)
        time.sleep(REQUEST_DELAY_S)
        if record is None:
            record = lrclib_search(meta)
            time.sleep(REQUEST_DELAY_S)

        if record is None:
            missing += 1
            print(f"  missing: {meta['artist']} — {meta['title']}")
            continue

        payload = lyrics_payload(record)
        if payload is None:
            missing += 1
            print(f"  missing (instrumental/empty): {meta['artist']} — {meta['title']}")
            continue

        text, suffix = payload
        out = flac.with_suffix(suffix)
        out.write_text(text, encoding="utf-8")
        fetched += 1
        print(f"  wrote {out.name}: {meta['artist']} — {meta['title']}")

        # Extra pacing for large libraries even when we already slept per request.
        if index + 1 < len(flacs):
            time.sleep(0)

    print(
        "Lyrics summary: "
        f"fetched={fetched} skipped={skipped} missing={missing} bad_tags={bad_tags}"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "path",
        nargs="?",
        default="/music",
        help="Music library root or album subdirectory (default: /music)",
    )
    args = parser.parse_args()
    root = Path(args.path)
    if not root.is_dir():
        print(f"Error: path not found: {root}", file=sys.stderr)
        return 1
    return process_library(root.resolve())


if __name__ == "__main__":
    raise SystemExit(main())
