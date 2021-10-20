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
MOVIE_INNER_WIDTH=$(expr $MOVIE_WIDTH - $BORDER_SIZE_FULL)
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
SPOILER="./images/spoiler.png"
SPOILER_WIDTH=1000
SPOILER_HEIGHT=333
SPOILER_IN=0.75
SPOILER_OUT=5.5
SPOILER_FADE=1

# --- input file parameters

name=$(cat "$1" | jq -r '.name')
year=$(cat "$1" | jq -r '.year')
txt1=$(cat "$1" | jq -r '.txt1')
txt2=$(cat "$1" | jq -r '.txt2')
txt3=$(cat "$1" | jq -r '.txt3')
file=$(cat "$1" | jq -r '.file')
from=$(cat "$1" | jq -r '.from')
time=$(cat "$1" | jq -r '.time')
warn=$(cat "$1" | jq -r '.warn')

# --- calculated parameters

filename=$(basename "$1" .json)
input="./masters/$file.mp4"
output="./output/$filename.mp4"
extract="./extract.mp4"
stamped="./stamped.mp4"
mounted="./mounted.mp4"

from_secs=$(echo $from | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
time_secs=$(echo $time | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')
fade_point=$(expr $from_secs + $time_secs - $AUDIO_FADE_SECS)

size_x=$(ffprobe -v error -select_streams v:0 -show_entries stream=width  -of csv=s=x:p=0 $input)
size_y=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=s=x:p=0 $input)
MOVIE_HEIGHT=$(bc -l <<< "$MOVIE_WIDTH / $size_x * $size_y")

pos_y=$(bc -l <<< "$MOVIE_MID_HEIGHT - ($MOVIE_HEIGHT / 2)")
pos_y=$(echo $pos_y | awk '{ print int($1 + 0.5) }')

spoiler_x=$(bc -l <<< "($MOVIE_WIDTH - $SPOILER_WIDTH) / 2")
spoiler_x=$(echo $spoiler_x | awk '{ print int($1 + 0.5) }')

spoiler_y=$(bc -l <<< "($MOVIE_HEIGHT - $SPOILER_HEIGHT) / 2")
spoiler_y=$(echo $spoiler_y | awk '{ print int($1 + 0.5) }')

# --- start processing video

echo
echo "--- $name ---"
echo

rm $output 2> /dev/null

echo "  extracting..."
ffmpeg     -i $input \
          -ss $from -t $time \
       -lavfi "[0]scale= $MOVIE_INNER_WIDTH:-1[i]; \
               [i]pad= w=$BORDER_SIZE_FULL+iw : h=$BORDER_SIZE_FULL+ih : x=$BORDER_SIZE : y=$BORDER_SIZE : color=$BORDER_COLOR; \
                afade= t=out : st=$fade_point : d=$AUDIO_FADE_SECS" \
           -v error \
           -y $extract

if [ "$warn" = true ]; then
   echo "  stamping..."
   ffmpeg     -i $extract \
      -loop 1 -i $SPOILER \
     -lavfi "[1]format=yuva420p,fade=in:st=$SPOILER_IN:d=$SPOILER_FADE:alpha=1,fade=out:st=$SPOILER_OUT:d=$SPOILER_FADE:alpha=1[i]; \
             [0][i]overlay=$spoiler_x:$spoiler_y:shortest=1" \
       -c:a copy \
         -v error \
         -y $stamped
else
    cp $extract $stamped
fi

echo "  mounting..."
ffmpeg  -loop 1 -i $BACKGROUND \
           -i $stamped \
       -lavfi "[0][1]overlay=$MOVIE_LEFT:$pos_y:shortest=1[out]" \
         -map "[out]" -map 1:a \
         -c:a copy \
           -v error \
           -y $mounted

echo "  finalising..."
ffmpeg    -i $mounted \
        -vf "drawtext= x=(w-text_w)/2 : fontcolor=$TEXT_COLOUR : y=$TITLE_TOP : fontsize=$TITLE_SIZE : text='$name' : fontfile=./fonts/$TITLE_FONT.ttf, \
             drawtext= x=(w-text_w)/2 : fontcolor=$TEXT_COLOUR : y=$YEAR_TOP  : fontsize=$YEAR_SIZE  : text='$year' : fontfile=./fonts/$YEAR_FONT.ttf, \
             drawtext= x=(w-text_w)/2 : fontcolor=$TEXT_COLOUR : y=$DESC_1    : fontsize=$DESC_SIZE  : text='$txt1' : fontfile=./fonts/$DESC_FONT.ttf, \
             drawtext= x=(w-text_w)/2 : fontcolor=$TEXT_COLOUR : y=$DESC_2    : fontsize=$DESC_SIZE  : text='$txt2' : fontfile=./fonts/$DESC_FONT.ttf, \
             drawtext= x=(w-text_w)/2 : fontcolor=$TEXT_COLOUR : y=$DESC_3    : fontsize=$DESC_SIZE  : text='$txt3' : fontfile=./fonts/$DESC_FONT.ttf" \
        -c:a copy \
          -v error \
          -y $output

rm $extract
rm $stamped
rm $mounted

open $output

echo
