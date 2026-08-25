import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/troita_icons.dart';
import '../settings/settings_page.dart';

/// `profil` (2:430), minus the account header — there are no accounts yet, so a
/// name and an avatar would be a lie.
///
/// The visited-churches and favourites lists belong here once those exist.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TroitaSpacing.page, TroitaSpacing.page, TroitaSpacing.page, 12,
            ),
            child: Text('Profil',
                style: Theme.of(context).textTheme.headlineMedium),
          ),
          _Row(
            icon: TroitaIcons.bell,
            title: 'Setări',
            subtitle: 'Notificări și date',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(
          TroitaSpacing.page, 0, TroitaSpacing.page, TroitaSpacing.listGap,
        ),
        decoration: TroitaTheme.cardDecoration(),
        child: ListTile(
          leading: Icon(icon, color: TroitaColors.burgundy),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle:
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          trailing:
              const Icon(TroitaIcons.chevronRight, color: TroitaColors.muted),
          onTap: onTap,
        ),
      );
}
