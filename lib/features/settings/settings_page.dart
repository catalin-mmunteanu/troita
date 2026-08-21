import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/native/troita_native.dart';
import '../../core/permissions/permission_service.dart';
import '../../app/app_scope.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;

  /// Passive mode is the only thing in the app that needs
  /// ACCESS_BACKGROUND_LOCATION, so it carries its own disclosure and its own
  /// honest warning about what the OS will do to it.
  Future<void> _togglePassive(bool enable) async {
    final AppState state = AppScope.of(context);

    if (!enable) {
      setState(() => _busy = true);
      await state.setPassive(false);
      if (mounted) setState(() => _busy = false);
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Anunțuri automate'),
        content: const Text(
          'Pentru a vă anunța și când aplicația este închisă, Android cere '
          'accesul „Permite tot timpul" la locație.\n\n'
          'Locația rămâne pe telefon — nu o trimitem nicăieri.\n\n'
          'Pe ecranul următor alegeți „Permite tot timpul".',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nu acum'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuă'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final LocationGrant grant = await state.permissions.requestBackground();

    if (grant != LocationGrant.background) {
      if (!mounted) return;
      setState(() => _busy = false);
      // On API 30+ the request opens Settings rather than a dialog, so this is
      // the normal path, not an error.
      _snack(
        'Alegeți „Permite tot timpul" din Setări pentru a activa anunțurile automate.',
        action: 'Deschide',
        onAction: state.permissions.openSettings,
      );
      return;
    }

    final WindowResult result = await state.setPassive(true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      _snack('Nu am putut porni anunțurile automate (${result.reason}).');
    }
  }

  void _snack(String message, {String? action, VoidCallback? onAction}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: action == null
            ? null
            : SnackBarAction(label: action, onPressed: onAction ?? () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final NativeStatus status = state.status;
    final OemInfo? oem = state.oem;

    return Scaffold(
      appBar: AppBar(title: const Text('Setări')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: <Widget>[
          const _Header('Anunțuri'),
          SwitchListTile(
            value: status.soundEnabled,
            onChanged: _busy ? null : (bool v) => state.setSound(v),
            title: const Text('Sunet de toacă'),
            subtitle: const Text(
              'Implicit doar vibrație scurtă, ca să nu deranjeze la volan.',
            ),
          ),
          ListTile(
            title: const Text('Setările notificărilor'),
            subtitle: const Text('Vibrație, sunet, prioritate'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => state.native.openNotificationSettings(
              status.soundEnabled ? 'troita_bell_v1' : 'troita_discreet_v1',
            ),
          ),

          const _Header('Mod de funcționare'),
          SwitchListTile(
            value: status.passiveEnabled,
            onChanged: _busy ? null : _togglePassive,
            title: const Text('Anunțuri automate'),
            subtitle: Text(
              status.passiveEnabled
                  ? '${status.windowCount} biserici urmărite în fundal'
                  : 'Anunțuri fără să porniți drumul. Necesită „Permite tot timpul".',
            ),
          ),
          if (status.passiveEnabled)
            ListTile(
              title: const Text('Reîmprospătează zonele'),
              subtitle: Text(
                status.windowUpdatedAt == null
                    ? 'Niciodată'
                    : 'Ultima dată: ${status.windowUpdatedAt}',
              ),
              trailing: _busy
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onTap: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final WindowResult r = await state.native.refreshWindow();
                      await state.refreshStatus();
                      if (!mounted) return;
                      setState(() => _busy = false);
                      _snack(r.ok
                          ? '${r.registered} biserici urmărite.'
                          : 'Nu am putut reînregistra zonele (${r.reason}).');
                    },
            ),

          // The single biggest cause of "it stopped working" in Romania: MIUI
          // autostart and Samsung's sleeping-apps list. Surface it rather than
          // letting users discover it as a bug.
          if (oem != null && (oem.isAggressive || oem.batteryOptimised)) ...<Widget>[
            const _Header('Fiabilitate'),
            if (oem.batteryOptimised)
              _Fix(
                title: 'Scoateți Troița din optimizarea bateriei',
                body: 'Altfel Android amână anunțurile, uneori cu ore.',
                onTap: state.native.openBatterySettings,
              ),
            if (oem.needsAutostart)
              _Fix(
                title: 'Activați pornirea automată (${oem.label})',
                body: 'Fără autostart, anunțurile nu mai funcționează după '
                    'repornirea telefonului.',
                onTap: state.native.openAutostartSettings,
              ),
            if (oem.id == 'samsung')
              _Fix(
                title: 'Scoateți Troița din „aplicații în repaus"',
                body: 'Samsung adoarme aplicațiile folosite rar, iar anunțurile '
                    'se opresc după câteva zile.',
                onTap: state.native.openAppDetails,
              ),
          ],

          const _Header('Date'),
          ListTile(
            title: const Text('Set de date'),
            subtitle: Text(
              'Versiunea ${state.seed['seed_version'] ?? '—'} · '
              '${state.seed['count'] ?? '0'} locuri · ${state.seed['area'] ?? ''}',
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Date din OpenStreetMap, disponibile sub licența ODbL, completate '
              'cu contribuții comunitare. Corecturile sunt binevenite.',
              style: TextStyle(fontSize: 12.5, color: TroitaTheme.muted),
            ),
          ),
        ],
      ),
    );
  }
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
            color: TroitaTheme.muted,
          ),
        ),
      );
}

class _Fix extends StatelessWidget {
  const _Fix({required this.title, required this.body, required this.onTap});

  final String title;
  final String body;
  final Future<bool> Function() onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: TroitaTheme.gold),
        title: Text(title),
        subtitle: Text(body),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => onTap(),
      );
}
