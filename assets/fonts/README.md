# Fonts

The Figma file uses two families, both OFL-licensed and free from Google Fonts:

| Family | Used for | Weights needed |
|---|---|---|
| **Fraunces** | Headings — "Noiembrie 2026", section titles | Bold (700) |
| **Geist** | Everything else | Regular 400, Medium 500, SemiBold 600, Bold 700 |

Fraunces is a variable font; the designs draw it with `SOFT 0, WONK 1`. If you
grab the static Bold instead of the variable file you lose the wonky axis, which
is most of its character on the headings — take the variable file where you can.

## Installing

1. Download from https://fonts.google.com/specimen/Fraunces and
   https://fonts.google.com/specimen/Geist
2. Drop the `.ttf` files here.
3. Uncomment the `fonts:` block in `pubspec.yaml`.

## Why the app works without them

`theme.dart` names the families in `TroitaFonts`, but they are deliberately not
declared in `pubspec.yaml` yet. Flutter treats an undeclared family as a
fallback to the platform default — it logs a warning and carries on rather than
failing the build. So the app runs today with Roboto and upgrades to the real
type the moment the files land, with no code change.
