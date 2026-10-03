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
  final IntroController controller;
  final Widget child;
  final bool enabled, stopOnDispose;
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
    if (widget.stopOnDispose) widget.controller.stop(deferNotification: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
