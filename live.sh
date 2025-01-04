#!/bin/bash

file_list="filelist.txt"
rm -f "$file_list"
for f in songs/*.mp3; do
    echo "file '$PWD/$f'" >> "$file_list"
done

video_file="video.mp4" # Name of your video file
quality="854:480"      # Set video resolution (e.g., 1280:720 for 720p, 1920:1080 for 1080p, 3840:2160 for 4K)
                         # Resolution Options:
                         # 480p -> "854:480" (Low quality, for small screens or low bandwidth)
                         # 720p -> "1280:720" (Standard HD, good for most purposes)
                         # 1080p -> "1920:1080" (Full HD, widely used for higher quality)
                         # 1440p -> "2560:1440" (Quad HD, better quality than Full HD)
                         # 4K -> "3840:2160" (Ultra HD, very high quality for large displays)
fps=30                   # Set frames per second (e.g., 30, 50, 60)
                         # Recommended: 30 for standard, 50 or 60 for smooth motion
bitrate="1500"         # Set video bitrate (e.g., 1500k, 5000k, 10000k)
                         # Video Bitrate Recommendations:
                         # 480p -> 1500k
                         # 720p -> 2500k-3500k
                         # 1080p -> 5000k-10000k
                         # 1440p -> 10000k-15000k
                         # 4K -> 20000k-50000k or higher for ultra-high quality
audio_bitrate="320k"     # Set audio bitrate (e.g., 64k, 128k, 320k)
                         # Audio Bitrate Recommendations:
                         # 64k -> Low quality audio (for voice streams, e.g., podcasts)
                         # 128k -> Good audio quality (stereo, standard quality)
                         # 320k -> High quality audio (for music, good fidelity)
audio_channels=2         # Set audio channels (1 for mono, 2 for stereo)
                         # Audio Channels:
                         # 1 -> Mono (single channel, lower quality)
                         # 2 -> Stereo (dual channel, standard for most streams)
sample_rate=44100        # Set audio sample rate (e.g., 44100, 48000)
                         # Recommended: 44100 for most use cases, 48000 for professional audio
threads=4                # Number of threads to use (depends on CPU cores)
                         # Recommended: Match your CPU core count
stream_url="rtmp://a.rtmp.youtube.com/live2/sch2-1qmh-zgam-x7za-4z9c"  # Streaming destination URL
                         # Replace with your platform's RTMP URL and stream key


# FFmpeg Command
ffmpeg -stream_loop -1 -re -i "$video_file" -f concat -safe 0 -i "$file_list" \
-vcodec libx264 -preset ultrafast -pix_fmt yuv420p -r "$fps" -g "$((fps * 2))" -keyint_min "$((fps * 2))" \
-b:v "$bitrate"k -maxrate "$bitrate"k -bufsize "$((2 * bitrate))k" \
-c:a aac -b:a "$audio_bitrate" -ar "$sample_rate" -ac "$audio_channels" -movflags +faststart \
-vf "scale=$quality" \
-f flv "$stream_url" \
-reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 2 -threads "$threads" -y



rm -f "$file_list"
