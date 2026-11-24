import 'package:material_ui/material_ui.dart';

import '../../app/text_size.dart';
import '../../app/theme.dart';
import '../../app/troita_icons.dart';
import '../settings/settings_page.dart';
import '../map/churches_map_page.dart';
import 'my_churches_page.dart';
import 'saved_names_page.dart';

/// `profil` (2:430), minus the account header — there are no accounts yet, so a
/// name and an avatar would be a lie.
///
/// The text size of the whole app is set here first, where people look for
/// it, with rows large enough to read before they have found it.

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
          const TextSizeCard(),
          _Row(
            icon: Icons.star_border,
            title: 'Bisericile mele',
            subtitle: 'Favorite și locuri vizitate',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MyChurchesPage()),
            ),
          ),
          _Row(
            icon: TroitaIcons.map,
            title: 'Biserici și hartă',
            subtitle: 'Bisericile, mănăstirile și troițele din toată țara',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ChurchesMapPage()),
            ),
          ),
          _Row(
            icon: Icons.cake_outlined,
            title: 'Zile de nume',
            subtitle: 'Numele celor dragi și ziua lor',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SavedNamesPage()),
            ),
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Icon(icon, color: TroitaColors.burgundy, size: 28),
          title: Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 18)),
          subtitle: Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 15, color: TroitaColors.muted)),
          trailing:
              const Icon(TroitaIcons.chevronRight, color: TroitaColors.muted),
          onTap: onTap,
        ),
      );
}
