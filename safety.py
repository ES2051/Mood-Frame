"""
safety.py
The caring branch: when someone may be in real distress, they need a person,
not a picture. This routes those cases to support resources.

IMPORTANT: this is a BASIC safety net, not a clinical or crisis-detection tool.
Phrase matching misses a lot and flags some false positives. For a real product,
use a purpose-built risk model and involve mental-health professionals.
"""

import config

# Minimal set of phrases that suggest someone may need immediate human support.
# Kept deliberately short and non-graphic. Expand thoughtfully for your users.
_CONCERN_PHRASES = [
    "i want to die",
    "i don't want to be here",
    "can't go on",
    "no reason to live",
    "end it all",
    "hurt myself",
    "give up on everything",
]


def needs_support(text: str, detection: dict) -> bool:
    """Return True if we should show support resources instead of an image."""
    lowered = text.lower()
    return any(phrase in lowered for phrase in _CONCERN_PHRASES)


def support_response(detection: dict) -> dict:
    return {
        "type": "support",
        "detection": detection,
        "message": (
            "It sounds like things feel really heavy right now, and you don't "
            "have to face that alone. Talking to someone can help."
        ),
        "resources": config.SUPPORT_RESOURCES,
    }