# Dally — app icon

**Final variant:** B (`variants/dally_b.svg`)

## Construction
- Grid: 108 × 108 dp adaptive canvas, 72 dp visible viewport, 66 dp safe zone.
- Stroke: **9 dp on 108 dp = 0.0833 of the canvas** (42.7 px on the 512 px Play icon). Round caps, round joins. Same for every icon in the family.
- Glyph: A die face built from the family strokes. Dark stroke: left side and bottom. Mid stroke: starts on top of the dark at the bottom-right corner, runs up the right side, across the top and down onto the dark at the top-left (two folds). Two pips on the diagonal.
- Accent: Two die pips, dark tone, 9 dp diameter.
- Glyph box: 47.0 × 47.0 dp. Furthest ink from centre: 27.9 dp (safe-zone limit 33 dp). Ink coverage: 11.5% of the canvas.
- Draw order: dark stroke(s) first, mid stroke(s) on top. No gradients, shadows or outlines.

## Colours
| Role | Value |
|---|---|
| Dark (base stroke) | #721A49 |
| Mid (overlapping stroke) | #C84C8B |
| Background (pale tint) | #FEDEEB |
| Splash background, light | #FEDEEB |
| Splash background, dark | #27141C |
| Splash glyph, dark mode (base / top) | #D65997 / #F4B6D0 |

OKLCH hue: 352.

## Files
- `ic_launcher_foreground.svg` — glyph, 108 dp, transparent
- `ic_launcher_background.svg` — solid pale tint, 108 dp
- `ic_launcher_monochrome.svg` — single-colour glyph for Android 13+ themed icons (system tints it)
- `ic_launcher_preview.svg` — composited 72 dp viewport, for previews only
- `splash_icon.svg` / `splash_icon_night.svg` — 288 dp canvas; glyph sits inside the 192 dp circle (max radius 74.4 dp of 96)
- `play_store_512.png` (+ `play_store_source.svg`) — full 108 dp canvas at 512 px, same framing as the existing Kuber / PostPurush / Unfurl Play icons
- `ic_stat_notification.svg` / `ic_stat_notification_96.png` — white silhouette, 24 dp, glyph scaled to 0.4 (stroke 3.6 dp)
- `variants/` — variant sources

To import: Android Studio → New → Vector Asset for each SVG, then reference them from `mipmap-anydpi-v26/ic_launcher.xml` (`<foreground>`, `<background>`, `<monochrome>`).

## Variants
- **B** — Die. Final. (47.0×47.0 dp, ink 11.5%)
