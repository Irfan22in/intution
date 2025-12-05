#!/bin/bash

# Frigate API Helper Scripts
# Use these commands to interact with Frigate API without C#

FRIGATE_URL="${FRIGATE_URL:-http://localhost:5000}"
CAMERA="${CAMERA:-camera1}"
OUTPUT_DIR="${OUTPUT_DIR:-./clips}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function: Show help
show_help() {
    echo "Frigate API Helper"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  status          - Check Frigate status"
    echo "  events          - List recent events"
    echo "  latest          - Get and download latest event clip"
    echo "  clip [event_id] - Download specific event clip"
    echo "  thumbnail [id]  - Download event thumbnail"
    echo "  export [mins]   - Export last N minutes of recording"
    echo "  live            - Show live stream URL"
    echo ""
    echo "Environment Variables:"
    echo "  FRIGATE_URL  - Frigate server URL (default: http://localhost:5000)"
    echo "  CAMERA       - Camera name (default: camera1)"
    echo "  OUTPUT_DIR   - Output directory for clips (default: ./clips)"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 events"
    echo "  $0 latest"
    echo "  $0 clip 1234567890.123456-abc123"
    echo "  $0 export 5"
}

# Function: Check Frigate status
check_status() {
    echo -e "${YELLOW}Checking Frigate status...${NC}"
    RESPONSE=$(curl -s "$FRIGATE_URL/api/stats")
    if [ $? -eq 0 ] && [ -n "$RESPONSE" ]; then
        echo -e "${GREEN}Frigate is running!${NC}"
        echo "$RESPONSE" | jq '.'
    else
        echo -e "${RED}Error: Cannot connect to Frigate at $FRIGATE_URL${NC}"
        exit 1
    fi
}

# Function: List recent events
list_events() {
    echo -e "${YELLOW}Fetching recent events...${NC}"
    RESPONSE=$(curl -s "$FRIGATE_URL/api/events?camera=$CAMERA&limit=10&has_clip=true")
    if [ $? -eq 0 ]; then
        echo "$RESPONSE" | jq -r '.[] | "ID: \(.id)\n  Label: \(.label)\n  Time: \(.start_time | todate)\n  Has Clip: \(.has_clip)\n"'
    else
        echo -e "${RED}Error fetching events${NC}"
        exit 1
    fi
}

# Function: Get and download latest event clip
get_latest() {
    echo -e "${YELLOW}Fetching latest event with clip...${NC}"
    RESPONSE=$(curl -s "$FRIGATE_URL/api/events?camera=$CAMERA&limit=1&has_clip=true")
    
    EVENT_ID=$(echo "$RESPONSE" | jq -r '.[0].id')
    EVENT_LABEL=$(echo "$RESPONSE" | jq -r '.[0].label')
    EVENT_TIME=$(echo "$RESPONSE" | jq -r '.[0].start_time')
    
    if [ "$EVENT_ID" != "null" ] && [ -n "$EVENT_ID" ]; then
        FILENAME="$OUTPUT_DIR/${EVENT_LABEL}_${EVENT_TIME}.mp4"
        echo -e "${GREEN}Found event: $EVENT_ID${NC}"
        echo "Label: $EVENT_LABEL"
        echo "Time: $(date -d @$EVENT_TIME)"
        echo ""
        echo -e "${YELLOW}Downloading clip...${NC}"
        curl -o "$FILENAME" "$FRIGATE_URL/api/events/$EVENT_ID/clip.mp4"
        echo -e "${GREEN}Saved to: $FILENAME${NC}"
        echo ""
        echo "Play in browser: $FRIGATE_URL/api/events/$EVENT_ID/clip.mp4"
    else
        echo -e "${RED}No events with clips found${NC}"
        exit 1
    fi
}

# Function: Download specific event clip
get_clip() {
    EVENT_ID=$1
    if [ -z "$EVENT_ID" ]; then
        echo -e "${RED}Error: Event ID required${NC}"
        echo "Usage: $0 clip [event_id]"
        exit 1
    fi
    
    echo -e "${YELLOW}Downloading clip for event: $EVENT_ID${NC}"
    FILENAME="$OUTPUT_DIR/event_${EVENT_ID}.mp4"
    curl -o "$FILENAME" "$FRIGATE_URL/api/events/$EVENT_ID/clip.mp4"
    
    if [ -f "$FILENAME" ] && [ -s "$FILENAME" ]; then
        echo -e "${GREEN}Saved to: $FILENAME${NC}"
    else
        echo -e "${RED}Error downloading clip${NC}"
        rm -f "$FILENAME"
        exit 1
    fi
}

# Function: Download event thumbnail
get_thumbnail() {
    EVENT_ID=$1
    if [ -z "$EVENT_ID" ]; then
        echo -e "${RED}Error: Event ID required${NC}"
        echo "Usage: $0 thumbnail [event_id]"
        exit 1
    fi
    
    echo -e "${YELLOW}Downloading thumbnail for event: $EVENT_ID${NC}"
    FILENAME="$OUTPUT_DIR/thumbnail_${EVENT_ID}.jpg"
    curl -o "$FILENAME" "$FRIGATE_URL/api/events/$EVENT_ID/thumbnail.jpg"
    
    if [ -f "$FILENAME" ] && [ -s "$FILENAME" ]; then
        echo -e "${GREEN}Saved to: $FILENAME${NC}"
    else
        echo -e "${RED}Error downloading thumbnail${NC}"
        rm -f "$FILENAME"
        exit 1
    fi
}

# Function: Export last N minutes of recording
export_recording() {
    MINUTES=${1:-5}
    
    END_TIME=$(date +%s)
    START_TIME=$((END_TIME - MINUTES * 60))
    
    echo -e "${YELLOW}Exporting last $MINUTES minutes of recording...${NC}"
    echo "From: $(date -d @$START_TIME)"
    echo "To: $(date -d @$END_TIME)"
    
    FILENAME="$OUTPUT_DIR/recording_${START_TIME}_${END_TIME}.mp4"
    curl -o "$FILENAME" "$FRIGATE_URL/api/$CAMERA/start/$START_TIME/end/$END_TIME/clip.mp4"
    
    if [ -f "$FILENAME" ] && [ -s "$FILENAME" ]; then
        echo -e "${GREEN}Saved to: $FILENAME${NC}"
    else
        echo -e "${RED}Error exporting recording${NC}"
        rm -f "$FILENAME"
        exit 1
    fi
}

# Function: Show live stream URL
show_live() {
    echo -e "${GREEN}Live Stream URLs:${NC}"
    echo ""
    echo "Web UI:     $FRIGATE_URL"
    echo "Camera:     $FRIGATE_URL/api/$CAMERA"
    echo "RTSP:       rtsp://localhost:8554/$CAMERA"
    echo "WebRTC:     $FRIGATE_URL/live/$CAMERA"
}

# Main
case "$1" in
    status)
        check_status
        ;;
    events)
        list_events
        ;;
    latest)
        get_latest
        ;;
    clip)
        get_clip "$2"
        ;;
    thumbnail)
        get_thumbnail "$2"
        ;;
    export)
        export_recording "$2"
        ;;
    live)
        show_live
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac
