#-------------------------------------------------------------------------------------------------------------
# Customization Section
Video_File="/workspaces/Livestream-24-7/video.mp4" # Change the path according to your system
Audio_File="/workspaces/Livestream-24-7/songs/Polvo Rodante.mp3" # Change the path according to your system
Audio_Bitrate="128k" # Options: "64k" , "128k" , "320k"
FPS=30  # Options: "60" , "50", "30"
Video_Quality="1440p"  # Options: "2160p", "1440p", "1080p", "720p", "480p", "360p", "144p"
Stream_Key="qfcd-v3wp-hcqb-kjs1-1eqc"  # Replace with your actual stream key
RTMP_URL="rtmp://a.rtmp.youtube.com/live2"  # Replace with your platform's RTMP URL (for YouTube, use the default URL)
#-------------------------------------------------------------------------------------------------------------

if [ ! -f "$Video_File" ]; then
    echo "Error: Video file not found at $Video_File!"
    exit 1
fi

if [ ! -f "$Audio_File" ]; then
    echo "Error: Audio file not found at $Audio_File!"
    exit 1
fi

if ! echo "$Audio_Bitrate" | grep -qE '^(64k|128k|320k)$'; then
    echo "Error: Invalid audio bitrate $Audio_Bitrate! Valid options are '64k', '128k', or '320k'."
    exit 1
fi

if ! echo "$FPS" | grep -qE '^(30|50|60)$'; then
    echo "Error: Invalid FPS value $FPS! Valid options are '30', '50', or '60'."
    exit 1
fi

if [ -z "$Stream_Key" ]; then
    echo "Error: Stream key is missing. Please provide a valid stream key."
    exit 1
fi

if [ -z "$RTMP_URL" ]; then
    echo "Error: RTMP URL is missing. Please provide a valid RTMP server URL."
    exit 1
fi

if ! echo "$Video_Quality" | grep -qE '^(2160p|1440p|1080p|720p|480p|360p|144p)$'; then
    echo "Error: Invalid video quality $Video_Quality! Valid options are '2160p', '1440p', '1080p', '720p', '480p', '360p', or '144p'."
    exit 1
fi

if [ "$Video_Quality" = "2160p" ]; then
    Resolution="3840x2160"
    Video_Bitrate="5000k"  
elif [ "$Video_Quality" = "1440p" ]; then
    Resolution="2560x1440"
    Video_Bitrate="4000k"  
elif [ "$Video_Quality" = "1080p" ]; then
    Resolution="1920x1080"
    Video_Bitrate="3000k"
elif [ "$Video_Quality" = "720p" ]; then
    Resolution="1280x720"
    Video_Bitrate="1500k"  
elif [ "$Video_Quality" = "480p" ]; then
    Resolution="854x480"
    Video_Bitrate="1000k"
elif [ "$Video_Quality" = "360p" ]; then
    Resolution="640x360"
    Video_Bitrate="750k"
elif [ "$Video_Quality" = "144p" ]; then
    Resolution="256x144"
    Video_Bitrate="400k"
else
    Resolution="1920x1080"
    Video_Bitrate="3000k"
fi

ffmpeg -stream_loop -1 -re -i "$Video_File" -stream_loop -1 -re -i "$Audio_File" -vcodec libx264 -pix_fmt yuvj420p -maxrate 20048k -preset veryfast -r $FPS -framerate 30 -g 50 -c:a aac -b:a $Audio_Bitrate -ar 44100 -strict experimental -video_track_timescale 1000 -b:v $Video_Bitrate -s $Resolution -f flv  "$RTMP_URL/$Stream_Key"