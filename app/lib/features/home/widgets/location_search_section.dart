import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/geocoding_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/location.dart';
import '../../explore/providers/saved_locations_provider.dart';

/// Shared location search: debounced worldwide suggestions with per-result
/// save toggles, used by the Home location sheet, the Explore picker and
/// the Saved add-sheet.
///
/// Renders a search field plus a [Flexible] results area, so callers must
/// give it a bounded height (inside `Expanded` or a fixed `SizedBox`). While
/// the query is shorter than 2 characters, [idleChild] (presets) shows
/// instead of results.
class LocationSearchSection extends ConsumerStatefulWidget {
  const LocationSearchSection({
    super.key,
    required this.onSelected,
    this.idleChild,
    this.autofocus = false,
  });

  final ValueChanged<AppLocation> onSelected;
  final Widget? idleChild;
  final bool autofocus;

  @override
  ConsumerState<LocationSearchSection> createState() =>
      _LocationSearchSectionState();
}

enum _SearchStatus { idle, searching, done }

class _LocationSearchSectionState
    extends ConsumerState<LocationSearchSection> {
  final _controller = TextEditingController();
  Timer? _debounce;

  /// Monotonic guard: a slow response can never overwrite a newer query's
  /// results (or the cleared idle state).
  int _generation = 0;
  var _status = _SearchStatus.idle;
  var _results = const <AppLocation>[];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      // Sync reset: presets return instantly, stale responses invalidated.
      _generation++;
      setState(() {
        _status = _SearchStatus.idle;
        _results = const [];
      });
      return;
    }
    setState(() => _status = _SearchStatus.searching);
    _debounce =
        Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String query) async {
    final generation = ++_generation;
    final results = await GeocodingService.searchMany(query);
    if (!mounted || generation != _generation) return;
    setState(() {
      _status = _SearchStatus.done;
      _results = results;
    });
  }

  void _toggleSaved(AppLocation loc, bool saved) {
    final notifier = ref.read(savedLocationsProvider.notifier);
    final entry = SavedLocation(name: loc.name, lat: loc.lat, lon: loc.lon);
    if (saved) {
      notifier.remove(entry);
    } else {
      notifier.add(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedNames = ref
        .watch(savedLocationsProvider)
        .map((s) => s.name)
        .toSet();
    final searching = _status == _SearchStatus.searching;

    return Column(
      children: [
        TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (q) async {
            // Enter searches immediately and picks the first suggestion.
            _debounce?.cancel();
            await _search(q);
            if (!mounted) return;
            if (_results.isNotEmpty) widget.onSelected(_results.first);
          },
          decoration: InputDecoration(
            hintText: 'location.search_hint'.tr(),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
            filled: true,
            fillColor: AppColors.surfaceCardAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.borderSubtle),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: _status == _SearchStatus.idle
              ? widget.idleChild ?? const SizedBox.shrink()
              : searching && _results.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24),
                            child: Text(
                              'location.no_results'.tr(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final loc = _results[i];
                            final isSaved =
                                savedNames.contains(loc.name);
                            return ListTile(
                              leading: const Icon(
                                  Icons.place_outlined),
                              title: Text(loc.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                tooltip: isSaved
                                    ? 'location.saved'.tr()
                                    : 'location.save'.tr(),
                                icon: Icon(
                                  isSaved
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: isSaved
                                      ? AppColors.statusAmber
                                      : AppColors.textSecondary,
                                ),
                                onPressed: () =>
                                    _toggleSaved(loc, isSaved),
                              ),
                              onTap: () => widget.onSelected(loc),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
