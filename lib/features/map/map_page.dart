import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/models/church.dart';
import '../church_detail/church_detail_page.dart';
import 'place_kind.dart';

/// The map of churches, monasteries and troițe.
///
/// Four decisions are worth knowing before changing anything here.
///
/// **The tiles are OpenFreeMap.** Not `tile.openstreetmap.org`: the OSM tile
/// usage policy forbids apps with this kind of traffic, and those servers now
/// answer 403. OpenFreeMap serves OSM-derived vector tiles with no API key, no
/// request ceiling and no registration, which is what keeps this feature free
/// at any number of installs.
///
/// **Clustering happens on the GPU, not in Dart.** The country is roughly
/// thirteen thousand points. As Flutter markers that is thirteen thousand
/// widgets laid out every frame, which no phone survives at national zoom. A
/// GeoJSON source with `cluster: true` moves grouping into the native engine,
/// where it is a solved problem — Dart only ever sees the one feature tapped.
///
/// **Filtering by kind replaces the source's data rather than the layer's
/// filter.** A layer filter would hide the dots but leave them inside their
/// clusters, so a bubble would claim forty places while showing eight. Clusters
/// are computed by the source, so the only way to make the numbers true is to
/// give the source fewer features.
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
  bool _styleLoaded = false;
  Timer? _styleWatchdog;
  int _attempt = 0;

  /// Every place, unfiltered, held so a chip toggle is a list filter rather
  /// than another trip to SQLite.
  List<Map<String, Object?>> _all = const <Map<String, Object?>>[];
  Set<PlaceKind> _visible = PlaceKind.defaultVisible;

  /// Places per kind, counted once when the data arrives. It was recomputed
  /// in build — a pass over thirteen thousand features on every rebuild,
  /// including every keystroke in the search field.
  Map<PlaceKind, int> _counts = const <PlaceKind, int>{};

  /// Whether the legend shows its rows or only its row of dots.
  bool _legendOpen = true;
  int _shown = 0;

  final TextEditingController _query = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  Timer? _debounce;
  List<Church> _results = const <Church>[];
  bool _searching = false;
  Church? _selected;

  static const String _sourceId = 'churches';
  static const String _selectedSourceId = 'church-selected';
  static const String _pointsLayer = 'church-points';
  static const String _clusterLayer = 'church-clusters';

  /// Romania, framed so the whole country is visible on first open.
  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(45.9, 25.0),
    zoom: 5.6,
  );

  static const String _styleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  @override
  void initState() {
    super.initState();
    _armWatchdog();
  }

  @override
  void dispose() {
    _styleWatchdog?.cancel();
    _debounce?.cancel();
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  /// MapLibre reports a failed style load only to the native log — the widget
  /// exposes no callback for it, and `onStyleLoadedCallback` simply never
  /// fires. Left alone, a phone with no DNS shows a blank grey rectangle
  /// forever and the user cannot tell whether the app or their connection is
  /// broken. So: if the style has not arrived in fifteen seconds, say so.
  void _armWatchdog() {
    _styleWatchdog?.cancel();
    _styleWatchdog = Timer(const Duration(seconds: 15), () {
      if (mounted && !_styleLoaded) setState(() => _error = 'offline');
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

  // ------------------------------------------------------------------ data

  /// The features the source should currently hold.
  Map<String, dynamic> _collection() {
    final Set<String> ids = _visible.map((PlaceKind k) => k.id).toSet();
    final List<Map<String, Object?>> features = <Map<String, Object?>>[
      for (final Map<String, Object?> f in _all)
        if (ids.contains(_kindIdOf(f))) f,
    ];
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  static String _kindIdOf(Map<String, Object?> feature) {
    final Object? props = feature['properties'];
    if (props is Map) return (props['kind'] as String?) ?? 'church';
    return 'church';
  }

  /// How many places each kind has, for the chips.
  ///
  /// A chip that is switched off needs to say what switching it on would give
  /// you. "Troițe" alone reads as a category that might be empty; "Troițe
  /// 1.505" is an invitation.
  Map<PlaceKind, int> _countByKind() {
    final Map<PlaceKind, int> counts = <PlaceKind, int>{
      for (final PlaceKind k in PlaceKind.values) k: 0,
    };
    for (final Map<String, Object?> f in _all) {
      final PlaceKind k = PlaceKind.from(_kindIdOf(f));
      counts[k] = (counts[k] ?? 0) + 1;
    }
    return counts;
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

      _all = (geojson['features'] as List<Object?>)
          .cast<Map<String, Object?>>()
          .toList(growable: false);
      _counts = _countByKind();

      final Map<String, dynamic> initial = _collection();
      debugPrint('[map] ${_all.length} places, '
          '${(initial['features'] as List<Object?>).length} visible');

      await map.addSource(
        _sourceId,
        GeojsonSourceProperties(
          data: initial,
          cluster: true,
          // Stop clustering at 13: by then the user is looking at one
          // neighbourhood and wants the individual places.
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

      // Individual places, coloured and sized by kind. A `match` expression
      // rather than one layer per kind: five layers would mean five sets of
      // properties to keep in step, and five chances for a tap to land on the
      // wrong one.
      await map.addCircleLayer(
        _sourceId,
        _pointsLayer,
        CircleLayerProperties(
          circleColor: _matchByKind(
            (PlaceKind k) => k.colour.toHexStringRGB(),
          ),
          circleRadius: _matchByKind((PlaceKind k) => k.radius),
          circleStrokeWidth: 1.5,
          circleStrokeColor: _matchByKind(
            (PlaceKind k) => k.stroke.toHexStringRGB(),
          ),
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

      // The ring drawn around a search result. Its own source, so highlighting
      // is one small update instead of touching the thirteen-thousand-feature
      // collection. Added last, so it draws over everything.
      await map.addSource(
        _selectedSourceId,
        const GeojsonSourceProperties(
          data: <String, dynamic>{
            'type': 'FeatureCollection',
            'features': <Object>[],
          },
        ),
      );
      await map.addCircleLayer(
        _selectedSourceId,
        'church-selected-ring',
        CircleLayerProperties(
          circleRadius: 16,
          // Hollow: the dot underneath must stay visible and keep its own
          // colour, so this marks the place without hiding what it is.
          circleColor: TroitaColors.burgundy.toHexStringRGB(),
          circleOpacity: 0.12,
          circleStrokeWidth: 2.5,
          circleStrokeColor: TroitaColors.burgundy.toHexStringRGB(),
        ),
        enableInteraction: false,
      );

      final List<String> ids = await map.getSourceIds();
      debugPrint('[map] sources now in the style: $ids');
      if (mounted) {
        setState(() => _shown = ids.contains(_sourceId)
            ? (initial['features'] as List<Object?>).length
            : 0);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// `['match', ['get','kind'], 'monastery', x, 'cathedral', y, …, fallback]`.
  static List<Object> _matchByKind(Object Function(PlaceKind) value) {
    return <Object>[
      'match',
      <Object>['get', 'kind'],
      for (final PlaceKind k in PlaceKind.values) ...<Object>[
        k.id,
        value(k),
      ],
      // Unrecognised kinds draw as a plain church rather than disappearing.
      value(PlaceKind.church),
    ];
  }

  Future<void> _toggleKind(PlaceKind kind) async {
    final Set<PlaceKind> next = Set<PlaceKind>.of(_visible);
    if (!next.remove(kind)) next.add(kind);

    // Turning the last kind off is allowed. Refusing it made the chip do
    // nothing with no explanation, which is worse than an empty map — and an
    // empty map is not confusing here, because every chip then reads "+1.505"
    // and says exactly how to undo it.
    setState(() => _visible = next);
    final Map<String, dynamic> data = _collection();
    setState(() => _shown = (data['features'] as List<Object?>).length);
    await _controller?.setGeoJsonSource(_sourceId, data);
  }

  // ---------------------------------------------------------------- search

  void _onQueryChanged(String raw) {
    _debounce?.cancel();
    final String q = raw.trim();
    if (q.length < 2) {
      setState(() {
        _results = const <Church>[];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    // Typing is faster than SQLite over thirteen thousand rows with three LIKE
    // clauses; without this every keystroke queues a query and the results
    // arrive out of order.
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      final List<Church> found =
          await AppScope.of(context).repository.search(q, limit: 30);
      if (!mounted || _query.text.trim() != q) return;
      setState(() {
        _results = found;
        _searching = false;
      });
    });
  }

  Future<void> _select(Church church) async {
    _queryFocus.unfocus();
    final PlaceKind kind = PlaceKind.from(church.kind);

    // Searching past a filter and landing on an invisible dot would look like
    // the map ignored the tap, so the kind is switched back on.
    final bool needsKind = !_visible.contains(kind);
    setState(() {
      _results = const <Church>[];
      _query.clear();
      _selected = church;
      if (needsKind) _visible = Set<PlaceKind>.of(_visible)..add(kind);
    });

    final MapLibreMapController? map = _controller;
    if (map == null) return;

    if (needsKind) {
      final Map<String, dynamic> data = _collection();
      setState(() => _shown = (data['features'] as List<Object?>).length);
      await map.setGeoJsonSource(_sourceId, data);
    }

    await map.setGeoJsonSource(_selectedSourceId, <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'Feature',
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': <double>[church.lon, church.lat],
          },
          'properties': <String, dynamic>{'id': church.id},
        },
      ],
    });

    // 15 is past clusterMaxZoom, so the place is guaranteed to be drawn as
    // itself rather than swallowed by a bubble the user then has to hunt for.
    await map.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(church.lat, church.lon), 15),
      duration: const Duration(milliseconds: 700),
    );
  }

  Future<void> _clearSelection() async {
    setState(() => _selected = null);
    await _controller?.setGeoJsonSource(_selectedSourceId, <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <Object>[],
    });
  }

  // ------------------------------------------------------------------- taps

  /// A tap on the map. Empty ground returns no features and does nothing.
  ///
  /// A cluster zooms to exactly the level where it breaks apart, which the
  /// engine can compute — guessing "current zoom + 2" either overshoots the
  /// split or leaves the same bubble sitting there, and the second is the one
  /// users read as the map being broken.
  Future<void> _onMapClick(Point<double> point, LatLng coords) async {
    final MapLibreMapController? map = _controller;
    if (map == null) return;
    _queryFocus.unfocus();

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

  // ------------------------------------------------------------------ build

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
          // OSM data is ODbL; the attribution button carries the credit.
          attributionButtonPosition: AttributionButtonPosition.bottomRight,
          myLocationEnabled: false,
          compassEnabled: true,
        ),
        if (_error != null)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(TroitaSpacing.gap),
              child: _OfflineCard(onRetry: _retry),
            ),
          )
        else
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(TroitaSpacing.gap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _SearchField(
                    controller: _query,
                    focus: _queryFocus,
                    onChanged: _onQueryChanged,
                    onClear: () {
                      _query.clear();
                      _onQueryChanged('');
                      _clearSelection();
                    },
                    showClear: _query.text.isNotEmpty || _selected != null,
                  ),
                  if (_results.isNotEmpty || _searching)
                    _Results(
                      results: _results,
                      searching: _searching,
                      onTap: _select,
                    ),
                  const Spacer(),
                  // Hidden while results are open: the list needs the height,
                  // and the legend is one tap away once a result is chosen.
                  if (_results.isEmpty && !_searching && _counts.isNotEmpty)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: _Legend(
                        visible: _visible,
                        counts: _counts,
                        shown: _shown,
                        expanded: _legendOpen,
                        onToggleKind: _toggleKind,
                        onToggleOpen: () =>
                            setState(() => _legendOpen = !_legendOpen),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------- pieces

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focus,
    required this.onChanged,
    required this.onClear,
    required this.showClear,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool showClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TroitaColors.paper,
      borderRadius: TroitaRadius.mediumAll,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            const Icon(Icons.search, size: 22, color: TroitaColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focus,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 15, color: TroitaColors.ink),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Caută o biserică sau o localitate',
                  hintStyle:
                      TextStyle(fontSize: 14, color: TroitaColors.muted),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (showClear)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: TroitaColors.muted,
                onPressed: onClear,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.results,
    required this.searching,
    required this.onTap,
  });

  final List<Church> results;
  final bool searching;
  final ValueChanged<Church> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: TroitaSpacing.listGap),
      // Capped so the map stays visible behind the results — the point of
      // searching here rather than in a list is to keep seeing where things are.
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: TroitaColors.paper,
        borderRadius: TroitaRadius.mediumAll,
        border: Border.all(color: TroitaColors.border),
      ),
      child: searching && results.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(TroitaSpacing.card),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: TroitaColors.border),
              itemBuilder: (BuildContext context, int i) {
                final Church c = results[i];
                final PlaceKind kind = PlaceKind.from(c.kind);
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: kind.colour,
                      shape: BoxShape.circle,
                      border: Border.all(color: TroitaColors.paper, width: 1.5),
                    ),
                  ),
                  title: Text(
                    c.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, color: TroitaColors.ink),
                  ),
                  subtitle: Text(
                    <String>[
                      kind.singular,
                      if (c.address != null && c.address!.isNotEmpty) c.address!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: TroitaColors.muted),
                  ),
                  onTap: () => onTap(c),
                );
              },
            ),
    );
  }
}

