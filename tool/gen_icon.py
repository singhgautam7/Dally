"""Renders the Dally app icon from the design spec (Dally App Icon.dc.html).

Fixed colours, never per-theme: bg #0E0F12, mark #ECEDEF, accent Ember #F5A524.
Geometry is the 108-viewBox: a solid-D silhouette
(`M34 30h20a24 24 0 0 1 0 48H34z`) with a rounded accent tile
(`rect x=45 y=45 w=18 h=18 rx=5`) laid into its counter.

Outputs (into assets/icon/):
  icon_full.png        1024²  bg + mark            (iOS + legacy Android)
  icon_foreground.png  1024²  mark on transparent  (Android adaptive foreground)
  icon_play.png         512²  bg + mark, no rounding (Play Store listing)
"""

import os
from PIL import Image, ImageDraw

BG = (0x0E, 0x0F, 0x12, 255)
MARK = (0xEC, 0xED, 0xEF, 255)
ACCENT = (0xF5, 0xA5, 0x24, 255)

SS = 4  # supersample for antialiasing


def draw_mark(size):
    """A transparent RGBA image of the D + accent tile at `size`, 108-viewBox."""
    img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = size * SS / 108.0

    def p(x, y):
        return (x * s, y * s)

    # D silhouette = stem rectangle (x34..54) ∪ right semicircle (centre 54,54 r24).
    d.rectangle([p(34, 30), p(54, 78)], fill=MARK)
    d.pieslice([p(30, 30), p(78, 78)], start=-90, end=90, fill=MARK)

    # Accent tile knocked into the counter (rounded rect r5).
    d.rounded_rectangle([p(45, 45), p(63, 63)], radius=5 * s, fill=ACCENT)

    return img.resize((size, size), Image.LANCZOS)


def full(size, rounded_bg=True):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg = Image.new("RGBA", (size, size), BG)
    img.alpha_composite(bg)
    img.alpha_composite(draw_mark(size))
    return img


def main():
    out = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
    os.makedirs(out, exist_ok=True)
    full(1024).save(os.path.join(out, "icon_full.png"))
    draw_mark(1024).save(os.path.join(out, "icon_foreground.png"))
    full(512).save(os.path.join(out, "icon_play.png"))
    print("wrote icon_full.png, icon_foreground.png, icon_play.png")


if __name__ == "__main__":
    main()
