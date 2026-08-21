import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/theme.dart';
import '../../core/permissions/permission_service.dart';
import '../../app/app_scope.dart';

/// First run.
///
/// The order here is not cosmetic. Play requires a *prominent disclosure*
/// explaining what location is used for, shown before the runtime prompt. And
/// Android requires foreground location to be granted before background
/// location can even be asked for. Getting either wrong means a silent denial
/// or a rejected release.
///
/// Background location is deliberately not requested here at all — journey mode
/// works without it, so v1 can ship without the Play Console declaration and
/// the review video. Passive mode asks for it later, from Settings, with its
/// own disclosure.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  bool _busy = false;
  String? _message;

  Future<void> _grantLocation() async {
    setState(() => _busy = true);
    final AppState state = AppScope.of(context);
    final LocationGrant grant = await state.permissions.requestForeground();
    await state.native.status();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (grant) {
        LocationGrant.denied =>
          'Fără acces la locație nu vă putem anunța când treceți pe lângă o biserică.',
        LocationGrant.permanentlyDenied =>
          'Permisiunea a fost refuzată definitiv. O puteți activa din Setările telefonului.',
        _ => null,
      };
      if (grant != LocationGrant.denied &&
          grant != LocationGrant.permanentlyDenied) {
        _step = 2;
      }
    });
    await state.refreshStatus();
  }

  Future<void> _grantNotifications() async {
    setState(() => _busy = true);
    final AppState state = AppScope.of(context);
    await state.permissions.requestNotifications();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = 1;
    });
    await state.refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
          child: switch (_step) {
            0 => _Intro(busy: _busy, onNext: _grantNotifications),
            1 => _Disclosure(
                busy: _busy,
                message: _message,
                onGrant: _grantLocation,
              ),
            _ => const _Done(),
          },
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.busy, required this.onNext});

  final bool busy;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Spacer(),
        Icon(Icons.add, size: 56, color: TroitaTheme.red.withValues(alpha: 0.8)),
        const SizedBox(height: 24),
        Text('Troița', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          'Treceți zilnic pe lângă biserici și troițe pe care nu le observați. '
          'Troița vă dă un semn discret — o vibrație scurtă — și vă spune '
          'hramul, anul și povestea locului.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        FilledButton(
          onPressed: busy ? null : onNext,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: TroitaTheme.red,
          ),
          child: const Text('Începem'),
        ),
      ],
    );
  }
}

/// The prominent disclosure. Play reviewers look for this exact thing, in the
/// app, before the system dialog appears.
class _Disclosure extends StatelessWidget {
  const _Disclosure({
    required this.busy,
    required this.onGrant,
    this.message,
  });

  final bool busy;
  final VoidCallback onGrant;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 12),
        Text('Accesul la locație',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Text(
          'Troița folosește locația telefonului pentru a recunoaște bisericile '
          'și troițele pe lângă care treceți și pentru a vă anunța despre ele.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        const _Bullet(
          'Locația este folosită doar pe telefon. Nu o trimitem nicăieri și nu '
          'o păstrăm.',
        ),
        const _Bullet(
          'În modul „Drum" locația este folosită doar cât timp porniți dumneavoastră '
          'urmărirea, cu o notificare permanentă vizibilă.',
        ),
        const _Bullet(
          'Anunțurile automate, fără să porniți nimic, sunt opționale și le puteți '
          'activa mai târziu din Setări.',
        ),
        const Spacer(),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              message!,
              style: const TextStyle(color: TroitaTheme.red, fontSize: 13.5),
            ),
          ),
        FilledButton(
          onPressed: busy ? null : onGrant,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: TroitaTheme.red,
          ),
          child: const Text('Permite accesul la locație'),
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done();

  @override
  Widget build(BuildContext context) {
    // The store rebuilds into HomePage as soon as refreshStatus lands; this is
    // only visible for a frame or two.
    return const Center(child: CircularProgressIndicator());
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 7, right: 10),
            child: Icon(Icons.circle, size: 5, color: TroitaTheme.gold),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
