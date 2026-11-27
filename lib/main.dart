import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_scope.dart';
import 'app/app_state.dart';
import 'app/theme.dart';
import 'app/troita_mark.dart';
import 'core/models/lecturi.dart' show ReadingTab;
import 'features/calendar/day_detail_page.dart';
import 'features/church_detail/church_detail_page.dart';
import 'features/home/home_page.dart';
import 'features/lecturi/lecturi_page.dart';
import 'features/onboarding/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ro');

  // The animated splash plays once, on the first start after installing;
  // later starts show the still mark while the data opens. Read before the
  // first frame so the right one is drawn from the start.
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool firstRun = !(prefs.getBool(_kSplashSeen) ?? false);

  final AppState state = AppState();
  // Fire and forget: the UI renders a splash until `ready` flips.
  unawaited(state.initialize());

  runApp(TroitaApp(state: state, firstRun: firstRun));
}

const String _kSplashSeen = 'splash_seen';

class TroitaApp extends StatelessWidget {
  const TroitaApp({required this.state, this.firstRun = false, super.key});

  final AppState state;

  /// The first start after installing: play "Troița se ridică".
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Troița',
        debugShowCheckedModeBanner: false,
        theme: TroitaTheme.light(),
        // The app's text size multiplies the phone's, everywhere at once.
        builder: (BuildContext context, Widget? child) {
          final MediaQueryData mq = MediaQuery.of(context);
          final double phone = mq.textScaler.scale(16) / 16;
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(
                  (phone * AppScope.of(context).textScale).clamp(0.8, 2.4)),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: _Root(firstRun: firstRun),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root({required this.firstRun});

  final bool firstRun;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _routing = false;

  /// Whether the first-run animation has finished (or never had to run).
  late bool _splashDone = !widget.firstRun;

  Future<void> _onSplashDone() async {
    if (mounted) setState(() => _splashDone = true);
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setBool(_kSplashSeen, true);
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    // A notification tap can arrive before the first frame (cold start) or
    // after it (app already running), so routing is driven from build. The
    // store is only mutated in the post-frame callback: calling
    // notifyListeners() during build throws.
    if (state.ready && state.pendingChurchId != null && !_routing) {
      _routing = true;
      final String id = state.pendingChurchId!;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        state.consumePending();
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChurchDetailPage(churchId: id),
          ),
        );
        _routing = false;
      });
    }

    if (state.ready && state.pendingDate != null && !_routing) {
      _routing = true;
      final DateTime date = state.pendingDate!;
      final ReadingTab? tab = state.pendingReadingTab;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        state.consumePendingDate();
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => tab == null
                ? DayDetailPage(date: date)
                : LecturiPage(date: date, tab: tab),
          ),
        );
        _routing = false;
      });
    }

    if (state.error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Nu am putut porni aplicația.\n\n${state.error}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // The same burgundy and troiță as Android's launch screen, so the
    // hand-over from it is seamless; animated only on the first start.
    if (!state.ready || !_splashDone) {
      return TroitaSplash(
        animate: widget.firstRun,
        onDone: widget.firstRun ? _onSplashDone : null,
      );
    }

    // Gated on having been through onboarding, not on holding a permission:
    // the calendar works fine without location.
    return state.status.onboarded ? const HomePage() : const OnboardingPage();
  }
}
