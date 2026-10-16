import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/config.dart';
import '../../app/theme.dart';
import '../../core/data/church_marks_repository.dart';
import '../../core/data/photo_resolver.dart';
import '../../core/format.dart';
import '../../core/models/church.dart';
import '../../core/models/feast_calendar.dart';

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
  ChurchMark? _mark;

  @override
  void initState() {
    super.initState();
    _church = widget.initial;
    // dependOnInheritedWidgetOfExactType is illegal during initState, and
    // _load reaches the store — defer it by a frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final AppState state = AppScope.of(context);
    final Church? found = _church ?? await state.repository.byId(widget.churchId);
    final ChurchMark mark = await state.marks.forChurch(widget.churchId);
    if (!mounted) return;
    setState(() {
      _church = found;
      _missing = found == null;
      _mark = mark;
    });
  }

  Future<void> _toggleFavourite() async {
    final bool on = !(_mark?.favourite ?? false);
    final ChurchMark mark =
        await AppScope.of(context).setFavourite(widget.churchId, on);
    if (mounted) setState(() => _mark = mark);
  }

  Future<void> _toggleVisited() async {
    final bool on = !(_mark?.visited ?? false);
    final ChurchMark mark =
        await AppScope.of(context).setVisited(widget.churchId, on);
    if (mounted) setState(() => _mark = mark);
  }

  /// Directions in whatever the user has — Google Maps, Waze, anything that
  /// answers a geo: link. No location permission: the maps app finds the
  /// user itself, which is the whole reason not to do it here.
  Future<void> _navigate(Church c) async {
    final String label = Uri.encodeComponent(c.name);
    final bool ok = await AppScope.of(context).native.openUri(
          'geo:${c.lat},${c.lon}?q=${c.lat},${c.lon}($label)',
        );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nu există pe telefon o aplicație de hărți.'),
      ));
    }
  }

  /// A pre-filled email: which place, where, and room to say what is wrong.
  /// Nothing about the phone or the user goes in — only the place itself.
  Future<void> _report(Church c) async {
    final String subject = Uri.encodeComponent('Troița: ${c.name}');
    final String body = Uri.encodeComponent(
      'Ce nu este corect?\n\n\n'
      '—\n'
      '${c.name}\n'
      '${Fmt.kind(c.kind)} · ${c.lat.toStringAsFixed(5)}, '
      '${c.lon.toStringAsFixed(5)}\n'
      '${c.id}',
    );
    final bool ok = await AppScope.of(context).native.openUri(
          'mailto:${AppConfig.supportEmail}?subject=$subject&body=$body',
        );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nu există pe telefon o aplicație de email.'),
      ));
    }
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
                const SizedBox(height: 18),
                _Actions(
                  mark: _mark,
                  onFavourite: _toggleFavourite,
                  onVisited: _toggleVisited,
                  onNavigate: () => _navigate(church),
                ),
                const SizedBox(height: 22),
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
                if (AppConfig.canReport) ...<Widget>[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _report(church),
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: const Text('Raportează o greșeală'),
                      style: TextButton.styleFrom(
                        foregroundColor: TroitaColors.muted,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
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


/// Favourite, visited, directions: three equal buttons, each a large target.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.mark,
    required this.onFavourite,
    required this.onVisited,
    required this.onNavigate,
  });

  final ChurchMark? mark;
  final VoidCallback onFavourite;
  final VoidCallback onVisited;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final bool fav = mark?.favourite ?? false;
    final bool visited = mark?.visited ?? false;
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionButton(
            icon: fav ? Icons.star : Icons.star_border,
            label: fav ? 'Favorită' : 'Adaugă la favorite',
            on: fav,
            colour: TroitaColors.gold,
            onTap: onFavourite,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: visited ? Icons.check_circle : Icons.check_circle_outline,
            label: visited ? 'Vizitată' : 'Am vizitat',
            on: visited,
            colour: TroitaColors.burgundy,
            onTap: onVisited,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.directions_outlined,
            label: 'Navighează',
            on: false,
            colour: TroitaColors.ink,
            onTap: onNavigate,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.on,
    required this.colour,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool on;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      child: Material(
        color: on ? colour.withValues(alpha: 0.12) : TroitaColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: TroitaRadius.smallAll,
          side: BorderSide(
            color: on ? colour : TroitaColors.border,
            width: on ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: TroitaRadius.smallAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 24, color: on ? colour : TroitaColors.ink),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.15,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    color: on ? colour : TroitaColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
