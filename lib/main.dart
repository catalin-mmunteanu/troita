import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app_scope.dart';
import 'app/app_state.dart';
import 'app/theme.dart';
import 'core/models/lecturi.dart' show ReadingTab;
import 'features/calendar/day_detail_page.dart';
import 'features/church_detail/church_detail_page.dart';
import 'features/home/home_page.dart';
import 'features/lecturi/lecturi_page.dart';
import 'features/onboarding/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ro');

  final AppState state = AppState();
  // Fire and forget: the UI renders a splash until `ready` flips.
  unawaited(state.initialize());

  runApp(TroitaApp(state: state));
}

class TroitaApp extends StatelessWidget {
  const TroitaApp({required this.state, super.key});

  final AppState state;

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
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _routing = false;

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

    if (!state.ready) {
      return Scaffold(
        body: Center(
          child: state.error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Nu am putut porni aplicația.\n\n${state.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      );
    }

    // Gated on having been through onboarding, not on holding a permission:
    // the calendar works fine without location.
    return state.status.onboarded ? const HomePage() : const OnboardingPage();
  }
}
