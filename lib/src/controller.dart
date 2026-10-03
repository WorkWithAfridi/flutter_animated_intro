import 'dart:async';
import 'package:flutter/material.dart';
import 'history.dart';
import 'models.dart';

/// Observable playback and asynchronous sequencing, independent of state managers.
/// The owner disposes the controller after its flow is removed.
class IntroController extends ChangeNotifier {
  IntroController({
    required this.tourId,
    required List<IntroStep> steps,
    this.policy = const IntroPlaybackPolicy(),
    IntroHistoryStore? historyStore,
    this.onStarted,
    this.onCompleted,
    this.onSkipped,
    this.onStepChanged,
    this.onError,
    DateTime Function()? clock,
  }) : steps = List.unmodifiable(steps),
       historyStore = historyStore ?? MemoryIntroHistoryStore.shared,
       _clock = clock ?? DateTime.now {
    if (tourId.isEmpty || steps.isEmpty) {
      throw ArgumentError(
        'A nonempty tourId and at least one step are required.',
      );
    }
    if (policy.cooldown.isNegative) {
      throw ArgumentError('cooldown cannot be negative.');
    }
  }

  /// Stable history key; change the ID when introducing a new tour version.
  final String tourId;

  /// Immutable ordered steps for this controller.
  final List<IntroStep> steps;

  /// Eligibility rules for automatic starts, including the optional play limit.
  final IntroPlaybackPolicy policy;

  /// Storage owned by the host; defaults to process-local memory.
  final IntroHistoryStore historyStore;

  /// Awaited lifecycle hooks; completion/skip cleanup precedes the final save.
  final Future<void> Function()? onStarted, onCompleted, onSkipped;

  /// Called before onEnter whenever a step is entered, including retry/resume.
  final void Function(int index, IntroStep step)? onStepChanged;

  /// Reports errors from playback, target preparation, and lifecycle hooks.
  final void Function(Object error, StackTrace stackTrace)? onError;
  final DateTime Function() _clock;
  // Session eligibility is shared across controller replacements for the same ID.
  static final Set<String> _sessionPlayed = {};
  final Map<String, GlobalKey> _targets = {};
  Future<bool> Function(IntroStep)? _prepareTarget;
  Object? _host;
  bool _active = false, _paused = false, _busy = false, _disposed = false;
  // Async operations capture a generation. Stop/pause/skip invalidate their
  // results without claiming to cancel side effects in host callbacks.
  int _index = 0, _generation = 0;
  int? _finishingGeneration;
  Object? _error;
  IntroHistory _history = const IntroHistory();

  /// Whether a run exists, including while it is paused.
  bool get isActive => _active;

  /// Whether the active run is hidden and the underlying screen is unlocked.
  bool get isPaused => _paused;

  /// Whether preparation, an action, or storage operation is in progress.
  bool get isBusy => _busy;

  /// Zero-based current step index.
  int get currentIndex => _index;

  /// Active step, or null when no run is active.
  IntroStep? get currentStep => _active ? steps[_index] : null;

  /// Whether the current index points to the final configured step.
  bool get isLastStep => _index == steps.length - 1;

  /// Most recent recoverable playback error, cleared by a new action.
  Object? get error => _error;

  /// Last loaded or successfully persisted history snapshot.
  IntroHistory get history => _history;

  /// One-based step progress from zero to one; zero when inactive.
  double get progress => _active ? (_index + 1) / steps.length : 0;

  /// Infrastructure registration; IDs must be unique among mounted targets.
  void registerTarget(String id, GlobalKey key) {
    if (_targets[id] != null && !identical(_targets[id], key)) {
      throw FlutterError('Duplicate IntroTarget ID "$id" in tour "$tourId".');
    }
    _targets[id] = key;
  }

  /// Removes a registration only when the key still belongs to that target.
  void unregisterTarget(String id, GlobalKey key) {
    if (identical(_targets[id], key)) _targets.remove(id);
  }

