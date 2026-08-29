# fixed_mood_frame

Consolidated, working copy of MoodFrame: iOS app + backend + firmware, with the
fixes applied during setup/testing on this Mac.

## What's in here

```
ios_app/     SwiftUI app (Xcode project) — same as MoodFrame/ in the original zip
backend/     FastAPI server + the real fine-tuned emotion model
tag_firmware/  ESP32 e-paper tag firmware (unmodified)
```

## Fixes applied vs. the original zip

- **ios_app/MoodFrame/MoodAPI.swift** — `baseURL` now points at the backend
  running on this Mac's local IP (`http://172.30.1.9:8000`) instead of a dead
  Cloudflare tunnel URL. If your Mac's IP changes (check with
  `ipconfig getifaddr en0`), update this and rebuild.
- **ios_app/MoodFrame/Views/MainView.swift** — the "save this image to your
  diary?" prompt was a system `confirmationDialog` that could render with only
  one visible button on this iOS version. Replaced with a custom card that
  always shows both **저장하기** (save) and **저장 안 함** (don't save).
- **backend/comfort_image.py** — removed a `DPMSolverMultistepScheduler`
  swap that crashed with an `IndexError` on the last diffusion step (a
  version mismatch with the installed `diffusers==0.36`). Uses the pipeline's
  default scheduler instead.
- **backend/app.py** — `/support` now calls `comfort_from_emotion(..., for_epd=False, send_to_tag=False)`
  so it generates a full photorealistic comfort photo and doesn't spend ~10s
  scanning for a BLE tag device that isn't connected. Flip these back to
  `True` once you have the physical tag.
- **backend/config.py** / **backend/comfort_image.py** — added
  `GOEMOTIONS_TO_BUCKET`, mapping all 28 GoEmotions labels (the model's real
  output) down to the 8 art-style buckets `comfort_image.py` knows about, so
  labels like "excitement" or "curiosity" get a matching image style instead
  of always falling back to "neutral".

## Running the backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -m uvicorn app:app --host 0.0.0.0 --port 8000
```

First request will be slow (loads the emotion model + Stable Diffusion
pipeline into memory). Each `/support` call after that takes ~20-35s on
Apple Silicon (MPS) since it runs real local image generation.

`backend/emotion-model-goemotions/` is the actual fine-tuned model
referenced by `config.py`'s `EMOTION_MODEL` — no download needed.

## Running the iOS app

1. Open `ios_app/MoodFrame.xcodeproj` in Xcode.
2. Target → Signing & Capabilities → set your own Team (the bundled one is
   `com.sumaiya.moodframe` / your personal team; change if it conflicts).
3. Confirm `MoodAPI.swift`'s `baseURL` matches your Mac's current LAN IP and
   the backend above is running.
4. Build & run on a real device (BLE doesn't work in the simulator). Phone
   and Mac must be on the same Wi-Fi.

## Not included

Older training checkpoints (`goemotions-ckpt/`, `emotion-model/`, etc.) and
the `.venv`/`venv` folders from the original project were left out to keep
this bundle a reasonable size — only the one model actually used by
`config.py` (`emotion-model-goemotions`) is included.
