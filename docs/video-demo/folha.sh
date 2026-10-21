#!/bin/bash
# folha de quadros de um vídeo: folha.sh entrada.mp4 saida.png [n]
n=${3:-12}; d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$1")
ffmpeg -y -loglevel error -i "$1" -vf "fps=$n/$d,scale=480:-1,tile=4x$(( (n+3)/4 ))" -frames:v 1 "$2"
