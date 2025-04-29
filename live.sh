#!/bin/bash
#-------------------------------------------------------------------------------------------------------------
# Livestream Automation Script for YouTube RTMP using FFmpeg
# This script continuously streams a looping video with dynamic, shuffled audio from a folder of MP3s.
# It includes logging, retry handling, and buffer/bandwidth optimizations.
#-------------------------------------------------------------------------------------------------------------

# Customization Section
Video_File="/workspaces/Livestream-24-7/video.mp4"          # Path to video file
Audio_Directory="/workspaces/Livestream-24-7/songs"         # Folder containing MP3 files
Audio_Bitrate="128k"                                        # Audio bitrate
Audio_Sample_Rate="44100"                                   # Audio sample rate
FPS=60                                                      # Video framerate
Video_Quality="480p"                                        # Output video quality
Video_Encoder="libx264"                                     # Video encoder (e.g., libx264, libx265)
Preset="veryfast"                                           # Encoder preset
Stream_Key="tsty-4mae-hx5t-hktq-6xxj"                       # YouTube stream key
RTMP_URL="rtmp://a.rtmp.youtube.com/live2"                  # RTMP destination
Retry_Delay=5                                               # Delay between retries
Max_Retries=10                                              # Max retry count (-1 for infinite)
Thread_Count=0                                              # FFmpeg thread count (0 = auto)
Log_File="/tmp/stream_log_$(date +%Y%m%d_%H%M%S).txt"       # Log file path
Log_Level="INFO"                                            # Log verbosity: INFO, WARN, ERROR
Buffer_Multiplier=2                                         # Buffer size multiplier for smoother stream
#-------------------------------------------------------------------------------------------------------------

# Logger function for standardized logging
log() {
    local level="$1"
    shift
    case "$Log_Level" in
        "ERROR") [[ "$level" != "ERROR" ]] && return ;;
        "WARN")  [[ "$level" == "INFO" ]] && return ;;
        "INFO")  : ;;
        *) log "ERROR" "Invalid Log_Level '$Log_Level'. Defaulting to INFO."; Log_Level="INFO" ;;
    esac
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level]: $*" | tee -a "$Log_File"
}

# Cleanup function for graceful shutdown on Ctrl+C or kill signal
cleanup() {
    log "INFO" "Stopping stream..."
    killall ffmpeg 2>/dev/null
    exit 0
}
trap cleanup INT TERM

log "INFO" "Starting livestream script..."

# Dependency check: Ensure FFmpeg is installed
if ! command -v ffmpeg &>/dev/null; then
    log "ERROR" "ffmpeg is not installed!"
    exit 1
fi

# Validate FPS
if ! [[ "$FPS" =~ ^[0-9]+$ ]] || [ "$FPS" -le 0 ]; then
    log "ERROR" "FPS must be a positive integer!"
    exit 1
fi

# Validate file paths
[ ! -r "$Video_File" ] && { log "ERROR" "Cannot read video file: $Video_File"; exit 1; }
[ ! -d "$Audio_Directory" ] && { log "ERROR" "Invalid audio directory: $Audio_Directory"; exit 1; }

# Determine video resolution and bitrate based on selected quality
case "$Video_Quality" in
    "2160p") Resolution="3840x2160"; Video_Bitrate="51000k" ;; # 4K @ 60fps
    "1440p") Resolution="2560x1440"; Video_Bitrate="24000k" ;;
    "1080p") Resolution="1920x1080"; Video_Bitrate="12000k" ;;
    "720p")  Resolution="1280x720";  Video_Bitrate="7500k"  ;;
    "480p")  Resolution="854x480";   Video_Bitrate="2500k"  ;;
    "360p")  Resolution="640x360";   Video_Bitrate="1000k"  ;;
    "240p")  Resolution="426x240";   Video_Bitrate="700k"   ;;
    "144p")  Resolution="256x144";   Video_Bitrate="400k"   ;;
    *) log "ERROR" "Invalid Video_Quality: $Video_Quality"; exit 1 ;;
esac

# Parse numeric value from bitrate
Numeric_Bitrate=${Video_Bitrate%k}
if ! [[ "$Numeric_Bitrate" =~ ^[0-9]+$ ]]; then
    log "ERROR" "Invalid Video_Bitrate format '$Video_Bitrate'"
    exit 1
fi

# Validate buffer multiplier
if ! [[ "$Buffer_Multiplier" =~ ^[0-9]+$ ]] || [ "$Buffer_Multiplier" -lt 1 ]; then
    log "ERROR" "Buffer_Multiplier must be a positive integer"
    exit 1
fi

# Calculate buffer size for FFmpeg
bufsize=$((Numeric_Bitrate * 1000 * Buffer_Multiplier))

# Generate a shuffled playlist of MP3s
generate_audio_playlist() {
    Playlist_File="/tmp/audio_playlist.txt"
    rm -f "$Playlist_File"
    find "$Audio_Directory" -type f -iname "*.mp3" | shuf | while read -r audio; do
        echo "file '$audio'" >> "$Playlist_File"
    done

    if [ ! -s "$Playlist_File" ]; then
        log "ERROR" "No MP3 files found in $Audio_Directory!"
        exit 1
    fi

    log "INFO" "Audio playlist created with $(wc -l < "$Playlist_File") shuffled tracks."
}

# Stream initiation function
start_stream() {
    generate_audio_playlist

    while true; do
        log "INFO" "Launching FFmpeg stream..."

        # Start FFmpeg livestreaming with looped video and shuffled audio
        ffmpeg -re -stream_loop -1 -i "$Video_File" \
            -f concat -safe 0 -stream_loop -1 -i "/tmp/audio_playlist.txt" \
            -c:v "$Video_Encoder" -preset "$Preset" -r "$FPS" -vf "fps=$FPS" -g $((FPS * 2)) -threads "$Thread_Count" \
            -b:v "$Video_Bitrate" -maxrate "$Video_Bitrate" -bufsize "$bufsize" \
            -pix_fmt yuv420p -s "$Resolution" \
            -c:a aac -b:a "$Audio_Bitrate" -ar "$Audio_Sample_Rate" -async 1 -strict experimental \
            -map 0:v:0 -map 1:a:0 -f flv -flvflags no_duration_filesize "$RTMP_URL/$Stream_Key" 2>> "$Log_File"

        exit_code=$?
        log "INFO" "FFmpeg exited with code $exit_code."

        # If stream ends cleanly, exit loop
        if [ "$exit_code" -eq 0 ]; then
            break
        else
            return 1
        fi
    done
}

# Retry loop to restart stream on failure
Retries=0
while [ "$Max_Retries" -eq -1 ] || [ "$Retries" -lt "$Max_Retries" ]; do
    start_stream
    exit_code=$?
    if [ "$exit_code" -eq 0 ]; then
        log "INFO" "Stream finished gracefully."
        break
    fi
    Retries=$((Retries + 1))
    log "WARN" "Retry $Retries of $Max_Retries. Waiting $Retry_Delay seconds..."
    sleep "$Retry_Delay"
done

# Final message on permanent failure
if [ "$Max_Retries" -ne -1 ] && [ "$Retries" -ge "$Max_Retries" ]; then
    log "ERROR" "Max retries reached. Exiting stream script."
    exit 1
fi
