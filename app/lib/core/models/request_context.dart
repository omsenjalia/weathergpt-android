/// Request context shared by every agent-facing call (`/chat`, `/voice`).
///
/// Chat and voice must send *identical* context so the same question produces
/// the same answer from either surface, and so a UI/backend parity fixture can
/// assert it. Previously each surface hand-built its own payload, and voice
/// hardcoded `crop: "Wheat"` regardless of the user's actual farm profile.
///
/// Pure Dart (no Flutter imports) so the payload shape is unit-testable.
library;

import 'app_mode.dart';

/// The farm details a farmer request may carry. The app never infers crop,
/// growth stage, soil or irrigation state from the weather — these come from
/// the user's saved profile or not at all.
class FarmContext {
  const FarmContext({
    required this.crop,
    this.growthStage,
    this.soilType,
    this.irrigationType,
  });

  final String crop;
  final String? growthStage;
  final String? soilType;
  final String? irrigationType;

  bool get isEmpty =>
      crop.trim().isEmpty &&
      (growthStage ?? '').trim().isEmpty &&
      (soilType ?? '').trim().isEmpty &&
      (irrigationType ?? '').trim().isEmpty;
}

/// Validated mode plus optional farm context for one outgoing request.
class AgentRequestContext {
  const AgentRequestContext({required this.mode, this.farm});

  final AppMode mode;

  /// Farm details, present only when the mode actually uses them.
  final FarmContext? farm;

  bool get includesFarmContext => farm != null && !farm!.isEmpty;

  /// Body fields describing mode and farm context.
  ///
  /// `mode` is authoritative. `farmer_mode` is kept only for backward
  /// compatibility with the current backend and is derived from [mode], so the
  /// two can never disagree on the wire.
  Map<String, dynamic> toPayload() {
    final farmContext = includesFarmContext ? farm! : null;
    return <String, dynamic>{
      'mode': mode.wire,
      'farmer_mode': legacyFarmerModeFor(mode),
      'crop': farmContext?.crop ?? '',
      if (farmContext != null && (farmContext.growthStage ?? '').isNotEmpty)
        'growth_stage': farmContext.growthStage,
      if (farmContext != null && (farmContext.soilType ?? '').isNotEmpty)
        'soil': farmContext.soilType,
      if (farmContext != null && (farmContext.irrigationType ?? '').isNotEmpty)
        'irrigation': farmContext.irrigationType,
    };
  }
}

/// Builds the context for one request.
///
/// [profilePersona] is the raw persisted persona string; it is validated here
/// so an unrecognised value can never be sent, and never escalates. [farm] is
/// attached only for farmer mode — Everyone and Researcher requests carry no
/// private farm context.
AgentRequestContext buildAgentRequestContext({
  required String profilePersona,
  bool legacyFarmerMode = false,
  FarmContext? farm,
}) {
  final mode = resolveAppMode(
    mode: profilePersona,
    legacyFarmerMode: legacyFarmerMode,
    // A persona this build does not know de-escalates rather than throwing,
    // because the value came from storage rather than from a caller.
    strict: false,
  );
  return AgentRequestContext(
    mode: mode,
    farm: mode == AppMode.farmer ? farm : null,
  );
}
