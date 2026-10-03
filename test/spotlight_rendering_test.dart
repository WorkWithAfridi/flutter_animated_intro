import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_animated_intro/flutter_animated_intro.dart';

void main() {
  testWidgets(
    'spotlight preserves target pixels on initial and subsequent steps',
    (tester) async {
      final boundary = GlobalKey();
      final firstKey = GlobalKey();
      final secondKey = GlobalKey();
      const targetColor = Color(0xFFF06432);
      final controller = IntroController(
        tourId: 'spotlight-pixels',
        historyStore: MemoryIntroHistoryStore(),
        steps: [
          IntroStep(
            target: IntroAnchor.key(firstKey),
            title: 'First',
            description: 'First target',
          ),
          IntroStep(
            target: IntroAnchor.key(secondKey),
            title: 'Second',
            description: 'Second target',
          ),
        ],
      );
      Future<void> settleStep() async {
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 32));
        }
      }

      Future<List<int>> pixel(Offset position) async =>
          (await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final offset =
                (position.dy.floor() * image.width + position.dx.floor()) * 4;
            final result = [
              for (var i = 0; i < 4; i++) bytes!.getUint8(offset + i),
            ];
            image.dispose();
            return result;
          }))!;

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            home: IntroFlow(
              controller: controller,
              startDelay: Duration.zero,
              child: Scaffold(
                backgroundColor: Colors.white,
                body: Stack(
                  children: [
                    Positioned(
                      left: 40,
                      top: 40,
                      width: 100,
                      height: 60,
                      child: ColoredBox(key: firstKey, color: targetColor),
                    ),
                    Positioned(
                      right: 40,
                      top: 40,
                      width: 100,
                      height: 60,
                      child: ColoredBox(key: secondKey, color: targetColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await settleStep();
      final firstCenter = tester.getCenter(find.byKey(firstKey));
      final secondCenter = tester.getCenter(find.byKey(secondKey));
      expect(
        await pixel(firstCenter),
        [240, 100, 50, 255],
        reason: 'The active target must keep its original brightness.',
      );
      expect(
        (await pixel(const Offset(400, 500)))[0],
        lessThan(100),
        reason: 'The surrounding screen must remain dimmed.',
      );
      await controller.next();
      await settleStep();
      expect(
        await pixel(secondCenter),
        [240, 100, 50, 255],
        reason:
            'The new spotlight must also remain transparent after a transition.',
      );
      expect(
        (await pixel(firstCenter))[0],
        lessThan(100),
        reason: 'The previous target should be dimmed again.',
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
