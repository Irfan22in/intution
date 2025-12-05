# Frigate NVR Docker Setup

This repository provides configuration and tools for running Frigate NVR in Docker, with support for USB webcams on a Ubuntu VM (VMware Player).

## 📋 Documentation

- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Complete step-by-step setup guide for:
  - VMware Player USB camera passthrough
  - Ubuntu VM configuration
  - Docker installation
  - Frigate Docker setup
  - Camera configuration (USB and IP cameras)
  - API-based clip capture (no C# required)
  - Browser-based clip playback

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/Irfan22in/intution.git
   cd intution
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Configure camera** (USB webcam)
   ```bash
   cp config/config.usb-camera.yml config/config.yml
   ```

4. **Start Frigate**
   ```bash
   docker compose up -d
   ```

5. **Access Frigate**
   - Web UI: http://localhost:5000
   - RTSP Stream: rtsp://localhost:8554/camera1

## 📁 Repository Structure

```
.
├── README.md                    # This file
├── SETUP_GUIDE.md              # Complete setup documentation
├── docker-compose.yaml         # Docker Compose configuration
├── .env.example                # Environment variables template
├── clip-player.html            # Browser-based clip player
├── config/
│   ├── config.yml              # Main Frigate configuration
│   ├── config.usb-camera.yml   # USB webcam configuration template
│   └── FrigateEventHandler.cs  # C# integration (optional, for Optix)
└── scripts/
    └── frigate-api.sh          # Shell script for API interactions
```

## 🎬 Capturing & Playing Clips

### Using the API Helper Script

```bash
# Make script executable
chmod +x scripts/frigate-api.sh

# Check status
./scripts/frigate-api.sh status

# List recent events
./scripts/frigate-api.sh events

# Download latest clip
./scripts/frigate-api.sh latest

# Export last 5 minutes of recording
./scripts/frigate-api.sh export 5
```

### Using curl

```bash
# Get latest event with clip
curl -s "http://localhost:5000/api/events?limit=1&has_clip=true" | jq

# Download a clip
EVENT_ID="your_event_id"
curl -o clip.mp4 "http://localhost:5000/api/events/$EVENT_ID/clip.mp4"
```

### Using the Browser Player

Open `clip-player.html` in your browser to view and play clips with a nice UI.

## 🔌 API Endpoints

| Endpoint | Description |
|----------|-------------|
| `/api/stats` | System statistics |
| `/api/events?limit=N` | List events |
| `/api/events/{id}/clip.mp4` | Download event clip |
| `/api/events/{id}/thumbnail.jpg` | Event thumbnail |
| `/api/{camera}/start/{s}/end/{e}/clip.mp4` | Export custom clip |

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for complete API documentation.

## ⚙️ Configuration

### USB Camera (Webcam)

The default configuration uses a USB webcam via V4L2. Edit `config/config.yml`:

```yaml
go2rtc:
  streams:
    camera1:
      - "v4l2:///dev/video0"
```

### IP Camera (RTSP)

For IP cameras, update the stream source:

```yaml
go2rtc:
  streams:
    camera1:
      - "rtsp://user:pass@camera-ip:554/stream1"
```

## 🛠️ Troubleshooting

See the [Troubleshooting section](SETUP_GUIDE.md#troubleshooting) in the setup guide.

## 📚 Resources

- [Frigate Documentation](https://docs.frigate.video/)
- [go2rtc Documentation](https://github.com/AlexxIT/go2rtc)
- [VMware USB Passthrough Guide](https://docs.vmware.com/en/VMware-Workstation-Player/)

---

## Legacy: Optix Integration

For C# integration with Rockwell Optix, see `config/FrigateEventHandler.cs`. This is optional and not required for basic clip capture and playback.

