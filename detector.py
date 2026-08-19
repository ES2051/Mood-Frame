"""detector.py — text in, detected emotion + confidence out."""
from transformers import pipeline
import config

_classifier = pipeline("text-classification", model=config.EMOTION_MODEL, top_k=None)


def detect_emotion(text: str) -> dict:
    scores = _classifier(text)[0]
    scores = sorted(scores, key=lambda x: x["score"], reverse=True)
    top = scores[0]
    return {
        "emotion": top["label"],
        "confidence": round(top["score"], 4),
        "uncertain": top["score"] < config.LOW_CONFIDENCE,
        "all_scores": [
            {"label": s["label"], "score": round(s["score"], 4)} for s in scores
        ],
    }
