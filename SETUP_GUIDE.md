# Frigate NVR Setup Guide - USB Camera on Ubuntu VM

This guide walks you through the complete process of setting up Frigate NVR in Docker on an Ubuntu virtual machine (running in VMware Player) with a USB camera connected to the host machine.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [VMware Player Setup - USB Camera Passthrough](#vmware-player-setup---usb-camera-passthrough)
3. [Ubuntu VM Configuration](#ubuntu-vm-configuration)
4. [Docker Installation](#docker-installation)
5. [Frigate Docker Setup](#frigate-docker-setup)
6. [Camera Configuration](#camera-configuration)
7. [Starting Frigate](#starting-frigate)
8. [Capturing Clips via API](#capturing-clips-via-api)
9. [Playing Clips in Browser](#playing-clips-in-browser)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- VMware Workstation Player installed on host machine (Windows/Linux)
- Ubuntu 22.04 LTS VM created in VMware Player
- USB webcam connected to host machine
- Host machine with at least 8GB RAM (4GB for VM recommended)
- Internet connectivity

---

## VMware Player Setup - USB Camera Passthrough

### Step 1: Configure USB Controller in VM Settings

1. **Shut down the Ubuntu VM** if running
2. Open VMware Player and select your Ubuntu VM
3. Click **"Edit virtual machine settings"**
4. Go to **Hardware** tab → Click **"Add..."**
5. Select **"USB Controller"** and click **Next**
6. Choose **USB 3.0** compatibility (or USB 2.0 if your camera doesn't support 3.0)
7. Click **Finish**

### Step 2: Connect USB Camera to VM

1. Start the Ubuntu VM
2. Once Ubuntu boots, plug in your USB camera to the host machine
3. In VMware Player menu: **VM** → **Removable Devices** → **[Your Camera Name]** → **Connect (Disconnect from host)**
4. Click **OK** if prompted that the device will be disconnected from host

### Step 3: Verify Camera Connection in VM

Open a terminal in Ubuntu VM and run:

```bash
# Check if camera is detected
lsusb

# List video devices
ls -la /dev/video*

# Install v4l-utils for camera testing
sudo apt update
sudo apt install v4l-utils -y

# List camera capabilities
v4l2-ctl --list-devices
v4l2-ctl -d /dev/video0 --list-formats-ext
```

You should see your camera listed as `/dev/video0` (or similar).

---

## Ubuntu VM Configuration

### Step 1: Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### Step 2: Install Required Packages

```bash
# Install essential tools
sudo apt install -y \
    curl \
    wget \
    git \
    v4l-utils \
    ffmpeg \
    jq
```

### Step 3: Set Up Permissions for Camera Access

```bash
# Add your user to video group
sudo usermod -aG video $USER

# Apply group changes (or log out and back in)
newgrp video

# Verify video device permissions
ls -la /dev/video*
```

---

## Docker Installation

### Step 1: Install Docker

```bash
# Install Docker using official script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Apply changes
newgrp docker

# Verify Docker installation
docker --version
docker run hello-world
```

### Step 2: Install Docker Compose

```bash
# Install Docker Compose plugin
sudo apt install docker-compose-plugin -y

# Verify installation
docker compose version
```

---

## Frigate Docker Setup

### Step 1: Clone This Repository

```bash
# Clone the repository
git clone https://github.com/Irfan22in/intution.git
cd intution
```

### Step 2: Create Required Directories

```bash
# Create storage directory for recordings
mkdir -p storage

# Set permissions
chmod 755 storage
```

### Step 3: Create Environment File

Create a `.env` file in the project root:

```bash
cat > .env << 'EOF'
# Timezone (change to your timezone)
TIMEZONE=America/New_York

# RTSP credentials (for restreaming)
FRIGATE_RTSP_USER=admin
FRIGATE_RTSP_PASSWORD=your_secure_password

# MQTT (optional - leave empty if not using)
MQTT_HOST=
MQTT_PORT=1883
MQTT_USER=
MQTT_PASSWORD=
EOF
```

---

## Camera Configuration

### Option A: USB Webcam (V4L2)

Edit `config/config.yml` to use your USB camera:

```yaml
mqtt:
  enabled: false

database:
  path: /media/frigate/frigate.db

api: {}

detectors:
  cpu1:
    type: cpu

model:
  width: 320
  height: 320
  input_tensor: nhwc
  input_pixel_format: rgb

go2rtc:
  streams:
    camera1:
      - "v4l2:///dev/video0"
  rtsp:
    listen: ":8554"

record:
  enabled: true
  retain:
    days: 7
    mode: all
  events:
    pre_capture: 20
    post_capture: 20
    retain:
      default: 30
      mode: active_objects
    objects:
      - person
      - car

snapshots:
  enabled: true
  retain:
    default: 30
  quality: 90
  timestamp: true
  bounding_box: true

live:
  height: 720
  quality: 8

objects:
  track:
    - person
    - car
    - dog
    - cat

cameras:
  camera1:
    enabled: true
    ffmpeg:
      inputs:
        - path: rtsp://127.0.0.1:8554/camera1
          roles:
            - detect
            - record
      output_args:
        record: preset-record-generic-audio-copy
    detect:
      width: 1280
      height: 720
      fps: 5
      enabled: true
    objects:
      track:
        - person
        - car
    record:
      enabled: true
      retain:
        days: 7
        mode: all
      events:
        pre_capture: 20
        post_capture: 20
        objects:
          - person
          - car
        retain:
          default: 30
          mode: active_objects
    snapshots:
      enabled: true
      timestamp: true
      bounding_box: true
```

### Option B: IP Camera (RTSP)

If you have an IP camera instead, update the camera configuration:

```yaml
go2rtc:
  streams:
    camera1:
      - "rtsp://username:password@camera-ip:554/stream1"
```

---

## Starting Frigate

### Step 1: Update Docker Compose for USB Camera

The `docker-compose.yaml` needs device passthrough. It's already configured, but verify:

```yaml
services:
  frigate:
    # ... other settings ...
    privileged: true  # Required for device access
    devices:
      - /dev/video0:/dev/video0  # Add this line for USB camera
```

### Step 2: Start Frigate

```bash
# Start Frigate in detached mode
docker compose up -d

# Check if container is running
docker ps

# View logs
docker compose logs -f frigate
```

### Step 3: Verify Frigate is Running

Open a browser in the Ubuntu VM and navigate to:

```
http://localhost:5000
```

You should see the Frigate web interface with your camera feed.

---

## Capturing Clips via API

Frigate provides a REST API to access recordings, events, and clips. No C# required - use `curl` or any HTTP client.

### API Base URL

```
http://localhost:5000/api
```

### Get Latest Events

```bash
# Get latest 10 events with clips
curl -s "http://localhost:5000/api/events?limit=10&has_clip=true" | jq

# Get events for specific camera
curl -s "http://localhost:5000/api/events?camera=camera1&limit=5" | jq

# Get events with person detection
curl -s "http://localhost:5000/api/events?label=person&limit=5" | jq
```

### Get Event Details

```bash
# Get specific event by ID
EVENT_ID="1234567890.123456-abc123"
curl -s "http://localhost:5000/api/events/$EVENT_ID" | jq
```

### Download Event Clip (MP4)

```bash
# Get event clip URL format
# http://localhost:5000/api/events/{event_id}/clip.mp4

# Download clip to file
EVENT_ID="your_event_id_here"
curl -o event_clip.mp4 "http://localhost:5000/api/events/$EVENT_ID/clip.mp4"

# Or get latest event clip automatically
LATEST_EVENT_ID=$(curl -s "http://localhost:5000/api/events?camera=camera1&limit=1&has_clip=true" | jq -r '.[0].id')
echo "Latest Event ID: $LATEST_EVENT_ID"
curl -o latest_clip.mp4 "http://localhost:5000/api/events/$LATEST_EVENT_ID/clip.mp4"
```

### Get Event Thumbnail

```bash
# Download thumbnail
curl -o thumbnail.jpg "http://localhost:5000/api/events/$EVENT_ID/thumbnail.jpg"
```

### Get Recording Segments

```bash
# Get recordings for a time range (Unix timestamps)
START_TIME=$(date -d "1 hour ago" +%s)
END_TIME=$(date +%s)

curl -s "http://localhost:5000/api/camera1/recordings?after=$START_TIME&before=$END_TIME" | jq
```

### Export Recording Clip

```bash
# Export a specific time range as clip
# Format: /api/{camera}/start/{start_timestamp}/end/{end_timestamp}/clip.mp4

START_TIME=$(date -d "5 minutes ago" +%s)
END_TIME=$(date +%s)

curl -o custom_clip.mp4 "http://localhost:5000/api/camera1/start/$START_TIME/end/$END_TIME/clip.mp4"
```

### Trigger Manual Event

```bash
# Create a manual event (useful for testing)
curl -X POST "http://localhost:5000/api/events/camera1/create" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "person",
    "sub_label": "manual_test",
    "duration": 30
  }'
```

### Useful Scripts

Create a script to get the latest clip:

```bash
cat > get_latest_clip.sh << 'EOF'
#!/bin/bash

FRIGATE_URL="http://localhost:5000"
CAMERA="camera1"
OUTPUT_DIR="./clips"

mkdir -p $OUTPUT_DIR

# Get latest event with clip
RESPONSE=$(curl -s "$FRIGATE_URL/api/events?camera=$CAMERA&limit=1&has_clip=true")
EVENT_ID=$(echo $RESPONSE | jq -r '.[0].id')
EVENT_LABEL=$(echo $RESPONSE | jq -r '.[0].label')
EVENT_TIME=$(echo $RESPONSE | jq -r '.[0].start_time')

if [ "$EVENT_ID" != "null" ] && [ -n "$EVENT_ID" ]; then
    FILENAME="$OUTPUT_DIR/${EVENT_LABEL}_${EVENT_TIME}.mp4"
    echo "Downloading clip for event: $EVENT_ID"
    curl -o "$FILENAME" "$FRIGATE_URL/api/events/$EVENT_ID/clip.mp4"
    echo "Saved to: $FILENAME"
else
    echo "No events with clips found"
fi
EOF

chmod +x get_latest_clip.sh
```

---

## Playing Clips in Browser

### Method 1: Frigate Web UI (Recommended)

1. Open browser in Ubuntu VM
2. Navigate to `http://localhost:5000`
3. Click on **Events** in the left sidebar
4. Click on any event to view the clip
5. Use the built-in video player to play/pause/seek

### Method 2: Direct URL in Browser

```
# View live stream
http://localhost:5000/api/camera1

# View specific event clip
http://localhost:5000/api/events/{event_id}/clip.mp4
```

### Method 3: Create Simple HTML Player

Create a simple HTML file to play clips:

```bash
cat > clip_player.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Frigate Clip Player</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #1a1a1a; color: #fff; }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 { color: #4CAF50; }
        video { width: 100%; max-width: 800px; background: #000; }
        .events { margin-top: 20px; }
        .event-item { 
            background: #333; 
            padding: 10px; 
            margin: 5px 0; 
            border-radius: 5px;
            cursor: pointer;
        }
        .event-item:hover { background: #444; }
        button {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 10px 20px;
            margin: 5px;
            cursor: pointer;
            border-radius: 5px;
        }
        button:hover { background: #45a049; }
        #status { color: #888; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎬 Frigate Clip Player</h1>
        
        <div>
            <button onclick="loadEvents()">Refresh Events</button>
            <button onclick="loadLatestClip()">Play Latest Clip</button>
        </div>
        
        <p id="status">Click "Refresh Events" to load available clips</p>
        
        <video id="player" controls>
            <source id="videoSource" src="" type="video/mp4">
            Your browser does not support the video tag.
        </video>
        
        <div class="events" id="eventsList"></div>
    </div>

    <script>
        const FRIGATE_URL = 'http://localhost:5000';
        
        async function loadEvents() {
            document.getElementById('status').textContent = 'Loading events...';
            try {
                const response = await fetch(`${FRIGATE_URL}/api/events?limit=20&has_clip=true`);
                const events = await response.json();
                displayEvents(events);
                document.getElementById('status').textContent = `Loaded ${events.length} events`;
            } catch (error) {
                document.getElementById('status').textContent = 'Error loading events: ' + error.message;
            }
        }
        
        function displayEvents(events) {
            const container = document.getElementById('eventsList');
            container.innerHTML = '<h3>Recent Events:</h3>';
            
            events.forEach(event => {
                const date = new Date(event.start_time * 1000);
                const div = document.createElement('div');
                div.className = 'event-item';
                div.innerHTML = `
                    <strong>${event.label}</strong> - ${event.camera}<br>
                    <small>${date.toLocaleString()}</small>
                `;
                div.onclick = () => playClip(event.id);
                container.appendChild(div);
            });
        }
        
        function playClip(eventId) {
            const clipUrl = `${FRIGATE_URL}/api/events/${eventId}/clip.mp4`;
            document.getElementById('videoSource').src = clipUrl;
            document.getElementById('player').load();
            document.getElementById('player').play();
            document.getElementById('status').textContent = `Playing event: ${eventId}`;
        }
        
        async function loadLatestClip() {
            try {
                const response = await fetch(`${FRIGATE_URL}/api/events?limit=1&has_clip=true`);
                const events = await response.json();
                if (events.length > 0) {
                    playClip(events[0].id);
                } else {
                    document.getElementById('status').textContent = 'No clips available';
                }
            } catch (error) {
                document.getElementById('status').textContent = 'Error: ' + error.message;
            }
        }
        
        // Load events on page load
        loadEvents();
    </script>
</body>
</html>
EOF

# Open in browser
firefox clip_player.html &
# or
xdg-open clip_player.html
```

### Method 4: Using VLC

```bash
# Install VLC
sudo apt install vlc -y

# Play clip directly
vlc "http://localhost:5000/api/events/{event_id}/clip.mp4"

# Play live RTSP stream
vlc "rtsp://localhost:8554/camera1"
```

---

## Troubleshooting

### Camera Not Detected in VM

```bash
# Check USB passthrough
lsusb

# If camera not listed, reconnect in VMware:
# VM → Removable Devices → [Camera] → Connect

# Check video devices
ls -la /dev/video*

# If no video devices, camera driver may be missing
sudo apt install linux-generic
```

### Frigate Container Won't Start

```bash
# Check container logs
docker compose logs frigate

# Check if port 5000 is in use
sudo netstat -tlnp | grep 5000

# Restart container
docker compose down
docker compose up -d
```

### Camera Feed Not Showing

```bash
# Test camera with ffmpeg
ffmpeg -f v4l2 -i /dev/video0 -frames:v 1 test.jpg

# Check go2rtc streams
curl http://localhost:5000/api/go2rtc

# Verify camera configuration
cat config/config.yml
```

### Events Not Recording

```bash
# Check storage permissions
ls -la storage/

# Verify recording is enabled in config
grep -A 10 "record:" config/config.yml

# Check disk space
df -h
```

### API Not Responding

```bash
# Check if Frigate is running
docker ps | grep frigate

# Test API
curl -v http://localhost:5000/api/stats
```

---

## Quick Reference - API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/stats` | GET | System statistics |
| `/api/events` | GET | List events |
| `/api/events/{id}` | GET | Event details |
| `/api/events/{id}/clip.mp4` | GET | Event clip video |
| `/api/events/{id}/thumbnail.jpg` | GET | Event thumbnail |
| `/api/{camera}/recordings` | GET | Recording segments |
| `/api/{camera}/start/{s}/end/{e}/clip.mp4` | GET | Custom clip |
| `/api/events/{camera}/create` | POST | Create manual event |

---

## Summary

1. **VMware Setup**: Pass USB camera to Ubuntu VM via VMware → Removable Devices
2. **Install Docker**: Use official Docker installation script
3. **Clone Repo**: Get configuration files from this repository
4. **Configure Camera**: Edit `config/config.yml` for V4L2 USB camera
5. **Start Frigate**: Run `docker compose up -d`
6. **Access UI**: Open `http://localhost:5000` in browser
7. **Use API**: Retrieve clips using curl or HTTP requests
8. **Play Clips**: Use Frigate UI, browser, or VLC

For questions or issues, check the [Frigate documentation](https://docs.frigate.video/).
