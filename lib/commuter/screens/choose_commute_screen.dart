import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/constants/app_constants.dart';
import 'package:fibus/core/theme/app_colors.dart';
import 'package:fibus/core/widgets/glass_card.dart';
import 'package:fibus/models/bus_model.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/models/stop_model.dart';
import 'package:fibus/services/firestore_service.dart';
import 'package:fibus/commuter/providers/commute_provider.dart';

/// Screen allowing the commuter to select their route, assigned bus, boarding stop,
/// and advance warning lead time.
class ChooseCommuteScreen extends StatefulWidget {
  const ChooseCommuteScreen({super.key});

  @override
  State<ChooseCommuteScreen> createState() => _ChooseCommuteScreenState();
}

class _ChooseCommuteScreenState extends State<ChooseCommuteScreen> {
  final FirestoreService _firestore = FirestoreService.instance;

  bool _isLoading = true;
  bool _isSaving = false;

  List<RouteModel> _routes = [];
  List<BusModel> _buses = [];
  List<StopModel> _stops = [];

  RouteModel? _selectedRoute;
  BusModel? _selectedBus;
  StopModel? _selectedStop;
  double _advanceWarningMinutes = AppConstants.defaultAdvanceWarningMinutes.toDouble();
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      // Only backend-configured routes are listed (PRD FR-02); never invent any.
      _routes = await _firestore.getActiveRoutes();

      final saved = context.read<CommuteProvider>().currentPreference;
      if (saved != null) {
        _advanceWarningMinutes = saved.advanceWarningMinutes.toDouble();
      }

      if (_routes.isEmpty) {
        _loadError = 'No bus routes are set up yet. Ask your Fibus admin to add your route.';
      } else {
        _selectedRoute = _routes.firstWhere(
          (r) => r.id == saved?.routeId,
          orElse: () => _routes.first,
        );
        await _loadBusesAndStopsForRoute(_selectedRoute!);
      }
    } catch (e) {
      _routes = [];
      _loadError = 'Could not load bus routes. Check your connection and try again.';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadBusesAndStopsForRoute(RouteModel route) async {
    try {
      _buses = await _firestore.getBusesForRoute(route.id);
      _stops = await _firestore.getStopsForRoute(route);
    } catch (_) {
      _buses = [];
      _stops = [];
      _loadError = 'Could not load buses and stops for ${route.name}.';
      return;
    }

    final saved = mounted ? context.read<CommuteProvider>().currentPreference : null;
    _selectedBus = _buses.isEmpty
        ? null
        : _buses.firstWhere((b) => b.id == saved?.busId, orElse: () => _buses.first);
    _selectedStop = _stops.isEmpty
        ? null
        : _stops.firstWhere((st) => st.id == saved?.boardingStopId, orElse: () => _stops.first);

    if (_buses.isEmpty || _stops.isEmpty) {
      _loadError = '${route.name} has no ${_buses.isEmpty ? 'buses' : 'stops'} set up yet.';
    }
  }

  Future<void> _saveCommute() async {
    if (_selectedRoute == null || _selectedBus == null || _selectedStop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a route, bus, and stop.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final commuteProvider = context.read<CommuteProvider>();
      await commuteProvider.saveCommutePreference(
        route: _selectedRoute!,
        bus: _selectedBus!,
        stop: _selectedStop!,
        advanceWarningMinutes: _advanceWarningMinutes.round(),
      );

      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving commute: $e'),
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
      appBar: AppBar(
        title: const Text('Configure Commute'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _routes.isEmpty || _buses.isEmpty || _stops.isEmpty
              ? _buildLoadError()
              : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step 1: Select Route
                    _buildSectionHeader(
                      step: '1',
                      title: 'Select Bus Route',
                      subtitle: 'Choose your regular morning bus route',
                    ),
                    const SizedBox(height: 12),
                    ..._routes.map((r) => _buildOptionCard(
                          title: r.name,
                          subtitle: 'Direction: ${r.direction}',
                          isSelected: _selectedRoute?.id == r.id,
                          icon: Icons.alt_route_rounded,
                          onTap: () async {
                            setState(() {
                              _selectedRoute = r;
                              _isLoading = true;
                            });
                            await _loadBusesAndStopsForRoute(r);
                            setState(() => _isLoading = false);
                          },
                        )),

                    const SizedBox(height: 24),

                    // Step 2: Select Bus
                    _buildSectionHeader(
                      step: '2',
                      title: 'Select Assigned Bus',
                      subtitle: 'Choose the bus running on this route',
                    ),
                    const SizedBox(height: 12),
                    ..._buses.map((b) => _buildOptionCard(
                          title: b.displayName,
                          subtitle: 'Assigned to ${_selectedRoute?.name ?? 'Route'}',
                          isSelected: _selectedBus?.id == b.id,
                          icon: Icons.directions_bus_rounded,
                          onTap: () => setState(() => _selectedBus = b),
                        )),

                    const SizedBox(height: 24),

                    // Step 3: Select Boarding Stop
                    _buildSectionHeader(
                      step: '3',
                      title: 'Select Boarding Stop',
                      subtitle: 'Ordered along the bus route sequence',
                    ),
                    const SizedBox(height: 12),
                    ..._stops.map((s) => _buildOptionCard(
                          title: s.name,
                          subtitle:
                              'Timetable Arrival: ${s.scheduledArrivalLocalTime} | Stop #${s.sequenceIndex + 1}',
                          isSelected: _selectedStop?.id == s.id,
                          icon: Icons.location_on_rounded,
                          onTap: () => setState(() => _selectedStop = s),
                        )),

                    const SizedBox(height: 24),

                    // Step 4: Advance Warning Time Slider
                    _buildSectionHeader(
                      step: '4',
                      title: 'Advance Warning Lead Time',
                      subtitle: 'Alert you before it is time to leave home',
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Warning Lead Time',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_advanceWarningMinutes.round()} minutes',
                                  style: const TextStyle(
                                    color: AppColors.primaryLight,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Slider(
                            value: _advanceWarningMinutes,
                            min: 5,
                            max: 30,
                            divisions: 5,
                            label: '${_advanceWarningMinutes.round()} min',
                            onChanged: (val) {
                              setState(() => _advanceWarningMinutes = val);
                            },
                          ),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('5 min',
                                  style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 12)),
                              Text('15 min (Default)',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                              Text('30 min',
                                  style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Save & Continue Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveCommute,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save & Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader({
    required String step,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderColor: isSelected ? AppColors.primary : AppColors.glassBorder,
        borderWidth: isSelected ? 1.5 : 1.0,
        backgroundColor: isSelected
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.surfaceVariant.withValues(alpha: 0.5),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_bus_filled_rounded,
                color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text(
              _loadError ?? 'Nothing to choose from yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadCatalog,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
