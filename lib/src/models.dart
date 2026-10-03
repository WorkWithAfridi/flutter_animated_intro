import 'package:flutter/material.dart';
import 'target.dart';

enum IntroFrequency { once, oncePerSession, everyVisit, cooldown, manual }

/// Applies to automatic starts. A run is counted at start, even if later skipped.
class IntroPlaybackPolicy {
  const IntroPlaybackPolicy({
    this.frequency = IntroFrequency.once,
    this.cooldown = const Duration(days: 7),
    this.maxPlays,
  }) : assert(maxPlays == null || maxPlays > 0);
  final IntroFrequency frequency;
  final Duration cooldown;
  final int? maxPlays;
}

enum IntroActionResult { advance, stay }

enum IntroPlacement { automatic, above, below }

enum IntroMissingTargetBehavior { wait, skip }

/// Uses a scoped wrapped target ID or a key belonging to an existing widget.
class IntroAnchor {
  const IntroAnchor.id(String this.id) : key = null;
  const IntroAnchor.key(GlobalKey this.key) : id = null;
  final String? id;
  final GlobalKey? key;
}

/// Copy comes from the host, allowing any localization system.
class IntroStep {
  const IntroStep({
    required this.target,
    required this.title,
    required this.description,
    this.onEnter,
    this.onNext,
    this.placement = IntroPlacement.automatic,
    this.targetPadding = 8,
    this.targetRadius = 16,
    this.advanceOnTargetTap = true,
    this.autoScroll = true,
    this.missingTargetBehavior = IntroMissingTargetBehavior.wait,
    this.semanticLabel,
  }) : assert(targetPadding >= 0),
       assert(targetRadius >= 0),
       _widget = null;

  /// Supply a widget, then insert [targetWidget] once in your screen layout.
  IntroStep.widget({
    required String id,
    required Widget widget,
    required this.title,
    required this.description,
    this.onEnter,
    this.onNext,
    this.placement = IntroPlacement.automatic,
    this.targetPadding = 8,
    this.targetRadius = 16,
    this.advanceOnTargetTap = true,
    this.autoScroll = true,
    this.missingTargetBehavior = IntroMissingTargetBehavior.wait,
    this.semanticLabel,
  }) : assert(targetPadding >= 0),
       assert(targetRadius >= 0),
       target = IntroAnchor.id(id),
       _widget = IntroTarget(id: id, child: widget);

  final IntroAnchor target;
  final String title, description;
  final String? semanticLabel;
  final IntroPlacement placement;
  final double targetPadding, targetRadius;
  final bool advanceOnTargetTap, autoScroll;
  final IntroMissingTargetBehavior missingTargetBehavior;

  /// Prepare the screen (open a tab/drawer/modal) before measuring this target.
  final Future<void> Function()? onEnter;

  /// Return stay on cancellation/validation failure. When opening a modal
  /// targeted by the next step, return after opening, not after dismissal.
  final Future<IntroActionResult> Function()? onNext;
  final Widget? _widget;
  Widget get targetWidget =>
      _widget ?? (throw StateError('Use IntroStep.widget to supply a widget.'));
}

/// Customize the default coach card, controls, animation and spotlight.
class IntroTheme {
  const IntroTheme({
    this.barrierColor = const Color(0xB8000000),
    this.accentColor,
    this.cardColor,
    this.foregroundColor,
    this.cardWidth = 360,
    this.cardRadius = 22,
    this.screenPadding = 16,
    this.arrowGap = 28,
    this.showArrow = true,
    this.showProgress = true,
    this.animationDuration = const Duration(milliseconds: 260),
    this.nextLabel = 'Next',
    this.backLabel = 'Back',
    this.skipLabel = 'Skip tour',
    this.doneLabel = 'Done',
    this.retryLabel = 'Retry',
    this.waitingLabel = 'Preparing the next step…',
    this.errorLabel = 'This step could not be opened.',
  }) : assert(cardWidth > 0),
       assert(cardRadius >= 0),
       assert(screenPadding >= 0),
       assert(arrowGap >= 0);
  final Color barrierColor;
  final Color? accentColor, cardColor, foregroundColor;
  final double cardWidth, cardRadius, screenPadding, arrowGap;
  final bool showArrow, showProgress;
  final Duration animationDuration;
  final String nextLabel, backLabel, skipLabel, doneLabel, retryLabel;
  final String waitingLabel, errorLabel;
}
