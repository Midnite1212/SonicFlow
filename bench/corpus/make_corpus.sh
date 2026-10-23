#!/usr/bin/env bash
# Synthesizes the bench corpus with macOS TTS as 16 kHz mono PCM16 WAVs.
set -euo pipefail

corpus_dir="$(cd "$(dirname "$0")" && pwd)"
voice="${SONICFLOW_VOICE:-Samantha}"
mkdir -p "$corpus_dir/audio"

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  id="$(jq -r .id <<<"$line")"
  spoken="$(jq -r .spoken <<<"$line")"
  say -v "$voice" -o "$corpus_dir/audio/$id.wav" --file-format=WAVE --data-format=LEI16@16000 "$spoken"
  echo "$id"
done <"$corpus_dir/manifest.jsonl"
