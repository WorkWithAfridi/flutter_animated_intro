import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_animated_intro_flow/flutter_animated_intro_flow.dart';
import 'package:flutter_animated_intro_flow_example/main.dart';
import 'package:flutter_animated_intro_flow_example/preferences_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> frames(WidgetTester tester, [int count = 30]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 32));
  }
}

void main() {
  testWidgets('mobile walkthrough completes all five steps including modal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryIntroHistoryStore();
    await tester.pumpWidget(IntroDemoApp(historyStore: store));
    await frames(tester);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Next'));
      await frames(tester);
    }
    await tester.tap(find.text('Done'));
    await frames(tester);
    expect((await store.read('bloom-store-v1'))?.completed, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'walkthrough performs real cart action, follows modal and completes',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryIntroHistoryStore();
      await tester.pumpWidget(IntroDemoApp(historyStore: store));
      await frames(tester);
      expect(find.text('Welcome to Bloom'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await frames(tester);
      expect(find.text('Bring a little green home'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await frames(tester);
      expect(find.text('Your bag (1)'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await frames(tester);
      expect(find.text('Works inside a bottom sheet'), findsOneWidget);
      expect(find.text('Your little green corner'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await frames(tester);
      expect(find.text('A little inspiration'), findsOneWidget);
      expect(find.text('Your little green corner'), findsNothing);
      await tester.tap(find.text('Done'));
      await frames(tester);
      expect((await store.read('bloom-store-v1'))?.completed, isTrue);
      expect(
        find.text('Tour complete. Make yourself at home.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('responsive mobile store renders and skip releases interaction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      IntroDemoApp(historyStore: MemoryIntroHistoryStore()),
    );
    await frames(tester);
    expect(find.text('Welcome to Bloom'), findsOneWidget);
    await tester.tap(find.text('Skip tour'));
    await frames(tester);
    expect(find.text('Welcome to Bloom'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'once policy prevents autoplay on reopening; replay remains available',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        IntroDemoApp(historyStore: MemoryIntroHistoryStore()),
      );
      await frames(tester);
      await tester.tap(find.text('Skip tour'));
      await frames(tester);
      await tester.tap(find.text('Reopen screen'));
      await frames(tester);
      expect(find.text('Welcome to Bloom'), findsNothing);
      await tester.tap(find.text('Replay intro'));
      await frames(tester);
      expect(find.text('Welcome to Bloom'), findsOneWidget);
      await tester.tap(find.text('Skip tour'));
      await frames(tester);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('preferences adapter preserves history and deletes it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PreferencesHistoryStore(prefs);
    final h = IntroHistory(
      playCount: 2,
      lastPlayedAt: DateTime.utc(2026),
      completed: true,
    );
    await store.write('test', h);
    expect((await PreferencesHistoryStore(prefs).read('test'))?.playCount, 2);
    expect(
      jsonDecode(prefs.getString('intro_flow_demo.test')!)['completed'],
      isTrue,
    );
    await store.delete('test');
    expect(await store.read('test'), isNull);
  });
}
