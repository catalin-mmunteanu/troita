import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/data/church_marks_repository.dart';
import '../../core/format.dart';
import '../../core/models/church.dart';
import '../../core/models/feast_calendar.dart';
import '../church_detail/church_detail_page.dart';

/// "Bisericile mele": favourites, then the places visited.
///
/// Two lists rather than one with filters, because they answer different
/// questions — "where do I want to go back to" and "where have I been" — and a
/// church can be in both.
class MyChurchesPage extends StatefulWidget {
  const MyChurchesPage({super.key});

  @override
  State<MyChurchesPage> createState() => _MyChurchesPageState();
}

class _Entry {
  const _Entry(this.church, this.mark);
  final Church church;
  final ChurchMark mark;
}

class _MyChurchesPageState extends State<MyChurchesPage> {
  List<_Entry>? _entries;
  int _seenRevision = -1;

  Future<void> _load() async {
    final AppState state = AppScope.of(context);
    final List<ChurchMark> marks = await state.marks.all();
    final List<_Entry> entries = <_Entry>[];
    for (final ChurchMark m in marks) {
      // A mark whose church the current seed no longer has is kept in the
      // database (see church_marks) but not listed: there is nothing to open.
      final Church? c = await state.repository.byId(m.churchId);
      if (c != null) entries.add(_Entry(c, m));
    }
    if (mounted) setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    if (state.marksRevision != _seenRevision) {
      _seenRevision = state.marksRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }

    final List<_Entry>? entries = _entries;
    final List<_Entry> favourites =
        (entries ?? const <_Entry>[]).where((e) => e.mark.favourite).toList();
    final List<_Entry> visited =
        (entries ?? const <_Entry>[]).where((e) => e.mark.visited).toList();

    return Scaffold(
      backgroundColor: TroitaColors.paper,
      appBar: AppBar(
        title: const Text('Bisericile mele'),
        backgroundColor: TroitaColors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? const _Empty()
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: <Widget>[
                    if (favourites.isNotEmpty) ...<Widget>[
                      _Header('Favorite · ${favourites.length}'),
                      for (final _Entry e in favourites)
                        _ChurchRow(entry: e, showFeast: true),
                    ],
                    if (visited.isNotEmpty) ...<Widget>[
                      _Header('Vizitate · ${visited.length}'),
                      for (final _Entry e in visited)
                        _ChurchRow(entry: e, showFeast: false),
                    ],
                  ],
                ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(TroitaSpacing.page * 1.5),
        child: Center(
          child: Text(
            'Deschide o biserică pe hartă și apasă „Adaugă la favorite” sau '
            '„Am vizitat”. O vei găsi apoi aici.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: TroitaColors.muted, height: 1.4),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            TroitaSpacing.page, TroitaSpacing.page, TroitaSpacing.page, 8),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge),
      );
}

class _ChurchRow extends StatelessWidget {
  const _ChurchRow({required this.entry, required this.showFeast});

  final _Entry entry;

  /// Favourites show the next hram; visits show when.
  final bool showFeast;

  @override
  Widget build(BuildContext context) {
    final Church c = entry.church;
    final String? detail;
    if (showFeast) {
      final int? days = FeastCalendar.daysUntil(c.feastDay);
      detail = days == null
          ? null
          : days == 0
              ? 'Hramul este astăzi'
              : days == 1
                  ? 'Hramul este mâine'
                  : 'Hramul: ${Fmt.feast(c.feastDay)}';
    } else {
      final DateTime? on = entry.mark.visitedOn;
      detail = on == null
          ? null
          : 'Vizitată pe ${DateFormat('d MMMM y', 'ro').format(on)}';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
          TroitaSpacing.page, 0, TroitaSpacing.page, TroitaSpacing.listGap),
      decoration: TroitaTheme.cardDecoration(),
      child: ListTile(
        title: Text(c.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          <String>[Fmt.kind(c.kind), if (detail != null) detail].join(' · '),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right, color: TroitaColors.muted),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ChurchDetailPage(churchId: c.id, initial: c),
        )),
      ),
    );
  }
}
