import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'controller.dart';
import 'models.dart';
import 'target.dart';

/// Builds a replacement coach card using the current step and playback controls.
typedef IntroCardBuilder =
    Widget Function(BuildContext context, IntroCardDetails details);

/// State and controls available to a custom coach card.
class IntroCardDetails {
  const IntroCardDetails({
    required this.controller,
    required this.step,
    required this.theme,
    required this.allowSkip,
    required this.allowBack,
  });

  /// Playback state and commands shared with the overlay.
  final IntroController controller;

  /// Step whose copy and target the card describes.
  final IntroStep step;

  /// Host customization available to both default and custom cards.
  final IntroTheme theme;

  /// UI permissions; custom cards should honor these when showing controls.
  final bool allowSkip, allowBack;

  /// One-based step number for display.
  int get stepNumber => controller.currentIndex + 1;

  /// Total number of configured steps.
  int get stepCount => controller.steps.length;

  /// Whether the next action completes the tour.
  bool get isLastStep => controller.isLastStep;

  /// Use this to disable controls while asynchronous work is pending.
  bool get isBusy => controller.isBusy;

  /// Runs the step action and advances when permitted.
  Future<void> next() => controller.next();

  /// Re-enters the previous step without executing onNext.
  Future<void> back() => controller.previous();

  /// Ends the tour through its skip callback.
  Future<void> skip() => controller.skip();
}

/// Wrap a screen for autoplay after its first frame. For targets inside modal
/// routes, mount above the Navigator in MaterialApp.builder instead.
class IntroFlow extends StatefulWidget {
  const IntroFlow({
    super.key,
    required this.controller,
    required this.child,
    this.autoPlay = true,
    this.enabled = true,
    this.startDelay = const Duration(milliseconds: 400),
    this.targetWaitTimeout = const Duration(seconds: 5),
    this.scrollDuration = const Duration(milliseconds: 300),
    this.theme = const IntroTheme(),
    this.cardBuilder,
    this.allowSkip = true,
    this.allowBack = true,
    this.blockBackNavigation = true,
    this.routeObserver,
  });

  /// Host-owned controller; this widget attaches it but does not dispose it.
  final IntroController controller;

  /// Screen or Navigator beneath the overlay.
  final Widget child;

  /// Automatic start, overlay enablement, default controls, and back blocking.
  /// Disabling pauses a run; re-enabling resumes it or requests autoplay.
  final bool autoPlay, enabled, allowSkip, allowBack, blockBackNavigation;

  /// Initial delay, target polling timeout, and automatic scroll duration.
  final Duration startDelay, targetWaitTimeout, scrollDuration;
  final IntroTheme theme;

  /// Replaces the ready-step card; loading/error states remain built in.
  final IntroCardBuilder? cardBuilder;

  /// Register this observer in MaterialApp.navigatorObservers to pause covered
  /// screen-level flows and replay/resume when their route becomes visible.
  /// Do not use it for a global flow whose next target is inside a modal route.
  final RouteObserver<ModalRoute<dynamic>>? routeObserver;
  @override
  State<IntroFlow> createState() => _IntroFlowState();
}

