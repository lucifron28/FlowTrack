from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SAMPLES = [
    ("Lucky Me Pancit Canton Chilimansi", "4807770271137"),
    ("555 Sardines Tomato Sauce", "4800110020303"),
    ("Nescafe Original Stick", "4800361417402"),
    ("Great Taste White Sachet", "4800016112300"),
    ("SkyFlakes Crackers", "4800016640704"),
    ("C2 Green Tea Apple 230ml", "4804888801232"),
    ("Safeguard White Bar 60g", "4800888206015"),
    ("Piattos Cheese 40g", "4800016060212"),
    ("Coke Sakto 200ml", "4801981111114"),
    ("Asukal Tingi 1/4 kilo", "FT-TINGI-ASUKAL"),
    ("Mantika Tingi 100ml", "FT-TINGI-MANTIKA"),
    ("Bigas Tingi 1 kilo", "FT-TINGI-BIGAS"),
]


def main():
    out_dir = Path("demo/barcodes")
    out_dir.mkdir(parents=True, exist_ok=True)
    for index, (name, value) in enumerate(SAMPLES, 1):
        image = make_card(index, name, value)
        image.save(out_dir / f"{index:02d}-{slugify(name)}.png")


def make_card(index, name, value):
    width, height = 1400, 720
    image = Image.new("RGB", (width, height), "#F8FAFC")
    draw = ImageDraw.Draw(image)
    title_font = font(54, bold=True)
    label_font = font(32, bold=False)
    code_font = font(38, bold=True)
    small_font = font(26, bold=False)

    draw.rounded_rectangle((48, 48, width - 48, height - 48), radius=36, fill="#FFFFFF", outline="#CBD5E1", width=3)
    draw.text((86, 88), f"{index:02d}. {name}", fill="#0F172A", font=title_font)
    draw.text((86, 154), "FlowTrack QA barcode", fill="#64748B", font=label_font)

    barcode_top = 232
    barcode_height = 250
    barcode_width = draw_barcode(draw, value, 86, barcode_top, barcode_height)
    draw.rectangle((86, barcode_top - 18, 86 + barcode_width, barcode_top - 8), fill="#DDD6FE")
    draw.text((86, barcode_top + barcode_height + 34), value, fill="#0F172A", font=code_font)
    draw.text(
        (86, height - 112),
        "Load QA sample data in Settings, then scan this from Sales or Inventory.",
        fill="#64748B",
        font=small_font,
    )
    return image


def draw_barcode(draw, value, x, y, height):
    from barcode import EAN13, Code128
    is_ean13 = value.isdigit() and len(value) == 13
    if is_ean13:
        bc = EAN13(value)
    else:
        bc = Code128(value)
        
    patterns = bc.build()
    pattern = patterns[0]
    
    narrow = 4
    cursor = x
    for mark in pattern:
        if mark == "1":
            draw.rectangle((cursor, y, cursor + narrow - 1, y + height), fill="#0F172A")
        cursor += narrow
    return cursor - x


def font(size, bold=False):
    candidates = [
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def slugify(value):
    chars = []
    for char in value.lower():
        if char.isalnum():
            chars.append(char)
        elif char in {" ", "-", "/"}:
            chars.append("-")
    slug = "".join(chars)
    while "--" in slug:
        slug = slug.replace("--", "-")
    return slug.strip("-")


if __name__ == "__main__":
    main()
