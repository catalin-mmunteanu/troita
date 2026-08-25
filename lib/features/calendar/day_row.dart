import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/data/day_repository.dart';
import '../../core/liturgical/fast_level.dart';
import '../../core/models/feast.dart';

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
    super.key,
  });

  final DayEntry entry;
  final bool isToday;
  final VoidCallback onTap;

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
          '${entry.title}, ${entry.liturgical.fastLevel.label}',
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
                      if (major)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.add,
                                  size: 15, color: feastRankColor(entry.rank)),
                              const SizedBox(width: 5),
                              Text(
                                entry.rank.label.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  letterSpacing: 0.6,
                                  fontWeight: FontWeight.w700,
                                  color: feastRankColor(entry.rank),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        entry.title,
                        // Four lines is enough for the longest day in the year
                        // and still lets the row breathe.
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TroitaCalendarText.commemoration.copyWith(
                          fontSize: 17,
                          height: 1.35,
                          fontWeight:
                              major ? FontWeight.w600 : FontWeight.w400,
                          color: entry.primary?.kind == 'romanesc'
                              ? TroitaColors.romanianSaint
                              : TroitaColors.calendarInk,
                        ),
                      ),
                      if (entry.liturgical.isFasting) ...<Widget>[
                        const SizedBox(height: 8),
                        FastPill(level: entry.liturgical.fastLevel),
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
