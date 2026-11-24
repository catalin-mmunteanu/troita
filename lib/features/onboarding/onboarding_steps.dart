import 'dart:async';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/text_size.dart';
import '../../app/theme.dart';
import '../../core/models/church.dart';
import '../../core/models/name_days.dart';
import '../../core/models/saved_name.dart';
import '../../core/notifications/notification_prefs.dart';
import '../church_detail/church_detail_page.dart';
import '../profile/saved_names_page.dart';

/// The steps of the onboarding, in order. Each one is only its content; the
/// frame (progress, Înapoi, Continuă) is the page's.
///
/// Type is set larger than elsewhere in the app (titles 26, text 18): these
/// screens are read once, by someone who may not yet have made it larger.

const TextStyle _title =
    TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25);
const TextStyle _body = TextStyle(fontSize: 18, height: 1.45);
const TextStyle _small =
    TextStyle(fontSize: 16, height: 1.4, color: TroitaColors.muted);

class _Heading extends StatelessWidget {
  const _Heading(this.title, [this.text]);

  final String title;
  final String? text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(header: true, child: Text(title, style: _title)),
            if (text != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(text!, style: _body),
            ],
          ],
        ),
      );
}

/// A large choice: a card with a radio, a title and a line under it.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.title,
    required this.onTap,
    this.text,
    this.leading,
    this.badge,
  });

  final bool selected;
  final String title;
  final String? text;
  final Widget? leading;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        button: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: selected ? TroitaColors.accentSurface : TroitaColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: selected ? TroitaColors.burgundy : TroitaColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? TroitaColors.burgundy
                            : TroitaColors.muted,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      if (leading != null) ...<Widget>[
                        leading!,
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w700)),
                            if (badge != null)
                              Text(badge!,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: TroitaColors.burgundy)),
                            if (text != null) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(text!, style: _small),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

// ------------------------------------------------------------ 1. welcome

/// Bun venit, and the text size: three large choices that apply at once,
/// so the rest of the setup is read at the chosen size.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  static const List<(double, String, double)> _sizes = <(double, String, double)>[
    (1.0, 'Normal', 20),
    (1.3, 'Mare', 26),
    (1.6, 'Foarte mare', 32),
  ];

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        const Icon(Icons.add, size: 56, color: TroitaColors.burgundy),
        const SizedBox(height: 12),
        const _Heading(
          'Bun venit în Troița',
          'Calendarul ortodox, zi de zi: sfântul zilei, posturile, '
              'Evanghelia și dezlegările. Îl pregătim pentru dumneavoastră '
              'în mai puțin de un minut.',
        ),
        const Text('Cum citiți mai ușor?',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        for (final (double scale, String label, double sample) in _sizes)
          _ChoiceCard(
            selected: (state.textScale - scale).abs() < 0.08,
            title: label,
            // The letter keeps its own size, so the three can be compared.
            leading: MediaQuery.withNoTextScaling(
              child: SizedBox(
                width: 40,
                child: Text('A',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: sample, fontWeight: FontWeight.w700)),
              ),
            ),
            onTap: () => state.setTextScale(scale),
          ),
        const SizedBox(height: 4),
        const Text('Sf. Ierarh Nicolae · Dezlegare la pește', style: _body),
        const SizedBox(height: 6),
        Text(
          'Mărimea se poate schimba oricând din Profil, cu A− și A+ '
          '(acum: ${TextSize.label(state.textScale)}).',
          style: _small,
        ),
      ],
    );
  }
}

// ------------------------------------------------------ 2. notifications

/// What to be told, in three cards, and the Gospel apart. The permission
/// is asked when leaving this step, now that its purpose is clear.
class NotificationsStep extends StatefulWidget {
  const NotificationsStep({super.key});

  @override
  State<NotificationsStep> createState() => NotificationsStepState();
}

