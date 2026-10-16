import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/troita_icons.dart';
import '../calendar/calendar_page.dart';
import '../fasting/fasting_page.dart';
import '../map/map_page.dart';
import '../profile/profile_page.dart';

/// Four tabs, matching `bottom-nav` (2:239): Calendar · Posturi · Hartă · Profil.
///
/// An [IndexedStack] keeps a tab's state when you leave it, which the map
/// needs — re-creating it means re-downloading its style and re-sending
/// thirteen thousand places. But an IndexedStack also *builds* every child on
/// the first frame, so the map used to start at launch for every user, opened
/// or not: a request to tiles.openfreemap.org on each start (an IP address
/// handed to a third party by someone who only wanted today's saint), and the
/// whole country's GeoJSON built alongside the calendar's first frame. So the
/// map is built the first time its tab is chosen, and kept from then on.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _tab = 0;

  /// Tabs that have been opened at least once. Only these are built.
  final Set<int> _opened = <int>{0};

  static const int _mapTab = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permissions and battery settings can change while backgrounded — the user
    // may be returning from the Settings app.
    if (state == AppLifecycleState.resumed) {
      final AppState app = AppScope.of(context);
      app.refreshStatus();
      // What stops the 60-day window from silently expiring. Throttled inside:
      // only rebuilt on a new day or after a few hours.
      app.rescheduleNotifications(force: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: <Widget>[
          const CalendarPage(),
          const FastingPage(),
          if (_opened.contains(_mapTab))
            const MapPage()
          else
            const SizedBox.shrink(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (int i) => setState(() {
          _tab = i;
          _opened.add(i);
        }),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(TroitaIcons.calendar),
            selectedIcon: Icon(TroitaIcons.calendarFilled),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(TroitaIcons.fasting),
            label: 'Posturi',
          ),
          NavigationDestination(
            icon: Icon(TroitaIcons.map),
            selectedIcon: Icon(TroitaIcons.mapFilled),
            label: 'Harta',
          ),
          NavigationDestination(
            icon: Icon(TroitaIcons.profile),
            selectedIcon: Icon(TroitaIcons.profileFilled),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
