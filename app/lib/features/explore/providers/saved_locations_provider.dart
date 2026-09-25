import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../models/location.dart';

class SavedLocationsNotifier extends StateNotifier<List<SavedLocation>> {
  SavedLocationsNotifier() : super(_load());

  static List<SavedLocation> _load() {
    if (!Hive.isBoxOpen('saved_locations')) return const [];
    final stored =
        Hive.box('saved_locations').get('locations', defaultValue: []);
    return (stored as List)
        .whereType<Map>()
        .map(SavedLocation.fromMap)
        .toList(growable: false);
  }

  Future<void> add(SavedLocation location) async {
    if (state.any((item) => item.name == location.name)) return;
    state = [...state, location];
    await _persist();
  }

  Future<void> remove(SavedLocation location) async {
    state = state.where((item) => item.name != location.name).toList();
    await _persist();
  }

  Future<void> _persist() async {
    final box = Hive.isBoxOpen('saved_locations')
        ? Hive.box('saved_locations')
        : await Hive.openBox('saved_locations');
    await box.put('locations', state.map((item) => item.toMap()).toList());
  }
}

final savedLocationsProvider =
    StateNotifierProvider<SavedLocationsNotifier, List<SavedLocation>>(
  (ref) => SavedLocationsNotifier(),
);