  /// Resolves an explicit key or a currently registered target ID.
  GlobalKey? keyFor(IntroAnchor anchor) => anchor.key ?? _targets[anchor.id];

  /// Infrastructure hook used by IntroFlow. One controller supports one host.
  void attach(Object host, Future<bool> Function(IntroStep) prepareTarget) {
    if (_host != null && !identical(_host, host)) {
      throw StateError('One IntroController cannot drive two mounted flows.');
    }
    _host = host;
    _prepareTarget = prepareTarget;
  }

  /// Detaches only the matching host and stops its run without lifecycle hooks.
  void detach(Object host) {
    if (!identical(_host, host)) return;
    stop(deferNotification: true);
    _host = null;
    _prepareTarget = null;
  }

  bool _valid(int generation) => !_disposed && generation == _generation;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _fail(Object error, StackTrace stack) {
    _error = error;
    _emit();
    onError?.call(error, stack);
  }

  /// Manual start bypasses frequency by default. Automatic hosts use force:false.
  Future<bool> start({bool force = true, int initialStep = 0}) async {
    if (_disposed || _busy || _active) return false;
    RangeError.checkValidIndex(initialStep, steps, 'initialStep');
    _busy = true;
    _error = null;
    final generation = ++_generation;
    _emit();
    try {
      final loaded = await historyStore.read(tourId) ?? const IntroHistory();
      if (!_valid(generation)) return false;
      _history = loaded;
      final now = _clock();
      if (!force && !_eligible(now)) return false;
      final started = IntroHistory(
        playCount: _history.playCount + 1,
        lastPlayedAt: now,
        completed: _history.completed,
      );
      // Record the start before revealing the overlay: skipped runs also count.
      await historyStore.write(tourId, started);
      if (!_valid(generation)) return false;
      _history = started;
      _sessionPlayed.add(tourId);
      _active = true;
      _paused = false;
      _index = initialStep;
      _emit();
      await onStarted?.call();
      if (!_valid(generation)) return false;
      await _enter(generation);
      return _valid(generation) && _active;
    } catch (error, stack) {
      if (_valid(generation)) _fail(error, stack);
      return false;
    } finally {
      if (_valid(generation)) {
        _busy = false;
        _emit();
      }
    }
  }

  bool _eligible(DateTime now) {
    if (policy.maxPlays != null && _history.playCount >= policy.maxPlays!) {
      return false;
    }
    return switch (policy.frequency) {
      IntroFrequency.manual => false,
      IntroFrequency.once => _history.playCount == 0,
      IntroFrequency.oncePerSession => !_sessionPlayed.contains(tourId),
      IntroFrequency.everyVisit => true,
      IntroFrequency.cooldown =>
        _history.lastPlayedAt == null ||
            now.difference(_history.lastPlayedAt!) >= policy.cooldown,
    };
  }

  Future<void> _enter(int generation) async {
    while (_valid(generation) && _active) {
      final step = steps[_index];
      onStepChanged?.call(_index, step);
      await step.onEnter?.call();
      if (!_valid(generation)) return;
      final prepare = _prepareTarget;
      final found = prepare == null ? true : await prepare(step);
      if (!_valid(generation)) return;
      if (found) return;
      if (step.missingTargetBehavior == IntroMissingTargetBehavior.wait) {
        throw TimeoutException(
          'Target for step $_index of "$tourId" is unavailable.',
        );
      }
      if (isLastStep) {
        await _finish(generation, skipped: false);
        return;
      }
      _index++;
      _emit();
    }
  }

  // Serialize normal controls so rapid taps cannot execute an action twice.
  Future<void> _run(Future<void> Function(int) action) async {
    if (_disposed || !_active || _paused || _busy) return;
    _busy = true;
    _error = null;
    final generation = ++_generation;
    _emit();
    try {
      await action(generation);
    } catch (error, stack) {
      if (_valid(generation)) _fail(error, stack);
    } finally {
      if (_valid(generation)) {
        _busy = false;
        _emit();
      }
    }
  }

