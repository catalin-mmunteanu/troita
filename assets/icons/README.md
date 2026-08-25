# Icons

The designs use [lucide](https://lucide.dev). The Figma layer names are lucide's
own: `calendar-days`, `fish-off`, `map-pin`, `user-circle`, `search`, `cross`,
`bell`, `clock`, `globe`, `log-out`, `chevron-right`, `arrow-left`,
`book-open`, `bookmark`, `eye-off`.

## Current state

`lib/app/troita_icons.dart` maps each name to the closest Material glyph, so the
app builds and runs with no extra dependency. `fish-off` in particular has no
real Material equivalent — it is the fasting icon and it matters, so it is worth
replacing early.

## Replacing them properly

Two routes, both fine:

**Export from Figma.** Select each icon node, export as SVG at 1×, drop the
files here using the lucide names above. Then add `flutter_svg` and change
`TroitaIcons` to return `SvgPicture.asset(...)` widgets instead of `IconData`.

**Use a lucide package.** There are three on pub.dev (`flutter_lucide`,
`lucide_icons_flutter`, `lucide_flutter`) with no clear canonical choice —
check which is actively maintained before committing to one.

Either way the change is confined to `TroitaIcons`. Nothing else in the app
names an icon.

## Note on colour

Lucide icons are strokes, not fills, and are drawn at 24×24 with a 2px stroke.
If you export them, keep `currentColor` on the stroke so the tint applies.
