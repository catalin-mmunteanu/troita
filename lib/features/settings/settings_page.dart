import 'package:material_ui/material_ui.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/site_links.dart';
import '../../app/text_size.dart';
import '../../app/theme.dart';
import '../../app/troita_icons.dart';
import '../../core/models/saved_name.dart';
import '../../core/notifications/notification_prefs.dart';
import '../../core/notifications/notification_service.dart';
import '../profile/saved_names_page.dart';
import '../onboarding/onboarding_page.dart';
import 'notifications_page.dart';
import 'settings_widgets.dart';
import 'text_size_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// Setări: an overview, after Android's settings guidelines. Each row says
/// what it is set to, so the screen can be read at a glance; the many
/// choices of notifications live on a screen of their own.
class _SettingsPageState extends State<SettingsPage> {
  bool? _permitted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bool ok = await TroitaNotifications.instance.areEnabled();
      if (mounted) setState(() => _permitted = ok);
    });
  }

  String _notificationsValue(NotificationPrefs prefs) {
    if (_permitted == false) return 'Nepermise de telefon';
    if (!prefs.enabled) return 'Oprite';
    return '${prefs.activeCount} din ${NotifKind.values.length} pornite · '
        'dimineața ${prefs.timeLabel}, seara ${prefs.eveningTimeLabel}';
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final NotificationPrefs prefs = state.notificationPrefs;
    final int names = state.savedNames.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Setări')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        children: <Widget>[
          SettingsTile(
            icon: Icons.auto_awesome_outlined,
            title: 'Configurare rapidă',
            value: 'Textul, notificările, numele, biserica, pas cu pas',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const OnboardingPage(rerun: true),
            )),
          ),
          SettingsTile(
            icon: TroitaIcons.bell,
            title: 'Notificări',
            value: _notificationsValue(prefs),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const NotificationsPage(),
              ));
              final bool ok = await TroitaNotifications.instance.areEnabled();
              if (mounted) setState(() => _permitted = ok);
            },
          ),
          SettingsTile(
            icon: Icons.format_size,
            title: 'Mărimea textului',
            value: TextSize.label(state.textScale),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const TextSizePage(),
            )),
          ),
          SettingsTile(
            icon: Icons.cake_outlined,
            title: 'Zile de nume',
            value: names == 0
                ? 'Niciun nume salvat'
                : state.savedNames.map((SavedName n) => n.display).join(', '),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const SavedNamesPage(),
            )),
          ),
          SwitchListTile(
            value: state.journalEnabled,
            onChanged: (bool v) => state.setJournalEnabled(v),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            secondary: const Icon(Icons.edit_calendar_outlined,
                color: TroitaColors.burgundy, size: 26),
            title: const Text('Jurnal de post', style: TextStyle(fontSize: 17)),
            subtitle: const Text(
              'Întrebarea „Ați ținut postul?” și zilele însemnate',
              style: TextStyle(fontSize: 15, color: TroitaColors.muted),
            ),
          ),

          const SectionHeader('Despre aplicație'),
          // The site carries the same calendar, the fasting guide and the
          // privacy policy Google Play links to.
          SettingsTile(
            title: 'Calendarul pe troita.ro',
            value: 'Același calendar, pe orice dispozitiv',
            external: true,
            onTap: () => state.native.openUri(SiteLinks.base),
          ),
          SettingsTile(
            title: 'Politica de confidențialitate',
            external: true,
            onTap: () => state.native.openUri(SiteLinks.privacy),
          ),
          SettingsTile(
            title: 'Versiunea datelor',
            value: state.seed['seed_version'] ?? '—',
          ),
          // Required by the ODbL licence of the church data and map tiles.
          const Footnote(
              'Date despre biserici și hartă: © contributorii OpenStreetMap.'),
          // The source of the readings, once here rather than under each
          // one. Same words as `source` in assets/data/biblia_nt.json.
          const Footnote('Textul Apostolului și al Evangheliei: Biblia, '
              'ediția Sfântului Sinod, IBMBOR, 1988.'),
        ],
      ),
    );
  }
}
