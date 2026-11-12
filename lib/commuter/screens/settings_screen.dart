import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/commuter/providers/commute_provider.dart';
import 'package:fibus/core/constants/app_constants.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/theme/fibus_theme.dart';
import 'package:fibus/core/widgets/fib_card.dart';
import 'package:fibus/services/auth_service.dart';
import 'package:fibus/services/notification_service.dart';

/// Account, commute, alert timing and notification permission.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationService _notificationService = NotificationService.instance;
  bool _notificationsEnabled = true;
  double? _draftLead;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    final enabled = await _notificationService.areNotificationsEnabled();
    if (mounted) setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _requestNotifications() async {
    final granted = await _notificationService.requestPermission();
    if (mounted) setState(() => _notificationsEnabled = granted);
  }

  Future<void> _handleSignOut() async {
    final c = context.fib;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out of Fibus'),
        content: const Text('Today\'s alerts stop until you sign in again'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: c.negative),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<AuthService>().signOut();
    if (mounted) context.go('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    final t = context.type;
    final user = context.watch<AuthService>().currentUser;
    final commute = context.watch<CommuteProvider>();
    final pref = commute.currentPreference;
    final lead =
        _draftLead ??
        (pref?.advanceWarningMinutes ??
                AppConstants.defaultAdvanceWarningMinutes)
            .toDouble();
    final name = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : 'You';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            FibusSpace.page,
            FibusSpace.s8,
            FibusSpace.page,
            FibusSpace.s32,
          ),
          children: [
            FibCard(
              padding: const EdgeInsets.all(FibusSpace.s16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: c.raised,
                    foregroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: t.titleSmall?.copyWith(color: c.textSecondary),
                    ),
                  ),
                  const SizedBox(width: FibusSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: t.titleSmall),
                        if (user?.email != null)
                          Text(
                            user!.email!,
                            style: t.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FibusSpace.s24),
            const SectionLabel('Commute'),
            const SizedBox(height: FibusSpace.s8),
            FibCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _NavRow(
                    icon: Icons.home_outlined,
                    title: 'Home',
                    value: pref != null && pref.hasHomePin
                        ? 'Saved'
                        : 'Not set',
                    onTap: () => context.push('/home-pin'),
                  ),
                  const Divider(indent: 48),
                  _NavRow(
                    icon: Icons.directions_bus_outlined,
                    title: 'Bus and stop',
                    value: pref != null && pref.boardingStopName.isNotEmpty
                        ? pref.boardingStopName
                        : 'Not set',
                    onTap: () => context.push('/choose-commute'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FibusSpace.s24),
            const SectionLabel('Alerts'),
            const SizedBox(height: FibusSpace.s8),
            FibCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Heads-up', style: t.bodyMedium)),
                      Text(
                        '${lead.round()} min before',
                        style: FibusType.figure(context, size: 14),
                      ),
                    ],
                  ),
                  Slider(
                    value: lead.clamp(5.0, 30.0),
                    min: 5,
                    max: 30,
                    divisions: 5,
                    label: '${lead.round()} min',
                    onChanged: (v) => setState(() => _draftLead = v),
                    onChangeEnd: (v) {
                      commute.updateAdvanceWarningMinutes(v.round());
                      setState(() => _draftLead = null);
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: FibusSpace.s12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notifications', style: t.bodyMedium),
                            Text(
                              _notificationsEnabled
                                  ? 'Allowed'
                                  : 'Blocked, so alerts cannot reach you',
                              style: t.bodySmall?.copyWith(
                                color: _notificationsEnabled
                                    ? null
                                    : c.negative,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_notificationsEnabled)
                        OutlinedButton(
                          onPressed: _requestNotifications,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          child: const Text('Allow'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: FibusSpace.s32),
            TextButton(
              onPressed: _handleSignOut,
              style: TextButton.styleFrom(
                foregroundColor: c.negative,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Sign out'),
            ),
            const SizedBox(height: FibusSpace.s16),
            Center(
              child: Text(
                'Fibus 1.0.0 · Route 9 pilot',
                style: FibusType.figure(context, size: 12, color: c.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FibusSpace.s16,
            vertical: FibusSpace.s8,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Icon(icon, size: 18, color: c.textSecondary),
              ),
              const SizedBox(width: FibusSpace.s12),
              Expanded(child: Text(title, style: context.type.bodyMedium)),
              Flexible(
                child: Text(
                  value,
                  style: context.type.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: FibusSpace.s4),
              Icon(Icons.chevron_right, size: 18, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
