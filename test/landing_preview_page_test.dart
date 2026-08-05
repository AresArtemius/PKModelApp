import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modelapp/features/landing/landing_preview_page.dart';

void main() {
  Future<void> pumpLanding(WidgetTester tester, {required Size size}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: LandingPreviewPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('landing preview renders on desktop', (tester) async {
    await pumpLanding(tester, size: const Size(1280, 720));

    expect(find.text('ТАЛАНТЫ. КАСТИНГИ. НОВЫЕ ВОЗМОЖНОСТИ.'), findsOneWidget);
    expect(find.text('PK MANAGEMENT'), findsOneWidget);
  });

  testWidgets('landing preview renders on mobile', (tester) async {
    await pumpLanding(tester, size: const Size(390, 844));

    expect(find.text('СОЗДАТЬ АНКЕТУ'), findsOneWidget);
    expect(find.text('РАЗМЕСТИТЬ КАСТИНГ'), findsOneWidget);
  });
}
