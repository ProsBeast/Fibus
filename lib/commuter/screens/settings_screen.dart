import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/theme/app_colors.dart';
import 'package:fibus/core/widgets/glass_card.dart';
import 'package:fibus/services/auth_service.dart';
import 'package:fibus/services/notification_service.dart';
import 'package:fibus/commuter/providers/commute_provider.dart';

/// Settings screen for commuter preferences, alert lead times, notifications,
/// profile, and sign-out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    final enabled = await _notificationService.areNotificationsEnabled();
    if (mounted) {
      setState(() => _notificationsEnabled = enabled);
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to sign out of Fibus Commuter?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthService>().signOut();
      if (mounted) {
        context.go('/sign-in');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final commuteProvider = context.watch<CommuteProvider>();
    final user = authService.currentUser;
    final pref = commuteProvider.currentPreference;

    final advanceMinutes = pref?.advanceWarningMinutes.toDouble() ?? 15.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Card
              GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryContainer,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? Text(
                              (user?.displayName?.isNotEmpty == true
                                      ? user!.displayName![0]
                                      : 'U')
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Commuter',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section 1: Commute Configuration
              const Text(
                'COMMUTE CONFIGURATION',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              GlassCard(
                borderRadius: 18,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.home_rounded,
                          color: AppColors.primaryLight),
                      title: const Text(
                        'Home Location Pin',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                      ),
                      subtitle: Text(
                        pref != null && pref.hasHomePin
                            ? 'Pinned (${pref.homeLatitude.toStringAsFixed(3)}, ${pref.homeLongitude.toStringAsFixed(3)})'
                            : 'Not set yet',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textTertiary),
                      onTap: () => context.push('/home-pin'),
                    ),
                    const Divider(color: AppColors.divider),
                    ListTile(
                      leading: const Icon(Icons.alt_route_rounded,
                          color: AppColors.accent),
                      title: const Text(
                        'Change Route & Bus',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                      ),
                      subtitle: Text(
                        pref != null && pref.routeName.isNotEmpty
                            ? '${pref.routeName} • ${pref.busName}'
                            : 'No route selected',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textTertiary),
                      onTap: () => context.push('/choose-commute'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section 2: Alerts & Lead Times
              const Text(
                'NOTIFICATIONS & TIMING',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              GlassCard(
                borderRadius: 18,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Advance Warning Time',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${advanceMinutes.round()} min',
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: advanceMinutes,
                      min: 5,
                      max: 30,
                      divisions: 5,
                      onChanged: (val) {
                        commuteProvider.updateAdvanceWarningMinutes(val.round());
                      },
                    ),
                    const Divider(color: AppColors.divider),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        _notificationsEnabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        color: _notificationsEnabled
                            ? AppColors.statusLive
                            : AppColors.textTertiary,
                      ),
                      title: const Text(
                        'Push Notifications',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                      ),
                      subtitle: Text(
                        _notificationsEnabled ? 'Enabled' : 'Disabled (Permission required)',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                      value: _notificationsEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (val) async {
                        if (val) {
                          final granted =
                              await _notificationService.requestPermission();
                          setState(() => _notificationsEnabled = granted);
                        } else {
                          setState(() => _notificationsEnabled = false);
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _handleSignOut,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // App Version Footer
              const Center(
                child: Column(
                  children: [
                    Text(
                      'Fibus Commuter',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Version 1.0.0 (Build 1) • India Pilot Edition',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
