# Frigate NVR + Optix Event Capture Integration

This repository provides all configuration needed to run Frigate NVR in Docker and integrate event-based video clips (20s before and 20s after each event) with Optix through C# NetLogic.

## Included Files

- `docker-compose.yml`: Frigate Docker Compose service
- `.env`: Environment variables for Frigate and MQTT
- `config/config.yml`: Frigate main configuration for recording, clips, MQTT, camera, and RTSP restreaming
- `FrigateEventHandler.cs`: C# NetLogic class for Optix to grab event clips from Frigate's API
- `README.md`: This file

## How it works

1. Docker Compose runs Frigate, which detects events and records MP4 clips (20s before + 20s after events)
2. Optix NetLogic (C#) queries the Frigate API and finds the latest event and its MP4 clip URL
3. Optix UI can display a button or video widget to playback the event clip

## Setup

1. **Edit `.env` file**  
   Configure your timezone, Frigate RTSP credentials, and MQTT settings.

2. **Edit `config/config.yml`**  
   Change RTSP `path` under `camera1` to match your camera stream.

3. **Run Frigate**  
   ```
   docker-compose up -d
   ```

4. **Optix Project**  
   - Add variables: Model/EventActive, Model/LastEventId, Model/EventClipUrl, Model/EventThumbnailUrl
   - Add the NetLogic `FrigateEventHandler.cs`
   - Hook up buttons to call `PlayEventClip()` or bind a video widget to `EventClipUrl`

## Frigate API endpoints of interest

- **Latest event:**  
  ```
  GET /api/events?camera=camera1&limit=1&has_clip=true
  ```

- **Event clip MP4:**  
  ```
  /api/events/{event_id}/clip.mp4
  ```

- **Event thumbnail:**  
  ```
  /api/events/{event_id}/thumbnail.jpg
  ```

Enjoy!
