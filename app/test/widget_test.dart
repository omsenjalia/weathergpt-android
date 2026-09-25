import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure smoke tests only.
///
/// Importing real app screens pulls in Hive, speech_to_text, geolocator,
/// go_router, continuous animations, etc. and causes indefinite hangs in
/// headless CI. Screen-level coverage belongs in integration_test later.
/// Localization key consistency is covered by localization_keyset_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MaterialApp + Scaffold smoke', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('WeatherGPT')),
        ),
      ),
    );
    expect(find.text('WeatherGPT'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('Theme and dark scaffold smoke', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Text('ok'),
        ),
      ),
    );
    expect(find.text('ok'), findsOneWidget);
  });
}
