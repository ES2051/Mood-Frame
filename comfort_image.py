"""
comfort_image.py
Emotion in -> path to a supportive image out.
"""

import os
import uuid
import config

COMFORT_STYLES = {
    "joy":      "a bright, sunny scene celebrating a happy moment, warm golden light, uplifting",
    "sadness":  "a soft, cozy scene with gentle warm light and a hopeful sunrise, comforting and tender",
    "anger":    "a calm, spacious landscape with cool blues and greens, still water, quiet and slow",
    "fear":     "a safe, sheltered space with soft protective light, grounded and reassuring",
    "surprise": "a scene of gentle wonder and delight, soft playful colors",
    "love":     "a warm, tender scene evoking closeness and connection, soft light",
    "disgust":  "a clean, fresh, orderly natural scene, crisp air and open space",
    "neutral":  "a peaceful, pleasant natural scene with soft balanced light",
}

STYLE_SUFFIX = (
    "photograph, shot on a 50mm lens, natural light, shallow depth of "
    "field, film grain, photorealistic, highly detailed, no text, no faces"
)

NEGATIVE_PROMPT = (
    "cartoon, illustration, painting, drawing, anime, 3d render, cgi, "
    "digital art, blurry, low quality, deformed, disfigured, watermark, "
    "text, logo, oversaturated, plastic skin, extra limbs, bad anatomy"
)

EPD_COMFORT_STYLES = {
    "joy":      "a single bright sun rising over a simple hill horizon, bold shapes, high contrast",
    "sadness":  "a single raindrop on a plain window pane, simple composition, soft light, high contrast",
    "anger":    "a single still lake with one calm ripple, minimal composition, high contrast",
    "fear":     "a single lit window in a dark house, simple shape, warm glow, high contrast",
    "surprise": "a single burst of a few large confetti shapes against plain sky, bold shapes",
    "love":     "two simple overlapping circles like linked rings, warm minimal composition",
    "disgust":  "a single clean open window with plain sky beyond, minimal composition",
    "neutral":  "a simple flat horizon line with plain sky, minimal composition, high contrast",
}

EPD_STYLE_SUFFIX = (
    "flat bold graphic illustration, simple shapes, strong silhouette, "
    "high contrast, limited color palette, minimalist poster style, "
    "no gradients, no fine detail, no text, no faces"
)


def build_prompt(emotion: str) -> str:
    direction = COMFORT_STYLES.get(emotion.lower(), COMFORT_STYLES["neutral"])
    return f"{direction}, {STYLE_SUFFIX}"


def build_prompt_epd(emotion: str) -> str:
    direction = EPD_COMFORT_STYLES.get(emotion.lower(), EPD_COMFORT_STYLES["neutral"])
    return f"{direction}, {EPD_STYLE_SUFFIX}"


def build_prompt_claude(text: str, emotion: str) -> str:
    import anthropic

    client = anthropic.Anthropic()
    system = (
        "You write short image-generation prompts for a wellbeing app. Given a "
        "person's message and their detected emotion, write ONE vivid prompt "
        "(max 40 words) for a calming, supportive PHOTOGRAPH -- not a painting "
        "or illustration. Meet the feeling gently -- comfort, don't force "
        "positivity. Reference camera/lens/light like a real photographer would "
        "(e.g. '50mm lens, golden hour, shallow depth of field'). "
        "Output only the prompt."
    )
    msg = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=150,
        system=system,
        messages=[{"role": "user", "content": f"Message: {text}\nEmotion: {emotion}"}],
    )
    return msg.content[0].text.strip()


_pipe = None

MODEL_ID = "SG161222/Realistic_Vision_V6.0_B1_noVAE"


def generate_image_local(prompt: str, emotion: str = "neutral") -> str:
    global _pipe
    from diffusers import StableDiffusionPipeline, DPMSolverMultistepScheduler
    import torch

    if _pipe is None:
        if torch.backends.mps.is_available():
            device = "mps"
        elif torch.cuda.is_available():
            device = "cuda"
        else:
            device = "cpu"

        _pipe = StableDiffusionPipeline.from_pretrained(
            MODEL_ID,
            torch_dtype=torch.float32,
            low_cpu_mem_usage=False,
            safety_checker=None,
        )
        _pipe.scheduler = DPMSolverMultistepScheduler.from_config(_pipe.scheduler.config)
        _pipe = _pipe.to(device)
        _pipe.enable_attention_slicing()

    image = _pipe(
        prompt,
        negative_prompt=NEGATIVE_PROMPT,
        num_inference_steps=35,
        guidance_scale=6.0,
    ).images[0]

    os.makedirs(config.GENERATED_DIR, exist_ok=True)
    filename = f"{emotion.lower()}_{uuid.uuid4().hex[:8]}.png"
    path = os.path.join(config.GENERATED_DIR, filename)
    image.save(path)
    return path


def generate_image_hosted(prompt: str, emotion: str = "neutral") -> str:
    import base64
    from openai import OpenAI

    client = OpenAI()
    result = client.images.generate(
        model="gpt-image-1",
        prompt=prompt,
        size="1024x1024",
        quality="high",
    )
    image_bytes = base64.b64decode(result.data[0].b64_json)

    os.makedirs(config.GENERATED_DIR, exist_ok=True)
    filename = f"{emotion.lower()}_{uuid.uuid4().hex[:8]}.png"
    path = os.path.join(config.GENERATED_DIR, filename)
    with open(path, "wb") as f:
        f.write(image_bytes)
    return path


def comfort_from_emotion(
    emotion: str,
    text: str = "",
    use_claude: bool = False,
    hosted: bool = False,
    for_epd: bool = True,
    send_to_tag: bool = True,
) -> dict:
    if for_epd:
        prompt = build_prompt_epd(emotion)
    else:
        prompt = build_prompt_claude(text, emotion) if use_claude else build_prompt(emotion)

    path = (
        generate_image_hosted(prompt, emotion)
        if hosted
        else generate_image_local(prompt, emotion)
    )

    result = {"original": path}
    if for_epd:
        if send_to_tag:
            from ble_epd import send_image_to_tag

            try:
                result["tag_sent"] = send_image_to_tag(path)
            except Exception as e:
                result["tag_sent"] = False
                result["tag_error"] = str(e)
    return result
