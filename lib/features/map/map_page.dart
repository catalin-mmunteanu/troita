import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../church_detail/church_detail_page.dart';

/// The map of churches, monasteries and troițe.
///
/// Three decisions are worth knowing before changing anything here.
///
/// **The tiles are OpenFreeMap.** Not `tile.openstreetmap.org`: the OSM tile
/// usage policy forbids apps with this kind of traffic, and those servers now
/// answer 403 rather than degrading. OpenFreeMap serves OSM-derived vector
/// tiles with no API key, no request ceiling and no registration, which is what
/// keeps this feature free at any number of installs. Moving to MapTiler or
/// Stadia later means adding a key and a bill, not rewriting this file.
///
/// **Clustering happens on the GPU, not in Dart.** The country is roughly
/// twenty thousand points. As Flutter markers that is twenty thousand widgets
/// laid out every frame, which no phone survives at national zoom. A GeoJSON
/// source with `cluster: true` moves grouping into the native engine, where it
/// is a solved problem — Dart only ever sees the one feature actually tapped.
///
/// **Taps arrive through [MapLibreMap.onMapClick], and that needs
/// `featureTapsTriggersMapClick`.** Layers added through the controller are
/// interactive by default, and a tap landing on an interactive layer is
/// reported as a *feature* tap which never reaches `onMapClick`. Without that
/// flag this handler is dead code that looks perfectly correct.
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapLibreMapController? _controller;
  String? _error;
  int _count = 0;
  bool _styleLoaded = false;
  Timer? _styleWatchdog;
  int _attempt = 0;

  static const String _sourceId = 'churches';
  static const String _pointsLayer = 'church-points';
  static const String _clusterLayer = 'church-clusters';

  /// Romania, framed so the whole country is visible on first open.
  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(45.9, 25.0),
    zoom: 5.6,
  );

  /// Vector style, free and keyless. `liberty` is the fullest of the
  /// OpenFreeMap styles; swap in `positron` if the map should recede behind
  /// the markers.
  static const String _styleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  @override
  void initState() {
    super.initState();
    _armWatchdog();
  }

  @override
  void dispose() {
    _styleWatchdog?.cancel();
    super.dispose();
  }

  /// MapLibre reports a failed style load only to the native log — the widget
  /// exposes no callback for it, and `onStyleLoadedCallback` simply never
  /// fires. Left alone, a phone with no DNS or no signal shows a blank grey
  /// rectangle forever and the user has no idea whether the app is broken or
  /// their connection is. So: if the style has not arrived in fifteen seconds,
  /// say so and offer to try again.
  void _armWatchdog() {
    _styleWatchdog?.cancel();
    _styleWatchdog = Timer(const Duration(seconds: 15), () {
      if (mounted && !_styleLoaded) {
        setState(() => _error = 'offline');
      }
    });
  }

  void _retry() {
    setState(() {
      _error = null;
      _styleLoaded = false;
      // Changing the key rebuilds the platform view, which is the only way to
      // make MapLibre attempt the style again.
      _attempt++;
    });
    _armWatchdog();
  }

  Future<void> _onStyleLoaded() async {
    final MapLibreMapController? map = _controller;
    if (map == null) return;
    _styleWatchdog?.cancel();
    if (mounted) setState(() => _styleLoaded = true);

    try {
      final AppState state = AppScope.of(context);
      final Map<String, Object?> geojson =
          await state.repository.allAsGeoJson();
      if (!mounted) return;

      final int featureCount = (geojson['features'] as List<Object?>).length;
      debugPrint('[map] adding $featureCount churches to the source');

      await map.addSource(
        _sourceId,
        GeojsonSourceProperties(
          data: geojson,
          cluster: true,
          // Stop clustering at 13: by then the user is looking at one
          // neighbourhood and wants the individual churches.
          clusterMaxZoom: 13,
          clusterRadius: 50,
        ),
      );

      // Cluster bubbles. Stepped rather than continuous — an unbounded scale
      // would turn Bucharest into a disc covering half the screen.
      await map.addCircleLayer(
        _sourceId,
        _clusterLayer,
        CircleLayerProperties(
          circleColor: TroitaColors.burgundy.toHexStringRGB(),
          circleOpacity: 0.9,
          circleRadius: <Object>[
            'step',
            <Object>['get', 'point_count'],
            16,
            25, 20,
            100, 26,
            500, 32,
          ],
          circleStrokeWidth: 2,
          circleStrokeColor: TroitaColors.paper.toHexStringRGB(),
        ),
        filter: <Object>['has', 'point_count'],
      );

      await map.addSymbolLayer(
        _sourceId,
        'church-cluster-count',
        SymbolLayerProperties(
          textField: <Object>['get', 'point_count_abbreviated'],
          textSize: 13,
          textColor: TroitaColors.onBurgundy.toHexStringRGB(),
          textFont: <String>['Noto Sans Bold'],
          // Otherwise MapLibre hides counts whose bubbles touch, and dense
          // regions end up as numberless circles.
          textAllowOverlap: true,
        ),
        filter: <Object>['has', 'point_count'],
        // The label must not swallow the tap meant for the bubble under it.
        enableInteraction: false,
      );

      await map.addCircleLayer(
        _sourceId,
        _pointsLayer,
        CircleLayerProperties(
          circleColor: TroitaColors.feastRed.toHexStringRGB(),
          circleRadius: 6,
          circleStrokeWidth: 2,
          circleStrokeColor: TroitaColors.paper.toHexStringRGB(),
        ),
        filter: <Object>[
          '!',
          <Object>['has', 'point_count'],
        ],
      );

      // Names appear only once the map is close enough for them to be readable
      // and for the engine's collision detection to have room to work.
      await map.addSymbolLayer(
        _sourceId,
        'church-labels',
        SymbolLayerProperties(
          textField: <Object>['get', 'name'],
          textSize: 12,
          textColor: TroitaColors.ink.toHexStringRGB(),
          textHaloColor: TroitaColors.paper.toHexStringRGB(),
          textHaloWidth: 1.5,
          textOffset: <Object>[
            'literal',
            <double>[0, 1.4],
          ],
          textAnchor: 'top',
          textFont: <String>['Noto Sans Regular'],
        ),
        filter: <Object>[
          '!',
          <Object>['has', 'point_count'],
        ],
        minzoom: 13,
        enableInteraction: false,
      );

      // Prove the source actually exists rather than trusting that addSource
      // returned without throwing. It returns cleanly even when the native
      // side declined to build the source — which is exactly how this feature
      // first shipped a perfect, empty map.
      final List<String> ids = await map.getSourceIds();
      debugPrint('[map] sources now in the style: $ids');
      if (mounted) {
        setState(() => _count = ids.contains(_sourceId) ? featureCount : 0);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// A tap on the map. Empty ground returns no features and does nothing.
  ///
  /// A cluster zooms to exactly the level where it breaks apart, which the
  /// engine can compute — guessing "current zoom + 2" either overshoots past
  /// the split or leaves the same bubble sitting there, and the second is the
  /// one users read as the map being broken.
  Future<void> _onMapClick(Point<double> point, LatLng coords) async {
    final MapLibreMapController? map = _controller;
    if (map == null) return;

    final List<dynamic> hits = await map.queryRenderedFeatures(
      point,
      <String>[_pointsLayer, _clusterLayer],
      null,
    );
    if (hits.isEmpty || !mounted) return;

    final Map<Object?, Object?> feature = hits.first as Map<Object?, Object?>;
    final Map<Object?, Object?> props =
        (feature['properties'] as Map<Object?, Object?>?) ??
            const <Object?, Object?>{};

    final Object? clusterId = props['cluster_id'];
    if (clusterId is num) {
      final int zoom =
          await map.getClusterExpansionZoom(_sourceId, clusterId.toInt());
      if (!mounted) return;
      await map.animateCamera(
        CameraUpdate.newLatLngZoom(coords, zoom.toDouble()),
      );
      return;
    }

    final Object? id = props['id'];
    if (id is! String || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChurchDetailPage(churchId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        MapLibreMap(
          key: ValueKey<int>(_attempt),
          initialCameraPosition: _initialCamera,
          styleString: _styleUrl,
          onMapCreated: (MapLibreMapController c) => _controller = c,
          onStyleLoadedCallback: _onStyleLoaded,
          onMapClick: _onMapClick,
          // Without this, taps on the church and cluster layers never reach
          // _onMapClick. See the class comment.
          featureTapsTriggersMapClick: true,
          // OSM data is ODbL; the attribution button is how we carry the credit.
          attributionButtonPosition: AttributionButtonPosition.bottomRight,
          myLocationEnabled: false,
          compassEnabled: true,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(TroitaSpacing.gap),
            child: _Banner(
              count: _count,
              error: _error,
              onRetry: _retry,
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.count,
    required this.error,
    required this.onRetry,
  });

  final int count;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.all(TroitaSpacing.card),
          decoration: BoxDecoration(
            color: TroitaColors.paper,
            borderRadius: TroitaRadius.mediumAll,
            border: Border.all(color: TroitaColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Harta nu s-a putut încărca',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 6),
              const Text(
                'Fondul de hartă are nevoie de internet.\n'
                'Verifică conexiunea și încearcă din nou.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: TroitaColors.muted),
              ),
              const SizedBox(height: TroitaSpacing.gap),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: TroitaColors.burgundy,
                  foregroundColor: TroitaColors.onBurgundy,
                ),
                child: const Text('Încearcă din nou'),
              ),
            ],
          ),
        ),
      );
    }
    if (count == 0) return const SizedBox.shrink();
    return _Pill(colour: TroitaColors.burgundy, text: '$count lăcașuri');
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.colour, required this.text});

  final Color colour;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: colour,
          borderRadius: TroitaRadius.smallAll,
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: TroitaColors.onBurgundy,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
