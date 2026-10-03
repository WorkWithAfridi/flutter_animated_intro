import 'dart:async';
import 'package:flutter/widgets.dart';
import 'controller.dart';

/// Screen-level autoplay trigger for an IntroFlow mounted above the Navigator.
/// This widget does not render another overlay. It starts after the screen's
/// first frame and stops its tour when the screen leaves the widget tree.
class IntroAutoPlay extends StatefulWidget {
  const IntroAutoPlay({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
    this.delay = const Duration(milliseconds: 400),
    this.stopOnDispose = true,
  });

  /// Controller already attached to the enclosing/global IntroFlow.
  final IntroController controller;

  /// Screen whose mounting requests an automatic start.
  final Widget child;

  /// Whether to request autoplay and stop the run when this screen unmounts.
  final bool enabled, stopOnDispose;

  /// Delay after the first frame, allowing initial layout to settle.
  final Duration delay;
  @override
  State<IntroAutoPlay> createState() => _IntroAutoPlayState();
}

class _IntroAutoPlayState extends State<IntroAutoPlay> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    // Targets need mounted render objects before the controller can measure them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enabled) return;
      _timer = Timer(widget.delay, () {
        if (mounted && widget.enabled) {
          unawaited(widget.controller.start(force: false));
        }
      });
    });
  }

  @override
  void didUpdateWidget(IntroAutoPlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _timer?.cancel();
    if (widget.controller != oldWidget.controller ||
        (widget.enabled && !oldWidget.enabled)) {
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Defer listener notifications until widget-tree teardown has completed.
    if (widget.stopOnDispose) widget.controller.stop(deferNotification: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
