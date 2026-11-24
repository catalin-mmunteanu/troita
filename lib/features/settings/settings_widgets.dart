import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';

/// The pieces every settings screen is built from, so they read alike:
/// a group heading, a row with its current value under the title, the main
/// switch, a footnote. Sizes are a step above Material's defaults: the
/// people who most need these screens are the ones who see least well.

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 6),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: TroitaColors.burgundy,
            ),
          ),
        ),
      );
}

/// Title, and under it what the setting is set to now.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.value,
    this.icon,
    this.onTap,
    this.enabled = true,
    this.external = false,
  });

  final String title;
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool enabled;

  /// Opens something outside the app (a web page).
  final bool external;

  @override
  Widget build(BuildContext context) => ListTile(
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        leading: icon == null
            ? null
            : Icon(icon, color: TroitaColors.burgundy, size: 26),
        title: Text(title, style: const TextStyle(fontSize: 17)),
        subtitle: value == null
            ? null
            : Text(value!,
                style: const TextStyle(fontSize: 15, color: TroitaColors.muted)),
        trailing: external
            ? const Icon(Icons.open_in_new, size: 20)
            : null,
        onTap: enabled ? onTap : null,
      );
}

/// The switch at the top of a screen that turns the whole feature on or
/// off. Set apart in a tinted bar, as Android does.
class MainSwitch extends StatelessWidget {
  const MainSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          color: value ? TroitaColors.accentSurface : TroitaColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            value ? '$title: pornite' : '$title: oprite',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      );
}

class Footnote extends StatelessWidget {
  const Footnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Text(text,
            style: const TextStyle(fontSize: 14, color: TroitaColors.muted)),
      );
}

class PermissionCard extends StatelessWidget {
  const PermissionCard({super.key, required this.onGrant});

  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(TroitaSpacing.card),
        decoration: TroitaTheme.cardDecoration(
          color: TroitaColors.accentSurface,
          borderColor: TroitaColors.gold,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Telefonul nu permite notificările',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Permiteți-le, ca să primiți notificările alese aici.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onGrant,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Permite notificările'),
            ),
          ],
        ),
      );
}
