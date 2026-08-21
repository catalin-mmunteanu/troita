import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../history/history_page.dart';
import '../nearby/nearby_page.dart';
import '../settings/settings_page.dart';
import 'journey_page.dart';

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
    // Permissions and battery settings can change while we're backgrounded —
    // the user may have just come back from the Settings app. Re-read rather
    // than trusting cached state.
    if (state == AppLifecycleState.resumed) {
      AppScope.of(context).refreshStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          switch (_tab) {
            0 => 'Drum',
            1 => 'În apropiere',
            _ => 'Istoric',
          },
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const <Widget>[JourneyPage(), NearbyPage(), HistoryPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (int i) => setState(() => _tab = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.navigation_outlined),
            selectedIcon: Icon(Icons.navigation),
            label: 'Drum',
          ),
          NavigationDestination(
            icon: Icon(Icons.church_outlined),
            selectedIcon: Icon(Icons.church),
            label: 'În apropiere',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Istoric',
          ),
        ],
      ),
    );
  }
}
