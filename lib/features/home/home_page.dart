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
/// Hartă is a placeholder while the map feature is being redefined.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _tab = 0;

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
      // Cheap, and it is what stops the 60-day window from silently expiring.
      app.rescheduleNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const <Widget>[
          CalendarPage(),
          FastingPage(),
          MapPage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (int i) => setState(() => _tab = i),
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
