import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/commuter/providers/alert_session_provider.dart';
import 'package:fibus/commuter/providers/commute_provider.dart';
import 'package:fibus/commuter/widgets/bus_eta_card.dart';
import 'package:fibus/commuter/widgets/departure_countdown.dart';
import 'package:fibus/commuter/widgets/route_map_view.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/widgets/error_display.dart';
import 'package:fibus/core/widgets/fib_card.dart';
import 'package:fibus/core/widgets/fibus_wordmark.dart';
import 'package:fibus/models/alert_session.dart';
import 'package:fibus/models/commute_preference.dart';
import 'package:fibus/services/auth_service.dart';
import 'package:fibus/services/service_calendar.dart';

/// Today's commute: when to leave, where the bus is, today's alerts, map.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthService>().currentUser;
      if (user != null) {
        context.read<CommuteProvider>().initForUser(user.uid);
        context.read<AlertSessionProvider>().initForUser(user.uid);
      }
    });
  }

  Future<void> _handleRefresh() => context.read<CommuteProvider>().refresh();

  Future<void> _toggleAlerts() async {
    final alertProvider = context.read<AlertSessionProvider>();
    final commuteProvider = context.read<CommuteProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (alertProvider.isActive) {
      await alertProvider.cancelAlerts();
      messenger.showSnackBar(const SnackBar(content: Text('Alerts off')));
      return;
    }
    final pref = commuteProvider.currentPreference;
    if (pref == null) return;
    try {
      await alertProvider.activateAlerts(
        preference: pref,
        recommendation: commuteProvider.departureRecommendation,
      );
      messenger.showSnackBar(const SnackBar(content: Text('Alerts on')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not turn on alerts. Try again')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final commute = context.watch<CommuteProvider>();
    final alerts = context.watch<AlertSessionProvider>();
    final pref = commute.currentPreference;
    final rec = commute.departureRecommendation;
    final configured = pref != null && pref.isFullyConfigured;

    return Scaffold(
      appBar: AppBar(
        title: const FibusWordmark(),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: FibusSpace.s8),
        ],
      ),
      body: commute.isLoading && pref == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  FibusSpace.page,
                  FibusSpace.s8,
                  FibusSpace.page,
                  FibusSpace.s32,
                ),
                children: [
                  // A failed load must not look like "you never set up".
                  if (pref == null && commute.errorMessage != null) ...[
                    ErrorDisplay(
                      compact: true,
                      title: 'Could not load your commute',
                      message: 'Check your connection and try again',
                      onRetry: _handleRefresh,
                    ),
                    const SizedBox(height: FibusSpace.s16),
                  ] else if (!configured) ...[
                    _SetupCard(pref: pref),
                    const SizedBox(height: FibusSpace.s16),
                  ],
                  if (configured) ...[
                    DepartureCountdown(
                      recommendation: rec,
                      stopName: commute.currentStop?.name,
                    ),
                    const SizedBox(height: FibusSpace.s12),
                    BusEtaCard(
                      bus: commute.currentBus,
                      route: commute.currentRoute,
                      stop: commute.currentStop,
                      liveBus: commute.liveBus,
                      busEta: commute.busEta,
                      etaStatus: commute.etaEstimate.status,
                      delayMinutes: rec?.delayMinutes ?? 0,
                      stopNames: [for (final s in commute.routeStops) s.name],
                      stopFractions: commute.stopFractions,
                      busFraction: commute.busFraction,
                    ),
                    const SizedBox(height: FibusSpace.s12),
                    _AlertsCard(
                      alerts: alerts,
                      dayLabel: commute.serviceDay == null
                          ? ''
                          : relativeDayLabel(
                              commute.serviceDay!,
                              DateTime.now(),
                            ),
                      leadMinutes: pref.advanceWarningMinutes,
                      onToggle: alerts.isLoading ? null : _toggleAlerts,
                    ),
                    const SizedBox(height: FibusSpace.s24),
                    const SectionLabel('Map'),
                    const SizedBox(height: FibusSpace.s8),
                    RouteMapView(
                      route: commute.currentRoute,
                      stop: commute.currentStop,
                      liveBus: commute.liveBus,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.pref});
  final CommutePreference? pref;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final needsHome = pref == null || !pref!.hasHomePin;
    return FibCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            needsHome ? 'Set your home' : 'Choose your bus and stop',
            style: t.titleMedium,
          ),
          const SizedBox(height: FibusSpace.s4),
          Text(
            needsHome
                ? 'Fibus needs your home to time the ride to your stop'
                : 'Pick the route, the bus and where you get on',
            style: t.bodySmall,
          ),
          const SizedBox(height: FibusSpace.s16),
          FilledButton(
            onPressed: () =>
                context.push(needsHome ? '/home-pin' : '/choose-commute'),
            child: Text(needsHome ? 'Set home' : 'Choose commute'),
          ),
        ],
      ),
    );
  }
}

/// Today's alerts as one switch, with what will happen next.
class _AlertsCard extends StatelessWidget {
  const _AlertsCard({
    required this.alerts,
    required this.dayLabel,
    required this.leadMinutes,
    required this.onToggle,
  });

  final AlertSessionProvider alerts;

  /// Empty for today, else `tomorrow` or a weekday name.
  final String dayLabel;
  final int leadMinutes;
  final VoidCallback? onToggle;

  String _subtitle() {
    if (!alerts.isActive) {
      return 'Off. A heads-up $leadMinutes min before, then Leave now';
    }
    switch (alerts.currentState) {
      case AlertSessionStatus.advanceSent:
        return 'Heads-up sent. Leave now is next';
      case AlertSessionStatus.leaveNowSent:
        return 'Leave now sent. You will hear if the bus runs late';
      default:
        return 'A heads-up $leadMinutes min before, then Leave now. '
            'Follows the live bus';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final t = context.type;
    final blocked = alerts.isActive && !alerts.notificationsEnabled;

    return FibCard(
      padding: const EdgeInsets.fromLTRB(
        FibusSpace.s20,
        FibusSpace.s16,
        FibusSpace.s12,
        FibusSpace.s16,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Icon(
              alerts.isActive
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none,
              size: 18,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(width: FibusSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alerts for ${dayLabel.isEmpty ? 'today' : dayLabel}',
                  style: t.titleSmall,
                ),
                const SizedBox(height: FibusSpace.s4),
                Text(
                  blocked
                      ? 'Notifications are off for Fibus in Android settings, '
                            'so alerts cannot reach you'
                      : _subtitle(),
                  style: t.bodySmall?.copyWith(
                    color: blocked ? c.negative : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: FibusSpace.s8),
          Switch(
            value: alerts.isActive,
            onChanged: onToggle == null ? null : (_) => onToggle!(),
          ),
        ],
      ),
    );
  }
}
