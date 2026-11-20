import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/data/local_church_repository.dart';
import '../../core/liturgical/fast_level.dart';
import '../../core/models/feast.dart';
import '../../core/models/name_days.dart';
import 'day_detail_page.dart';

/// "When is Sf. Parascheva?" — a saint's name to their next day.
///
/// Searches the commemorations, not the sinaxar text: someone looking for a
/// saint types the saint's name, and matching inside four hundred lives would
/// bury that one day under every page that mentions it in passing.
///
/// Diacritics are folded the same way as the church search, so "Parascheva"
/// and "parascheva" find the same day. Each query word must *start* a word of
/// the name — "ilie" finds Sf. Ilie, not every name with "-ilie-" inside it,
/// and "nicol" is already enough for Nicolae. Each feast is shown at
/// its *next* occurrence, which is the date the question is almost always
/// about, and moveable feasts resolve to this year's or next year's Pascha.
class CalendarSearchPage extends StatefulWidget {
  const CalendarSearchPage({super.key});

  @override
  State<CalendarSearchPage> createState() => _CalendarSearchPageState();
}

class _Hit {
  const _Hit(this.title, this.date, this.rank);
  final String title;
  final DateTime date;
  final FeastRank rank;
}

class _CalendarSearchPageState extends State<CalendarSearchPage> {
  final TextEditingController _query = TextEditingController();
  List<Feast> _all = const <Feast>[];
  Map<Feast, List<String>> _folded = const <Feast, List<String>>{};

  /// Zile de nume: "Andrei" finds 30 noiembrie, as "Ziua numelui Andrei".
  List<NameFeast> _nameFeasts = const <NameFeast>[];
  Map<String, String> _foldedNames = const <String, String>{};
  List<_Hit> _hits = const <_Hit>[];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final AppState state = AppScope.of(context);
      final List<Feast> all = await state.feasts.all();
      NameDays? nameDays;
      try {
        nameDays = await state.nameDays.load();
      } catch (_) {}
      if (!mounted) return;
      if (nameDays != null) {
        _nameFeasts = nameDays.feasts;
        _foldedNames = <String, String>{
          for (final String n in nameDays.allNames)
            n: LocalChurchRepository.foldForSearch(n),
        };
      }
      // Folded once: there are a few hundred, and keystrokes are frequent.
      setState(() {
        _all = all;
        _folded = <Feast, List<String>>{
          for (final Feast f in all)
            f: LocalChurchRepository.foldForSearch(f.name).split(' '),
        };
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () => _search(raw));
  }

  void _search(String raw) {
    final String q = LocalChurchRepository.foldForSearch(raw);
    if (q.length < 3) {
      setState(() => _hits = const <_Hit>[]);
      return;
    }
    // Every query word must start some word of the name, in any order:
    // "nicolae sf" finds "Sf. Nicolae".
    final List<String> words = q.split(' ');
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final List<_Hit> hits = <_Hit>[];
    for (final Feast f in _all) {
      final List<String> hay = _folded[f] ?? const <String>[];
      if (!words.every((String w) => hay.any((String h) => h.startsWith(w)))) {
        continue;
      }
      DateTime? date = f.dateIn(today.year);
      if (date == null || date.isBefore(today)) date = f.dateIn(today.year + 1);
      if (date == null) continue;
      hits.add(_Hit(f.name, date, f.rank));
    }
    // A single word can also be a first name: every day that name is kept.
    if (words.length == 1) {
      final Set<String> names = <String>{
        for (final MapEntry<String, String> e in _foldedNames.entries)
          if (e.value.startsWith(words.first)) e.key,
      };
      for (final NameFeast f in _nameFeasts) {
        final List<String> found =
            f.names.where(names.contains).toList(growable: false);
        if (found.isEmpty) continue;
        DateTime? date = f.dateIn(today.year);
        if (date == null || date.isBefore(today)) {
          date = f.dateIn(today.year + 1);
        }
        if (date == null) continue;
        hits.add(_Hit(
            'Ziua numelui ${found.join(', ')} · ${f.saint}', date, FeastRank.simplu));
      }
    }
    hits.sort((_Hit a, _Hit b) => a.date.compareTo(b.date));
    setState(() => _hits = hits.take(60).toList(growable: false));
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('EEEE, d MMMM y', 'ro');
    return Scaffold(
      backgroundColor: TroitaColors.paper,
      appBar: AppBar(
        backgroundColor: TroitaColors.paper,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 17, color: TroitaColors.ink),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Caută un sfânt, o sărbătoare sau un nume',
            hintStyle: TextStyle(fontSize: 16, color: TroitaColors.muted),
          ),
        ),
      ),
      body: _query.text.trim().length < 3
          ? const _Hint()
          : _hits.isEmpty
              ? const Center(
                  child: Text('Niciun rezultat.',
                      style: TextStyle(fontSize: 15, color: TroitaColors.muted)),
                )
              : ListView.separated(
                  itemCount: _hits.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: TroitaColors.border),
                  itemBuilder: (BuildContext context, int i) {
                    final _Hit h = _hits[i];
                    final Color colour = feastRankColor(h.rank);
                    return ListTile(
                      leading: SizedBox(
                        width: 44,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text('${h.date.day}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: h.rank == FeastRank.simplu
                                      ? TroitaColors.ink
                                      : colour,
                                  height: 1,
                                )),
                            Text(DateFormat('MMM', 'ro').format(h.date),
                                style: const TextStyle(
                                    fontSize: 11, color: TroitaColors.muted)),
                          ],
                        ),
                      ),
                      title: Text(h.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, color: TroitaColors.ink)),
                      subtitle: Text(
                        toBeginningOfSentenceCase(fmt.format(h.date)) ?? '',
                        style: const TextStyle(
                            fontSize: 12.5, color: TroitaColors.muted),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DayDetailPage(date: h.date),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(TroitaSpacing.page * 1.5),
        child: Text(
          'Scrieți numele unui sfânt sau al unei sărbători, de exemplu '
          '„Parascheva” sau „Buna Vestire”, ori un prenume, de exemplu '
          '„Andrei”, ca să aflați ziua numelui. Diacriticele nu contează, iar '
          'începutul numelui este de ajuns.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: TroitaColors.muted, height: 1.4),
        ),
      );
}
