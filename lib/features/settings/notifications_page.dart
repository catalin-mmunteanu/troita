import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/notifications/notification_prefs.dart';
import '../../core/notifications/notification_service.dart';
import '../profile/saved_names_page.dart';
import 'settings_widgets.dart';

/// Setări → Notificări.
///
/// Laid out after Android's settings guidelines: a main switch on top that
/// turns the whole feature off without losing the choices under it; then
/// short groups, each row a title with its current value under it; a choice
/// of three opens a radio list, a choice of two is a switch. Under fifteen
/// rows per group, and nothing that needs reading twice.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _busy = false;
  bool? _permitted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermission());
  }

  Future<void> _checkPermission() async {
    final bool ok = await TroitaNotifications.instance.areEnabled();
    if (mounted) setState(() => _permitted = ok);
  }

  Future<void> _update(NotificationPrefs next) async {
    setState(() => _busy = true);
    await AppScope.of(context).setNotificationPrefs(next);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickTime({
    required String help,
    required int hour,
    required int minute,
    required NotificationPrefs Function(TimeOfDay) apply,
  }) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      helpText: help,
    );
    if (picked != null) await _update(apply(picked));
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final NotificationPrefs prefs = state.notificationPrefs;
    final bool on = prefs.enabled && _permitted != false;

    Widget row(NotifKind k, {String? note}) => LevelTile(
          kind: k,
          prefs: prefs,
          enabled: on && !_busy,
          note: note,
          onChanged: _update,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Notificări')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: <Widget>[
          if (_permitted == false)
            PermissionCard(onGrant: () async {
              final bool ok = await state.requestNotificationPermission();
              if (mounted) setState(() => _permitted = ok);
            }),

          MainSwitch(
            title: 'Notificări Troița',
            value: prefs.enabled,
            onChanged: _busy || _permitted == false
                ? null
                : (bool v) => _update(prefs.copyWith(enabled: v)),
          ),

          const SectionHeader('În fiecare zi'),
          row(NotifKind.saint),
          row(NotifKind.gospel),
          row(NotifKind.dezlegari),

          const SectionHeader('Pentru dumneavoastră'),
          row(
            NotifKind.nameDays,
            note: state.savedNames.isEmpty ? 'Niciun nume salvat.' : null,
          ),
          SettingsTile(
            title: 'Numele salvate',
            value: state.savedNames.isEmpty
                ? 'Adăugați numele celor dragi'
                : '${state.savedNames.length} nume',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const SavedNamesPage(),
            )),
          ),
          row(NotifKind.hram),
          if (state.journalEnabled) row(NotifKind.jurnal),

          const SectionHeader('Calendarul anului'),
          row(NotifKind.fasts),
          row(NotifKind.ajun),
          row(NotifKind.mosi),
          row(NotifKind.legale),

          const SectionHeader('Ore'),
          SettingsTile(
            title: 'Dimineața',
            value: '${prefs.timeLabel} · ce este azi',
            enabled: on && !_busy,
            onTap: () => _pickTime(
              help: 'Ora notificărilor de dimineață',
              hour: prefs.hour,
              minute: prefs.minute,
              apply: (TimeOfDay t) =>
                  prefs.copyWith(hour: t.hour, minute: t.minute),
            ),
          ),
          SettingsTile(
            title: 'Seara',
            value: '${prefs.eveningTimeLabel} · ce este mâine',
            enabled: on && !_busy,
            onTap: () => _pickTime(
              help: 'Ora notificărilor de seară',
              hour: prefs.eveningHour,
              minute: prefs.eveningMinute,
              apply: (TimeOfDay t) => prefs.copyWith(
                  eveningHour: t.hour, eveningMinute: t.minute),
            ),
          ),
          SettingsTile(
            title: 'Evanghelia zilei',
            value: prefs.gospelTimeLabel,
            enabled: on && !_busy,
            onTap: () => _pickTime(
              help: 'Ora Evangheliei zilei',
              hour: prefs.gospelHour,
              minute: prefs.gospelMinute,
              apply: (TimeOfDay t) => prefs.copyWith(
                  gospelHour: t.hour, gospelMinute: t.minute),
            ),
          ),
          SwitchListTile(
            value: prefs.sound,
            onChanged: on && !_busy
                ? (bool v) => _update(prefs.copyWith(sound: v))
                : null,
            title: const Text('Sunet la sărbătorile mari'),
            subtitle: const Text('Celelalte vin fără sunet'),
          ),

          const SectionHeader('Verificare'),
          SettingsTile(
            title: 'Trimite o notificare de probă',
            value: 'Arată acum dacă notificările ajung pe telefon',
            enabled: _permitted != false,
            onTap: () => TroitaNotifications.instance.showTest(),
          ),
          const Footnote(
            'Fiecare tip are și un canal al lui în setările Android ale '
            'aplicației, unde poate fi oprit sau făcut silențios.',
          ),
        ],
      ),
    );
  }
}

/// One kind: title, and under it its level and what that level does. Tap
/// for the three choices, each with its meaning.
class LevelTile extends StatelessWidget {
  const LevelTile({
    super.key,
    required this.kind,
    required this.prefs,
    required this.enabled,
    required this.onChanged,
    this.note,
  });

  final NotifKind kind;
  final NotificationPrefs prefs;
  final bool enabled;
  final ValueChanged<NotificationPrefs> onChanged;

  /// Shown after the value, for a row that cannot do anything yet.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final NotifLevel level = prefs.level(kind);
    final String? what = kind.describe(level);
    return SettingsTile(
      title: kind.title,
      value: <String>[
        level.label,
        if (what != null) what,
        if (note != null && level != NotifLevel.off) note!,
      ].join(' · '),
      enabled: enabled,
      onTap: () => _choose(context, level),
    );
  }

  Future<void> _choose(BuildContext context, NotifLevel current) async {
    final NotifLevel? picked = await showModalBottomSheet<NotifLevel>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          child: RadioGroup<NotifLevel>(
            groupValue: current,
            onChanged: (NotifLevel? v) => Navigator.of(context).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(kind.title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                for (final NotifLevel l in NotifLevel.values)
                  RadioListTile<NotifLevel>(
                    value: l,
                    activeColor: TroitaColors.burgundy,
                    title: Text(l.label),
                    subtitle: Text(kind.describe(l) ?? 'Nicio notificare'),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null && picked != current) {
      onChanged(prefs.withLevel(kind, picked));
    }
  }
}
