#!/bin/bash

# --- verify input file

if [ -z "$1" ]; then
    echo "no specification provided"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "specification '$1' does not exist"
    exit 1
fi

# --- constant values

SCREEN_WIDTH=1080
SCREEN_HEIGHT=1920
MOVIE_WIDTH=1062
MOVIE_MID_HEIGHT=605
BORDER_COLOR="white"
BORDER_SIZE=2
BORDER_SIZE_FULL=$(expr $BORDER_SIZE + $BORDER_SIZE)
MOVIE_LEFT=10
TEXT_COLOUR="white"
TITLE_TOP=1100
TITLE_SIZE=68
TITLE_FONT="calibri_bold"
YEAR_TOP=1170
YEAR_SIZE=38
YEAR_FONT="calibri"
DESC_TOP=1240
DESC_LINE_GAP=50
DESC_SIZE=42
DESC_FONT="cambria"
DESC_1=$(bc -l <<< "$DESC_TOP + 0 * $DESC_LINE_GAP")
DESC_2=$(bc -l <<< "$DESC_TOP + 1 * $DESC_LINE_GAP")
DESC_3=$(bc -l <<< "$DESC_TOP + 2 * $DESC_LINE_GAP")
AUDIO_FADE_SECS=1
BACKGROUND="./images/background.jpg"

# --- input file parameters

name=$(cat "$1" | jq -r '.name')
year=$(cat "$1" | jq -r '.year')
txt1=$(cat "$1" | jq -r '.txt1')
txt2=$(cat "$1" | jq -r '.txt2')
txt3=$(cat "$1" | jq -r '.txt3')
file=$(cat "$1" | jq -r '.file')
from=$(cat "$1" | jq -r '.from')
time=$(cat "$1" | jq -r '.time')

# --- calculated parameters

filename=$(basename "$1" .json)
input="./masters/$file.mp4"
output="./output/$filename.mp4"
extract="./extract.mp4"
mounted="./mounted.mp4"

from_secs=$(echo $from | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
time_secs=$(echo $time | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
fade_point=$(expr $from_secs + $time_secs - $AUDIO_FADE_SECS)

size_x=$(ffprobe -v error -select_streams v:0 -show_entries stream=width  -of csv=s=x:p=0 $input)
size_y=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 $input)
pos_y=$(bc -l <<< "$MOVIE_MID_HEIGHT - (($MOVIE_WIDTH / $size_x * $size_y) / 2)")
pos_y=$(echo $pos_y | awk '{ print int($1 + 0.5) }')

# --- start processing video

echo
echo "--- $name ---"
echo

rm $output 2> /dev/null

echo "  extracting..."
ffmpeg     -i $input \
          -ss $from -t $time \
       -lavfi "pad= w=$BORDER_SIZE_FULL+iw : h=$BORDER_SIZE_FULL+ih : x=$BORDER_SIZE : y=$BORDER_SIZE : color=$BORDER_COLOR; \
               afade= t=out : st=$fade_point : d=$AUDIO_FADE_SECS" \
           -v error \
           -y $extract

echo "  mounting..."
   ffmpeg  -loop 1 -i $BACKGROUND \
           -i $extract \
       -lavfi "[1]scale=$MOVIE_WIDTH:-1[inner]; \
               [0][inner]overlay=$MOVIE_LEFT:$pos_y:shortest=1[out]" \
         -map "[out]" -map 1:a -c:a copy \
           -v error \
           -y $mounted

echo "  finalising..."
ffmpeg    -i $mounted \
        -vf "drawtext= x=(w-text_w)/2 : fontcolor=$TEXT_COLOUR : y=$TITLE_TOP : fontsize=$TITLE_SIZE : text='$name' : fontfile=./fonts/$TITLE_FONT.ttf, \
             drawtext= x=(w-text_w)/2 : fontcolor=$TEXT_COLOUR : y=$YEAR_TOP  : fontsize=$YEAR_SIZE  : text='$year' : fontfile=./fonts/$YEAR_FONT.ttf, \
             drawtext= x=(w-text_w)/2 : fontcolor=$TEXT_COLOUR : y=$DESC_1    : fontsize=$DESC_SIZE  : text='$txt1' : fontfile=./fonts/$DESC_FONT.ttf, \
             drawtext= x=(w-text_w)/2 : fontcolor=$TEXT_COLOUR : y=$DESC_2    : fontsize=$DESC_SIZE  : text='$txt2' : fontfile=./fonts/$DESC_FONT.ttf, \
             drawtext= x=(w-text_w)/2 : fontcolor=$TEXT_COLOUR : y=$DESC_3    : fontsize=$DESC_SIZE  : text='$txt3' : fontfile=./fonts/$DESC_FONT.ttf" \
          -v error \
          -y $output

rm $extract
rm $mounted
open $output

echo
