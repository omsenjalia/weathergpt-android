import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/farm_profile_model.dart';

class FarmProfileNotifier extends StateNotifier<FarmProfile> {
  FarmProfileNotifier(this._ref) : super(_load());

  final Ref _ref;

  static FarmProfile _load() {
    if (!Hive.isBoxOpen('farm_profile')) return FarmProfile.defaultProfile;
    final stored = Hive.box('farm_profile').get('profile');
    return stored is Map
        ? FarmProfile.fromMap(stored)
        : FarmProfile.defaultProfile;
  }

  /// True once the user has explicitly saved their farm details — either in
  /// the farmer onboarding step or in the profile editor. Profiles saved
  /// before this flag existed (a `profile` entry with no flag) count as
  /// completed so existing farmers are never nagged to re-enter details.
  static bool loadCompleted() {
    if (!Hive.isBoxOpen('farm_profile')) return false;
    final box = Hive.box('farm_profile');
    if (box.containsKey('profile_completed')) {
      return box.get('profile_completed') == true;
    }
    return box.containsKey('profile');
  }

  Future<void> save(FarmProfile profile) async {
    final box = Hive.isBoxOpen('farm_profile')
        ? Hive.box('farm_profile')
        : await Hive.openBox('farm_profile');
    await box.put('profile', profile.toMap());
    await box.put('profile_completed', true);
    _ref.read(farmProfileCompletedProvider.notifier).state = true;
    state = profile;
  }
}

final farmProfileProvider =
    StateNotifierProvider<FarmProfileNotifier, FarmProfile>(
  (ref) => FarmProfileNotifier(ref),
);

/// Whether the user has explicitly saved farm details (see [loadCompleted]).
final farmProfileCompletedProvider =
    StateProvider<bool>((ref) => FarmProfileNotifier.loadCompleted());
