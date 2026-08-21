# Orthodox calendar data — sources, licensing, recommendation

Research note, August 2026. Written before any calendar UI, because the data
shape determines the screens rather than the other way round.

---

## Recommendation in one paragraph

**Compute everything that is computable; hand-curate a small set of major feasts;
never redistribute anyone's menologion or saints' lives.** Roughly 80% of what
the Figma screens display — the fasting banner, the entire Posturi screen, glas,
which feasts are coming, the date badges — is derivable from Pascha with pure
arithmetic and carries no licensing risk whatsoever. The remaining 20% (a named
saint for all 365 days, biographies, scripture text) is copyrighted content with
no open Romanian source, and should be scoped down to ~150 curated entries with
honest blanks elsewhere, rather than acquired.

---

## The strategic point, first

**The Romanian Patriarchate ships its own official calendar app.** "Calendar
Ortodox" (`ro.patriarhie.calendarortodox`) is on Google Play, was updated for
2026, and carries data authorised by the Holy Synod. `calendar.patriarhia.ro`
states *"TOATE DREPTURILE REZERVATE"*.

That matters in two ways:

1. **Legally** — their calendar content is explicitly all-rights-reserved. It
   cannot be scraped, mirrored, or shipped inside this app.
2. **Strategically** — you cannot win a calendar-accuracy contest against an app
   with Synod authorisation, and you shouldn't try. Nobody else has the
   proximity feature. The calendar should be *support* for the differentiator,
   not the product. A calendar good enough to keep someone in the app daily, and
   honest about what it doesn't know, is the right target.

---

## What is computable — no licensing risk at all

All of this follows from the Pascha computus already implemented in
`lib/core/models/feast_calendar.dart`. Dates and arithmetic are facts, not
creative works.

### Fasting periods (the entire Posturi screen)

| Post | Rule | Kind |
|---|---|---|
| Postul Crăciunului | 15 Nov – 24 Dec | fixed |
| Postul Mare (Păresimile) | Clean Monday (Pascha − 48) → Pascha | movable |
| Postul Sfinților Apostoli | Monday after Duminica Tuturor Sfinților (Pascha + 57) → 28 June | movable length, sometimes zero days |
| Postul Adormirii | 1 – 14 August | fixed |

Note the third one: its **length varies with Pascha and can collapse to nothing**
in late-Pascha years. That's a genuine bug magnet and an argument for computing
rather than hardcoding date ranges.

### Weekly and daily fasting

- Wednesday and Friday year-round, except during harți
- **Harți** (fast-free weeks), all Pascha-relative except the first:
  - 25 Dec – 4 Jan (Crăciun → Bobotează)
  - Week after Duminica Vameșului și a Fariseului (Pascha − 70 → − 64)
  - Săptămâna Brânzei (Pascha − 56 → − 50) — dairy permitted, meat not
  - Săptămâna Luminată (Pascha → Pascha + 6)
  - Week after Rusalii (Pascha + 50 → + 56)
- Strict fast days: 14 Sept (Înălțarea Sfintei Cruci), 29 Aug (Tăierea Capului
  Sf. Ioan Botezătorul), 5 Jan (Ajunul Bobotezei)

This is what drives `Astăzi: Post cu dezlegare la untdelemn și vin` in the
header banner and the per-day dot markers in the month grid.

### Liturgical cycle

- **Glas** — eight tones cycling weekly from Duminica Tomii (Pascha + 7)
- **Voscreasna / Eothinon** — eleven-week resurrection gospel cycle
- **Pericope cycle** — the Sunday gospel/epistle sequence is Pascha-relative,
  including the Matthew→Luke transition

### Fixed feasts

The twelve Praznice Împărătești and the major fixed commemorations are plain
calendar facts. `tool/hram.py` already encodes about 60 of them with correct
dates, built for hram inference — that table transfers directly.

> ⚠️ These rules are written from general knowledge of the Romanian typikon and
> **need review by someone competent** before anyone fasts by them. The
> arithmetic is testable; the pastoral correctness is not something code can
> verify. Treat the fasting engine as draft until a priest signs off.

---

## What is *not* computable, and what it costs

