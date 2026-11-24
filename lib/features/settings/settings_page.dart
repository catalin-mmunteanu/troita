import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/site_links.dart';
import '../../app/text_size.dart';
import '../../app/theme.dart';
import '../../core/models/saved_name.dart';
import '../../core/notifications/notification_prefs.dart';
import '../../core/notifications/notification_service.dart';
import '../profile/saved_names_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;
  bool? _permitted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bool ok = await TroitaNotifications.instance.areEnabled();
      if (mounted) setState(() => _permitted = ok);
    });
  }

  Future<void> _update(NotificationPrefs next) async {
    setState(() => _busy = true);
    await AppScope.of(context).setNotificationPrefs(next);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickTime(NotificationPrefs prefs) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.hour, minute: prefs.minute),
      helpText: 'Ora notificărilor de dimineață',
    );
    if (picked == null) return;
    await _update(prefs.copyWith(hour: picked.hour, minute: picked.minute));
  }

  Future<void> _pickEveningTime(NotificationPrefs prefs) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: prefs.eveningHour, minute: prefs.eveningMinute),
      helpText: 'Ora notificărilor de seară',
    );
    if (picked == null) return;
    await _update(prefs.copyWith(
        eveningHour: picked.hour, eveningMinute: picked.minute));
  }

  Future<void> _pickGospelTime(NotificationPrefs prefs) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.gospelHour, minute: prefs.gospelMinute),
      helpText: 'Ora Evangheliei zilei',
    );
    if (picked == null) return;
    await _update(
        prefs.copyWith(gospelHour: picked.hour, gospelMinute: picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final NotificationPrefs prefs = state.notificationPrefs;

    return Scaffold(
      appBar: AppBar(title: const Text('Setări')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: <Widget>[
          if (_permitted == false) _PermissionCard(onGrant: () async {
            final bool ok = await state.requestNotificationPermission();
            if (mounted) setState(() => _permitted = ok);
          }),

          const _Header('Text'),
          const TextSizeCard(),

          const _Header('Notificări'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: SegmentedButton<NotifLevel>(
              segments: const <ButtonSegment<NotifLevel>>[
                ButtonSegment<NotifLevel>(
                    value: NotifLevel.all, label: Text('Toate')),
                ButtonSegment<NotifLevel>(
                    value: NotifLevel.important, label: Text('Importante')),
                ButtonSegment<NotifLevel>(
                    value: NotifLevel.off, label: Text('Oprite')),
              ],
              // Nothing selected when the rows differ.
              selected: <NotifLevel>{
                if (prefs.common != null) prefs.common!,
              },
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              onSelectionChanged: _busy
                  ? null
                  : (Set<NotifLevel> v) {
                      if (v.isNotEmpty) _update(prefs.withAll(v.first));
                    },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
            child: Text(
              'Schimbă toate rândurile de mai jos deodată. Fiecare rând se '
              'poate alege și separat.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

          const _Header('În fiecare zi'),
          for (final NotifKind k in const <NotifKind>[
            NotifKind.saint,
            NotifKind.gospel,
            NotifKind.dezlegari,
          ])
            _LevelRow(kind: k, prefs: prefs, busy: _busy, onChanged: _update),

          const _Header('Sărbători și zile de nume'),
          for (final NotifKind k in const <NotifKind>[
            NotifKind.nameDays,
            NotifKind.hram,
            NotifKind.fasts,
            NotifKind.ajun,
            NotifKind.mosi,
            NotifKind.legale,
          ])
            _LevelRow(
              kind: k,
              prefs: prefs,
              busy: _busy,
              onChanged: _update,
              note: k == NotifKind.nameDays && state.savedNames.isEmpty
                  ? 'Niciun nume salvat încă.'
                  : null,
            ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Numele salvate'),
            subtitle: Text(state.savedNames.isEmpty
                ? 'Adăugați numele celor dragi.'
                : state.savedNames
                    .map((SavedName n) => n.display)
                    .join(', ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const SavedNamesPage(),
            )),
          ),

          const _Header('Ore'),
          _TimeRow(
            title: 'Dimineața',
            subtitle: 'Ce este azi: sfântul, dezlegările, zilele de nume, '
                'hramurile, ajunurile.',
            label: prefs.timeLabel,
            onTap: _busy ? null : () => _pickTime(prefs),
          ),
          _TimeRow(
            title: 'Evanghelia zilei',
            subtitle: 'Are ora ei.',
            label: prefs.gospelTimeLabel,
            onTap: _busy ? null : () => _pickGospelTime(prefs),
          ),
          _TimeRow(
            title: 'Seara',
            subtitle: 'Ce este mâine: posturile, hramurile, zilele de nume, '
                'Moșii, zilele libere.',
            label: prefs.eveningTimeLabel,
            onTap: _busy ? null : () => _pickEveningTime(prefs),
          ),
          SwitchListTile(
            value: prefs.sound,
            onChanged:
                _busy ? null : (bool v) => _update(prefs.copyWith(sound: v)),
            title: const Text('Sunet la sărbătorile mari'),
            subtitle: const Text('Celelalte notificări vin fără sunet.'),
          ),

          const _Header('Jurnal de post'),
          SwitchListTile(
            value: state.journalEnabled,
            onChanged: (bool v) => state.setJournalEnabled(v),
            title: const Text('Întrebarea „Ați ținut postul?”'),
            subtitle: const Text('Notați zilele în care ați ținut postul.'),
          ),
          if (state.journalEnabled)
            _LevelRow(
              kind: NotifKind.jurnal,
              prefs: prefs,
              busy: _busy,
              onChanged: _update,
            ),

          const _Header('Despre aplicație'),
          ListTile(
            title: const Text('Versiunea datelor'),
            trailing: Text(state.seed['seed_version'] ?? '—'),
          ),
          // The site carries the same calendar, the fasting guide and the
          // privacy policy Google Play links to.
          ListTile(
            title: const Text('Calendarul pe troita.ro'),
            subtitle: const Text('Același calendar, pe orice dispozitiv.'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => state.native.openUri(SiteLinks.base),
          ),
          ListTile(
            title: const Text('Politica de confidențialitate'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => state.native.openUri(SiteLinks.privacy),
          ),
          // Required by the ODbL licence of the church data and map tiles.
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              'Date despre biserici și hartă: © contributorii OpenStreetMap.',
              style: TextStyle(fontSize: 12.5, color: TroitaColors.muted),
            ),
          ),
          // The source of the readings, once here rather than under each
          // one. Same words as `source` in assets/data/biblia_nt.json.
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Text(
              'Textul Apostolului și al Evangheliei: Biblia, ediția Sfântului '
              'Sinod, IBMBOR, 1988.',
              style: TextStyle(fontSize: 12.5, color: TroitaColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(TroitaSpacing.card),
        decoration: TroitaTheme.cardDecoration(
          color: TroitaColors.accentSurface,
          borderColor: TroitaColors.gold,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Notificările sunt oprite',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Permiteți-le pentru a primi notificări.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onGrant,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Permite notificările'),
            ),
          ],
        ),
      );
}

/// One kind of notification: its name, what its level means, and a sheet to
/// choose Toate · Doar importante · Oprit.
class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.kind,
    required this.prefs,
    required this.busy,
    required this.onChanged,
    this.note,
  });

  final NotifKind kind;
  final NotificationPrefs prefs;
  final bool busy;
  final ValueChanged<NotificationPrefs> onChanged;

  /// Shown under the description, for a row that cannot do anything yet.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final NotifLevel level = prefs.level(kind);
    final String? what = kind.describe(level);
    return ListTile(
      title: Text(kind.title),
      subtitle: Text(<String>[
        if (what != null) what else 'Nicio notificare.',
        if (note != null && level != NotifLevel.off) note!,
      ].join(' ')),
      trailing: Text(
        level.label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: level == NotifLevel.off
              ? TroitaColors.muted
              : TroitaColors.burgundy,
        ),
      ),
      onTap: busy ? null : () => _choose(context, level),
    );
  }

  Future<void> _choose(BuildContext context, NotifLevel current) async {
    final NotifLevel? picked = await showModalBottomSheet<NotifLevel>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: RadioGroup<NotifLevel>(
          groupValue: current,
          onChanged: (NotifLevel? v) => Navigator.of(context).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(kind.title,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final NotifLevel l in NotifLevel.values)
                RadioListTile<NotifLevel>(
                  value: l,
                  activeColor: TroitaColors.burgundy,
                  title: Text(l.label),
                  subtitle: Text(kind.describe(l) ?? 'Nicio notificare.',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked != current) {
      onChanged(prefs.withLevel(kind, picked));
    }
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.title,
    required this.subtitle,
    required this.label,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontSize: 22),
        ),
        onTap: onTap,
      );
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: TroitaColors.muted,
          ),
        ),
      );
}
