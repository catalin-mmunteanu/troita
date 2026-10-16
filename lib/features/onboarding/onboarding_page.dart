import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';

/// First run: one screen, one permission.
///
/// This used to ask for location "to show the churches on the map" — a
/// promise the map did not keep, since it never asked for a position. Asking
/// for something and then not using it is worse than not asking: the user is
/// left wondering what it was really for. Only notifications are requested
/// now, and declining them still lets the app open.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _busy = false;

  Future<void> _continue() async {
    setState(() => _busy = true);
    final AppState state = AppScope.of(context);
    await state.permissions.requestNotifications();
    // Record that we asked, regardless of the answer — otherwise declining
    // notifications traps the user on this screen forever.
    await state.completeOnboarding();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Spacer(),
              const Icon(Icons.add, size: 56, color: TroitaColors.burgundy),
              const SizedBox(height: 24),
              Text('Troița',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'Calendarul ortodox, zi de zi: sfântul zilei, posturile și '
                'dezlegările, și bisericile, mănăstirile și troițele din '
                'toată țara.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Text(
                'Vă putem anunța sfântul zilei și începutul fiecărui post. '
                'Notificările sunt programate pe telefon; nimic nu este '
                'trimis nicăieri.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _continue,
                child: const Text('Continuă'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
