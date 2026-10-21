#!/bin/bash
# junta as cenas num MP4 só, com fade curto entre elas
cd "$(dirname "$0")/out"
rm -f lista.txt; for i in 00 01 02 03 04 05 06 07 08; do
  ffmpeg -y -v error -i cena_$i.mp4 -vf "fade=t=in:st=0:d=0.4,fade=t=out:st=$(ffprobe -v error -show_entries format=duration -of csv=p=0 cena_$i.mp4 | awk '{print $1-0.4}'):d=0.4" -c:v libx264 -crf 19 -pix_fmt yuv420p -r 30 -an f_$i.mp4
  echo "file 'f_$i.mp4'" >> lista.txt; done
ffmpeg -y -v error -f concat -safe 0 -i lista.txt -c copy -movflags +faststart growths-demo.mp4
ffprobe -v error -show_entries format=duration -of csv=p=0 growths-demo.mp4
