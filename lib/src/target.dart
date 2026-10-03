import 'package:flutter/material.dart';
import 'controller.dart';

/// Registers a real widget in its nearest flow. Explicit [controller] supports
/// targets in Navigator dialogs/sheets outside a screen-level flow's scope.
class IntroTarget extends StatefulWidget {
  const IntroTarget({
    super.key,
    required this.id,
    required this.child,
    this.controller,
  });
  final String id;
  final Widget child;
  final IntroController? controller;
  @override
  State<IntroTarget> createState() => _IntroTargetState();
}

class _IntroTargetState extends State<IntroTarget> {
  final _targetKey = GlobalKey();
  IntroController? _controller;
  String? _registeredId;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(IntroTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  void _register() {
    final next = widget.controller ?? IntroScope.of(context);
    if (identical(next, _controller) && _registeredId == widget.id) return;
    _unregister();
    next.registerTarget(widget.id, _targetKey);
    _controller = next;
    _registeredId = widget.id;
  }

  void _unregister() {
    if (_registeredId != null) {
      _controller?.unregisterTarget(_registeredId!, _targetKey);
    }
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _targetKey, child: widget.child);
}

class IntroScope extends InheritedWidget {
  const IntroScope({super.key, required this.controller, required super.child});
  final IntroController controller;
  static IntroController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<IntroScope>();
    if (scope == null) {
      throw FlutterError(
        'IntroTarget needs an IntroFlow ancestor or controller.',
      );
    }
    return scope.controller;
  }

  @override
  bool updateShouldNotify(IntroScope oldWidget) =>
      controller != oldWidget.controller;
}
