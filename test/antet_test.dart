import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medro/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // iPhone-uri de la cel mai ingust la cel mai lat, in puncte logice
  for (final latime in [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('subtitlul din antet incape pe un rand la latimea $latime', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(latime * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MedRoApp());
      // incarcarea nomenclatorului din asset
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pump();

      final subtitlu = find.textContaining('medicamente ·');
      expect(subtitlu, findsOneWidget);
      final text = tester.widget<Text>(subtitlu);
      expect(text.maxLines, 1);
      // un singur rand de 13 pt are sub 20 de puncte inaltime, chiar si micsorat
      expect(tester.getSize(subtitlu).height, lessThan(20));
      // si nu iese din ecran
      expect(tester.getRect(subtitlu).right, lessThanOrEqualTo(latime));
    });
  }
}
