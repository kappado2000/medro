import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medro/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('aplicatia ignora textul aldin si marirea textului din telefon', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(boldText: true);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(const MedRoApp());
    await tester.pump();

    final context = tester.element(find.text('MedRO').first);
    final mq = MediaQuery.of(context);
    expect(mq.boldText, isFalse);
    expect(mq.textScaler.scale(10), 10);
  });

  testWidgets('micsorarea textului din telefon ramane respectata', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.textScaleFactorTestValue = 0.85;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(const MedRoApp());
    await tester.pump();

    final context = tester.element(find.text('MedRO').first);
    expect(MediaQuery.of(context).textScaler.scale(10), closeTo(8.5, 0.001));
  });
}
