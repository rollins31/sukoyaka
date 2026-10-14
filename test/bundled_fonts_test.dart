import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukoyaka/main.dart';

/// The release app never fetches fonts at runtime, so a GoogleFonts weight
/// with no matching file in assets/google_fonts/ silently renders in a
/// fallback font. This walks every tab, entry form, and Settings screen with
/// fetching disabled; google_fonts fails the test for any missing file.
///
/// Note: `flutter test` caches assets in build/unit_test_assets, so after
/// *removing* a font file, delete that folder before trusting a pass.
void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({
      'feeding_entries': '[{"id":1,"time":"2026-10-01T09:00:00.000","milkType":"Bottle","notes":"n"}]',
      'diaper_entries': '[{"id":1,"time":"2026-10-01T09:00:00.000","pee":true,"poo":false,"notes":"n"}]',
      'sleep_entries': '[{"id":1,"start":"2026-10-01T09:00:00.000","end":"2026-10-01T10:00:00.000","notes":"n"}]',
      'growth_entries': '[{"id":1,"time":"2026-10-01T09:00:00.000","weight":6.5,"weightUnit":"kg"}]',
    });
  });

  testWidgets('every font the app uses is bundled', (tester) async {
    // Font loads do real asset I/O, which only progresses when the fake
    // clock is pumped between real-time waits.
    Future<void> settleFonts() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
    }

    Future<void> tap(Finder finder) async {
      await tester.tap(finder.first);
      await tester.pumpAndSettle();
      await settleFonts();
    }

    Finder tab(String label) =>
        find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

    await tester.pumpWidget(const MainApp());
    await tester.pumpAndSettle();
    await settleFonts();

    for (final label in ['Feedings', 'Sleep', 'Diapers', 'Growth']) {
      await tap(tab(label));
      await tap(find.byType(FloatingActionButton));
      await tap(find.text('Cancel'));
    }
    await tap(tab('Home'));

    await tap(find.byTooltip('Settings'));
    await tap(find.text('Customize home page'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Privacy Policy'), 200);
    await tap(find.text('Privacy Policy'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap(find.text('Open-source licenses'));
  });
}
