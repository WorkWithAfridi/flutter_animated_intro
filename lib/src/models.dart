import 'package:flutter/material.dart';
import 'target.dart';

/// Determines eligibility for automatic starts; forced starts bypass this rule.
/// `once` uses stored history, while `oncePerSession` lasts for this process.
enum IntroFrequency { once, oncePerSession, everyVisit, cooldown, manual }

/// Applies to automatic starts. A run is counted at start, even if later skipped.
class IntroPlaybackPolicy {
  const IntroPlaybackPolicy({
    this.frequency = IntroFrequency.once,
    this.cooldown = const Duration(days: 7),
    this.maxPlays,
  }) : assert(maxPlays == null || maxPlays > 0);

  /// Automatic playback rule evaluated whenever the host requests a start.
  final IntroFrequency frequency;

  /// Minimum time between starts when [frequency] is cooldown.
  final Duration cooldown;

  /// Optional automatic-start limit, including runs that were skipped.
  final int? maxPlays;
}

/// Whether an awaited step action permits advancing to the next step.
enum IntroActionResult { advance, stay }

/// Preferred coach-card position; automatic favors below when it fits,
/// otherwise choosing the side with more room.
enum IntroPlacement { automatic, above, below }

/// After the target timeout, wait exposes retry/skip; skip moves on.
enum IntroMissingTargetBehavior { wait, skip }

/// Uses a scoped wrapped target ID or a key belonging to an existing widget.
class IntroAnchor {
  const IntroAnchor.id(String this.id) : key = null;
  const IntroAnchor.key(GlobalKey this.key) : id = null;

  /// ID registered by an IntroTarget in this controller.
  final String? id;

  /// Key already attached to the real widget; no wrapper is required.
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

  /// Locates the mounted widget whose bounds form the spotlight.
  final IntroAnchor target;

  /// Host-provided, localized copy displayed in the coach card.
  final String title, description;

  /// Optional accessibility announcement replacing the default step label.
  final String? semanticLabel;

  /// Preferred placement, clamped to the available screen bounds.
  final IntroPlacement placement;

  /// Spotlight expansion and rounded-corner radius in logical pixels.
  final double targetPadding, targetRadius;

  /// Whether spotlight taps run onNext, and mounted targets scroll into view.
  /// Taps invoke the tour action rather than the underlying widget callback.
  final bool advanceOnTargetTap, autoScroll;

  /// How to proceed if the target cannot be measured before the timeout.
  final IntroMissingTargetBehavior missingTargetBehavior;

  /// Prepare the screen (open a tab/drawer/modal) before measuring this target.
  final Future<void> Function()? onEnter;

  /// Return stay on cancellation/validation failure. When opening a modal
  /// targeted by the next step, return after opening, not after dismissal.
  final Future<IntroActionResult> Function()? onNext;
  final Widget? _widget;

  /// The wrapped widget supplied to IntroStep.widget; insert it exactly once.
  /// Throws StateError when this step was created without a supplied widget.
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

  /// Dimming color outside the transparent spotlight cutout.
  final Color barrierColor;

  /// Optional overrides; omitted colors come from the surrounding theme.
  final Color? accentColor, cardColor, foregroundColor;

  /// Card width, corner radius, screen margin, and target-to-card gap.
  /// All dimensions use logical pixels; width shrinks on narrow screens.
  final double cardWidth, cardRadius, screenPadding, arrowGap;

  /// Visibility of the target arrow and default card progress indicator.
  final bool showArrow, showProgress;

  /// Spotlight/card transition duration; reduced-motion settings override it.
  final Duration animationDuration;

  /// Localizable labels for the default card controls.
  final String nextLabel, backLabel, skipLabel, doneLabel, retryLabel;

  /// Localizable target-loading and recoverable-error messages.
  final String waitingLabel, errorLabel;
}