class NotificationsStepState extends State<NotificationsStep> {
  late NotifPreset _preset;
  late bool _gospel;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    final NotificationPrefs prefs = AppScope.of(context).notificationPrefs;
    _preset = prefs.preset;
    _gospel = prefs.level(NotifKind.gospel) != NotifLevel.off;
    _ready = true;
  }

  /// Saves the choice and, unless it is "Fără notificări", asks the phone
  /// for the permission. Returns whether it was granted; null when not asked.
  Future<bool?> save() async {
    final AppState state = AppScope.of(context);
    await state.setNotificationPrefs(
        state.notificationPrefs.applyPreset(_preset, gospel: _gospel));
    if (_preset == NotifPreset.none) return null;
    return state.requestNotificationPermission();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Heading(
            'Ce vreți să vă amintim?',
            'Notificările sunt pregătite pe telefon. Nimic nu este trimis '
                'nicăieri.',
          ),
          _ChoiceCard(
            selected: _preset == NotifPreset.important,
            title: 'Doar ce este important',
            badge: 'Recomandat',
            text: 'Sărbătorile mari, începutul posturilor, hramul bisericii '
                'dumneavoastră și zilele de nume ale celor dragi.',
            onTap: () => setState(() => _preset = NotifPreset.important),
          ),
          _ChoiceCard(
            selected: _preset == NotifPreset.all,
            title: 'Tot',
            text: 'În fiecare zi sfântul zilei, plus dezlegările, ajunurile, '
                'Moșii și zilele libere.',
            onTap: () => setState(() => _preset = NotifPreset.all),
          ),
          _ChoiceCard(
            selected: _preset == NotifPreset.none,
            title: 'Fără notificări',
            text: 'Le puteți porni oricând din Setări.',
            onTap: () => setState(() => _preset = NotifPreset.none),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: TroitaTheme.cardDecoration(),
            child: SwitchListTile(
              value: _gospel && _preset != NotifPreset.none,
              onChanged: _preset == NotifPreset.none
                  ? null
                  : (bool v) => setState(() => _gospel = v),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              title: const Text('Evanghelia zilei, dimineața',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'La ora ${AppScope.of(context).notificationPrefs.gospelTimeLabel}, '
                'cu primul verset.',
                style: _small,
              ),
            ),
          ),
          if (_preset != NotifPreset.none) ...<Widget>[
            const SizedBox(height: 16),
            const Text(
              'La „Continuă”, telefonul vă va întreba dacă permiteți '
              'notificările. Alegeți „Permiteți”.',
              style: _small,
            ),
          ],
        ],
      );
}

// --------------------------------------------------------------- 3. names

class NamesStep extends StatefulWidget {
  const NamesStep({super.key});

  @override
  State<NamesStep> createState() => _NamesStepState();
}

class _NamesStepState extends State<NamesStep> {
  NameDays? _nameDays;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final NameDays n = await AppScope.of(context).nameDays.load();
      if (mounted) setState(() => _nameDays = n);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final NameDays? nd = _nameDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _Heading(
          'Zilele de nume ale celor dragi',
          'Adăugați numele lor și vă amintim de ziua lor, ca să le puteți '
              'spune „La mulți ani!”.',
        ),
        for (final SavedName n in state.savedNames)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: TroitaTheme.cardDecoration(),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(n.display,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              subtitle: Text(_when(nd, n.name), style: _small),
              trailing: IconButton(
                tooltip: 'Șterge ${n.display}',
                iconSize: 26,
                icon: const Icon(Icons.close),
                onPressed: () => state.removeSavedName(n),
              ),
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: nd == null
              ? null
              : () async {
                  final SavedName? picked = await showAddNameDialog(context, nd);
                  if (picked != null) await state.addSavedName(picked);
                },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 18),
          ),
          icon: const Icon(Icons.add),
          label: Text(state.savedNames.isEmpty
              ? 'Adaugă un nume'
              : 'Adaugă încă un nume'),
        ),
        const SizedBox(height: 12),
        const Text(
          'De exemplu: Mama, Maria. Numele rămân doar pe telefon; nu citim '
          'agenda.',
          style: _small,
        ),
      ],
    );
  }

  static String _when(NameDays? nd, String name) {
    if (nd == null) return '';
    final DateTime? d = nd.nextDay(name, DateTime.now());
    if (d == null) return 'Fără zi în calendar';
    return '${DateFormat('d MMMM', 'ro').format(d)} · '
        '${nd.feastsFor(name).first.saint}';
  }
}

// -------------------------------------------------------------- 4. church

/// Biserica mea, found by its name or its place; no location asked.
class ChurchStep extends StatefulWidget {
  const ChurchStep({super.key});

  @override
  State<ChurchStep> createState() => _ChurchStepState();
}

class _ChurchStepState extends State<ChurchStep> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  List<Church> _results = const <Church>[];
  Church? _chosen;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final AppState state = AppScope.of(context);
      final String? id = state.parishId;
      if (id == null) return;
      final Church? c = await state.church(id);
      if (mounted) setState(() => _chosen = c);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = const <Church>[]);
      return;
    }
    setState(() => _searching = true);
    final List<Church> found =
        await AppScope.of(context).repository.search(q, limit: 20);
    if (!mounted || q != _query.text) return;
    setState(() {
      _results = found;
      _searching = false;
    });
  }

  Future<void> _choose(Church c) async {
    setState(() => _chosen = c);
    await AppScope.of(context).setParish(c.id);
  }

  Future<void> _clear() async {
    setState(() => _chosen = null);
    await AppScope.of(context).setParish(null);
  }

  @override
  Widget build(BuildContext context) {
    final Church? chosen = _chosen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _Heading(
          'Biserica dumneavoastră',
          'Alegeți biserica la care mergeți. O găsiți în Profil și vă '
              'anunțăm cu o seară înainte de hramul ei.',
        ),
        if (chosen != null) ...<Widget>[
          _ChoiceCard(
            selected: true,
            title: chosen.name,
            text: _line(chosen),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ChurchDetailPage(churchId: chosen.id),
            )),
          ),
          TextButton(
            onPressed: _clear,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              textStyle: const TextStyle(fontSize: 17),
            ),
            child: const Text('Aleg altă biserică'),
          ),
        ] else ...<Widget>[
          TextField(
            controller: _query,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(
              labelText: 'Numele bisericii sau localitatea',
              hintText: 'de exemplu Sfântul Nicolae Iași',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_searching) const LinearProgressIndicator(),
          for (final Church c in _results)
            _ChoiceCard(
              selected: false,
              title: c.name,
              text: _line(c),
              onTap: () => _choose(c),
            ),
          if (!_searching &&
              _results.isEmpty &&
              _query.text.trim().length >= 2)
            const Text(
              'Nu am găsit-o. Încercați doar localitatea, sau un cuvânt din '
              'nume.',
              style: _small,
            ),
        ],
      ],
    );
  }

  static String _line(Church c) => <String>[
        if (c.address != null && c.address!.isNotEmpty) c.address!,
        if (c.patron != null && c.patron!.isNotEmpty) 'Hram: ${c.patron}',
      ].join(' · ');
}

