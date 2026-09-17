import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/notifications/notification_planner.dart';
import '../../core/notifications/notification_prefs.dart';
import '../../core/notifications/notification_service.dart';

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
      helpText: 'Ora notificării zilnice',
    );
    if (picked == null) return;
    await _update(prefs.copyWith(hour: picked.hour, minute: picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final NotificationPrefs prefs = state.notificationPrefs;
    final PlanResult? plan = state.lastPlan;

    return Scaffold(
      appBar: AppBar(title: const Text('Setări')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: <Widget>[
          if (_permitted == false) _PermissionCard(onGrant: () async {
            final bool ok = await state.requestNotificationPermission();
            if (mounted) setState(() => _permitted = ok);
          }),

          const _Header('Notificarea zilnică'),
          ...DailyNotificationMode.values.map(
            (DailyNotificationMode mode) => RadioListTile<DailyNotificationMode>(
              value: mode,
              groupValue: prefs.mode,
              onChanged: _busy
                  ? null
                  : (DailyNotificationMode? v) =>
                      v == null ? null : _update(prefs.copyWith(mode: v)),
              title: Text(mode.label),
              subtitle: Text(mode.description,
                  style: Theme.of(context).textTheme.bodySmall),
              activeColor: TroitaColors.burgundy,
            ),
          ),

          if (prefs.mode != DailyNotificationMode.off) ...<Widget>[
            ListTile(
              title: const Text('Ora'),
              subtitle: Text('În fiecare zi la ${prefs.timeLabel}'),
              trailing: Text(
                prefs.timeLabel,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 22),
              ),
              onTap: _busy ? null : () => _pickTime(prefs),
            ),
            SwitchListTile(
              value: prefs.sound,
              onChanged: _busy
                  ? null
                  : (bool v) => _update(prefs.copyWith(sound: v)),
              title: const Text('Sunet la sărbătorile mari'),
              subtitle: const Text(
                'Pomenirile obișnuite rămân silențioase oricum.',
              ),
            ),
          ],

          const _Header('Posturi'),
          SwitchListTile(
            value: prefs.fastReminders,
            onChanged:
                _busy ? null : (bool v) => _update(prefs.copyWith(fastReminders: v)),
            title: const Text('Anunț cu o zi înainte'),
            subtitle: const Text(
              'Doar pentru cele patru posturi mari. Miercurea și vinerea nu '
              'primiți notificări — ar fi peste o sută pe an.',
            ),
          ),

          const _Header('Programate'),
          if (plan != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                plan.blocked
                    ? 'Nicio notificare programată — lipsește permisiunea.'
                    : '${plan.daily} pomeniri și ${plan.fasts} anunțuri de post '
                        'în următoarele ${NotificationPlanner.windowDays} de zile. '
                        'Lista se reînnoiește de fiecare dată când deschideți aplicația.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const _NextScheduled(),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined,
                color: TroitaColors.burgundy),
            title: const Text('Trimite o notificare de test'),
            subtitle: const Text(
              'Apare imediat. Cea zilnică vine abia la ora stabilită.',
            ),
            onTap: () async {
              await TroitaNotifications.instance.showTest();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notificare trimisă.')),
              );
            },
          ),

          const _Header('Date'),
          ListTile(
            title: const Text('Set de date'),
            subtitle: Text(
              'Versiunea ${state.seed['seed_version'] ?? '—'} · '
              '${state.seed['feast_count'] ?? '0'} pomeniri · '
              '${state.seed['sinaxar_count'] ?? '0'} sinaxare',
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Sinaxarul este preluat de pe calendar-ortodox.ro. Datele despre '
              'biserici provin din OpenStreetMap, sub licența ODbL.',
              style: TextStyle(fontSize: 12.5, color: TroitaColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows what is actually queued.
///
/// Without this, "nothing happened" is indistinguishable from "scheduled for
/// tomorrow at 08:00", which is the normal state for most of the day.
class _NextScheduled extends StatelessWidget {
  const _NextScheduled();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({DateTime? when, String? title, int total})>(
      future: TroitaNotifications.instance.nextScheduled(),
      builder: (BuildContext context,
          AsyncSnapshot<({DateTime? when, String? title, int total})> snap) {
        final ({DateTime? when, String? title, int total})? data = snap.data;
        if (data == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text(
            data.when == null
                ? 'Coada este goală (${data.total} în așteptare).'
                : 'Următoarea: ${data.title ?? ''} — '
                    '${data.when!.day}.${data.when!.month}.${data.when!.year}. '
                    '${data.total} în coadă.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
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
              'Fără permisiune, nimic nu poate fi programat.',
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