/// The legend, which is also the filter.
///
/// It replaces a horizontally scrolling row of chips that had two problems.
/// Five chips did not fit across a phone, so some were always off screen; and
/// switched-off chips were moved to the front so the one you wanted stayed in
/// view, which meant the chip you had just tapped jumped away from your finger.
///
/// This sits still. A small card in the corner, one row per kind in a fixed
/// order — tapping a row switches it, and nothing moves. It is about as wide as
/// its longest label, so it covers a corner of the map and not a band across
/// it, and folding it leaves only the five dots, which still say what is shown.
class _Legend extends StatelessWidget {
  const _Legend({
    required this.visible,
    required this.counts,
    required this.shown,
    required this.expanded,
    required this.onToggleKind,
    required this.onToggleOpen,
  });

  final Set<PlaceKind> visible;
  final Map<PlaceKind, int> counts;
  final int shown;
  final bool expanded;
  final ValueChanged<PlaceKind> onToggleKind;
  final VoidCallback onToggleOpen;

  static String _n(int n) {
    // Romanian groups thousands with a dot: 11.059.
    final String s = '$n';
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
      out.write(s[i]);
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TroitaColors.paper.withValues(alpha: 0.96),
      elevation: 3,
      borderRadius: TroitaRadius.mediumAll,
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.bottomLeft,
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header: the count on the map, and the fold.
              InkWell(
                onTap: onToggleOpen,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
                  child: Row(
                    children: <Widget>[
                      if (expanded)
                        Text(
                          '${_n(shown)} pe hartă',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: TroitaColors.ink,
                          ),
                        )
                      else
                        // Folded, the dots alone still say what is shown.
                        for (final PlaceKind k in PlaceKind.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: _Dot(kind: k, on: visible.contains(k)),
                          ),
                      const SizedBox(width: 6),
                      const Spacer(),
                      Icon(
                        expanded ? Icons.expand_more : Icons.expand_less,
                        size: 20,
                        color: TroitaColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded) ...<Widget>[
                const Divider(height: 1, color: TroitaColors.border),
                for (final PlaceKind k in PlaceKind.values)
                  _LegendRow(
                    kind: k,
                    on: visible.contains(k),
                    count: _n(counts[k] ?? 0),
                    onTap: () => onToggleKind(k),
                  ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.kind,
    required this.on,
    required this.count,
    required this.onTap,
  });

  final PlaceKind kind;
  final bool on;
  final String count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      label: '${kind.label}, $count',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // 36 px rows: comfortably tappable, and five of them stay short.
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: Row(
            children: <Widget>[
              _Dot(kind: kind, on: on),
              const SizedBox(width: 9),
              Text(
                kind.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  // Off reads as off, not as disabled: still legible, just
                  // quieter, next to a hollow dot.
                  color: on ? TroitaColors.ink : TroitaColors.muted,
                  decoration: on ? null : TextDecoration.lineThrough,
                  decorationColor: TroitaColors.muted,
                ),
              ),
              const SizedBox(width: 14),
              const Spacer(),
              Text(
                count,
                style: TextStyle(
                  fontSize: 12,
                  // Still readable when off: the count is what tells you
                  // there is something to switch back on.
                  color: on
                      ? TroitaColors.muted
                      : TroitaColors.muted.withValues(alpha: 0.6),
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The same dot the map draws, at legend size: filled when shown, a ring when
/// hidden.
class _Dot extends StatelessWidget {
  const _Dot({required this.kind, required this.on});

  final PlaceKind kind;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: on ? kind.colour : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: on ? kind.stroke : kind.colour,
          width: on ? 1.5 : 2,
        ),
        boxShadow: on
            ? const <BoxShadow>[
                BoxShadow(color: Color(0x33000000), blurRadius: 1.5),
              ]
            : null,
      ),
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
}
