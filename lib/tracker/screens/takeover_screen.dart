import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/theme/app_colors.dart';
import 'package:fibus/core/widgets/glass_card.dart';
import 'package:fibus/models/live_bus_model.dart';
import 'package:fibus/services/realtime_db_service.dart';
import 'package:fibus/tracker/providers/trip_lifecycle_provider.dart';

/// Screen managing authoritative handover/takeover of an active or stale tracking session.
///
/// Prompts the operator with current broadcast age and previous operator UID,
/// explains the generation increment mechanism, and triggers [TripLifecycleProvider.takeoverTrip].
class TakeoverScreen extends StatefulWidget {
  final String busId;

  const TakeoverScreen({super.key, required this.busId});

  @override
  State<TakeoverScreen> createState() => _TakeoverScreenState();
}

class _TakeoverScreenState extends State<TakeoverScreen> {
  final RealtimeDbService _rtdbService = RealtimeDbService();

  bool _isLoading = true;
  LiveBusModel? _liveBus;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLiveStatus();
  }

  Future<void> _fetchLiveStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final live = await _rtdbService.getLiveBus(widget.busId);
      if (mounted) {
        setState(() {
          _liveBus = live;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to inspect current session: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _executeTakeover() async {
    final lifecycle = context.read<TripLifecycleProvider>();
    final success = await lifecycle.takeoverTrip(widget.busId);

    if (success && mounted) {
      context.go('/tracking/${widget.busId}');
    } else if (mounted && lifecycle.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lifecycle.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _formatAge() {
    final live = _liveBus;
    if (live == null || live.lastLocationAtServer == null) {
      return 'No broadcast history';
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffSeconds = ((now - live.lastLocationAtServer!) / 1000).round();
    if (diffSeconds < 60) return '$diffSeconds seconds ago';
    final diffMinutes = diffSeconds ~/ 60;
    return '$diffMinutes minute${diffMinutes > 1 ? "s" : ""} ago';
  }

  @override
  Widget build(BuildContext context) {
    final lifecycle = context.watch<TripLifecycleProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Takeover Bus ${widget.busId}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.trackerAmber),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon Header
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: AppColors.warning,
                        size: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Headline
                  const Text(
                    'Session Takeover Requested',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are about to transfer tracking authority for Bus ${widget.busId} to your device.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Current Session Details Card
                  GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CURRENT SESSION STATUS',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildDetailRow(
                          label: 'Feed Status',
                          value: _liveBus?.isLive == true
                              ? 'ACTIVE BROADCAST'
                              : (_liveBus?.isStale == true ? 'STALE' : 'OFFLINE'),
                          valueColor: _liveBus?.isLive == true
                              ? AppColors.statusLive
                              : AppColors.warning,
                        ),
                        const Divider(height: 18, color: AppColors.border),
                        _buildDetailRow(
                          label: 'Last GPS Fix',
                          value: _formatAge(),
                        ),
                        const Divider(height: 18, color: AppColors.border),
                        _buildDetailRow(
                          label: 'Current Generation',
                          value: '#${_liveBus?.sessionGeneration ?? 0}',
                        ),
                        const Divider(height: 18, color: AppColors.border),
                        _buildDetailRow(
                          label: 'Previous Operator',
                          value: _liveBus != null && _liveBus!.operatorUid.isNotEmpty
                              ? _liveBus!.operatorUid
                              : 'None recorded',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Explanation Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.trackerAmber,
                          size: 22,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Authoritative Handover: The session generation will be incremented. The previous operator\'s device will be automatically invalidated if it attempts to broadcast.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Takeover Action Button
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.trackerGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.trackerAmber.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: lifecycle.isProcessing ? null : _executeTakeover,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: lifecycle.isProcessing
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black87,
                                ),
                              ),
                            )
                          : const Text(
                              'CONFIRM & TAKE OVER TRACKING',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Cancel Button
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text(
                      'Cancel and Return',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
