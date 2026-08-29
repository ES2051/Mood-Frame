"""
detector.py — multi-label version (GoEmotions, 28 emotions).

Returns EVERY emotion above the threshold, not just one:
  "I'm excited but nervous" -> ["excitement", "nervousness"]
"""
from transformers import pipeline
import config

_classifier = pipeline(
    "text-classification",
    model=config.EMOTION_MODEL,
    top_k=None,
    function_to_apply="sigmoid",   # multi-label: sigmoid, not softmax
)


def detect_emotion(text: str) -> dict:
    scores = _classifier(text)[0]
    scores = sorted(scores, key=lambda x: x["score"], reverse=True)

    # everything clearing the bar -- can be several, or none
    active = [s for s in scores if s["score"] >= config.EMOTION_THRESHOLD]
    top = scores[0]

    return {
        "emotion": top["label"],                        # strongest (drives the image)
        "emotions": [s["label"] for s in active],       # all detected
        "confidence": round(top["score"], 4),
        "uncertain": top["score"] < config.LOW_CONFIDENCE,
        "all_scores": [
            {"label": s["label"], "score": round(s["score"], 4)} for s in scores[:8]
        ],
    }