// ---------------------------------------------------------------- 5. more

class MoreStep extends StatelessWidget {
  const MoreStep({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _Heading('Încă două lucruri'),
        Container(
          decoration: TroitaTheme.cardDecoration(),
          child: SwitchListTile(
            value: state.journalEnabled,
            onChanged: (bool v) => state.setJournalEnabled(v),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            title: const Text('Jurnal de post',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            subtitle: const Text(
              'Însemnați zilele în care ați ținut postul. Doar pentru '
              'dumneavoastră, pe telefon.',
              style: _small,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: TroitaTheme.cardDecoration(),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.widgets_outlined,
                  size: 28, color: TroitaColors.burgundy),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Sfântul zilei pe ecranul telefonului',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text(
                      'Țineți apăsat pe un loc gol al ecranului, alegeți '
                      '„Widgeturi”, apoi Troița.',
                      style: _small,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 6. done

/// What was chosen, each with Schimbă, and the way in.
class DoneStep extends StatefulWidget {
  const DoneStep({
    super.key,
    required this.permissionRefused,
    required this.onEdit,
  });

  final bool permissionRefused;

  /// Goes back to a step by its index (0 = text size).
  final ValueChanged<int> onEdit;

  @override
  State<DoneStep> createState() => _DoneStepState();
}

class _DoneStepState extends State<DoneStep> {
  String? _church;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final AppState state = AppScope.of(context);
      final String? id = state.parishId;
      if (id == null) return;
      final Church? c = await state.church(id);
      if (mounted) setState(() => _church = c?.name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final NotificationPrefs prefs = state.notificationPrefs;
    final String notifications = switch (prefs.preset) {
      NotifPreset.none => 'Fără notificări',
      NotifPreset.all => 'Tot',
      NotifPreset.important => 'Doar ce este important',
    };
    final bool gospel = prefs.on(NotifKind.gospel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.check_circle_outline,
            size: 56, color: TroitaColors.burgundy),
        const SizedBox(height: 12),
        const _Heading('Totul este pregătit'),
        _SummaryRow(
          label: 'Mărimea textului',
          value: TextSize.label(state.textScale),
          onEdit: () => widget.onEdit(0),
        ),
        _SummaryRow(
          label: 'Notificări',
          value: gospel ? '$notifications, cu Evanghelia zilei' : notifications,
          onEdit: () => widget.onEdit(1),
        ),
        _SummaryRow(
          label: 'Zile de nume',
          value: state.savedNames.isEmpty
              ? 'Niciun nume'
              : state.savedNames.map((SavedName n) => n.display).join(', '),
          onEdit: () => widget.onEdit(2),
        ),
        _SummaryRow(
          label: 'Biserica mea',
          value: _church ?? 'Nealeasă',
          onEdit: () => widget.onEdit(3),
        ),
        _SummaryRow(
          label: 'Jurnal de post',
          value: state.journalEnabled ? 'Pornit' : 'Oprit',
          onEdit: () => widget.onEdit(4),
        ),
        if (widget.permissionRefused) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: TroitaTheme.cardDecoration(
              color: TroitaColors.accentSurface,
              borderColor: TroitaColors.gold,
            ),
            child: const Text(
              'Telefonul nu permite încă notificările. Le puteți permite '
              'oricând din Profil → Setări → Notificări.',
              style: _body,
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Totul se poate schimba din Profil → Setări.',
            style: _small),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: TroitaTheme.cardDecoration(),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(label, style: _small),
          subtitle: Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: TroitaColors.ink)),
          trailing: TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              textStyle: const TextStyle(fontSize: 17),
            ),
            child: Text('Schimbă', semanticsLabel: 'Schimbă $label'),
          ),
        ),
      );
}

/// The church step on its own, from Profil → Biserica mea.
class ParishPickerPage extends StatelessWidget {
  const ParishPickerPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Biserica mea')),
        body: const SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: ChurchStep(),
        ),
      );
}
