import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/theme/app_colors.dart';
import 'package:fibus/core/widgets/glass_card.dart';
import 'package:fibus/models/alert_session.dart';
import 'package:fibus/models/commute_preference.dart';
import 'package:fibus/commuter/providers/alert_session_provider.dart';
import 'package:fibus/commuter/providers/commute_provider.dart';
import 'package:fibus/commuter/widgets/bus_eta_card.dart';
import 'package:fibus/commuter/widgets/departure_countdown.dart';
import 'package:fibus/commuter/widgets/leave_now_banner.dart';
import 'package:fibus/commuter/widgets/route_map_view.dart';
import 'package:fibus/services/auth_service.dart';

/// The central commuter dashboard displaying real-time bus countdown,
/// departure recommendation, alert activation, route mini map, and emergency banners.
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

  Future<void> _handleRefresh() async {
    await context.read<CommuteProvider>().refresh();
  }

  Future<void> _toggleAlerts() async {
    final alertProvider = context.read<AlertSessionProvider>();
    final commuteProvider = context.read<CommuteProvider>();

    if (alertProvider.isActive) {
      await alertProvider.cancelAlerts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Departure alerts cancelled for today.'),
            backgroundColor: AppColors.surfaceElevated,
          ),
        );
      }
    } else {
      if (commuteProvider.currentPreference == null) return;
      await alertProvider.activateAlerts(
        preference: commuteProvider.currentPreference!,
        recommendation: commuteProvider.departureRecommendation,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔔 Departure alerts activated for today!'),
            backgroundColor: AppColors.surfaceElevated,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commuteProvider = context.watch<CommuteProvider>();
    final alertProvider = context.watch<AlertSessionProvider>();

    final pref = commuteProvider.currentPreference;
    final recommendation = commuteProvider.departureRecommendation;
    final isLeaveNow = recommendation?.isLeaveNow ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_bus_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Fi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: 'bus',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: commuteProvider.isLoading && pref == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceElevated,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unconfigured Commute Prompt Card
                    if (pref == null || !pref.isFullyConfigured) ...[
                      _buildSetupRequiredCard(pref),
                      const SizedBox(height: 18),
                    ],

                    // Urgent Leave Now Banner (Shown if now >= leaveBy)
                    if (isLeaveNow && recommendation != null) ...[
                      LeaveNowBanner(
                        targetArrival: recommendation.targetStopArrival,
                        busName: commuteProvider.currentBus?.displayName ?? 'Bus',
                      ),
                    ],

                    // 1. Bus Status & Arrival Card
                    BusEtaCard(
                      bus: commuteProvider.currentBus,
                      route: commuteProvider.currentRoute,
                      stop: commuteProvider.currentStop,
                      liveBus: commuteProvider.liveBus,
                      busEta: commuteProvider.busEta,
                      etaStatus: commuteProvider.etaEstimate.status,
                      delayMinutes: recommendation?.delayMinutes ?? 0,
                    ),

                    const SizedBox(height: 16),

                    // 2. Departure Recommendation Card
                    DepartureCountdown(
                      recommendation: recommendation,
                    ),

                    const SizedBox(height: 18),

                    // 3. Activate Alerts for Today CTA Button
                    _buildAlertActivationButton(alertProvider, commuteProvider),

                    const SizedBox(height: 22),

                    // 4. Route Map Mini View
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Route & Live Position',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (commuteProvider.liveBus != null &&
                            commuteProvider.liveBus!.isLive)
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.statusLive,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'GPS Active',
                                style: TextStyle(
                                  color: AppColors.statusLive,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    RouteMapView(
                      route: commuteProvider.currentRoute,
                      stop: commuteProvider.currentStop,
                      liveBus: commuteProvider.liveBus,
                      height: 190,
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSetupRequiredCard(CommutePreference? pref) {
    final needsHome = pref == null || !pref.hasHomePin;
    return GlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(18),
      borderColor: AppColors.accent.withValues(alpha: 0.4),
      backgroundColor: AppColors.accent.withValues(alpha: 0.1),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assistant_direction_rounded,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  needsHome ? 'Set Your Home Pin' : 'Choose Your Commute',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  needsHome
                      ? 'Drop a map pin on your house to get accurate scooter travel time.'
                      : 'Select your bus route and boarding stop.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (needsHome) {
                context.push('/home-pin');
              } else {
                context.push('/choose-commute');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Set Up',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _alertSubtitle(
    AlertSessionProvider alertProvider,
    CommuteProvider commuteProvider,
  ) {
    final lead = commuteProvider.currentPreference?.advanceWarningMinutes ?? 10;
    if (!alertProvider.notificationsEnabled) {
      return 'Notifications are off for Fibus, so alerts cannot reach you. '
          'Turn them on in Android settings.';
    }
    switch (alertProvider.currentState) {
      case AlertSessionStatus.advanceSent:
        return 'Advance alert sent. Leave now alert is next.';
      case AlertSessionStatus.leaveNowSent:
        return 'Leave now sent. You will hear if the bus is delayed.';
      default:
        return 'Alert $lead min before, then Leave now. Follows the live bus.';
    }
  }

  Widget _buildAlertActivationButton(
    AlertSessionProvider alertProvider,
    CommuteProvider commuteProvider,
  ) {
    final isActive = alertProvider.isActive;

    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.statusLive.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.statusLive.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.statusLive.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.statusLive,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alerts Active for Today',
                    style: TextStyle(
                      color: AppColors.statusLive,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _alertSubtitle(alertProvider, commuteProvider),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: alertProvider.isLoading ? null : _toggleAlerts,
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: alertProvider.isLoading || !commuteProvider.isCommuteSelected
            ? null
            : _toggleAlerts,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: alertProvider.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.alarm_on_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Activate Alerts for Today',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
