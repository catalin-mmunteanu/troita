import 'package:flutter/material.dart';

/// Icon indirection.
///
/// The Figma file uses lucide (`fish-off`, `calendar-days`, `map-pin`,
/// `user-circle` are lucide's own layer names). The exported SVGs are not in
/// the repo yet — see `assets/icons/README.md` — so each name currently
/// resolves to the closest Material glyph.
///
/// Deliberately *not* hand-drawn approximations of the lucide paths: an
/// almost-right icon is worse than an honestly different one, because nobody
/// notices it needs replacing. Swapping to the real assets is a change to this
/// file only.
abstract final class TroitaIcons {
  static const IconData calendar = Icons.calendar_month_outlined;
  static const IconData calendarFilled = Icons.calendar_month;
  static const IconData fasting = Icons.set_meal_outlined;
  static const IconData map = Icons.place_outlined;
  static const IconData mapFilled = Icons.place;
  static const IconData profile = Icons.account_circle_outlined;
  static const IconData profileFilled = Icons.account_circle;
  static const IconData search = Icons.search;
  static const IconData cross = Icons.add;
  static const IconData book = Icons.menu_book_outlined;
  static const IconData bell = Icons.notifications_none;
  static const IconData clock = Icons.schedule;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData back = Icons.arrow_back;
  static const IconData church = Icons.church_outlined;

  /// Planned: favourites and the visited marker.
  static const IconData favorite = Icons.favorite_border;
  static const IconData favoriteFilled = Icons.favorite;
  static const IconData visited = Icons.check_circle_outline;
  static const IconData visitedFilled = Icons.check_circle;
}
