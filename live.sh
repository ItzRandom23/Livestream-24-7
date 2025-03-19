#!/bin/bash
#-------------------------------------------------------------------------------------------------------------
# Customization Section
Video_File="/workspaces/Livestream-24-7/video.mp4"          # Path to the video file to stream
Audio_File="/workspaces/Livestream-24-7/songs/Polvo Rodante.mp3"  # Path to the audio file to stream
Audio_Bitrate="128k"                                       # Audio bitrate (e.g., 64k, 128k, 192k)
Audio_Sample_Rate="44100"                                  # Audio sample rate (e.g., 44100, 48000)
FPS=30                                                     # Frames per second for video
Video_Quality="1440p"                                      # Video quality (144p, 360p, 480p, 720p, 1080p, 1440p, 2160p)
Video_Encoder="libx264"                                    # Video encoder (e.g., libx264, libx265, nvenc)
Preset="veryfast"                                          # Encoding preset (e.g., ultrafast, veryfast, fast, medium, slow)
Stream_Key="76m4-wxqb-apm6-7bzb-brwq"                      # RTMP stream key
RTMP_URL="rtmp://a.rtmp.youtube.com/live2"                 # RTMP server URL
Retry_Delay=5                                              # Seconds to wait before retrying after failure
Max_Retries=10                                             # Maximum number of retries before giving up (-1 for infinite)
Thread_Count=0                                             # Number of threads for FFmpeg (0 = auto)
Log_File="/tmp/stream_log_$(date +%Y%m%d_%H%M%S).txt"      # Path to the log file
Log_Level="INFO"                                           # Log verbosity (INFO, WARN, ERROR)
Buffer_Multiplier=2                                        # Multiplier for bufsize relative to Video_Bitrate
#-------------------------------------------------------------------------------------------------------------

# Logging function with level filtering
log() {
    local level="$1"
    shift
    case "$Log_Level" in
        "ERROR") [[ "$level" != "ERROR" ]] && return ;;
        "WARN")  [[ "$level" == "INFO" ]] && return ;;
        "INFO")  : ;; # Log everything
        *) log "ERROR" "Invalid Log_Level '$Log_Level'. Defaulting to INFO."; Log_Level="INFO" ;;
    esac
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level]: $*" | tee -a "$Log_File"
}

# Function to perform cleanup on exit
cleanup() {
    log "INFO" "Stopping stream..."
    killall ffmpeg 2>/dev/null
    exit 0
}
trap cleanup INT TERM

# Initial log entry
log "INFO" "Starting stream script"

# Check for required commands and inputs
if ! command -v ffmpeg &>/dev/null; then
    log "ERROR" "ffmpeg is not installed!"
    exit 1
fi

if ! [[ "$FPS" =~ ^[0-9]+$ ]] || [ "$FPS" -le 0 ]; then
    log "ERROR" "FPS must be a positive integer, got '$FPS'!"
    exit 1
fi

if ! [[ "$Retry_Delay" =~ ^[0-9]+$ ]] || [ "$Retry_Delay" -lt 0 ]; then
    log "ERROR" "Retry_Delay must be a non-negative integer, got '$Retry_Delay'!"
    exit 1
fi

if ! [[ "$Max_Retries" =~ ^-?[0-9]+$ ]]; then
    log "ERROR" "Max_Retries must be an integer, got '$Max_Retries'!"
    exit 1
fi

if ! [[ "$Thread_Count" =~ ^[0-9]+$ ]] || [ "$Thread_Count" -lt 0 ]; then
    log "ERROR" "Thread_Count must be a non-negative integer, got '$Thread_Count'!"
    exit 1
fi

[ ! -r "$Video_File" ] && { log "ERROR" "Cannot read video file at '$Video_File'!"; exit 1; }
[ ! -r "$Audio_File" ] && { log "ERROR" "Cannot read audio file at '$Audio_File'!"; exit 1; }
[ -z "$Stream_Key" ] && { log "ERROR" "Stream key is missing!"; exit 1; }
[ -z "$RTMP_URL" ] && { log "ERROR" "RTMP URL is missing!"; exit 1; }

