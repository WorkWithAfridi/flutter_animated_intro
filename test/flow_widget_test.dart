import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_animated_intro/flutter_animated_intro.dart';

Future<void> frames(WidgetTester tester, [int count = 15]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 32));
  }
}

void main() {
  testWidgets('route observer pauses covered screen and resumes on return', (
    tester,
  ) async {
    final observer = RouteObserver<ModalRoute<dynamic>>();
    final navigator = GlobalKey<NavigatorState>();
    final c = IntroController(
      tourId: 'routes',
      steps: [
        const IntroStep(
          target: IntroAnchor.id('a'),
          title: 'A',
          description: 'A',
        ),
      ],
      historyStore: MemoryIntroHistoryStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: IntroFlow(
          controller: c,
          routeObserver: observer,
          startDelay: Duration.zero,
          child: const Scaffold(
            body: IntroTarget(id: 'a', child: Text('Target')),
          ),
        ),
      ),
    );
    await frames(tester);
    expect(c.isActive, isTrue);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other screen')),
      ),
    );
    await frames(tester);
    expect(c.isPaused, isTrue);
    navigator.currentState!.pop();
    await frames(tester);
    expect(c.isPaused, isFalse);
    expect(c.currentIndex, 0);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('scrolls an existing offscreen key into view', (tester) async {
    final target = GlobalKey();
    final scroll = ScrollController();
    final c = IntroController(
      tourId: 'scroll',
      steps: [
        IntroStep(
          target: IntroAnchor.key(target),
          title: 'Scrolled target',
          description: 'Below the fold',
        ),
      ],
      historyStore: MemoryIntroHistoryStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: IntroFlow(
          controller: c,
          startDelay: Duration.zero,
          child: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  const SizedBox(height: 1000),
                  Text('Offscreen', key: target),
                  const SizedBox(height: 400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await frames(tester, 30);
    expect(scroll.offset, greaterThan(0));
    expect(find.text('Scrolled target'), findsOneWidget);
    expect(c.error, isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    scroll.dispose();
  });
  testWidgets('remounting targets releases old IDs before disposal', (
    tester,
  ) async {
    final c = IntroController(
      tourId: 'remount',
      steps: [
        const IntroStep(
          target: IntroAnchor.id('a'),
          title: 'A',
          description: 'A',
        ),
      ],
      historyStore: MemoryIntroHistoryStore(),
    );
    Widget screen(int visit) => MaterialApp(
      home: IntroFlow(
        controller: c,
        autoPlay: false,
        child: KeyedSubtree(
          key: ValueKey(visit),
          child: const Scaffold(
            body: IntroTarget(id: 'a', child: Text('Target')),
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen(0));
    await tester.pumpWidget(screen(1));
    expect(tester.takeException(), isNull);
    expect(c.keyFor(const IntroAnchor.id('a'))?.currentContext, isNotNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('screen trigger stops without notifying during disposal', (
    tester,
  ) async {
    final c = IntroController(
      tourId: 'trigger',
      steps: [
        const IntroStep(
          target: IntroAnchor.id('a'),
          title: 'A',
          description: 'A',
        ),
      ],
      historyStore: MemoryIntroHistoryStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: IntroFlow(
          controller: c,
          autoPlay: false,
          child: IntroAutoPlay(
            controller: c,
            delay: Duration.zero,
            child: const Scaffold(
              body: IntroTarget(id: 'a', child: Text('Target')),
            ),
          ),
        ),
      ),
    );
    await frames(tester);
    expect(c.isActive, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(c.isActive, isFalse);
    expect(tester.takeException(), isNull);
    c.dispose();
  });
  testWidgets(
    'offstage target waits instead of highlighting invisible content',
    (tester) async {
      final c = IntroController(
        tourId: 'offstage',
        steps: [
          const IntroStep(
            target: IntroAnchor.id('a'),
            title: 'A',
            description: 'A',
          ),
        ],
        historyStore: MemoryIntroHistoryStore(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: IntroFlow(
            controller: c,
            startDelay: Duration.zero,
            targetWaitTimeout: const Duration(milliseconds: 64),
            child: const Scaffold(
              body: Offstage(
                child: IntroTarget(id: 'a', child: Text('Invisible')),
              ),
            ),
          ),
        ),
      );
      await frames(tester);
      expect(c.error, isNotNull);
      expect(find.text('Retry'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'lifecycle hidden then paused resumes without losing pause ownership',
    (tester) async {
      final c = IntroController(
        tourId: 'lifecycle',
        steps: [
          const IntroStep(
            target: IntroAnchor.id('a'),
            title: 'A',
            description: 'A',
          ),
        ],
        historyStore: MemoryIntroHistoryStore(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: IntroFlow(
            controller: c,
            startDelay: Duration.zero,
            child: const Scaffold(
              body: IntroTarget(id: 'a', child: Text('Target')),
            ),
          ),
        ),
      );
      await frames(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(c.isPaused, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await frames(tester);
      expect(c.isPaused, isFalse);
      c.pause();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await frames(tester);
      expect(c.isPaused, isTrue);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'autoplays wrapped target and proxies a single action; barrier blocks background',
    (tester) async {
      var actions = 0, background = 0;
      final c = IntroController(
        tourId: 'widget-wrap',
        steps: [
          IntroStep(
            target: const IntroAnchor.id('button'),
            title: 'Try adding',
            description: 'Real action',
            onNext: () async {
              actions++;
              return IntroActionResult.advance;
            },
          ),
        ],
        historyStore: MemoryIntroHistoryStore(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: IntroFlow(
            controller: c,
            startDelay: Duration.zero,
            child: Scaffold(
              body: Column(
                children: [
                  IntroTarget(
                    id: 'button',
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text('Add product'),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => background++,
                    child: const Text('Background'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await frames(tester);
      expect(find.text('Try adding'), findsOneWidget);
      await tester.tap(find.text('Background'), warnIfMissed: false);
      expect(background, 0);
      await tester.tapAt(tester.getCenter(find.text('Add product')));
      await frames(tester);
      expect(actions, 1);
      expect(c.isActive, isFalse);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'supports provided keys and supplied widgets, back and completion',
    (tester) async {
      final key = GlobalKey();
      final supplied = IntroStep.widget(
        id: 'supplied',
        widget: const Text('Supplied widget'),
        title: 'Second',
        description: 'Widget API',
      );
      final c = IntroController(
        tourId: 'widget-key',
        steps: [
          IntroStep(
            target: IntroAnchor.key(key),
            title: 'First',
            description: 'Key API',
          ),
          supplied,
        ],
        historyStore: MemoryIntroHistoryStore(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: IntroFlow(
            controller: c,
            startDelay: Duration.zero,
            child: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Existing key', key: key),
                    supplied.targetWidget,
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await frames(tester);
      expect(find.text('First'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await frames(tester);
      expect(find.text('Second'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await frames(tester);
      expect(c.currentIndex, 0);
      await c.goTo(1);
      await frames(tester);
      await tester.tap(find.text('Done'));
      await frames(tester);
      expect(c.history.completed, isTrue);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('missing target blocks input, exposes retry and skip', (
    tester,
  ) async {
    final c = IntroController(
      tourId: 'widget-missing',
      steps: [
        const IntroStep(
          target: IntroAnchor.id('absent'),
          title: 'Missing',
          description: 'Waiting',
        ),
      ],
      historyStore: MemoryIntroHistoryStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: IntroFlow(
          controller: c,
          startDelay: Duration.zero,
          targetWaitTimeout: const Duration(milliseconds: 64),
          child: const Scaffold(body: Text('Underlying')),
        ),
      ),
    );
    await frames(tester);
    expect(c.error, isNotNull);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(ModalBarrier), findsWidgets);
    await tester.tap(find.text('Skip tour'));
    await frames(tester);
    expect(c.isActive, isFalse);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'custom builder and long copy fit small viewport at large text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = IntroController(
        tourId: 'widget-small',
        steps: [
          IntroStep(
            target: const IntroAnchor.id('a'),
            title: 'A long localized heading for a small screen',
            description: List.filled(
              20,
              'Detailed localized explanation.',
            ).join(' '),
          ),
        ],
        historyStore: MemoryIntroHistoryStore(),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: IntroFlow(
            controller: c,
            startDelay: Duration.zero,
            cardBuilder: (_, details) => IntroCoachCard(details: details),
            child: const Scaffold(
              body: Center(
                child: IntroTarget(id: 'a', child: Text('Target')),
              ),
            ),
          ),
        ),
      );
      await frames(tester);
      expect(tester.takeException(), isNull);
      c.stop();
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
