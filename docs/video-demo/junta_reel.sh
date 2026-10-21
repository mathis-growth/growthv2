#!/bin/bash
# Reel vertical: junta os trechos, acelera os mais longos, fade curto entre eles
cd "$(dirname "$0")/reels"; rm -f lista.txt
for par in r0:1 r1:1 r2:2 r3:1 r4:1.25 r5:1 r6:1.35 r9:1; do
  n=${par%%:*}; v=${par##*:}
  d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 reel_$n.mp4); d=$(echo "$d / $v" | bc -l)
  ffmpeg -y -v error -i reel_$n.mp4 -vf "setpts=PTS/$v,fps=30,fade=t=in:st=0:d=0.3,fade=t=out:st=$(echo "$d - 0.3" | bc -l):d=0.3" -c:v libx264 -crf 19 -pix_fmt yuv420p -an g_$n.mp4
  echo "file 'g_$n.mp4'" >> lista.txt; done
ffmpeg -y -v error -f concat -safe 0 -i lista.txt -c copy -movflags +faststart growths-reel.mp4
for n in r0 r1 r2 r3 r4 r5 r6 r9; do printf "%s %.1f\n" $n $(ffprobe -v error -show_entries format=duration -of csv=p=0 g_$n.mp4); done
ffprobe -v error -show_entries format=duration -of csv=p=0 growths-reel.mp4
