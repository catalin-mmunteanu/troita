import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/troita_icons.dart';
import '../calendar/calendar_page.dart';
import '../fasting/fasting_page.dart';
import '../lecturi/lecturi_page.dart';
import '../profile/profile_page.dart';

/// Four tabs: Calendar · Posturi · Lecturi · Profil.
///
/// Lecturi took the map's place: reading the day's sinaxar and Gospel is
/// what people come back for each day; the map is a thing looked up now and
/// then. It opens from Profil and from a day's "Hramuri" card, as
/// `ChurchesMapPage`, built only then, so no request reaches
/// tiles.openfreemap.org from someone who never asked for the map.
///
/// An [IndexedStack] keeps a tab's state when you leave it, and builds a tab
/// the first time it is chosen, so Lecturi does not load the sinaxar and
/// the Bible alongside the calendar's first frame.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _tab = 0;

  /// Tabs that have been opened at least once. Only these are built.
  final Set<int> _opened = <int>{0};

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
          if (_opened.contains(1)) const FastingPage() else const SizedBox.shrink(),
          if (_opened.contains(2)) const LecturiPage() else const SizedBox.shrink(),
          if (_opened.contains(3)) const ProfilePage() else const SizedBox.shrink(),
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
            icon: Icon(TroitaIcons.book),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Lecturi',
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
