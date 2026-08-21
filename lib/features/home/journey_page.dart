import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/native/troita_native.dart';
import '../../app/app_scope.dart';
import '../settings/settings_page.dart';

/// Journey mode is the primary experience in v1.
///
/// It uses a user-started foreground service, so it needs no background
/// location permission, survives every OEM battery manager, and — unlike OS
/// geofences — actually catches churches at driving speed.
class JourneyPage extends StatelessWidget {
  const JourneyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final JourneyState journey = state.journey;
    final bool active = journey.active || state.status.journeyActive;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: <Widget>[
        _JourneyCard(active: active, journey: journey),
        const SizedBox(height: 24),
        if (!state.status.passiveEnabled) const _PassiveHint(),
        if (state.status.passiveEnabled) _PassiveStatus(status: state.status),
        if ((state.oem?.isAggressive ?? false) && state.status.batteryOptimised)
          const _BatteryWarning(),
      ],
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.active, required this.journey});

  final bool active;
  final JourneyState journey;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: active
            ? TroitaTheme.red.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active
              ? TroitaTheme.red.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            active ? 'Vă însoțim pe drum' : 'Porniți la drum',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            active
                ? 'Urmărim traseul și vă anunțăm discret la fiecare biserică. '
                    'Puteți închide aplicația — notificarea din bara de sus rămâne activă.'
                : 'Cât timp sunteți pe drum, Troița urmărește poziția și vă anunță '
                    'la fiecare biserică sau troiță pe lângă care treceți.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (active) ...<Widget>[
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                _Stat(
                  value: '${journey.notified}',
                  label: 'anunțate',
                ),
                const SizedBox(width: 28),
                _Stat(
                  value: '${journey.candidates}',
                  label: 'urmărite',
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () =>
                active ? state.stopJourney() : state.startJourney(),
            icon: Icon(active ? Icons.stop_rounded : Icons.navigation_rounded),
            label: Text(active ? 'Oprește' : 'Pornește drumul'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: active ? TroitaTheme.muted : TroitaTheme.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: TroitaTheme.red,
            )),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PassiveHint extends StatelessWidget {
  const _PassiveHint();

  @override
  Widget build(BuildContext context) {
    return _Note(
      icon: Icons.notifications_none,
      title: 'Anunțuri automate',
      body: 'Puteți primi anunțuri și fără să porniți drumul, oricând treceți '
          'pe lângă o biserică. Necesită acces permanent la locație.',
      action: 'Activează din Setări',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
      ),
    );
  }
}

class _PassiveStatus extends StatelessWidget {
  const _PassiveStatus({required this.status});

  final NativeStatus status;

  @override
  Widget build(BuildContext context) {
    final String detail = status.windowCount == 0
        ? 'Nicio zonă activă încă — se configurează la prima poziție cunoscută.'
        : '${status.windowCount} biserici urmărite pe o rază de '
            '${(status.windowRadiusM / 1000).toStringAsFixed(1)} km.';

    return _Note(
      icon: Icons.radar,
      title: 'Anunțuri automate active',
      body: status.windowDirty
          ? 'Zonele trebuie reînregistrate. Se rezolvă singur la următoarea poziție.'
          : detail,
    );
  }
}

class _BatteryWarning extends StatelessWidget {
  const _BatteryWarning();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return _Note(
      icon: Icons.battery_alert_outlined,
      title: 'Telefonul poate opri Troița',
      body: '${state.oem?.label ?? 'Telefonul'} închide aplicațiile din fundal '
          'pentru economie de baterie. Fără o excepție, anunțurile se opresc '
          'după câteva zile.',
      action: 'Rezolvă',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 14),
            child: Icon(icon, size: 20, color: TroitaTheme.gold),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
                if (action != null)
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(action!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