  /// Runs onNext, then advances or completes unless the action returns stay.
  Future<void> next() => _run((generation) async {
    final result =
        await steps[_index].onNext?.call() ?? IntroActionResult.advance;
    if (!_valid(generation) || result == IntroActionResult.stay) return;
    if (isLastStep) {
      await _finish(generation, skipped: false);
    } else {
      _index++;
      _emit();
      await _enter(generation);
    }
  });

  /// Jump without executing onNext. onEnter prepares the destination.
  Future<void> goTo(int index) {
    RangeError.checkValidIndex(index, steps, 'index');
    return _run((generation) async {
      _index = index;
      _emit();
      await _enter(generation);
    });
  }

  /// Enters the preceding step without running the current step's onNext.
  Future<void> previous() => _index > 0 ? goTo(_index - 1) : Future.value();

  /// Re-runs onEnter and target preparation for the current step.
  Future<void> retry() => _run(_enter);

  /// Finishes directly, awaiting completion cleanup and recording success.
  Future<void> complete() =>
      _run((generation) => _finish(generation, skipped: false));

  /// Skip while a target/action is pending. Stale results cannot advance the tour;
  /// host actions themselves cannot be cancelled and must manage their own state.
  Future<void> skip() async {
    if (_disposed || !_active || _finishingGeneration == _generation) return;
    final generation = ++_generation;
    _busy = true;
    _paused = false;
    _error = null;
    _emit();
    try {
      await _finish(generation, skipped: true);
    } catch (error, stack) {
      if (_valid(generation)) _fail(error, stack);
    } finally {
      if (_valid(generation)) {
        _busy = false;
        _emit();
      }
    }
  }

  Future<void> _finish(int generation, {required bool skipped}) async {
    _finishingGeneration = generation;
    try {
      await (skipped ? onSkipped?.call() : onCompleted?.call());
      if (!_valid(generation)) return;
      final finished = IntroHistory(
        playCount: _history.playCount,
        lastPlayedAt: _history.lastPlayedAt,
        completed: _history.completed || !skipped,
      );
      await historyStore.write(tourId, finished);
      if (!_valid(generation)) return;
      _history = finished;
      _active = false;
      _emit();
    } finally {
      if (_finishingGeneration == generation) _finishingGeneration = null;
    }
  }

  /// Hides the overlay and invalidates pending results, preserving the step.
  void pause() {
    if (!_active || _paused) return;
    ++_generation;
    _paused = true;
    _busy = false;
    _emit();
  }

  /// Reveals the run and prepares its current step again.
  Future<void> resume() async {
    if (!_active || !_paused) return;
    _paused = false;
    _emit();
    await retry();
  }

  /// Hide without completion/skip callbacks. The started run remains recorded.
  /// Hosts defer notification when stopping during widget-tree disposal.
  void stop({bool deferNotification = false}) {
    ++_generation;
    _active = false;
    _paused = false;
    _busy = false;
    _error = null;
    if (deferNotification) {
      scheduleMicrotask(_emit);
    } else {
      _emit();
    }
  }

  /// Starts a fresh run and deliberately bypasses automatic playback rules.
  Future<bool> replay({int initialStep = 0}) async {
    stop();
    return start(initialStep: initialStep);
  }

  /// Clears persisted and session history; stop the tour before calling.
  /// Storage failures propagate to the caller.
  Future<void> resetHistory() async {
    if (_active || _busy) {
      throw StateError('Stop the tour before resetting history.');
    }
    if (_disposed) return;
    final generation = ++_generation;
    _busy = true;
    _emit();
    try {
      await historyStore.delete(tourId);
      if (!_valid(generation)) return;
      _sessionPlayed.remove(tourId);
      _history = const IntroHistory();
    } finally {
      if (_valid(generation)) {
        _busy = false;
        _emit();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _targets.clear();
    _host = null;
    _prepareTarget = null;
    super.dispose();
  }
}
