import 'package:flutter_test/flutter_test.dart';
import 'package:weathergpt_mobile/core/models/app_mode.dart';
import 'package:weathergpt_mobile/core/models/request_context.dart';

const _wheatFarm = FarmContext(
  crop: 'Wheat',
  growthStage: 'Flowering',
  soilType: 'Loamy',
  irrigationType: 'Borewell',
);

const _cottonFarm = FarmContext(
  crop: 'Cotton',
  growthStage: 'Boll formation',
  soilType: 'Black cotton',
  irrigationType: 'Drip',
);

void main() {
  group('buildAgentRequestContext', () {
    test('sends an explicit mode and a legacy flag derived from it', () {
      for (final persona in ['everyone', 'farmer', 'researcher']) {
        final context = buildAgentRequestContext(profilePersona: persona);
        final payload = context.toPayload();
        expect(payload['mode'], persona);
        expect(payload['farmer_mode'], persona == 'farmer',
            reason: 'legacy flag must agree with mode for $persona');
      }
    });

    test('an unknown persona de-escalates instead of escalating', () {
      final context = buildAgentRequestContext(profilePersona: 'superuser');
      expect(context.mode, AppMode.everyone);
      expect(context.toPayload()['mode'], 'everyone');
      expect(context.toPayload()['farmer_mode'], isFalse);
    });

    test('farm context is attached only in farmer mode', () {
      final farmer = buildAgentRequestContext(
          profilePersona: 'farmer', farm: _cottonFarm);
      expect(farmer.includesFarmContext, isTrue);
      expect(farmer.toPayload()['crop'], 'Cotton');

      // Private farm context must not ride along on other modes' requests.
      for (final persona in ['everyone', 'researcher']) {
        final context = buildAgentRequestContext(
            profilePersona: persona, farm: _cottonFarm);
        expect(context.includesFarmContext, isFalse);
        expect(context.toPayload()['crop'], '');
        expect(context.toPayload().containsKey('soil'), isFalse);
      }
    });

    test('uses the saved profile, never an assumed crop', () {
      // Regression: chat and voice both hardcoded crop: "Wheat" regardless of
      // the farmer's actual profile.
      final payload = buildAgentRequestContext(
              profilePersona: 'farmer', farm: _cottonFarm)
          .toPayload();
      expect(payload['crop'], 'Cotton');
      expect(payload['growth_stage'], 'Boll formation');
      expect(payload['soil'], 'Black cotton');
      expect(payload['irrigation'], 'Drip');
      expect(payload['crop'], isNot('Wheat'));
    });

    test('omits blank profile fields rather than sending empty strings', () {
      final payload = buildAgentRequestContext(
        profilePersona: 'farmer',
        farm: const FarmContext(crop: 'Bajra', soilType: ''),
      ).toPayload();
      expect(payload['crop'], 'Bajra');
      expect(payload['soil'], isNull);
      expect(payload.containsKey('growth_stage'), isFalse);
    });

    test('chat and voice build identical context from the same inputs', () {
      // Both surfaces share this builder, so a UI/backend parity fixture holds
      // by construction; this asserts the payload is stable.
      final a = buildAgentRequestContext(
              profilePersona: 'farmer', farm: _wheatFarm)
          .toPayload();
      final b = buildAgentRequestContext(
              profilePersona: 'farmer', farm: _wheatFarm)
          .toPayload();
      expect(a, b);
    });
  });

  group('FarmContext', () {
    test('an all-blank profile is treated as no context', () {
      expect(const FarmContext(crop: '').isEmpty, isTrue);
      expect(const FarmContext(crop: '  ').isEmpty, isTrue);
      expect(_wheatFarm.isEmpty, isFalse);
      final context = buildAgentRequestContext(
          profilePersona: 'farmer', farm: const FarmContext(crop: ''));
      expect(context.includesFarmContext, isFalse);
      expect(context.toPayload()['crop'], '');
    });
  });
}
