import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class HomeMiniTourTargets {
  HomeMiniTourTargets({
    required this.logPeriodsButtonKey,
    required this.symptomsSectionKey,
    required this.forecastButtonKey,
  });

  final GlobalKey logPeriodsButtonKey;
  final GlobalKey symptomsSectionKey;
  final GlobalKey forecastButtonKey;
}

class HomeMiniTour {
  static TutorialCoachMark build({
    required BuildContext context,
    required HomeMiniTourTargets targets,
    required VoidCallback onSkip,
    required VoidCallback onFinish,
  }) {
    final focusTargets = <TargetFocus>[
      TargetFocus(
        identify: 'log_periods',
        keyTarget: targets.logPeriodsButtonKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: _Bubble(
              title: 'How to log your period',
              body:
                  'Pick a day in the calendar and tap "Log periods" to add or edit your data.',
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: 'symptoms',
        keyTarget: targets.symptomsSectionKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: _Bubble(
              title: 'How to track symptoms',
              body:
                  'In "Symptoms of the day" you see symptoms for the selected day. Add or edit them from the "Log periods" screen.',
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: 'forecast',
        keyTarget: targets.forecastButtonKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: _Bubble(
              title: 'How to see the forecast',
              body:
                  'Tap the calendar icon at the top to open your forecast for the upcoming months.',
            ),
          ),
        ],
      ),
    ];

    return TutorialCoachMark(
      targets: focusTargets,
      textSkip: 'Skip',
      alignSkip: Alignment.bottomRight,
      paddingFocus: 10,
      opacityShadow: 0.75,
      hideSkip: false,
      onSkip: () {
        onSkip();
        return true;
      },
      onFinish: onFinish,
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 8),
            color: Color(0x33000000),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}


