import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../app/theme.dart';
import 'onboarding_steps.dart';

/// First run: a short setup, one question per screen.
///
/// Built after the onboarding guidance of Android and Apple and the research
/// on apps for older adults:
/// - text size first, so every following screen is already readable;
/// - one decision per screen, large type (18+) and 56 dp buttons;
/// - the progress shown ("Pasul 2 din 5"), Înapoi on every step, every
///   step skippable, the whole setup skippable from the first screen;
/// - no swiping, no auto-advancing carousel, no time limits;
/// - the notification permission asked in context, after the person chose
///   what to receive, and not at all for "Fără notificări";
/// - every choice saved at once, and the step remembered, so a setup
///   interrupted half way resumes where it stopped.
///
/// The same flow runs again from Setări → Configurare rapidă ([rerun]),
/// starting from the current choices, and closes instead of finishing the
/// first run.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, this.rerun = false});

  final bool rerun;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

enum _Step { welcome, notifications, names, church, more, done }

class _OnboardingPageState extends State<OnboardingPage> {
  static const String _kStep = 'onboarding_step';

  _Step _step = _Step.welcome;
  bool _busy = false;

  /// Set by the notifications step when the phone refused the permission,
  /// for the summary.
  bool _permissionRefused = false;

  final GlobalKey<NotificationsStepState> _notifications =
      GlobalKey<NotificationsStepState>();

  @override
  void initState() {
    super.initState();
    if (!widget.rerun) {
      SharedPreferences.getInstance().then((SharedPreferences p) {
        final int i = p.getInt(_kStep) ?? 0;
        if (mounted && i > 0 && i < _Step.values.length) {
          setState(() => _step = _Step.values[i]);
        }
      });
    }
  }

  Future<void> _go(_Step to) async {
    setState(() => _step = to);
    if (!widget.rerun) {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setInt(_kStep, to.index);
    }
  }

  Future<void> _next() async {
    setState(() => _busy = true);
    try {
      if (_step == _Step.notifications) {
        final bool? granted = await _notifications.currentState?.save();
        _permissionRefused = granted == false;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await _go(_Step.values[_step.index + 1]);
  }

  Future<void> _finish({bool skipped = false}) async {
    setState(() => _busy = true);
    final AppState state = AppScope.of(context);
    if (skipped && !widget.rerun) {
      // The defaults include the great feasts: ask once, as before.
      await state.requestNotificationPermission();
    }
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.remove(_kStep);
    if (widget.rerun) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await state.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_step) {
      _Step.welcome => const WelcomeStep(),
      _Step.notifications => NotificationsStep(key: _notifications),
      _Step.names => const NamesStep(),
      _Step.church => const ChurchStep(),
      _Step.more => const MoreStep(),
      _Step.done => DoneStep(
          permissionRefused: _permissionRefused,
          onEdit: (int step) => _go(_Step.values[step]),
        ),
    };

    final bool first = _step == _Step.welcome;
    final bool last = _step == _Step.done;

    return PopScope(
      // The system back gesture goes a step back, not out of the setup.
      canPop: first && widget.rerun,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && !first) _go(_Step.values[_step.index - 1]);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _TopBar(
                step: _step.index,
                count: _Step.values.length - 1,
                onBack:
                    first ? null : () => _go(_Step.values[_step.index - 1]),
                onClose: widget.rerun && first
                    ? () => Navigator.of(context).pop()
                    : null,
                onSkip: first || last || _busy
                    ? null
                    : () => _go(_Step.values[_step.index + 1]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey<_Step>(_step),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: body,
                ),
              ),
              _BottomBar(
                primary: switch (_step) {
                  _Step.welcome => 'Începem',
                  _Step.done => widget.rerun ? 'Gata' : 'Intră în aplicație',
                  _ => 'Continuă',
                },
                onPrimary: _busy ? null : () => last ? _finish() : _next(),
                secondary: first ? 'Configurez mai târziu' : null,
                onSecondary:
                    _busy || !first ? null : () => _finish(skipped: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Înapoi, the progress, Mai târziu.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.step,
    required this.count,
    required this.onBack,
    required this.onSkip,
    required this.onClose,
  });

  /// 0 for the welcome; [count] for the summary.
  final int step;
  final int count;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final bool numbered = step < count;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 56,
            child: Row(
              children: <Widget>[
                if (onBack != null)
                  IconButton(
                    tooltip: 'Înapoi',
                    iconSize: 28,
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  )
                else if (onClose != null)
                  IconButton(
                    tooltip: 'Închide',
                    iconSize: 28,
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  )
                else
                  const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    numbered ? 'Pasul ${step + 1} din $count' : 'Gata',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: TroitaColors.muted,
                    ),
                  ),
                ),
                if (onSkip != null)
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      textStyle: const TextStyle(fontSize: 17),
                    ),
                    child: const Text('Mai târziu'),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
          // The dots repeat the words for those who read shapes faster.
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < count; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == step ? 22 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? TroitaColors.burgundy
                          : TroitaColors.border,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.onSecondary,
  });

  final String primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
              ),
              child: Text(primary),
            ),
            if (secondary != null) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSecondary,
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: const TextStyle(fontSize: 17),
                ),
                child: Text(secondary!),
              ),
            ],
          ],
        ),
      );
}
