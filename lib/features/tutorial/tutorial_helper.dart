import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TutorialHelper {
  static List<TargetFocus> createTargets({
    required GlobalKey homeKey,
    required GlobalKey historyKey,
    required GlobalKey fabKey,
    required GlobalKey chartsKey,
    required GlobalKey settingsKey,
    required GlobalKey summaryKey,
  }) {
    return [
       _buildTarget(
        identify: "summary",
        keyTarget: summaryKey,
        title: "Spending Summary",
        content: "Track your total spending against your budget here.",
        align: ContentAlign.top,
      ),
      _buildTarget(
        identify: "home",
        keyTarget: homeKey,
        title: "Dashboard",
        content: "Your central hub for all activity.",
        align: ContentAlign.top,
      ),
      _buildTarget(
        identify: "history",
        keyTarget: historyKey,
        title: "History",
        content: "Review past transactions.",
        align: ContentAlign.top,
      ),
      _buildTarget(
        identify: "fab",
        keyTarget: fabKey,
        title: "Actions",
        content: "Scan, Add, or Budget from anywhere.",
        align: ContentAlign.top,
      ),
      _buildTarget(
        identify: "charts",
        keyTarget: chartsKey,
        title: "Insights",
        content: "AI-powered spending analysis.",
        align: ContentAlign.top,
      ),
      _buildTarget(
        identify: "settings",
        keyTarget: settingsKey,
        title: "Settings",
        content: "Configure your app preferences.",
        align: ContentAlign.top,
      ),
    ];
  }

  static TargetFocus _buildTarget({
    required String identify,
    required GlobalKey keyTarget,
    required String title,
    required String content,
    ContentAlign align = ContentAlign.bottom,
  }) {
    return TargetFocus(
      identify: identify,
      keyTarget: keyTarget,
      alignSkip: Alignment.topRight,
      enableOverlayTab: true,
      contents: [
        TargetContent(
          align: align,
          builder: (context, controller) {
            return _TutorialContent(
              title: title,
              content: content,
              onNext: () => controller.next(),
              onSkip: () => controller.skip(),
            );
          },
        ),
      ],
    );
  }

  static void showTutorial(
    BuildContext context, {
    required List<TargetFocus> targets,
    required Function(bool) onFinish,
  }) {
    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "", // Hiding default skip
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () => onFinish(false),
      onClickTarget: (target) {},
      onSkip: () {
        onFinish(true);
        return true;
      },
      onClickOverlay: (target) {},
    ).show(context: context);
  }
}

class _TutorialContent extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TutorialContent({
    required this.title,
    required this.content,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onSkip,
                child: const Text("Skip"),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onNext,
                child: const Text("Next"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
