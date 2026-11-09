import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/widgets/error_display.dart';
import 'package:fibus/core/widgets/fib_card.dart';
import 'package:fibus/core/widgets/fibus_wordmark.dart';
import 'package:fibus/core/widgets/status_badge.dart';
import 'package:fibus/models/bus_model.dart';
import 'package:fibus/models/live_bus_model.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/services/auth_service.dart';
import 'package:fibus/services/firestore_service.dart';
import 'package:fibus/services/realtime_db_service.dart';

/// The buses this operator is assigned to, each with its live status.
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
    final auth = context.read<AuthService>();
    try {
      final currentUser = auth.currentUser;
      if (currentUser == null) throw Exception('Not signed in');

      final assignments =
          await _firestoreService.getAssignmentsForOperator(currentUser.uid);
      final busIds = assignments.map((a) => a.busId).toList();

      // Fall back to the buses catalog when no assignment documents exist.
      if (busIds.isEmpty) {
        for (final bus in await _firestoreService.getAllActiveBuses()) {
          if (bus.operatorUids.contains(currentUser.uid)) busIds.add(bus.id);
        }
      }
      // Unassigned operators see no buses: the RTDB rules would reject their
      // location writes anyway (PRD FR-04).

      final items = <_AssignedBusItem>[];
      for (final busId in busIds) {
        final bus = await _firestoreService.getBus(busId);
        if (bus == null) continue;
        RouteModel? route;
        if (bus.routeIds.isNotEmpty) {
          route = await _firestoreService.getRoute(bus.routeIds.first);
        }
        items.add(_AssignedBusItem(bus: bus, route: route));
      }
      if (mounted) {
        setState(() {
          _assignedItems = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load your buses. Check your connection';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final c = context.fib;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sign out of Fibus Tracker'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: TextButton.styleFrom(foregroundColor: c.negative),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AuthService>().signOut();
    if (mounted) context.go('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FibusWordmark(suffix: 'Tracker'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _confirmSignOut,
          ),
          const SizedBox(width: FibusSpace.s8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAssignedBuses,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final t = context.type;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_errorMessage != null) {
      return ErrorDisplay(message: _errorMessage!, onRetry: _loadAssignedBuses);
    }
    if (_assignedItems.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          ErrorDisplay(
            icon: Icons.directions_bus_outlined,
            title: 'No buses assigned to you',
            message: 'Ask your Fibus admin to add you as the operator of your bus, '
                'then pull down to refresh',
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          FibusSpace.page, FibusSpace.s8, FibusSpace.page, FibusSpace.s32),
      children: [
        Text('Your buses', style: t.headlineSmall),
        const SizedBox(height: FibusSpace.s16),
        for (final item in _assignedItems) ...[
          _BusCard(item: item, stream: _rtdbService.streamLiveBus(item.bus.id)),
          const SizedBox(height: FibusSpace.s12),
        ],
      ],
    );
  }
}

class _BusCard extends StatelessWidget {
  const _BusCard({required this.item, required this.stream});
  final _AssignedBusItem item;
  final Stream<LiveBusModel?> stream;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final t = context.type;
    return StreamBuilder<LiveBusModel?>(
      stream: stream,
      builder: (context, snapshot) {
        final live = snapshot.data;
        final status = (live?.isLive ?? false)
            ? TrackingStatus.live
            : (live?.isStale ?? false)
                ? TrackingStatus.stale
                : TrackingStatus.offline;
        return FibCard(
          onTap: () => context.push('/trip-preview/${item.bus.id}'),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.bus.displayName, style: t.titleSmall),
                    const SizedBox(height: FibusSpace.s4),
                    Text(item.route?.name ?? 'No route set',
                        style: t.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: FibusSpace.s12),
                    StatusBadge(status: status),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: c.textMuted),
            ],
          ),
        );
      },
    );
  }
}

class _AssignedBusItem {
  _AssignedBusItem({required this.bus, this.route});
  final BusModel bus;
  final RouteModel? route;
}
