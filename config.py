"""
config.py
Everything tunable in one place.
"""

# Emotion model. Swap for your own fine-tuned folder (e.g. "./emotion-model-final").
EMOTION_MODEL = "./emotion-model-goemotions"


# Below this confidence, the detection is treated as "uncertain" and flagged.
LOW_CONFIDENCE = 0.60
EMOTION_THRESHOLD = 0.3



# Where generated images are saved (served by the API at /images/...).
GENERATED_DIR = "generated"

# --- BLE tag (EPD_TEST_01 firmware) --------------------------------------
# Must match the UUIDs/name advertised by ble_epd.c on the tag.
BLE_TAG_DEVICE_NAME = "MoodFrame-EPD"
BLE_TAG_SERVICE_UUID = "7a0247e0-4b3a-4bde-9e1f-1c9b6a4f9001"
BLE_TAG_IMAGE_CHAR_UUID = "7a0247e1-4b3a-4bde-9e1f-1c9b6a4f9002"
BLE_TAG_STATUS_CHAR_UUID = "7a0247e2-4b3a-4bde-9e1f-1c9b6a4f9003"

# --- Safety --------------------------------------------------------------
# Localize these for your users' region. This is a US starting example.
# Do not promise confidentiality or specific outcomes -- these vary.
SUPPORT_RESOURCES = [
    {"name": "988 Suicide & Crisis Lifeline (US)", "contact": "Call or text 988"},
    {"name": "Crisis Text Line", "contact": "Text HOME to 741741"},
    {"name": "Find a helpline in your country", "contact": "findahelpline.com"},
]
