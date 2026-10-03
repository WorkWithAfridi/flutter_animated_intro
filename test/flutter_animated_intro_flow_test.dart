import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_animated_intro_flow/flutter_animated_intro_flow.dart';

IntroStep step(String id, {Future<IntroActionResult> Function()? action}) =>
    IntroStep(
      target: IntroAnchor.id(id),
      title: 'Title $id',
      description: 'Description $id',
      onNext: action,
    );

void main() {
  test('repeated skip invokes asynchronous cleanup once', () async {
    var calls = 0;
    final pending = Completer<void>();
    final c = IntroController(
      tourId: 'skip-once',
      steps: [step('a')],
      historyStore: MemoryIntroHistoryStore(),
      onSkipped: () {
        calls++;
        return pending.future;
      },
    );
    await c.start();
    final first = c.skip();
    await c.skip();
    expect(calls, 1);
    pending.complete();
    await first;
    expect(c.isActive, isFalse);
    c.dispose();
  });
  test(
    'once policy counts skipped runs and replay bypasses frequency',
    () async {
      final c = IntroController(
        tourId: 'once',
        steps: [step('a')],
        historyStore: MemoryIntroHistoryStore(),
      );
      expect(await c.start(force: false), isTrue);
      await c.skip();
      expect(c.history.completed, isFalse);
      expect(await c.start(force: false), isFalse);
      expect(await c.replay(), isTrue);
      await c.next();
      expect(c.history.completed, isTrue);
      expect(c.history.playCount, 2);
      c.dispose();
    },
  );
  test('frequency and durable history survive controller recreation', () async {
    final store = MemoryIntroHistoryStore();
    final c = IntroController(
      tourId: 'persistent',
      steps: [step('a')],
      historyStore: store,
    );
    await c.start();
    await c.complete();
    c.dispose();
    final next = IntroController(
      tourId: 'persistent',
      steps: [step('a')],
      historyStore: store,
    );
    expect(await next.start(force: false), isFalse);
    await next.resetHistory();
    expect(await next.start(force: false), isTrue);
    next.dispose();
  });
  test('cooldown and maximum automatic plays use injected clock', () async {
    var now = DateTime.utc(2026, 1, 1);
    final c = IntroController(
      tourId: 'cooldown',
      steps: [step('a')],
      historyStore: MemoryIntroHistoryStore(),
      policy: const IntroPlaybackPolicy(
        frequency: IntroFrequency.cooldown,
        cooldown: Duration(hours: 1),
        maxPlays: 2,
      ),
      clock: () => now,
    );
    await c.start(force: false);
    c.stop();
    expect(await c.start(force: false), isFalse);
    now = now.add(const Duration(hours: 1));
    expect(await c.start(force: false), isTrue);
    c.stop();
    now = now.add(const Duration(hours: 1));
    expect(await c.start(force: false), isFalse);
    c.dispose();
  });
  test('manual policy never autoplays; everyVisit repeats', () async {
    for (final frequency in [
      IntroFrequency.manual,
      IntroFrequency.everyVisit,
    ]) {
      final c = IntroController(
        tourId: frequency.name,
        steps: [step('a')],
        historyStore: MemoryIntroHistoryStore(),
        policy: IntroPlaybackPolicy(frequency: frequency),
      );
      expect(
        await c.start(force: false),
        frequency == IntroFrequency.everyVisit,
      );
      c.stop();
      expect(await c.start(), isTrue);
      await c.complete();
      expect(
        await c.start(force: false),
        frequency == IntroFrequency.everyVisit,
      );
      c.dispose();
    }
  });
  test(
    'session frequency survives new controller even with separate storage',
    () async {
      IntroController create() => IntroController(
        tourId: 'session-test',
        steps: [step('a')],
        historyStore: MemoryIntroHistoryStore(),
        policy: const IntroPlaybackPolicy(
          frequency: IntroFrequency.oncePerSession,
        ),
      );
      final c = create();
      await c.start();
      c.stop();
      c.dispose();
      final next = create();
      expect(await next.start(force: false), isFalse);
      await next.resetHistory();
      expect(await next.start(force: false), isTrue);
      next.dispose();
    },
  );
  test(
    'cancelled action stays; duplicate next cannot run concurrently',
    () async {
      var calls = 0;
      final pending = Completer<IntroActionResult>();
      final c = IntroController(
        tourId: 'actions',
        steps: [
          step(
            'a',
            action: () {
              calls++;
              return pending.future;
            },
          ),
          step('b'),
        ],
        historyStore: MemoryIntroHistoryStore(),
      );
      await c.start();
      final first = c.next();
      await c.next();
      expect(calls, 1);
      pending.complete(IntroActionResult.stay);
      await first;
      expect(c.currentIndex, 0);
      expect(c.isBusy, isFalse);
      c.dispose();
    },
  );
  test('skip invalidates a pending action', () async {
    final pending = Completer<IntroActionResult>();
    final c = IntroController(
      tourId: 'cancel',
      steps: [
        step('a', action: () => pending.future),
        step('b'),
      ],
      historyStore: MemoryIntroHistoryStore(),
    );
    await c.start();
    final action = c.next();
    await c.skip();
    pending.complete(IntroActionResult.advance);
    await action;
    expect(c.isActive, isFalse);
    expect(c.currentIndex, 0);
    c.dispose();
  });
  test(
    'onEnter prepares jumps; pause blocks advancement and resume re-enters',
    () async {
      var enters = 0;
      final c = IntroController(
        tourId: 'navigation',
        steps: [
          step('a'),
          IntroStep(
            target: const IntroAnchor.id('b'),
            title: 'B',
            description: 'B',
            onEnter: () async {
              enters++;
            },
          ),
        ],
        historyStore: MemoryIntroHistoryStore(),
      );
      await c.start();
      await c.goTo(1);
      expect(enters, 1);
      c.pause();
      await c.next();
      expect(c.isActive, isTrue);
      await c.resume();
      expect(enters, 2);
      await c.previous();
      expect(c.currentIndex, 0);
      c.dispose();
    },
  );
  test('missing targets can skip or report error and retry', () async {
    var found = false;
    final c = IntroController(
      tourId: 'missing',
      steps: [step('a')],
      historyStore: MemoryIntroHistoryStore(),
    );
    final host = Object();
    c.attach(host, (_) async => found);
    expect(await c.start(), isFalse);
    expect(c.error, isA<TimeoutException>());
    expect(c.isActive, isTrue);
    found = true;
    await c.retry();
    expect(c.error, isNull);
    c.detach(host);
    c.dispose();
    final skip = IntroController(
      tourId: 'missing-skip',
      steps: [
        const IntroStep(
          target: IntroAnchor.id('a'),
          title: 'A',
          description: 'A',
          missingTargetBehavior: IntroMissingTargetBehavior.skip,
        ),
        step('b'),
      ],
      historyStore: MemoryIntroHistoryStore(),
    );
    skip.attach(host, (step) async => step.target.id == 'b');
    await skip.start();
    expect(skip.currentIndex, 1);
    skip.detach(host);
    skip.dispose();
  });
  test('errors from actions are recoverable and reported', () async {
    var fail = true;
    Object? reported;
    final c = IntroController(
      tourId: 'error',
      steps: [
        step(
          'a',
          action: () async {
            if (fail) throw StateError('Action failed');
            return IntroActionResult.advance;
          },
        ),
      ],
      historyStore: MemoryIntroHistoryStore(),
      onError: (error, _) => reported = error,
    );
    await c.start();
    await c.next();
    expect(reported, isA<StateError>());
    expect(c.isActive, isTrue);
    fail = false;
    await c.next();
    expect(c.isActive, isFalse);
    c.dispose();
  });
  test('history JSON round trips timestamps and completion', () {
    final h = IntroHistory(
      playCount: 3,
      lastPlayedAt: DateTime.utc(2026),
      completed: true,
    );
    final restored = IntroHistory.fromJson(h.toJson());
    expect(restored.playCount, 3);
    expect(restored.lastPlayedAt, h.lastPlayedAt);
    expect(restored.completed, isTrue);
  });
  test(
    'duplicate IDs are rejected and disposed controller ignores pending start',
    () async {
      final pending = Completer<IntroHistory?>();
      final c = IntroController(
        tourId: 'disposed',
        steps: [step('a')],
        historyStore: CallbackIntroHistoryStore(
          onRead: (_) => pending.future,
          onWrite: (_, _) async {},
          onDelete: (_) async {},
        ),
      );
      c.registerTarget('a', GlobalKey());
      expect(() => c.registerTarget('a', GlobalKey()), throwsFlutterError);
      final start = c.start();
      c.dispose();
      pending.complete(null);
      expect(await start, isFalse);
    },
  );
}
