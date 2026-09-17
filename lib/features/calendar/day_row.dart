import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/data/day_repository.dart';
import '../../core/liturgical/fast_level.dart';
import '../../core/models/fast_day.dart';
import '../../core/models/feast.dart';
import '../fasting/mood_selector.dart';

/// One day, set like a line in a printed calendar.
///
/// Deliberately large. The previous month grid put day numbers at 14pt and
/// carried fasting information in a 4-pixel dot, which is unreadable for the
/// people most likely to use this app daily. Here the date is 30pt, the
/// commemorations are set in full at 17pt with no truncation to one line, and
/// the fasting state is a labelled pill rather than a coloured speck.
class DayRow extends StatelessWidget {
  const DayRow({
    required this.entry,
    required this.isToday,
    required this.onTap,
    this.marked,
    super.key,
  });

  final DayEntry entry;
  final bool isToday;
  final VoidCallback onTap;

  /// The user's record for this day, if any. Shown, not editable — the
  /// calendar list stays a reading surface, and recording happens in Posturi
  /// or on the day's own page.
  final FastDay? marked;

  static const List<String> _weekdayLetters = <String>[
    'L', 'Ma', 'Mi', 'J', 'V', 'S', 'D',
  ];

  @override
  Widget build(BuildContext context) {
    final bool major = entry.rank == FeastRank.praznic ||
        entry.rank == FeastRank.cruceRosie;
    final bool red = major || entry.isSunday;
    final Color dateColor = red ? TroitaColors.feastRed : TroitaColors.calendarInk;

    return Semantics(
      button: true,
      label: '${entry.date.day} ${_monthName(entry.date.month)}, '
          '${entry.title}, ${entry.liturgical.fastLevel.label}'
          '${marked == null ? '' : ', ${marked!.kept ? 'ținut' : 'neținut'}'}',
      child: Material(
        color: isToday
            ? TroitaColors.accentSurface
            : (major ? TroitaColors.surfaceSubtle : Colors.transparent),
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isToday ? TroitaColors.burgundy : Colors.transparent,
                  width: 4,
                ),
                bottom: const BorderSide(color: TroitaColors.border),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 52,
                  child: Column(
                    children: <Widget>[
                      Text(
                        '${entry.date.day}',
                        style: TroitaCalendarText.numeral.copyWith(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: dateColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _weekdayLetters[entry.date.weekday - 1],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: dateColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (isToday)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'ASTĂZI',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                              color: TroitaColors.burgundy,
                            ),
                          ),
                        ),
                      // One marker per commemoration, not one per day.
                      // A day can carry a red-cross feast and a black-cross
                      // one at the same time; a single badge for the whole row
                      // put both under the wrong cross and hid the black one
                      // completely.
                      ..._commemorations(context),
                      if (entry.liturgical.isFasting) ...<Widget>[
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            FastPill(level: entry.liturgical.fastLevel),
                            if (marked != null) ...<Widget>[
                              const SizedBox(width: 8),
                              // The face when one was given, otherwise a plain
                              // tick or cross for the Da/Nu answer.
                              if (marked!.kept && marked!.mood != null)
                                Icon(
                                  MoodSelector.iconFor(marked!.mood!,
                                      filled: true),
                                  size: 22,
                                  color:
                                      MoodSelector.colourFor(marked!.mood!),
                                )
                              else
                                Icon(
                                  marked!.kept
                                      ? Icons.check_circle
                                      : Icons.cancel_outlined,
                                  size: 22,
                                  color: marked!.kept
                                      ? TroitaColors.burgundy
                                      : TroitaColors.muted,
                                ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Up to three commemorations, each with its own cross.
  ///
  /// Red cross for praznice and cruce roșie, black cross for cruce neagră,
  /// nothing for an ordinary day — the convention the printed calendars use,
  /// applied per name rather than per date.
  List<Widget> _commemorations(BuildContext context) {
    final List<Feast> feasts = entry.feasts;
    if (feasts.isEmpty) {
      return <Widget>[
        Text(
          'Pomenirea zilei',
          style: TroitaCalendarText.commemoration.copyWith(fontSize: 17),
        ),
      ];
    }

    const int limit = 3;
    final List<Feast> shown = feasts.take(limit).toList();
    final int hidden = feasts.length - shown.length;

    return <Widget>[
      for (final Feast f in shown)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The rank spelled out, per commemoration. On a day that carries
              // both a red-cross and a black-cross feast, each name gets its
              // own label rather than sharing one for the whole date.
              if (f.rank != FeastRank.simplu)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.add, size: 14, color: feastRankColor(f.rank)),
                      const SizedBox(width: 5),
                      Text(
                        f.rank.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11.5,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: feastRankColor(f.rank),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (f.rank == FeastRank.simplu)
                    Container(
                      margin: const EdgeInsets.only(top: 8, right: 8),
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: TroitaColors.muted,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      f.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TroitaCalendarText.commemoration.copyWith(
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: f.rank == FeastRank.simplu
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: f.kind == 'romanesc'
                            ? TroitaColors.romanianSaint
                            : TroitaColors.calendarInk,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      if (hidden > 0)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            'și încă $hidden',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ];
  }

  static String _monthName(int m) => const <String>[
        'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie',
        'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
      ][m - 1];
}

/// Icon plus written label. Never the icon alone — see [fastLevelIcon].
class FastPill extends StatelessWidget {
  const FastPill({required this.level, this.compact = false, super.key});

  final FastLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color colour = fastLevelColor(level);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(fastLevelIcon(level), size: compact ? 15 : 17, color: colour),
          const SizedBox(width: 7),
          Text(
            compact ? level.shortLabel : level.label,
            style: TextStyle(
              fontSize: compact ? 13 : 14.5,
              fontWeight: FontWeight.w600,
              color: colour,
            ),
          ),
        ],
      ),
    );
  }
}
