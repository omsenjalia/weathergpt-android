/// Validated user-facing product mode.
///
/// Everyone / Farmer / Researcher share one data platform but must not render
/// the same dashboard in different colours, and a user-selected Researcher mode
/// never grants server permissions.
///
/// Pure Dart (no Flutter imports) so the mode rules are unit-testable in
/// isolation, mirroring `features/farmer/models/advisory_models.dart`.
library;

enum AppMode { everyone, farmer, researcher }

/// Name of the mode as it travels over the wire in `mode` request fields.
extension AppModeWire on AppMode {
  String get wire => switch (this) {
        AppMode.everyone => 'everyone',
        AppMode.farmer => 'farmer',
        AppMode.researcher => 'researcher',
      };
}

/// Parses a mode value. Returns `null` for anything unrecognised so callers can
/// reject it instead of silently escalating to a more privileged mode.
AppMode? appModeFromName(Object? value) {
  if (value is AppMode) return value;
  if (value is! String) return null;
  switch (value.trim().toLowerCase()) {
    case 'everyone':
      return AppMode.everyone;
    case 'farmer':
      return AppMode.farmer;
    case 'researcher':
      return AppMode.researcher;
    default:
      return null;
  }
}

/// Raised when a caller supplies an explicit but unrecognised mode value.
class AppModeException implements Exception {
  const AppModeException(this.value);
  final Object? value;

  @override
  String toString() =>
      'Unsupported mode value: ${value == null ? 'null' : '"$value"'}';
}

/// Resolves the mode to send on an outgoing forecast/chat/voice request.
///
/// Rules (feature/app/implementation_plan.md §3 "End-to-end mode propagation"):
/// - An explicit [mode] is authoritative.
/// - An explicit but unknown value is **rejected**, never escalated. With
///   [strict] the caller gets [AppModeException]; otherwise it de-escalates to
///   [AppMode.everyone], which is the least privileged mode.
/// - A blank/absent [mode] falls back to the legacy boolean:
///   `farmer_mode == true` → farmer, anything else → everyone.
AppMode resolveAppMode({
  Object? mode,
  bool? legacyFarmerMode,
  bool strict = true,
}) {
  final explicit = appModeFromName(mode);
  if (explicit != null) return explicit;

  if (mode != null) {
    final blank = mode is String && mode.trim().isEmpty;
    if (!blank) {
      if (strict) throw AppModeException(mode);
      return AppMode.everyone;
    }
  }
  return legacyFarmerMode == true ? AppMode.farmer : AppMode.everyone;
}

/// Legacy compatibility flag derived *from* the resolved mode, so the two can
/// never disagree on the wire.
bool legacyFarmerModeFor(AppMode mode) => mode == AppMode.farmer;
