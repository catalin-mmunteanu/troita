import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/data/photo_resolver.dart';
import '../../core/format.dart';
import '../../core/models/church.dart';
import '../../core/models/feast_calendar.dart';
import '../../app/app_scope.dart';

class ChurchDetailPage extends StatefulWidget {
  const ChurchDetailPage({required this.churchId, this.initial, super.key});

  final String churchId;

  /// Passed when we already have the row, so the screen paints immediately
  /// instead of flashing a spinner — notification taps arrive without it.
  final Church? initial;

  @override
  State<ChurchDetailPage> createState() => _ChurchDetailPageState();
}

class _ChurchDetailPageState extends State<ChurchDetailPage> {
  Church? _church;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _church = widget.initial;
    // dependOnInheritedWidgetOfExactType is illegal during initState, and
    // _load reaches the store — defer it by a frame.
    if (_church == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final Church? found =
        await AppScope.of(context).repository.byId(widget.churchId);
    if (!mounted) return;
    setState(() {
      _church = found;
      _missing = found == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Church? church = _church;

    if (_missing) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Biserica nu a fost găsită.')),
      );
    }
    if (church == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final ImageProvider? photo = PhotoResolver.resolve(church.photoRef);
    final DateTime? feast = FeastCalendar.next(church.feastDay);

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: photo == null ? 0 : 240,
            pinned: true,
            flexibleSpace: photo == null
                ? null
                : FlexibleSpaceBar(
                    background: Image(
                      image: photo,
                      fit: BoxFit.cover,
                      // Photos are optional and often missing in the MVP seed;
                      // never let a missing asset break the screen.
                      errorBuilder: (_, __, ___) =>
                          Container(color: TroitaTheme.gold.withValues(alpha: 0.15)),
                    ),
                  ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                Text(church.name,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  <String>[
                    Fmt.kind(church.kind),
                    if (church.yearBuilt != null) 'ridicată în ${church.yearBuilt}',
                    if (church.distanceM != null) Fmt.distance(church.distanceM),
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                if (church.patron != null)
                  _Fact(
                    label: 'Hramul',
                    value: church.patron!,
                    detail: feast == null
                        ? null
                        : '${Fmt.feast(church.feastDay)}'
                            '${FeastCalendar.isToday(church.feastDay) ? ' — astăzi' : ''}',
                    highlight: FeastCalendar.isToday(church.feastDay),
                  ),
                if (church.address != null)
                  _Fact(label: 'Adresa', value: church.address!),
                if (church.history != null) ...<Widget>[
                  const SizedBox(height: 18),
                  Text(church.history!,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 28),
                Text(
                  'Coordonate: ${church.lat.toStringAsFixed(5)}, '
                  '${church.lon.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Date din OpenStreetMap (ODbL) și contribuții comunitare.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.detail,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String? detail;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: TroitaTheme.muted,
              )),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          if (detail != null)
            Text(
              detail!,
              style: TextStyle(
                fontSize: 13,
                color: highlight ? TroitaTheme.red : TroitaTheme.muted,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }
}
