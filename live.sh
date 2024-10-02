ffmpeg -stream_loop -1 -re -i **VIDEO FILE NAME** -stream_loop -1 -re -i **AUDIO FILE MP3 LINK** \
-vcodec libx264 -preset veryfast -profile:v high -pix_fmt yuv420p -r 60 -g 60 -keyint_min 60 \
-b:v 10000k -maxrate 11000k -bufsize 15000k -c:a aac -b:a 128k -ar 48000 -ac 2 -movflags +faststart \
-tune zerolatency -vf "scale=1920:1080" \
-f flv rtmp://a.rtmp.youtube.com/live2/*Stream Key* \
-reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 2 -y
