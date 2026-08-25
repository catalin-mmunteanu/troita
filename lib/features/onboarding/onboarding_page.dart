import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';

/// First run.
///
/// A fraction of what it was. With background location gone there is no
/// prominent-disclosure requirement, no strict request ordering, and no
/// settings-page redirect — just notifications and, optionally, location for
/// the map. Location is not required to use the calendar, so it can be skipped.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _busy = false;

  Future<void> _continue({required bool withLocation}) async {
    setState(() => _busy = true);
    final AppState state = AppScope.of(context);
    await state.permissions.requestNotifications();
    if (withLocation) await state.permissions.requestLocation();
    // Record that we asked, regardless of the answer — otherwise declining
    // location traps the user on this screen forever.
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
                'dezlegările, și bisericile din jurul dumneavoastră.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Text(
                'Locația este folosită doar pentru a vă arăta bisericile de pe '
                'hartă. Rămâne pe telefon și nu o trimitem nicăieri.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : () => _continue(withLocation: true),
                child: const Text('Continuă'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _continue(withLocation: false),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: TroitaColors.muted,
                ),
                child: const Text('Fără acces la locație'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
