// Optional artifact renderer. Set INTRO_PREVIEW_FONT_DIR to Flutter's
// bin/cache/artifacts/material_fonts to render README previews with real fonts.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_animated_intro_flow/flutter_animated_intro_flow.dart';
import 'package:flutter_animated_intro_flow_example/main.dart';

void main() {
  final fonts = Platform.environment['INTRO_PREVIEW_FONT_DIR'];
  testWidgets('render desktop, tour, modal and mobile previews', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final loader = FontLoader('Roboto');
      for (final file in ['roboto-regular.ttf', 'roboto-bold.ttf']) {
        loader.addFont(
          File(
            '$fonts/$file',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      }
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        File(
          '$fonts/materialicons-regular.otf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
      await icons.load();
    });
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    final boundary = GlobalKey();
    Future<void> pump() async {
      for (var i = 0; i < 35; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }
    }

    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('../doc/images');
        await dir.create(recursive: true);
        await File(
          '${dir.path}/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    tester.view.physicalSize = const Size(1440, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: IntroDemoApp(
          historyStore: MemoryIntroHistoryStore(),
          autoPlay: false,
        ),
      ),
    );
    await pump();
    await capture('desktop');
    await tester.tap(find.text('Replay intro'));
    await pump();
    await capture('tour');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await pump();
    }
    await capture('modal');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: IntroDemoApp(historyStore: MemoryIntroHistoryStore()),
      ),
    );
    await pump();
    await capture('mobile');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    debugDisableShadows = true;
  }, skip: fonts == null);
}
