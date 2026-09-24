from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "test" / "visual_closure" / "goldens"
BACKGROUND = Path(r"C:\Users\HP 1040 G8\.codex\generated_images\01a09fa6-925b-7e60-b7b3-4643dd2d614f\exec-d5e8b7c7-0edc-49a1-a1be-90cefaa1a7b7.png")
OUTPUT = Path(r"C:\Users\HP 1040 G8\Desktop\BIL_App_Store_Build_28_Screenshots_FINAL\iPhone_6_9")
FONT_BOLD = r"C:\Windows\Fonts\segoeuib.ttf"
FONT_REGULAR = r"C:\Windows\Fonts\segoeui.ttf"

SCREENS = [
    ("01_dashboard.png", "visual_closure_dashboard_phone.png", "Your health, finally\nunderstandable.", "TODAY • CONTEXT • DIRECTION"),
    ("02_ai_coach.png", "visual_closure_ai_coach_conversation_phone.png", "Ask about your body.\nGet a clear answer.", "ASK • UNDERSTAND • DECIDE"),
    ("03_daily_log.png", "visual_closure_daily_log_meal_entry_phone.png", "Your whole day,\none calm view.", "MEALS • WATER • ACTIVITY"),
    ("04_food_search.png", "visual_closure_food_catalog_verified_result_phone.png", "Find food with\ntrusted evidence.", "SEARCH • REVIEW • LOG"),
    ("05_progress.png", "visual_closure_analytics_progress_phone.png", "See progress—\nnot noise.", "TRENDS • CONTEXT • CLARITY"),
    ("06_nutrition_goals.png", "visual_closure_nutrition_goals_phone.png", "Goals that adapt to\nyour real day.", "CALORIES • MACROS • NUTRIENTS"),
    ("07_workouts.png", "visual_closure_workout_library_phone.png", "Move with a plan\nyou can follow.", "STRENGTH • CARDIO • MOBILITY"),
    ("08_recipes.png", "visual_closure_recipe_discovery_phone.png", "Real meals for\nreal routines.", "DISCOVER • SAVE • COOK"),
]


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def fit_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    ratio = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize((round(image.width * ratio), round(image.height * ratio)), Image.Resampling.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    base = fit_cover(Image.open(BACKGROUND).convert("RGB"), (1290, 2796))
    title_font = ImageFont.truetype(FONT_BOLD, 92)
    kicker_font = ImageFont.truetype(FONT_BOLD, 26)
    brand_font = ImageFont.truetype(FONT_BOLD, 34)
    brand_small = ImageFont.truetype(FONT_REGULAR, 18)

    for filename, source_name, headline, kicker in SCREENS:
        target = OUTPUT / filename
        if target.exists() and target.stat().st_size > 0:
            continue
        canvas = base.copy()
        draw = ImageDraw.Draw(canvas)
        draw.rounded_rectangle((72, 72, 156, 156), radius=42, fill="#F7FAFC")
        draw.text((92, 96), "BiL", font=ImageFont.truetype(FONT_BOLD, 25), fill="#071927")
        draw.text((184, 82), "BIL™", font=brand_font, fill="white")
        draw.text((184, 124), "BODY INTELLIGENCE LOG", font=brand_small, fill="#A8CBD7")
        draw.multiline_text((72, 205), headline, font=title_font, fill="white", spacing=2)
        draw.text((74, 435), kicker, font=kicker_font, fill="#72E4CF")

        shot = Image.open(SOURCE / source_name).convert("RGB")
        target_w = 930
        target_h = round(shot.height * target_w / shot.width)
        shot = shot.resize((target_w, target_h), Image.Resampling.LANCZOS)
        mask = rounded_mask(shot.size, 62)
        shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        shadow_shape = Image.new("RGBA", shot.size, (0, 0, 0, 170))
        shadow_shape.putalpha(mask)
        shadow.alpha_composite(shadow_shape, (195, 586))
        shadow = shadow.filter(ImageFilter.GaussianBlur(30))
        canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow)
        canvas.paste(shot, (180, 550), mask)

        out = canvas.convert("RGB")
        out.save(target, "PNG", optimize=True)

    (OUTPUT.parent / "README.txt").write_text(
        "BIL App Store replacement screenshots for iPhone 6.9-inch display.\n"
        "Exact dimensions: 1290 x 2796 pixels.\n"
        "Sources are app captures without Android status bars or Android platform branding.\n"
        "Do not upload to Google Play.\n",
        encoding="utf-8",
    )
    preview = Image.new("RGB", (720, 820), "#061A26")
    for index, (filename, *_rest) in enumerate(SCREENS):
        item = Image.open(OUTPUT / filename).convert("RGB")
        item.thumbnail((168, 364), Image.Resampling.LANCZOS)
        x = 9 + (index % 4) * 177
        y = 28 + (index // 4) * 392
        preview.paste(item, (x, y))
    preview.save(OUTPUT.parent / "CONTACT_SHEET_PREVIEW_FINAL.jpg", "JPEG", quality=92)


if __name__ == "__main__":
    main()
