import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:troita/core/liturgical/fast_level.dart';
import 'package:troita/core/models/feast_calendar.dart';
import 'package:troita/core/models/name_days.dart';
import 'package:troita/core/models/saved_name.dart';
import 'package:troita/core/notifications/notification_planner.dart';
import 'package:troita/core/notifications/notification_prefs.dart';

NotificationPrefs _store(Map<String, Object> values) =>
    NotificationPrefs.fromStore(
      getInt: (String k) => values[k] as int?,
      getBool: (String k) => values[k] as bool?,
      getString: (String k) => values[k] as String?,
    );

void main() {
  group('prefs', () {
    test('a new install gets the defaults', () {
      final NotificationPrefs p = _store(<String, Object>{});
      expect(p.level(NotifKind.saint), NotifLevel.important);
      expect(p.level(NotifKind.nameDays), NotifLevel.all);
      expect(p.level(NotifKind.gospel), NotifLevel.off);
      expect(p.level(NotifKind.mosi), NotifLevel.off);
      expect(p.eveningTimeLabel, '19:00');
      expect(p.gospelTimeLabel, '07:00');
    });

    test('the old switches carry over', () {
      final NotificationPrefs p = _store(<String, Object>{
        'notif_mode': 2, // every day
        'notif_gospel': true,
        'notif_fast_reminders': false,
        'notif_hram_reminders': true,
      });
      expect(p.level(NotifKind.saint), NotifLevel.all);
      expect(p.level(NotifKind.gospel), NotifLevel.all);
      expect(p.level(NotifKind.fasts), NotifLevel.off);
      expect(p.level(NotifKind.hram), NotifLevel.important);
    });

    test('a saved level wins over the old switch', () {
      final NotificationPrefs p = _store(<String, Object>{
        'notif_mode': 2,
        'notif_level_saint': 'off',
      });
      expect(p.level(NotifKind.saint), NotifLevel.off);
    });

    test('the shortcut sets every row', () {
      const NotificationPrefs p = NotificationPrefs();
      expect(p.common, isNull);
      expect(p.withAll(NotifLevel.all).common, NotifLevel.all);
      expect(
          p.withAll(NotifLevel.off).withLevel(NotifKind.saint, NotifLevel.all)
              .common,
          isNull);
    });

    test('the main switch silences without losing the rows', () {
      final NotificationPrefs p = _store(<String, Object>{
        'notif_enabled': false,
        'notif_level_gospel': 'all',
      });
      expect(p.enabled, isFalse);
      expect(p.on(NotifKind.gospel), isFalse);
      expect(p.level(NotifKind.gospel), NotifLevel.all);
      expect(p.copyWith(enabled: true).on(NotifKind.gospel), isTrue);
      // Defaults: saint, names, fasts, hram.
      expect(const NotificationPrefs().activeCount, 4);
    });

    test('onboarding presets', () {
      const NotificationPrefs p = NotificationPrefs();
      final NotificationPrefs all =
          p.applyPreset(NotifPreset.all, gospel: false);
      expect(all.level(NotifKind.mosi), NotifLevel.all);
      expect(all.level(NotifKind.gospel), NotifLevel.off);
      expect(all.preset, NotifPreset.all);

      final NotificationPrefs important =
          all.applyPreset(NotifPreset.important, gospel: true);
      expect(important.level(NotifKind.mosi), NotifLevel.off);
      expect(important.level(NotifKind.saint), NotifLevel.important);
      expect(important.level(NotifKind.gospel), NotifLevel.all);
      expect(important.preset, NotifPreset.important);

      final NotificationPrefs none =
          important.applyPreset(NotifPreset.none, gospel: true);
      expect(none.enabled, isFalse);
      expect(none.level(NotifKind.gospel), NotifLevel.all); // kept
      expect(none.preset, NotifPreset.none);
      expect(p.preset, NotifPreset.important);
    });

    test('every level of every kind but Oprit says what it means', () {
      for (final NotifKind k in NotifKind.values) {
        expect(k.describe(NotifLevel.all), isNotNull, reason: k.name);
        expect(k.describe(NotifLevel.important), isNotNull, reason: k.name);
        expect(k.describe(NotifLevel.off), isNull, reason: k.name);
      }
    });
  });

  group('name days', () {
    final NameDays nd =
        NameDays.parse(File('assets/data/name_days.json').readAsStringSync());

    test('a saved name lands on its primary day, grouped', () {
      final Map<DateTime, List<NameDayHit>> hits =
          NotificationPlanner.nameDaysAhead(
        nd,
        const <SavedName>[
          SavedName('Andrei', label: 'Tata'),
          SavedName('Maria', label: 'Mama'),
        ],
        DateTime(2026, 11, 24),
        60,
      );
      expect(hits.keys, <DateTime>[DateTime(2026, 11, 30)]);
      expect(hits.values.single.single.saved.display, 'Tata (Andrei)');
    });

    test('Maria next August, outside a 60-day window, inside a year', () {
      final Map<DateTime, List<NameDayHit>> hits =
          NotificationPlanner.nameDaysAhead(nd,
              const <SavedName>[SavedName('Maria')], DateTime(2026, 11, 24), 366);
      expect(hits.keys, <DateTime>[DateTime(2027, 8, 15)]);
    });

    test('today counts', () {
      expect(
          NotificationPlanner.nameDaysAhead(nd,
                  const <SavedName>[SavedName('Andrei')], DateTime(2026, 11, 30), 1)
              .keys,
          <DateTime>[DateTime(2026, 11, 30)]);
    });

    test('names are joined the Romanian way', () {
      expect(NotificationPlanner.joinRo(<String>['Ana']), 'Ana');
      expect(NotificationPlanner.joinRo(<String>['Ana', 'Ion']), 'Ana și Ion');
      expect(NotificationPlanner.joinRo(<String>['Ana', 'Ion', 'Maria']),
          'Ana, Ion și Maria');
    });
  });

  group('days', () {
    test('legal holidays: 17, two on one day in 2026', () {
      final Map<DateTime, List<String>> h =
          NotificationPlanner.legalHolidays(2026);
      expect(h.values.expand((List<String> n) => n).length, 17);
      expect(h[DateTime(2026, 6, 1)],
          <String>['Ziua Copilului', 'a doua zi de Rusalii']);
      expect(h[DateTime(2026, 4, 10)], <String>['Vinerea Mare']);
    });

    test('the three ajunuri', () {
      expect(NotificationPlanner.ajunName(DateTime(2026, 12, 24)),
          'Ajunul Crăciunului');
      expect(NotificationPlanner.ajunName(DateTime(2027, 1, 5)),
          'Ajunul Bobotezei');
      expect(NotificationPlanner.ajunName(DateTime(2026, 4, 11)),
          'Sâmbăta Mare');
      expect(NotificationPlanner.ajunName(DateTime(2026, 4, 12)), isNull);
    });

    test('Moșii from the published notes', () {
      expect(
          NotificationPlanner.pomenire(DateTime(2026, 11, 7),
              notes: 'Pomenirea morților - Moşii de toamnă',
              computed: false,
              level: NotifLevel.important),
          'Moșii de toamnă');
      const String lent =
          'Post; Sâmbăta a II-a din Post - Pomenirea morților; Nu se fac nunți';
      expect(
          NotificationPlanner.pomenire(DateTime(2026, 3, 7),
              notes: lent, computed: false, level: NotifLevel.all),
          'Sâmbăta a II-a din Post');
      expect(
          NotificationPlanner.pomenire(DateTime(2026, 3, 7),
              notes: lent, computed: false, level: NotifLevel.important),
          isNull);
      expect(
          NotificationPlanner.pomenire(DateTime(2026, 3, 8),
              notes: null, computed: false, level: NotifLevel.all),
          isNull);
    });

    test('Moșii in computed years follow Pascha, across the clock change',
        () {
      final DateTime p = FeastCalendar.pascha(2029);
      DateTime at(int d) => DateTime(p.year, p.month, p.day + d);
      String? mosi(int d, NotifLevel l) => NotificationPlanner.pomenire(at(d),
          notes: null, computed: true, level: l);
      expect(mosi(-57, NotifLevel.important), 'Moșii de iarnă');
      expect(mosi(48, NotifLevel.important), 'Moșii de vară');
      expect(mosi(-8, NotifLevel.important), isNull);
      expect(mosi(-8, NotifLevel.all), 'pomenirea morților');
      expect(mosi(-9, NotifLevel.all), isNull);
    });

    test('the published Moșii of 2026 match the Paschal rule', () {
      // 14 Feb and 30 May 2026, from the BOR calendar.
      String? computed(DateTime d) => NotificationPlanner.pomenire(d,
          notes: null, computed: true, level: NotifLevel.important);
      expect(computed(DateTime(2026, 2, 14)), 'Moșii de iarnă');
      expect(computed(DateTime(2026, 5, 30)), 'Moșii de vară');
    });

    test('dezlegări by level', () {
      expect(NotificationPlanner.isDezlegare(FastLevel.fish, NotifLevel.important),
          isTrue);
      expect(
          NotificationPlanner.isDezlegare(FastLevel.wineOil, NotifLevel.important),
          isFalse);
      expect(NotificationPlanner.isDezlegare(FastLevel.wineOil, NotifLevel.all),
          isTrue);
      expect(NotificationPlanner.isDezlegare(FastLevel.fast, NotifLevel.all),
          isFalse);
    });

    test('one-day fasts', () {
      expect(NotificationPlanner.oneDayFast(DateTime(2027, 8, 29)), isNotNull);
      expect(NotificationPlanner.oneDayFast(DateTime(2027, 8, 30)), isNull);
    });
  });

  test('saved names survive a round trip', () {
    const List<SavedName> names = <SavedName>[
      SavedName('Maria', label: 'Mama'),
      SavedName('Ion'),
    ];
    expect(SavedName.decodeList(SavedName.encodeList(names)), names);
    expect(SavedName.decodeList('not json'), isEmpty);
  });
}