class _IntroFlowState extends State<IntroFlow>
    with SingleTickerProviderStateMixin, RouteAware, WidgetsBindingObserver {
  // Both keys measure real layout: target coordinates are relative to the stack,
  // and card height can change with localized copy or a custom builder.
  final _stackKey = GlobalKey();
  final _cardKey = GlobalKey();
  late final Ticker _ticker;
  Timer? _startTimer;
  Rect? _target;
  Size _cardSize = const Size(360, 230);
  ModalRoute<dynamic>? _route;
  bool _covered = false, _lifecyclePaused = false;
  int _measuredIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((_) => _measure());
    _attach();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleStart();
    });
  }

  void _attach() {
    widget.controller.attach(this, _prepare);
    widget.controller.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribe();
  }

  void _subscribe() {
    final route = ModalRoute.of(context);
    if (identical(_route, route)) return;
    widget.routeObserver?.unsubscribe(this);
    _route = route;
    if (route != null) widget.routeObserver?.subscribe(this, route);
  }

  @override
  void didUpdateWidget(IntroFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      oldWidget.controller.detach(this);
      _attach();
      _target = null;
      _measuredIndex = -1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleStart();
      });
    }
    if (oldWidget.routeObserver != widget.routeObserver) {
      oldWidget.routeObserver?.unsubscribe(this);
      _route = null;
      _subscribe();
    }
    if (!widget.enabled) {
      _startTimer?.cancel();
      widget.controller.pause();
    } else if (!oldWidget.enabled) {
      if (widget.controller.isPaused) {
        unawaited(widget.controller.resume());
      } else {
        _scheduleStart();
      }
    }
    if (!widget.autoPlay) _startTimer?.cancel();
    if (widget.autoPlay && !oldWidget.autoPlay) _scheduleStart();
    _syncTicker();
  }

  void _scheduleStart() {
    _startTimer?.cancel();
    if (!widget.autoPlay || !widget.enabled || _covered) return;
    _startTimer = Timer(widget.startDelay, () {
      if (mounted && widget.enabled && !_covered) {
        unawaited(widget.controller.start(force: false));
      }
    });
  }

  @override
  void didPushNext() {
    _covered = true;
    _startTimer?.cancel();
    widget.controller.pause();
  }

  @override
  void didPopNext() {
    _covered = false;
    if (!widget.enabled) return;
    if (widget.controller.isPaused) {
      unawaited(widget.controller.resume());
    } else {
      _scheduleStart();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_lifecyclePaused && widget.enabled && !_covered) {
        _lifecyclePaused = false;
        unawaited(widget.controller.resume());
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Resume only pauses owned by the app lifecycle, preserving manual pauses.
      _lifecyclePaused =
          _lifecyclePaused ||
          (widget.controller.isActive && !widget.controller.isPaused);
      widget.controller.pause();
    }
  }

  void _changed() {
    if (!mounted) return;
    if (_measuredIndex != widget.controller.currentIndex) _target = null;
    _syncTicker();
    setState(() {});
  }

  void _syncTicker() {
    // Track scrolling and animated targets each frame only while the tour is visible.
    final active =
        widget.enabled &&
        widget.controller.isActive &&
        !widget.controller.isPaused;
    if (active && !_ticker.isActive) _ticker.start();
    if (!active && _ticker.isActive) _ticker.stop();
  }

  Rect? _rectFor(IntroStep step, {bool clipToViewport = true}) {
    final target = widget.controller
        .keyFor(step.target)
        ?.currentContext
        ?.findRenderObject();
    final overlay = _stackKey.currentContext?.findRenderObject();
    if (target is! RenderBox ||
        overlay is! RenderBox ||
        !target.attached ||
        !target.hasSize ||
        !overlay.hasSize) {
      return null;
    }
    // Convert into overlay coordinates instead of assuming a full-screen origin.
    var rect = MatrixUtils.transformRect(
      target.getTransformTo(overlay),
      Offset.zero & target.size,
    );
    // Intersect with ancestor paint clips, including scroll viewports and sheets.
    RenderObject child = target;
    RenderObject? parent = child.parent;
    while (parent != null && parent != overlay) {
      if ((parent is RenderOffstage && parent.offstage) ||
          (parent is RenderOpacity && parent.opacity == 0)) {
        return null;
      }
      final clip = parent.describeApproximatePaintClip(child);
      if (clipToViewport && clip != null) {
        rect = rect.intersect(
          MatrixUtils.transformRect(parent.getTransformTo(overlay), clip),
        );
      }
      child = parent;
      parent = parent.parent;
    }
    if (clipToViewport) rect = rect.intersect(Offset.zero & overlay.size);
    return rect.isEmpty || !rect.isFinite ? null : rect;
  }

  void _measure() {
    if (!mounted) return;
    final step = widget.controller.currentStep;
    final rect = step == null ? null : _rectFor(step);
    final cardBox = _cardKey.currentContext?.findRenderObject();
    final cardSize = cardBox is RenderBox && cardBox.hasSize
        ? cardBox.size
        : _cardSize;
    if (rect != _target ||
        cardSize != _cardSize ||
        _measuredIndex != widget.controller.currentIndex) {
      setState(() {
        _target = rect;
        _cardSize = cardSize;
        _measuredIndex = widget.controller.currentIndex;
      });
    }
  }

  Future<bool> _prepare(IntroStep step) async {
    // onEnter may have just opened a route. Poll until its target is laid out.
    // Lazy children must be mounted by the host before they can be auto-scrolled.
    var waited = Duration.zero;
    const interval = Duration(milliseconds: 32);
    var scrolled = false;
    while (mounted &&
        widget.controller.isActive &&
        !widget.controller.isPaused &&
        identical(widget.controller.currentStep, step)) {
      final targetContext = widget.controller
          .keyFor(step.target)
          ?.currentContext;
      if (targetContext != null &&
          targetContext.mounted &&
          step.autoScroll &&
          !scrolled &&
          _rectFor(step) != _rectFor(step, clipToViewport: false)) {
        // Scroll once per preparation to avoid repeatedly fighting user scrolling.
        scrolled = true;
        await Scrollable.ensureVisible(
          targetContext,
          duration: widget.scrollDuration,
          alignment: .5,
        );
        if (!mounted || !identical(widget.controller.currentStep, step)) {
          return false;
        }
      }
      if (_rectFor(step) != null) {
        _measure();
        return true;
      }
      if (waited >= widget.targetWaitTimeout) return false;
      await Future<void>.delayed(interval);
      waited += interval;
    }
    return false;
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.routeObserver?.unsubscribe(this);
    widget.controller.removeListener(_changed);
    widget.controller.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final visible =
        widget.enabled && controller.isActive && !controller.isPaused;
    return IntroScope(
      controller: controller,
      child: PopScope(
        canPop: !(visible && widget.blockBackNavigation),
        child: Stack(
          key: _stackKey,
          fit: StackFit.expand,
          children: [
            // Keep keyboard focus and accessibility navigation inside the tour.
            ExcludeFocus(
              excluding: visible,
              child: ExcludeSemantics(excluding: visible, child: widget.child),
            ),
            if (visible) Positioned.fill(child: _overlay(context)),
          ],
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final c = widget.controller;
    final step = c.currentStep!;
    final theme = widget.theme;
    final scheme = Theme.of(context).colorScheme;
    final accent = theme.accentColor ?? scheme.primary;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : theme.animationDuration;
    final error = c.error != null;
    final target = _target;
    final details = IntroCardDetails(
      controller: c,
      step: step,
      theme: theme,
      allowSkip: widget.allowSkip,
      allowBack: widget.allowBack,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final media = MediaQuery.of(context);
        final margin = theme.screenPadding;
        // Reserve safe areas and keyboard space before clamping card placement.
        final leftBound = media.padding.left + margin;
        final rightBound = size.width - media.padding.right - margin;
        final topBound = media.padding.top + margin;
        final bottomBound =
            size.height -
            math.max(media.padding.bottom, media.viewInsets.bottom) -
            margin;
        final availableWidth = math.max(1.0, rightBound - leftBound);
        final width = math.min(theme.cardWidth, availableWidth);
        final availableHeight = math.max(1.0, bottomBound - topBound);
        final cardHeight = math.min(_cardSize.height, availableHeight);
        var below = true;
        if (target != null) {
          final belowRoom = bottomBound - target.bottom - theme.arrowGap;
          final aboveRoom = target.top - theme.arrowGap - topBound;
          below = switch (step.placement) {
            IntroPlacement.below => true,
            IntroPlacement.above => false,
            IntroPlacement.automatic =>
              belowRoom >= cardHeight || belowRoom >= aboveRoom,
          };
        }
        final x = target == null
            ? leftBound + (availableWidth - width) / 2
            : (target.center.dx - width / 2)
                  .clamp(leftBound, math.max(leftBound, rightBound - width))
                  .toDouble();
        final y = target == null || error
            ? topBound + (availableHeight - cardHeight) / 2
            : (below
                      ? target.bottom + theme.arrowGap
                      : target.top - theme.arrowGap - cardHeight)
                  .clamp(topBound, math.max(topBound, bottomBound - cardHeight))
                  .toDouble();
        final card = target == null || error
            ? _WaitingCard(
                controller: c,
                theme: theme,
                allowSkip: widget.allowSkip,
                error: error,
              )
            : widget.cardBuilder?.call(context, details) ??
                  IntroCoachCard(details: details);
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(
                  begin: target ?? Rect.zero,
                  end: target ?? Rect.zero,
                ),
                duration: duration,
                builder: (_, rect, _) => CustomPaint(
                  painter: _SpotlightPainter(
                    target: error || target == null
                        ? null
                        : rect?.inflate(step.targetPadding),
                    radius: step.targetRadius,
                    barrier: theme.barrierColor,
                    accent: accent,
                  ),
                ),
              ),
            ),
            // Painting and input blocking are separate: the transparent barrier
            // also protects the screen while a target is missing or loading.
            const ModalBarrier(
              dismissible: false,
              color: Colors.transparent,
              barrierSemanticsDismissible: false,
            ),
            // Spotlight taps use the tour action, never forward to the child.
            if (target != null && !error && step.advanceOnTargetTap)
              Positioned.fromRect(
                rect: target
                    .inflate(step.targetPadding)
                    .intersect(Offset.zero & size),
                child: Semantics(
                  button: true,
                  label: step.semanticLabel ?? step.title,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: c.isBusy ? null : c.next,
                  ),
                ),
              ),
            if (theme.showArrow && target != null && !error)
              IgnorePointer(
                child: CustomPaint(
                  painter: _ArrowPainter(
                    from: Offset(
                      target.center.dx.clamp(
                        x + math.min(24, width / 2),
                        x + width - math.min(24, width / 2),
                      ),
                      below ? y : y + cardHeight,
                    ),
                    to: Offset(
                      target.center.dx,
                      below
                          ? target.bottom + step.targetPadding
                          : target.top - step.targetPadding,
                    ),
                    color: accent,
                  ),
                ),
              ),
            // Long descriptions and large text remain reachable on short screens.
            AnimatedPositioned(
              duration: duration,
              curve: Curves.easeOutCubic,
              left: x,
              top: y,
              width: width,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: availableHeight),
                child: SingleChildScrollView(
                  child: SizedBox(
                    key: _cardKey,
                    child: Semantics(liveRegion: true, child: card),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Default card, also reusable inside custom card builders.
/// Default accessible coach card with progress and asynchronous playback controls.
class IntroCoachCard extends StatelessWidget {
  const IntroCoachCard({super.key, required this.details});
  final IntroCardDetails details;
  @override
  Widget build(BuildContext context) {
    final d = details;
    final t = d.theme;
    final scheme = Theme.of(context).colorScheme;
    final foreground = t.foregroundColor ?? scheme.onSurface;
    final accent = t.accentColor ?? scheme.primary;
    return Material(
      color: t.cardColor ?? scheme.surface,
      elevation: 12,
      borderRadius: BorderRadius.circular(t.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (t.showProgress) ...[
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${d.stepNumber} of ${d.stepCount}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: d.controller.progress,
                color: accent,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              d.step.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              d.step.description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: foreground, height: 1.5),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (d.allowSkip)
                  TextButton(onPressed: d.skip, child: Text(t.skipLabel)),
                if (d.allowBack && d.stepNumber > 1)
                  TextButton(
                    onPressed: d.isBusy ? null : d.back,
                    child: Text(t.backLabel),
                  ),
                FilledButton(
                  onPressed: d.isBusy ? null : d.next,
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  child: d.isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(d.isLastStep ? t.doneLabel : t.nextLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    required this.controller,
    required this.theme,
    required this.allowSkip,
    required this.error,
  });
  final IntroController controller;
  final IntroTheme theme;
  final bool allowSkip, error;
  @override
  Widget build(BuildContext context) => Material(
    color: theme.cardColor ?? Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(theme.cardRadius),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!error)
            const CircularProgressIndicator()
          else
            const Icon(Icons.info_outline),
          const SizedBox(height: 16),
          Text(
            error ? theme.errorLabel : theme.waitingLabel,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              if (allowSkip)
                TextButton(
                  onPressed: controller.skip,
                  child: Text(theme.skipLabel),
                ),
              if (error)
                FilledButton(
                  onPressed: controller.isBusy ? null : controller.retry,
                  child: Text(theme.retryLabel),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.target,
    required this.radius,
    required this.barrier,
    required this.accent,
  });
  final Rect? target;
  final double radius;
  final Color barrier, accent;
  @override
  void paint(Canvas canvas, Size size) {
    // Explicit parity keeps the spotlight transparent on both web and native
    // renderers, without relying on a boolean path operation's contour winding.
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (target != null) {
      final hole = RRect.fromRectAndRadius(target!, Radius.circular(radius));
      path.addRRect(hole);
      canvas.drawPath(path, Paint()..color = barrier);
      canvas.drawRRect(
        hole,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    } else {
      canvas.drawPath(path, Paint()..color = barrier);
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      target != old.target ||
      radius != old.radius ||
      barrier != old.barrier ||
      accent != old.accent;
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({
    required this.from,
    required this.to,
    required this.color,
  });
  final Offset from, to;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    // Suppress arrows when a very small viewport forces card/target overlap.
    if ((from - to).distance < 8 || (from.dy - to.dy).abs() > 80) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    final direction = (from - to).direction;
    for (final delta in [-.55, .55]) {
      canvas.drawLine(
        to,
        to +
            Offset(math.cos(direction + delta), math.sin(direction + delta)) *
                9,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      from != old.from || to != old.to || color != old.color;
}
