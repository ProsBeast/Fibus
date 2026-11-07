import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/theme/app_colors.dart';
import 'package:fibus/core/widgets/glass_card.dart';
import 'package:fibus/core/widgets/status_badge.dart';
import 'package:fibus/models/bus_model.dart';
import 'package:fibus/models/live_bus_model.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/services/auth_service.dart';
import 'package:fibus/services/firestore_service.dart';
import 'package:fibus/services/realtime_db_service.dart';

/// Screen displaying the list of fleet buses assigned to the authenticated operator.
///
/// Queries assignments, fetches route metadata, streams live telemetry from RTDB,
/// and allows the operator to select a bus to launch or takeover tracking.
class AssignedBusesScreen extends StatefulWidget {
  const AssignedBusesScreen({super.key});

  @override
  State<AssignedBusesScreen> createState() => _AssignedBusesScreenState();
}

class _AssignedBusesScreenState extends State<AssignedBusesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final RealtimeDbService _rtdbService = RealtimeDbService();

  bool _isLoading = true;
  String? _errorMessage;
  List<_AssignedBusItem> _assignedItems = [];

  @override
  void initState() {
    super.initState();
    _loadAssignedBuses();
  }

  Future<void> _loadAssignedBuses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthService>();
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated.');
      }

      // 1. Fetch assignments for this operator
      final assignments = await _firestoreService.getAssignmentsForOperator(
        currentUser.uid,
      );

      final List<String> busIds = assignments.map((a) => a.busId).toList();

      // Fallback: If no direct OperatorAssignment documents found, check buses catalog
      if (busIds.isEmpty) {
        final allBuses = await _firestoreService.getAllActiveBuses();
        for (final bus in allBuses) {
          if (bus.operatorUids.contains(currentUser.uid)) {
            busIds.add(bus.id);
          }
        }
      }
      // Unassigned operators see no buses: the RTDB rules would reject their
      // location writes anyway (PRD FR-04).

      // 2. Fetch Bus and Route details for each busId
      final items = <_AssignedBusItem>[];
      for (final busId in busIds) {
        final bus = await _firestoreService.getBus(busId);
        if (bus != null) {
          RouteModel? route;
          if (bus.routeIds.isNotEmpty) {
            route = await _firestoreService.getRoute(bus.routeIds.first);
          }
          items.add(_AssignedBusItem(bus: bus, route: route));
        }
      }

      if (mounted) {
        setState(() {
          _assignedItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load assigned buses: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Sign Out', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to sign out of Fibus Tracker?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthService>().signOut();
      if (mounted) {
        context.go('/sign-in');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppColors.trackerGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.directions_bus_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text(
              'Assigned Buses',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAssignedBuses,
        color: AppColors.trackerAmber,
        backgroundColor: AppColors.surfaceElevated,
        child: _buildBody(user?.displayName ?? 'Operator'),
      ),
    );
  }

  Widget _buildBody(String operatorName) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.trackerAmber),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadAssignedBuses,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.trackerAmber,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_assignedItems.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.bus_alert_rounded,
                size: 56,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Buses Assigned',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You do not have any active bus routes assigned to your profile today. Please contact your dispatch administrator.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadAssignedBuses,
              icon: const Icon(Icons.refresh),
              label: const Text('Check for Assignments'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.trackerAmber,
                side: const BorderSide(color: AppColors.trackerAmber),
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Greeting card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.trackerAmber.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: AppColors.trackerAmber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $operatorName',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_assignedItems.length} active bus assignment${_assignedItems.length > 1 ? "s" : ""}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        const Text(
          'SELECT A BUS TO COMMENCE TRACKING',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),

        ..._assignedItems.map((item) => _buildBusCard(item)),
      ],
    );
  }

  Widget _buildBusCard(_AssignedBusItem item) {
    return StreamBuilder<LiveBusModel?>(
      stream: _rtdbService.streamLiveBus(item.bus.id),
      builder: (context, snapshot) {
        final liveBus = snapshot.data;
        final isLive = liveBus?.isLive ?? false;
        final isStale = liveBus?.isStale ?? false;

        TrackingStatus status;
        if (isLive) {
          status = TrackingStatus.live;
        } else if (isStale) {
          status = TrackingStatus.stale;
        } else {
          status = TrackingStatus.offline;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            onTap: () {
              context.push('/trip-preview/${item.bus.id}');
            },
            borderColor: isLive
                ? AppColors.statusLive.withValues(alpha: 0.5)
                : AppColors.border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.directions_bus_rounded,
                              color: AppColors.trackerAmber,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.bus.displayName,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: ${item.bus.id}',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.alt_route_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.route?.name ?? 'Assigned Route',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.trackerAmber,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AssignedBusItem {
  final BusModel bus;
  final RouteModel? route;

  _AssignedBusItem({required this.bus, this.route});
}
