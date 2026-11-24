import 'package:material_ui/material_ui.dart';

import 'map_page.dart';

/// The map as a screen of its own: "Biserici și hartă".
///
/// It used to be the third tab. It is opened now from Profil and from a
/// day's "Hramuri" card, and still built only when opened, so OpenFreeMap
/// hears from someone only when they asked for the map.
class ChurchesMapPage extends StatelessWidget {
  const ChurchesMapPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Biserici și hartă')),
        body: const MapPage(),
      );
}
