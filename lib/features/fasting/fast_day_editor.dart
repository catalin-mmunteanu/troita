import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/fast_day.dart';

/// The day-recording control: Da or Nu, and nothing else.
///
/// "Ați ținut postul?" is what people actually track, and it is answerable in
/// one tap. There used to be a second, optional question after Da — "cum a
/// fost?", with three faces from greu to ușor. It is gone: rating how hard a
/// fast felt turns a spiritual practice into a mood log, and the answer that
/// matters is the first one.
///
/// Tapping the selected answer again clears the day. That is the undo.
class FastDayEditor extends StatelessWidget {
  const FastDayEditor({
    required this.day,
    required this.onKept,
    this.question = 'Ați ținut postul?',
    super.key,
  });

  final FastDay? day;
  final ValueChanged<bool> onKept;
  final String question;

  @override
  Widget build(BuildContext context) {
    final bool? kept = day?.kept;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(question.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _AnswerButton(
                label: 'Da',
                icon: Icons.check,
                selected: kept == true,
                colour: TroitaColors.burgundy,
                onTap: () => onKept(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AnswerButton(
                label: 'Nu',
                icon: Icons.close,
                selected: kept == false,
                colour: TroitaColors.muted,
                onTap: () => onKept(false),
              ),
            ),
          ],
        ),

      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.colour,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: TroitaRadius.smallAll,
        child: Container(
          // Tall enough to hit without looking, which is the point for a
          // control used once a day by people who are not twenty-five.
          height: 54,
          decoration: BoxDecoration(
            color: selected ? colour : Colors.transparent,
            borderRadius: TroitaRadius.smallAll,
            border: Border.all(
              color: selected ? colour : TroitaColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon,
                  size: 22,
                  color: selected ? TroitaColors.onBurgundy : colour),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: selected ? TroitaColors.onBurgundy : colour,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
