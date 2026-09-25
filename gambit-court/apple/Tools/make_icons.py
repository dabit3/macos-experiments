"""Generate Gambit Court's original crown launcher icons. Requires Pillow."""

from pathlib import Path

from PIL import Image, ImageDraw

APP = Path(__file__).resolve().parents[1]


def main() -> None:
    image = Image.new("RGB", (1024, 1024), "#101B46")
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((128, 152, 896, 920), radius=180, fill="#987018")
    draw.rounded_rectangle((128, 104, 896, 872), radius=180, fill="#FFD34D")
    draw.polygon(
        [(248, 328), (388, 450), (512, 254), (636, 450),
         (776, 328), (704, 642), (320, 642)],
        fill="#101B46",
    )
    draw.rounded_rectangle((320, 694, 704, 746), radius=20, fill="#101B46")
    targets = [
        *APP.glob("Resources/iOSAssets.xcassets/AppIcon.appiconset/*.png"),
        *APP.glob("Resources/macOSAssets.xcassets/AppIcon.appiconset/*.png"),
    ]
    for path in targets:
        with Image.open(path) as previous:
            size = previous.size
        image.resize(size, Image.Resampling.LANCZOS).save(path)
    print(f"Generated {len(targets)} crown icons.")


if __name__ == "__main__":
    main()
