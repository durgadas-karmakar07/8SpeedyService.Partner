// Renders screens to PNG in CI (flutter test test_preview --update-goldens)
// so the design can be checked without a phone. Not part of `flutter test`.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadPreviewFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    var added = false;
    for (final a in assets) {
      try {
        loader.addFont(rootBundle.load(a));
        added = true;
      } catch (_) {}
    }
    if (added) {
      try {
        await loader.load();
      } catch (_) {}
    }
  }

  await load('Poppins', <String>[
    'assets/fonts/Poppins-Regular.ttf',
    'assets/fonts/Poppins-Medium.ttf',
    'assets/fonts/Poppins-Bold.ttf',
  ]);
  await load('MaterialIcons', <String>['fonts/MaterialIcons-Regular.otf']);
  await load('packages/material_ui/MaterialIcons', <String>['fonts/MaterialIcons-Regular.otf']);
}

void phoneSurface(WidgetTester tester, {double width = 412, double height = 892}) {
  tester.view.physicalSize = Size(width * 2.5, height * 2.5);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}
