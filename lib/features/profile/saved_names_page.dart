import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/data/local_church_repository.dart';
import '../../core/models/name_days.dart';
import '../../core/models/saved_name.dart';
import '../../core/notifications/notification_prefs.dart';

/// Zile de nume: the names whose day the user wants to be told about.
///
/// Each one is picked from the name-day list, so it is spelled as the list
/// spells it and always has a day. The label is the user's own word for the
/// person ("Mama"). Nothing is read from the contacts.
class SavedNamesPage extends StatefulWidget {
  const SavedNamesPage({super.key});

  @override
  State<SavedNamesPage> createState() => _SavedNamesPageState();
}

class _SavedNamesPageState extends State<SavedNamesPage> {
  NameDays? _nameDays;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final NameDays n = await AppScope.of(context).nameDays.load();
      if (mounted) setState(() => _nameDays = n);
    });
  }

  /// The next day of [name]'s primary feast, today included.
  DateTime? _next(String name) {
    final List<NameFeast> feasts = _nameDays?.feastsFor(name) ?? const <NameFeast>[];
    if (feasts.isEmpty) return null;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    for (final int y in <int>[today.year, today.year + 1]) {
      final DateTime? d = feasts.first.dateIn(y);
      if (d != null && !d.isBefore(today)) return d;
    }
    return null;
  }

  Future<void> _add() async {
    final NameDays? nameDays = _nameDays;
    if (nameDays == null) return;
    final SavedName? picked = await showAddNameDialog(context, nameDays);
    if (picked != null && mounted) {
      await AppScope.of(context).addSavedName(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<SavedName> names = state.savedNames;
    final NotifLevel level = state.notificationPrefs.level(NotifKind.nameDays);
    return Scaffold(
      appBar: AppBar(title: const Text('Zile de nume')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nameDays == null ? null : _add,
        icon: const Icon(Icons.add),
        label: const Text('Adaugă un nume'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              level == NotifLevel.off
                  ? 'Notificările pentru zilele de nume sunt oprite. Le '
                      'porniți din Setări → Notificări.'
                  : NotifKind.nameDays.describe(level)!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (names.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Text(
                'Adăugați numele celor dragi și Troița vă amintește de ziua '
                'lor de nume.',
              ),
            ),
          for (final SavedName n in names)
            ListTile(
              title: Text(n.display),
              subtitle: Text(_dateLabel(n.name)),
              trailing: IconButton(
                tooltip: 'Șterge ${n.display}',
                icon: const Icon(Icons.delete_outline,
                    color: TroitaColors.muted),
                onPressed: () => state.removeSavedName(n),
              ),
            ),
        ],
      ),
    );
  }

  String _dateLabel(String name) {
    if (_nameDays == null) return '';
    final DateTime? d = _next(name);
    if (d == null) return 'Fără zi în calendar';
    final String saint = _nameDays!.feastsFor(name).first.saint;
    return '${DateFormat('d MMMM yyyy', 'ro').format(d)} · $saint';
  }
}

/// Asks for a name from the list and an optional label. Shared with the
/// onboarding.
Future<SavedName?> showAddNameDialog(BuildContext context, NameDays nameDays) =>
    showDialog<SavedName>(
      context: context,
      builder: (_) => _AddNameDialog(names: nameDays.allNames),
    );

/// A name from the list, typed with or without diacritics, and a label.
class _AddNameDialog extends StatefulWidget {
  const _AddNameDialog({required this.names});

  final List<String> names;

  @override
  State<_AddNameDialog> createState() => _AddNameDialogState();
}

class _AddNameDialogState extends State<_AddNameDialog> {
  String? _name;
  final TextEditingController _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Iterable<String> _matches(String query) {
    final String q = LocalChurchRepository.foldForSearch(query.trim());
    if (q.isEmpty) return const <String>[];
    final List<String> starts = <String>[];
    for (final String n in widget.names) {
      if (LocalChurchRepository.foldForSearch(n).startsWith(q)) starts.add(n);
      if (starts.length == 12) break;
    }
    return starts;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Adaugă un nume'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue v) => _matches(v.text),
              onSelected: (String n) => setState(() => _name = n),
              fieldViewBuilder: (BuildContext context,
                      TextEditingController controller,
                      FocusNode focus,
                      VoidCallback onSubmit) =>
                  TextField(
                controller: controller,
                focusNode: focus,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Numele',
                  hintText: 'de exemplu Andrei',
                ),
                onChanged: (String v) {
                  // Typing after a pick undoes it: only a name from the
                  // list has a day.
                  final String t = v.trim();
                  setState(
                      () => _name = widget.names.contains(t) ? t : null);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Cine este (opțional)',
                hintText: 'de exemplu Mama',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: _name == null
                ? null
                : () => Navigator.of(context).pop(SavedName(
                      _name!,
                      label: _label.text.trim().isEmpty
                          ? null
                          : _label.text.trim(),
                    )),
            child: const Text('Adaugă'),
          ),
        ],
      );
}
