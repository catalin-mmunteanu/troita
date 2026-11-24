import 'package:material_ui/material_ui.dart';

import 'app_scope.dart';
import 'app_state.dart';
import 'theme.dart';

/// The steps of the app-wide text size: 85 % to 160 %, by 15.
abstract final class TextSize {
  static const double min = 0.85;
  static const double max = 1.6;
  static const double step = 0.15;

  static double clamp(double v) =>
      (((v.clamp(min, max) - min) / step).round() * step + min)
          .clamp(min, max);

  /// "Normal", "115 %".
  static String label(double v) =>
      (v - 1).abs() < 0.01 ? 'Normal' : '${(v * 100).round()} %';
}

/// A− and A+ for an app bar: the same setting everywhere, so making the
/// text larger on one screen makes it larger on all of them.
class TextSizeButtons extends StatelessWidget {
  const TextSizeButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final double s = state.textScale;
    // The buttons keep their own size: they must stay reachable at 160 %.
    return MediaQuery.withNoTextScaling(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Text mai mic',
            onPressed: s <= TextSize.min
                ? null
                : () => state.setTextScale(s - TextSize.step),
            icon: const Text('A−', style: TextStyle(fontSize: 16)),
          ),
          IconButton(
            tooltip: 'Text mai mare',
            onPressed: s >= TextSize.max
                ? null
                : () => state.setTextScale(s + TextSize.step),
            icon: const Text('A+', style: TextStyle(fontSize: 21)),
          ),
        ],
      ),
    );
  }
}

/// The larger control, for Profil and Setări: A−, the size, A+, and a line
/// of text to judge it by.
class TextSizeCard extends StatelessWidget {
  const TextSizeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final double s = state.textScale;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        TroitaSpacing.page, 0, TroitaSpacing.page, TroitaSpacing.listGap,
      ),
      padding: const EdgeInsets.all(TroitaSpacing.card),
      decoration: TroitaTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Mărimea textului', style: text.titleMedium),
          const SizedBox(height: 4),
          Text('Pentru toată aplicația. Se adaugă la mărimea aleasă în '
              'setările telefonului.', style: text.bodyMedium),
          const SizedBox(height: 12),
          MediaQuery.withNoTextScaling(
            child: Row(
              children: <Widget>[
                _StepButton(
                  label: 'A−',
                  tooltip: 'Text mai mic',
                  fontSize: 18,
                  onPressed: s <= TextSize.min
                      ? null
                      : () => state.setTextScale(s - TextSize.step),
                ),
                Expanded(
                  child: Text(
                    TextSize.label(s),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                _StepButton(
                  label: 'A+',
                  tooltip: 'Text mai mare',
                  fontSize: 24,
                  onPressed: s >= TextSize.max
                      ? null
                      : () => state.setTextScale(s + TextSize.step),
                ),
              ],
            ),
          ),
          if ((s - 1).abs() >= 0.01)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => state.setTextScale(1),
                child: const Text('Înapoi la normal'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.tooltip,
    required this.fontSize,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final double fontSize;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52)),
          child: Text(label, style: TextStyle(fontSize: fontSize)),
        ),
      );
}
