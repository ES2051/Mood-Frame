"""app.py — the API server (with CORS so the frontend can call it)."""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import os

import config
from detection_multi import detect_emotion
from safety import needs_support, support_response
from comfort_image import comfort_from_emotion

app = FastAPI(title="Mood Frame API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs(config.GENERATED_DIR, exist_ok=True)
app.mount("/images", StaticFiles(directory=config.GENERATED_DIR), name="images")


class TextIn(BaseModel):
    text: str
    use_claude_prompt: bool = False


@app.get("/health")
def health():
    return {"status": "ok", "model": config.EMOTION_MODEL}


@app.post("/support")
def support(payload: TextIn, request: Request):
    detection = detect_emotion(payload.text)
    if needs_support(payload.text, detection):
        return support_response(detection)

    paths = comfort_from_emotion(
        detection["emotion"],
        payload.text,
        use_claude=payload.use_claude_prompt,
        for_epd=False,      # no e-paper tag connected -- use the full photorealistic prompt
        send_to_tag=False,  # skip the BLE scan/send so requests don't hang waiting for the tag
    )
    base = str(request.base_url).rstrip("/")
    return {
        "type": "image",
        "detection": detection,
        "image_url": f"{base}/images/{os.path.basename(paths['original'])}",
        "tag_sent": paths.get("tag_sent"),
    }


# Serves static/index.html at "/" -- must be mounted last so it doesn't
# shadow the API routes above.
app.mount("/", StaticFiles(directory="static", html=True), name="frontend")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)