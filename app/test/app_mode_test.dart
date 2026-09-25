import 'package:flutter_test/flutter_test.dart';
import 'package:weathergpt_mobile/core/models/app_mode.dart';

void main() {
  group('appModeFromName', () {
    test('recognises the three supported modes, case- and space-insensitively',
        () {
      expect(appModeFromName('everyone'), AppMode.everyone);
      expect(appModeFromName('farmer'), AppMode.farmer);
      expect(appModeFromName('researcher'), AppMode.researcher);
      expect(appModeFromName(' Researcher '), AppMode.researcher);
      expect(appModeFromName('FARMER'), AppMode.farmer);
    });

    test('returns null rather than guessing for unknown values', () {
      expect(appModeFromName('admin'), isNull);
      expect(appModeFromName(''), isNull);
      expect(appModeFromName('   '), isNull);
      expect(appModeFromName(null), isNull);
      expect(appModeFromName(3), isNull);
    });

    test('wire names round-trip', () {
      for (final mode in AppMode.values) {
        expect(appModeFromName(mode.wire), mode);
      }
      expect(AppMode.everyone.wire, 'everyone');
      expect(AppMode.farmer.wire, 'farmer');
      expect(AppMode.researcher.wire, 'researcher');
    });
  });

  group('resolveAppMode', () {
    test('an explicit mode is authoritative over the legacy boolean', () {
      // A researcher session must not be downgraded to farmer by a stale flag.
      expect(
          resolveAppMode(mode: 'researcher', legacyFarmerMode: true),
          AppMode.researcher);
      expect(resolveAppMode(mode: 'everyone', legacyFarmerMode: true),
          AppMode.everyone);
    });

    test('legacy farmer_mode maps to farmer, anything else to everyone', () {
      expect(resolveAppMode(legacyFarmerMode: true), AppMode.farmer);
      expect(resolveAppMode(legacyFarmerMode: false), AppMode.everyone);
      expect(resolveAppMode(), AppMode.everyone);
      expect(resolveAppMode(mode: '', legacyFarmerMode: true), AppMode.farmer);
    });

    test('unknown explicit values are rejected, never escalated', () {
      expect(() => resolveAppMode(mode: 'admin'), throwsA(isA<AppModeException>()));
      // Non-strict callers de-escalate to the least privileged mode.
      expect(resolveAppMode(mode: 'admin', strict: false), AppMode.everyone);
      expect(
          resolveAppMode(mode: 'admin', legacyFarmerMode: true, strict: false),
          AppMode.everyone);
    });

    test('legacy flag is derived from the resolved mode so they cannot differ',
        () {
      expect(legacyFarmerModeFor(AppMode.farmer), isTrue);
      expect(legacyFarmerModeFor(AppMode.everyone), isFalse);
      expect(legacyFarmerModeFor(AppMode.researcher), isFalse);
    });
  });
}
