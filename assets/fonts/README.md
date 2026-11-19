# Fonts

The same four families as the website (DESIGN.MD §3 in troita-web), all OFL,
all with the Romanian comma-below ș and ț:

| Family | Used for | Files |
|---|---|---|
| **Literata** | Headings, the calendar, saints' names | 400, 600, 700 |
| **Plus Jakarta Sans** | Body text | 400, 500, 600, 700 |
| **Alegreya Sans** | Buttons, navigation labels | 400, 500, 700 |
| **JetBrains Mono** | Rubrics: small uppercase labels | 400, 500 |

Static instances (Flutter does not map `fontWeight` onto a variable font's
weight axis), from the `@expo-google-fonts/*` npm packages, which repackage the
Google Fonts releases. Licences: `OFL-*.txt`. Declared in `pubspec.yaml`;
family names come from `lib/app/design_tokens.dart`.

Geist and Fraunces, the earlier choice, are gone: Geist is on the DESIGN.MD ban
list.