# Set resolution and bitrate based on Video_Quality
case "$Video_Quality" in
    "2160p") Resolution="3840x2160"; Video_Bitrate="5000k" ;; # 4K UHD
    "1440p") Resolution="2560x1440"; Video_Bitrate="4000k" ;; # 2K QHD
    "1080p") Resolution="1920x1080"; Video_Bitrate="3000k" ;; # Full HD
    "720p")  Resolution="1280x720";  Video_Bitrate="1500k" ;;
    "480p")  Resolution="854x480";   Video_Bitrate="1000k" ;;
    "360p")  Resolution="640x360";   Video_Bitrate="750k" ;;
    "144p")  Resolution="256x144";   Video_Bitrate="400k" ;;
    *) log "ERROR" "Invalid video quality '$Video_Quality'!"; exit 1 ;;
esac

# Validate and calculate buffer size
Numeric_Bitrate=${Video_Bitrate%k}
if ! [[ "$Numeric_Bitrate" =~ ^[0-9]+$ ]]; then
    log "ERROR" "Invalid Video_Bitrate format '$Video_Bitrate'!"
    exit 1
fi
if ! [[ "$Buffer_Multiplier" =~ ^[0-9]+$ ]] || [ "$Buffer_Multiplier" -lt 1 ]; then
    log "ERROR" "Buffer_Multiplier must be a positive integer, got '$Buffer_Multiplier'!"
    exit 1
fi
bufsize=$((Numeric_Bitrate * 1000 * Buffer_Multiplier))

# Function to start ffmpeg stream and confirm it's live
start_stream() {
    log "INFO" "Starting FFmpeg stream to $RTMP_URL/$Stream_Key ..."
    ffmpeg -stream_loop -1 -re -i "$Video_File" \
           -stream_loop -1 -re -i "$Audio_File" \
           -c:v "$Video_Encoder" -preset "$Preset" -r "$FPS" -g $((FPS * 2)) -threads "$Thread_Count" \
           -b:v "$Video_Bitrate" -maxrate "$Video_Bitrate" -bufsize "$bufsize" \
           -pix_fmt yuv420p -s "$Resolution" \
           -c:a aac -b:a "$Audio_Bitrate" -ar "$Audio_Sample_Rate" -async 1 -strict experimental \
           -map 0:v:0 -map 1:a:0 -f flv -flvflags no_duration_filesize "$RTMP_URL/$Stream_Key" 2>> "$Log_File" &
    FFMPEG_PID=$!

    # Wait a few seconds and check if FFmpeg is still running
    sleep 3
    if ps -p $FFMPEG_PID > /dev/null; then
        log "INFO" "STREAM_LIVE: Stream has started successfully."
        echo "STREAM_LIVE" # Output to stdout for Node.js to detect
    else
        log "ERROR" "FFmpeg failed to start."
        return 1
    fi
    wait $FFMPEG_PID
    return $?
}

# Retry loop: restart stream with configurable retries
Retries=0
while [ "$Max_Retries" -eq -1 ] || [ "$Retries" -lt "$Max_Retries" ]; do
    start_stream
    exit_code=$?
    log "INFO" "FFmpeg stopped with exit code $exit_code."
    if [ "$exit_code" -eq 0 ]; then
        log "INFO" "Stream ended successfully."
        break
    fi
    Retries=$((Retries + 1))
    log "WARN" "Retry $Retries of $Max_Retries (or infinite if -1). Retrying in $Retry_Delay seconds..."
    sleep "$Retry_Delay"
done

if [ "$Max_Retries" -ne -1 ] && [ "$Retries" -ge "$Max_Retries" ]; then
    log "ERROR" "Maximum retries ($Max_Retries) reached. Exiting."
    exit 1
fi