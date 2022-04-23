#!/usr/bin/env bash
# I wrote this because I was waiting for subs2srs to finish


INPUT_SRT=input.srt
INPUT_VIDEO=ep1.mkv
DECK_NAME=Break_Blade
EPISODE=1

SS_TIMESTAMPS=""
VFRAMES=""
SS_AUDIO=""

MAP_ID=0
BATCH_SIZE=10
OUTPUT_FOLDER="output"
mkdir -p $OUTPUT_FOLDER

#generate audio_only file from video for faster clipping
ffmpeg -threads 0 -vn -y -i $INPUT_VIDEO -ac 2 -map 0:1 -b:a 128k $OUTPUT_FOLDER/audio_only.mp3
rm $OUTPUT_FOLDER/$DECK_NAME.tsv

while read -r number; do
  read -r time_stamp

  # read all content lines
  CONTENT=""

  while read -r line; do
    if [ -z "$line" ]
    then
          #$line is empty, next entry!
          break;
    else
          CONTENT=$CONTENT$line
    fi
  done
  # calculate middle of time_stamp
  time_stamp_array=($(echo $time_stamp | sed -e 's/--> //' | tr " " "\n"))
  time_stamp_start=$(echo ${time_stamp_array[0]} | sed -e 's/,/./')
  time_stamp_end=$(echo ${time_stamp_array[1]} | sed -e 's/,/./')

  time_stamp_start_millis=$(date --date="$time_stamp_start" "+%s%3N")
  time_stamp_end_millis=$(date --date="$time_stamp_end" "+%s%3N")
  let time_stamp_middle_millis=($time_stamp_start_millis+$time_stamp_end_millis)/2
  let time_stamp_middle_seconds=time_stamp_middle_millis/1000
  let time_stamp_middle_millis=time_stamp_middle_millis%1000
  time_stamp_middle=$(date --date="@$time_stamp_middle_seconds" "+%1H.%M.%S").$(printf %03d $time_stamp_middle_millis)

  time_stamp_start_a=$(date --date="$time_stamp_start" "+%1H.%M.%S.%3N")
  time_stamp_end_a=$(date --date="$time_stamp_end" "+%1H.%M.%S.%3N")

  JPG_FILE="${DECK_NAME}_${EPISODE}_${time_stamp_middle}.jpg"
  AUDIO_FILE="${DECK_NAME}_${EPISODE}_$time_stamp_start_a-$time_stamp_end_a.mp3"

  # full timestamp without %1H and colons
  time_stamp_middle=$(date --date="@$time_stamp_middle_seconds" "+%H:%M:%S").$(printf %03d $time_stamp_middle_millis)

  # create ffmpeg command

  SS_TIMESTAMPS=$SS_TIMESTAMPS"-ss $time_stamp_middle -i $INPUT_VIDEO "
  VFRAMES=$VFRAMES"-f image2 -vf scale=240:160 -map $MAP_ID:v -vframes 1 $OUTPUT_FOLDER/$JPG_FILE "
  SS_AUDIO=$SS_AUDIO" -ss $time_stamp_start -to $time_stamp_end -i $OUTPUT_FOLDER/audio_only.mp3 -codec:a copy $OUTPUT_FOLDER/$AUDIO_FILE"
  let MAP_ID+=1
  echo $MAP_ID

  # generate TSV
  echo $CONTENT$'\t'$CONTENT$'\t'[sound:$AUDIO_FILE]$'\t''<img src="'$JPG_FILE'">'$'\t'$CONTENT >> $OUTPUT_FOLDER/$DECK_NAME.tsv

  # send a batch of 10 and launch ffmpeg

  if [ "$MAP_ID" -gt "$BATCH_SIZE" ]; then
    #echo ffmpeg -y -an $SS_TIMESTAMPS $VFRAMES
    #echo ffmpeg -y $SS_AUDIO

    ffmpeg -y -an $SS_TIMESTAMPS $VFRAMES 2> /dev/null
    ffmpeg -y $SS_AUDIO 2> /dev/null
    SS_TIMESTAMPS=""
    VFRAMES=""
    SS_AUDIO=""
    MAP_ID=0
  fi
done <$INPUT_SRT

ffmpeg -y -an $SS_TIMESTAMPS $VFRAMES 2> /dev/null
ffmpeg -y $SS_AUDIO 2> /dev/null

rm $OUTPUT_FOLDER/audio_only.mp3
