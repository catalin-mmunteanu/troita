import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/fast_day.dart';

/// The whole day-recording control: Da / Nu, then the optional faces.
///
/// The primary question is "ați ținut postul?", because that is what people
/// actually track and it is answerable in one tap. How it felt is a second,
/// entirely skippable question that only appears once the answer is Da — asking
/// it of someone who has just said Nu would be tactless, and asking it of
/// everyone every day turns a simple check-in into a chore.
///
/// Tapping the selected answer again clears the day. That is the undo.
class FastDayEditor extends StatelessWidget {
  const FastDayEditor({
    required this.day,
    required this.onKept,
    required this.onMood,
    this.question = 'Ați ținut postul?',
    super.key,
  });

  final FastDay? day;
  final ValueChanged<bool> onKept;
  final ValueChanged<FastMood> onMood;
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

        // Only after Da, and never required.
        if (kept == true) ...<Widget>[
          const SizedBox(height: 18),
          Text('CUM A FOST? (OPȚIONAL)',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          MoodSelector(selected: day?.mood, onSelect: onMood),
        ],
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

/// The three faces on their own. Only shown once the answer is Da.
class MoodSelector extends StatelessWidget {
  const MoodSelector({
    required this.selected,
    required this.onSelect,
    this.compact = false,
    super.key,
  });

  final FastMood? selected;
  final ValueChanged<FastMood> onSelect;
  final bool compact;

  static IconData iconFor(FastMood mood, {required bool filled}) =>
      switch (mood) {
        FastMood.hard => filled
            ? Icons.sentiment_dissatisfied
            : Icons.sentiment_dissatisfied_outlined,
        FastMood.ok => filled
            ? Icons.sentiment_neutral
            : Icons.sentiment_neutral_outlined,
        FastMood.good => filled
            ? Icons.sentiment_very_satisfied
            : Icons.sentiment_very_satisfied_outlined,
      };

  static Color colourFor(FastMood mood) => switch (mood) {
        // Not red/green. Keeping a fast on a hard day is not a failure, and
        // colouring it like one would be the wrong message entirely.
        FastMood.hard => TroitaColors.muted,
        FastMood.ok => TroitaColors.gold,
        FastMood.good => TroitaColors.burgundy,
      };

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 30 : 40;

    return Row(
      mainAxisAlignment:
          compact ? MainAxisAlignment.start : MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        for (final FastMood mood in FastMood.values)
          Padding(
            padding: EdgeInsets.only(right: compact ? 10 : 0),
            child: Semantics(
              button: true,
              selected: selected == mood,
              label: mood.description,
              child: InkWell(
                onTap: () => onSelect(mood),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 14,
                    vertical: compact ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected == mood
                        ? colourFor(mood).withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected == mood
                          ? colourFor(mood)
                          : TroitaColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        iconFor(mood, filled: selected == mood),
                        size: size,
                        color: selected == mood
                            ? colourFor(mood)
                            : TroitaColors.muted,
                      ),
                      if (!compact) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          mood.label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: selected == mood
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected == mood
                                ? colourFor(mood)
                                : TroitaColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
