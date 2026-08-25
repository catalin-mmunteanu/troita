import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/troita_icons.dart';
import '../nearby/nearby_page.dart';

/// Placeholder for the map.
///
/// The `harta-bisericilor` frame in Figma is empty, and the feature is being
/// redefined — a browsable map of churches, monasteries and troițe, with
/// favourites and a visited marker. Until that is specified, this keeps the
/// tab useful by showing the church list that already works.
///
/// Nothing here is load-bearing; replace the whole file when the map lands.
class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TroitaSpacing.page, TroitaSpacing.page, TroitaSpacing.page, 6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Biserici',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'Biserici, mănăstiri și troițe din apropiere.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(
              TroitaSpacing.page, TroitaSpacing.listGap, TroitaSpacing.page, 0,
            ),
            padding: const EdgeInsets.all(TroitaSpacing.card),
            decoration: TroitaTheme.cardDecoration(),
            child: Row(
              children: <Widget>[
                const Icon(TroitaIcons.map, size: 20, color: TroitaColors.gold),
                const SizedBox(width: TroitaSpacing.gap),
                Expanded(
                  child: Text(
                    'Harta interactivă urmează. Deocamdată, lista de mai jos.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: NearbyPage()),
        ],
      ),
    );
  }
}
