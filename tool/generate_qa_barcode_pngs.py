from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SAMPLES = [
    ("Lucky Me Pancit Canton Chilimansi", "4807770271137"),
    ("555 Sardines Tomato Sauce", "4800110020307"),
    ("Nescafe Original Stick", "4800361417406"),
    ("Great Taste White Sachet", "4800016112306"),
    ("SkyFlakes Crackers", "4800016640706"),
    ("C2 Green Tea Apple 230ml", "4804888801234"),
    ("Safeguard White Bar 60g", "4800888206019"),
    ("Piattos Cheese 40g", "4800016060218"),
    ("Coke Sakto 200ml", "4801981111112"),
    ("Asukal Tingi 1/4 kilo", "FT-TINGI-ASUKAL"),
    ("Mantika Tingi 100ml", "FT-TINGI-MANTIKA"),
    ("Bigas Tingi 1 kilo", "FT-TINGI-BIGAS"),
]

CODE39 = {
    "0": "nnnwwnwnn",
    "1": "wnnwnnnnw",
    "2": "nnwwnnnnw",
    "3": "wnwwnnnnn",
    "4": "nnnwwnnnw",
    "5": "wnnwwnnnn",
    "6": "nnwwwnnnn",
    "7": "nnnwnnwnw",
    "8": "wnnwnnwnn",
    "9": "nnwwnnwnn",
    "A": "wnnnnwnnw",
    "B": "nnwnnwnnw",
    "C": "wnwnnwnnn",
    "D": "nnnnwwnnw",
    "E": "wnnnwwnnn",
    "F": "nnwnwwnnn",
    "G": "nnnnnwwnw",
    "H": "wnnnnwwnn",
    "I": "nnwnnwwnn",
    "J": "nnnnwwwnn",
    "K": "wnnnnnnww",
    "L": "nnwnnnnww",
    "M": "wnwnnnnwn",
    "N": "nnnnwnnww",
    "O": "wnnnwnnwn",
    "P": "nnwnwnnwn",
    "Q": "nnnnnnwww",
    "R": "wnnnnnwwn",
    "S": "nnwnnnwwn",
    "T": "nnnnwnwwn",
    "U": "wwnnnnnnw",
    "V": "nwwnnnnnw",
    "W": "wwwnnnnnn",
    "X": "nwnnwnnnw",
    "Y": "wwnnwnnnn",
    "Z": "nwwnwnnnn",
    "-": "nwnnnnwnw",
    ".": "wwnnnnwnn",
    " ": "nwwnnnwnn",
    "$": "nwnwnwnnn",
    "/": "nwnwnnnwn",
    "+": "nwnnnwnwn",
    "%": "nnnwnwnwn",
    "*": "nwnnwnwnn",
}


def main():
    out_dir = Path("docs/qa-barcodes")
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
    barcode_width = draw_code39(draw, value, 86, barcode_top, barcode_height)
    draw.rectangle((86, barcode_top - 18, 86 + barcode_width, barcode_top - 8), fill="#DDD6FE")
    draw.text((86, barcode_top + barcode_height + 34), value, fill="#0F172A", font=code_font)
    draw.text(
        (86, height - 112),
        "Load QA sample data in Settings, then scan this from Sales or Inventory.",
        fill="#64748B",
        font=small_font,
    )
    return image


def draw_code39(draw, value, x, y, height):
    narrow = 4
    cursor = x
    encoded = f"*{value.upper()}*"
    for char in encoded:
        pattern = CODE39.get(char)
        if pattern is None:
            raise ValueError(f"Unsupported Code 39 character: {char}")
        for i, mark in enumerate(pattern):
            bar_width = narrow * 3 if mark == "w" else narrow
            if i % 2 == 0:
                draw.rectangle((cursor, y, cursor + bar_width - 1, y + height), fill="#0F172A")
            cursor += bar_width
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
