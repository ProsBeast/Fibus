import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/constants/app_constants.dart';
import 'package:fibus/core/theme/app_colors.dart';
import 'package:fibus/commuter/providers/commute_provider.dart';
import 'package:fibus/services/geocoding_service.dart';

/// Interactive map screen enabling the commuter to pinpoint and save their home coordinates.
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

  /// Search-as-you-type state.
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
    final pref = context.read<CommuteProvider>().currentPreference;
    if (pref != null && pref.hasHomePin) {
      _currentCenter = pref.homeLocation;
    } else {
      _currentCenter = const LatLng(
        AppConstants.defaultLatitude,
        AppConstants.defaultLongitude,
      );
    }
  }

  @override
  void dispose() {
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
        _searchError = results.isEmpty ? 'No places found for "$query".' : null;
      });
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _suggestions = const [];
        _searchError = 'Search failed. Check your connection and try again.';
      });
    } finally {
      if (mounted && seq == _searchSeq) {
        setState(() => _isSearching = false);
      }
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

  Widget _buildSearchResults() {
    final hasContent = _suggestions.isNotEmpty || _searchError != null;
    if (!hasContent) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
          ),
        ],
      ),
      child: _searchError != null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _searchError!,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: AppColors.glassBorder.withValues(alpha: 0.5),
              ),
              itemBuilder: (context, index) {
                final place = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_rounded,
                      color: AppColors.primaryLight, size: 20),
                  title: Text(
                    place.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  ),
                  subtitle: place.subtitle.isEmpty
                      ? null
                      : Text(
                          place.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textTertiary, fontSize: 12),
                        ),
                  onTap: () => _selectSuggestion(place),
                );
              },
            ),
    );
  }

  Future<void> _confirmHomeLocation() async {
    setState(() => _isSaving = true);

    try {
      final commuteProvider = context.read<CommuteProvider>();
      await commuteProvider.updateHomeLocation(
        _currentCenter.latitude,
        _currentCenter.longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Home location saved successfully!'),
            backgroundColor: AppColors.surfaceElevated,
          ),
        );

        if (commuteProvider.isCommuteSelected) {
          context.go('/dashboard');
        } else {
          context.go('/choose-commute');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save home location: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Full-screen OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.0,
              onTap: (_, _) => _searchFocus.unfocus(),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _currentCenter = camera.center;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fibus.commuter',
                tileBuilder: (context, tileWidget, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.3, 0, 0, 0, 15,
                      0, 0.32, 0, 0, 20,
                      0, 0, 0.38, 0, 30,
                      0, 0, 0, 1, 0,
                    ]),
                    child: tileWidget,
                  );
                },
              ),
            ],
          ),

          // 2. Fixed Center Pin with Pulse and Shadow
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40), // Offset to pin tip
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.7),
                          blurRadius: 18,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.home_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  Container(
                    width: 3,
                    height: 12,
                    color: AppColors.primary,
                  ),
                  Container(
                    width: 10,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Floating App Bar & Search Input
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: AppColors.textPrimary),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/dashboard');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.glassBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 12,
                              ),
                            ],
                          ),
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
                            style:
                                const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              icon: const Icon(Icons.search_rounded,
                                  color: AppColors.primaryLight, size: 20),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : _searchController.text.isEmpty
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.close_rounded,
                                              color: AppColors.textTertiary,
                                              size: 18),
                                          onPressed: _clearSearch,
                                        ),
                              hintText: 'Search your area, or drag the map',
                              hintStyle: const TextStyle(
                                  color: AppColors.textTertiary, fontSize: 14),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildSearchResults(),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.glassBorder.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'Lat: ${_currentCenter.latitude.toStringAsFixed(5)}, Lng: ${_currentCenter.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Confirm Location Floating Bar
          Positioned(
            bottom: 28,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.accent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Fibus uses this to calculate scooter travel time to your boarding stop.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _confirmHomeLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, color: Colors.white),
                      label: Text(
                        _isSaving ? 'Saving Pin...' : 'Confirm Home Location',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
