#!/bin/bash
name=$(echo "$1" | cut -f 1 -d '.')
ffmpeg -i "$1" -map 0:s:0 "$name.srt"
