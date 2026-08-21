Church photographs referenced by `photo_ref` in the seed database, e.g.
`asset://churches/manastirea-stavropoleos.jpg` resolves to
`assets/churches/manastirea-stavropoleos.jpg` via `PhotoResolver`.

The MVP ships with none of these — the detail screen degrades to a text-only
layout when the asset is missing, and `build_seed.py` generates a slug-based
reference for every row regardless.

When there is a CDN, change the values in the database to `https://…` and
nothing outside `PhotoResolver` needs to know.

Licensing: most usable photos of Romanian churches on Wikimedia Commons are
CC BY-SA. Keep an attribution column alongside the file if you use them.
