import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:intl/intl.dart';

import '../core/data/day_repository.dart';
import '../core/liturgical/fast_level.dart';
import '../core/models/fast_day.dart';
import 'theme.dart';

/// What the home-screen widget shows, worked out here for the next [days].
///
/// The widget itself (TroitaWidget.kt) computes nothing: the fasting rules live
/// in the Dart engine and the published calendar, and a copy in Kotlin would
/// be a third implementation to keep in step. So the app hands it two months
/// at a time, and the widget looks up today. Colours travel with the text so
/// the widget prints a red-cross saint in red and a fish day in the same blue
/// as the calendar, without knowing why.
class WidgetFeed {
  const WidgetFeed._();

  static const int days = 60;

  static Future<String> build(DayRepository repo, {DateTime? from}) async {
    final DateTime now = from ?? DateTime.now();
    final DateFormat dateFmt = DateFormat('EEEE, d MMMM', 'ro');
    final Map<String, Object?> out = <String, Object?>{};

    for (int i = 0; i < days; i++) {
      // Calendar arithmetic, not Duration(days: i): see calendarDaysBetween.
      final DateTime date = DateTime(now.year, now.month, now.day + i);
      final DayEntry entry = await repo.entryFor(date);
      final FeastRank rank = entry.rank;
      final FastLevel level = entry.liturgical.fastLevel;

      out[FastDay.key(date)] = <String, Object?>{
        'date': toBeginningOfSentenceCase(dateFmt.format(date)),
        'saint': entry.primary?.displayName ?? 'Pomenirea zilei',
        if (rank != FeastRank.simplu) 'saintColour': _hex(feastRankColor(rank)),
        'fast': entry.liturgical.isFasting ? level.label : '',
        'fastColour': _hex(fastLevelColor(level)),
      };
    }
    return jsonEncode(out);
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