| Need | Status |
|---|---|
| A named saint for every one of 365 days, in Romanian | No open source exists. Patriarhia = all rights reserved. doxologia.ro, crestinortodox.ro = copyrighted, no API. |
| Saints' lives / biographies | Copyrighted everywhere. Orthocal's own lives are used "by permission from abbamoses.com" — the code is MIT, the content is not. |
| Scripture **text** in Romanian | Biblia Sinodală is copyrighted (Institutul Biblic). Cornilescu 1924's status is contested — the Romanian Bible Society asserts rights. Not safe to bundle. |
| Scripture **references** ("In. 1, 43-51") | Facts. Free to use. |
| Icons | Photographs of icons carry the photographer's copyright even when the icon is ancient. |

**Consequence for the day-detail screen:** the pericope *reference* can be
computed and displayed; the quoted text in the mockup cannot be shipped without
a licence. Either link out to doxologia.ro for the passage, or negotiate a
translation licence.

---

## Sources evaluated

| Source | Licence | Language | Verdict |
|---|---|---|---|
| [orthocal-python](https://github.com/brianglass/orthocal-python) | MIT (code) | English | **Best reference implementation.** Port the algorithms, not the content. OCA/Slavic usage differs from Romanian in places. |
| [paulkachur/orthodox_calendar](https://github.com/paulkachur/orthodox_calendar) | open | English | The engine orthocal is based on. Useful for the pericope tables' *structure*. |
| [Lives of the Saints API](https://www.livesofthesaintscalendar.com/developers) | free tier, ToS-bound | English | JSON, Gregorian + Julian, OpenAPI 3.1. Runtime dependency + English-only make it a poor fit for an offline-first Romanian app. |
| [calendar.patriarhia.ro](https://calendar.patriarhia.ro/) | **All rights reserved** | Romanian | Authoritative and off-limits. Useful only as a correctness check by hand. |
| [doxologia.ro](https://doxologia.ro/calendar-ortodox/202611) | copyrighted | Romanian | Same. Good target for an outbound "citește mai mult" link. |

---

## Proposed data model

Two additions to `tool/schema.sql`, keeping the existing contract intact:

```sql
-- Hand-curated fixed commemorations. ~150 rows, not 365.
CREATE TABLE feasts (
    id           TEXT PRIMARY KEY,   -- 'feast:11-21' | 'feast:movable:ascension'
    month_day    TEXT,               -- 'MM-DD', NULL when movable
    movable_key  TEXT,               -- 'ascension', matches FeastCalendar
    name         TEXT NOT NULL,
    rank         TEXT NOT NULL,      -- praznic|cruce_rosie|cruce_neagra|simplu
    kind         TEXT,               -- domnesc|maica_domnului|sfant|romanesc
    short_note   TEXT,               -- one line; ours, not anyone else's
    icon_ref     TEXT,
    source       TEXT NOT NULL,
    verified     INTEGER NOT NULL DEFAULT 0
);

-- Pericope references only. No scripture text.
CREATE TABLE readings (
    id         TEXT PRIMARY KEY,
    context    TEXT NOT NULL,        -- 'pascha+39' | '11-21' | 'glas:4'
    kind       TEXT NOT NULL,        -- apostol|evanghelie
    reference  TEXT NOT NULL         -- 'In. 1, 43-51'
);
```

Everything else — fasting state, glas, which post a date falls in, days until the
next feast — is a **pure function of the date**, computed at runtime by an
extended `FeastCalendar`. No table, no sync, no licence.

`rank` maps directly onto the red/black cross markers already in the mockups.

---

## Suggested phasing

1. **Fasting engine + Posturi screen.** Fully computable, zero licensing risk,
   and it's a complete, shippable screen on its own. Also the highest-value one
   — people check fasting rules far more often than they read a saint's life.
2. **Calendar month grid** with fasting dots and computed feast markers, using
   the ~150 curated entries. Days without a curated saint show the fasting state
   and nothing else — honest, not padded.
3. **Day detail** with saint (when known), fasting regime, glas, and pericope
   *references*, linking out for the text.
4. **Only then** decide whether a full menologion is worth licensing.

Phase 1 alone makes the app useful daily, which is what the proximity feature
needs in order to stay installed.
