import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/location.dart';
import '../../home/providers/weather_provider.dart';
import '../../home/widgets/location_search_section.dart';
import '../providers/saved_locations_provider.dart';

// Design is inferred from the saved-locations requirement; no dedicated mockup exists.
class SavedLocationsScreen extends ConsumerWidget {
  const SavedLocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(savedLocationsProvider);
    final weather = ref.watch(weatherProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Locations'),
        actions: [
          IconButton(
            tooltip: 'Add location',
            onPressed: () => _showAddLocation(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: locations.isEmpty
          ? const Center(
              child: Text('No saved locations yet.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: locations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final location = locations[index];
                return AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    onTap: () => context.go(
                      '/home?location=${Uri.encodeComponent(location.name)}&lat=${location.lat}&lon=${location.lon}',
                    ),
                    leading: const Icon(Icons.location_on_outlined,
                        color: AppColors.statusAmber),
                    title: Text(location.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        weather.when(
                          data: (snapshot) => '${snapshot.temperature} • ${snapshot.condition}',
                          loading: () => 'Loading weather…',
                          error: (_, __) => 'Weather unavailable',
                        ),
                        style: const TextStyle(color: AppColors.textSecondary)),
                    trailing: IconButton(
                      tooltip: 'Delete ${location.name}',
                      onPressed: () => ref
                          .read(savedLocationsProvider.notifier)
                          .remove(location),
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.textSecondary),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showAddLocation(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => const _AddLocationSheet(),
    );
  }
}

class _AddLocationSheet extends ConsumerStatefulWidget {
  const _AddLocationSheet();
  @override
  ConsumerState<_AddLocationSheet> createState() => _AddLocationSheetState();
}

class _AddLocationSheetState extends ConsumerState<_AddLocationSheet> {
  static const _cities = [
    SavedLocation(name: 'Ahmedabad, Gujarat', lat: 23.0225, lon: 72.5714),
    SavedLocation(name: 'Rajkot, Gujarat', lat: 22.3039, lon: 70.8022),
    SavedLocation(name: 'Surat, Gujarat', lat: 21.1702, lon: 72.8311),
    SavedLocation(name: 'Vadodara, Gujarat', lat: 22.3072, lon: 73.1812),
    SavedLocation(name: 'Anand, Gujarat', lat: 22.5645, lon: 72.9289),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add a location',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // Gujarat presets stay as the offline-friendly default; typing
          // searches worldwide, with save toggles on every result.
          SizedBox(
            height: 360,
            child: LocationSearchSection(
              autofocus: true,
              onSelected: (loc) async {
                await ref.read(savedLocationsProvider.notifier).add(
                    SavedLocation(
                        name: loc.name, lat: loc.lat, lon: loc.lon));
                if (context.mounted) Navigator.of(context).pop();
              },
              idleChild: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final location in _cities)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const Icon(Icons.location_on_outlined),
                      title: Text(location.name),
                      onTap: () async {
                        await ref
                            .read(savedLocationsProvider.notifier)
                            .add(location);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
