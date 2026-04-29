#!/bin/bash

printf "✨ starting yt-dlp capture ✨\n"

URL=$1

if [ -z "$URL" ]; then
  printf "❌ Exiting (must set URL)...\n"
  exit 1
fi

yt-dlp \
  --quiet \
  --write-info-json \
  --print "before_dl:▶ %(title|?)s [%(id|?)s]" \
  --print "after_move:✓ %(title|?)s → %(filepath|?)s" \
  -o '%(uploader,playlist_uploader,playlist_title,playlist_id)s/%(title)s-%(id)s.%(ext)s' \
  "$URL"

printf "🎉 capture done!\n"
