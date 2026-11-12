import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:fibus/commuter/providers/commute_provider.dart';
import 'package:fibus/core/constants/app_constants.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/widgets/map_tiles.dart';
import 'package:fibus/services/geocoding_service.dart';

/// Map screen where the commuter places a pin on their home.
class HomePinScreen extends StatefulWidget {
  const HomePinScreen({super.key});

  @override
  State<HomePinScreen> createState() => _HomePinScreenState();
}

class _HomePinScreenState extends State<HomePinScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final GeocodingService _geocoder = GeocodingService.instance;

  late LatLng _currentCenter;
  bool _isSaving = false;

  static const Duration _searchDebounce = Duration(milliseconds: 450);
  static const int _minQueryLength = 3;
  Timer? _debounceTimer;
  int _searchSeq = 0;
  bool _isSearching = false;
  String? _searchError;
  List<PlaceSuggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    // Rebuild on focus so the bottom panel can step aside while searching.
    _searchFocus.addListener(_onFocusChanged);
    final pref = context.read<CommuteProvider>().currentPreference;
    _currentCenter = (pref != null && pref.hasHomePin)
        ? pref.homeLocation
        : const LatLng(
            AppConstants.defaultLatitude,
            AppConstants.defaultLongitude,
          );
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onFocusChanged);
    _debounceTimer?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().length < _minQueryLength) {
      _searchSeq++; // Drop any in-flight result for an older query.
      setState(() {
        _suggestions = const [];
        _searchError = null;
        _isSearching = false;
      });
      return;
    }
    _debounceTimer = Timer(_searchDebounce, () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_searchSeq;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final results = await _geocoder.search(query, near: _currentCenter);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _suggestions = results;
        _searchError = results.isEmpty
            ? 'No places found for "$query" in Telangana'
            : null;
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _suggestions = const [];
        _searchError = 'Search is not reachable. Check your connection';
      });
    } finally {
      if (mounted && seq == _searchSeq) setState(() => _isSearching = false);
    }
  }

  void _selectSuggestion(PlaceSuggestion place) {
    _debounceTimer?.cancel();
    _searchSeq++;
    _searchFocus.unfocus();
    _searchController.text = place.title;
    _mapController.move(place.location, 17.0);
    setState(() {
      _currentCenter = place.location;
      _suggestions = const [];
      _searchError = null;
      _isSearching = false;
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchSeq++;
    _searchController.clear();
    setState(() {
      _suggestions = const [];
      _searchError = null;
      _isSearching = false;
    });
  }

  Future<void> _confirmHomeLocation() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final commuteProvider = context.read<CommuteProvider>();
      await commuteProvider.updateHomeLocation(
        _currentCenter.latitude,
        _currentCenter.longitude,
      );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Home saved')));
      context.go(
        commuteProvider.isCommuteSelected ? '/dashboard' : '/choose-commute',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save your home. Try again')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// A surface floating over the map: neutral with a soft, small shadow.
  BoxDecoration _floating(FibusPalette c) => BoxDecoration(
    color: c.surface,
    borderRadius: BorderRadius.circular(FibusSpace.radiusCard),
    border: Border.all(color: c.hairline),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
  );

  Widget _buildSearchResults(FibusPalette c) {
    if (_suggestions.isEmpty && _searchError == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: FibusSpace.s8),
      constraints: const BoxConstraints(maxHeight: 304),
      decoration: _floating(c),
      child: _searchError != null
          ? Padding(
              padding: const EdgeInsets.all(FibusSpace.s16),
              child: Text(_searchError!, style: context.type.bodySmall),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: FibusSpace.s4),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) =>
                  const Divider(indent: 48, endIndent: 16),
              itemBuilder: (context, index) {
                final place = _suggestions[index];
                return ListTile(
                  minLeadingWidth: 20,
                  horizontalTitleGap: FibusSpace.s12,
                  leading: Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: c.textMuted,
                  ),
                  title: Text(
                    place.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodyMedium,
                  ),
                  subtitle: place.subtitle.isEmpty
                      ? null
                      : Text(
                          place.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.bodySmall,
                        ),
                  onTap: () => _selectSuggestion(place),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final t = context.type;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.0,
              onTap: (_, _) => _searchFocus.unfocus(),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) setState(() => _currentCenter = camera.center);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fibus.commuter',
                tileBuilder: (context, tile, _) => ColorFiltered(
                  colorFilter: ColorFilter.matrix(
                    isDark ? MapTiles.dark : MapTiles.quiet,
                  ),
                  child: tile,
                ),
              ),
            ],
          ),

          // Fixed pin; the map moves under it.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 56),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 3),
                      ),
                      child: Icon(
                        Icons.home_outlined,
                        size: 20,
                        color: c.onAccent,
                      ),
                    ),
                    Container(width: 2, height: 12, color: c.textPrimary),
                    Container(
                      width: 8,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FibusSpace.s16,
                FibusSpace.s12,
                FibusSpace.s16,
                0,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: _floating(c),
                        child: IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/dashboard'),
                        ),
                      ),
                      const SizedBox(width: FibusSpace.s8),
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: _floating(c),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (query) {
                              _debounceTimer?.cancel();
                              if (query.trim().length >= _minQueryLength) {
                                _runSearch(query);
                              }
                            },
                            style: t.bodyMedium,
                            decoration: InputDecoration(
                              filled: false,
                              prefixIcon: const Icon(Icons.search, size: 18),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear',
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: _clearSearch,
                                    ),
                              hintText: 'Search your area',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildSearchResults(c),
                  const SizedBox(height: FibusSpace.s8),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: OsmAttributionChip(),
                  ),
                ],
              ),
            ),
          ),

          // Hidden while typing: with the keyboard up it would cover the
          // search results.
          if (!_searchFocus.hasFocus)
            Positioned(
              left: FibusSpace.s16,
              right: FibusSpace.s16,
              bottom: FibusSpace.s16,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(FibusSpace.s20),
                  decoration: _floating(c),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Set your home', style: t.titleMedium),
                      const SizedBox(height: FibusSpace.s4),
                      Text(
                        'Drag the map until the pin sits on your gate. Fibus uses '
                        'it to time your scooter ride to the stop',
                        style: t.bodySmall,
                      ),
                      const SizedBox(height: FibusSpace.s16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSaving ? null : _confirmHomeLocation,
                          child: Text(_isSaving ? 'Saving' : 'Save home'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
