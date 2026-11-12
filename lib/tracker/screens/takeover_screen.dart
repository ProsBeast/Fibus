import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/widgets/error_display.dart';
import 'package:fibus/core/widgets/fib_card.dart';
import 'package:fibus/models/live_bus_model.dart';
import 'package:fibus/services/realtime_db_service.dart';
import 'package:fibus/tracker/providers/trip_lifecycle_provider.dart';

/// Take over tracking from a phone whose feed has gone quiet. The old
/// phone's writes are rejected once the session generation moves on.
class TakeoverScreen extends StatefulWidget {
  const TakeoverScreen({super.key, required this.busId});

  final String busId;

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
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not check the current trip. Check your connection';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _executeTakeover() async {
    final lifecycle = context.read<TripLifecycleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await lifecycle.takeoverTrip(widget.busId);
    if (!mounted) return;
    if (success) {
      context.go('/tracking/${widget.busId}');
    } else if (lifecycle.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(lifecycle.error!)));
    }
  }

  String _lastFix() {
    final at = _liveBus?.lastLocationAtServer;
    if (at == null) return 'Never';
    final s = ((DateTime.now().millisecondsSinceEpoch - at) / 1000).round();
    if (s < 60) return '$s s ago';
    if (s < 3600) return '${s ~/ 60} min ago';
    return '${s ~/ 3600} h ago';
  }

  String _feed() {
    final live = _liveBus;
    if (live == null) return 'Not tracking';
    if (live.isLive) return 'Live';
    if (live.isStale) return 'GPS lost';
    return 'Ended';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final c = context.fib;
    final lifecycle = context.watch<TripLifecycleProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Take over tracking')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _errorMessage != null
          ? ErrorDisplay(message: _errorMessage!, onRetry: _fetchLiveStatus)
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                FibusSpace.page,
                FibusSpace.s8,
                FibusSpace.page,
                FibusSpace.s24,
              ),
              children: [
                Text('Track this bus from your phone', style: t.headlineSmall),
                const SizedBox(height: FibusSpace.s8),
                Text(
                  'The other phone stops counting as the tracker. If it '
                  'sends again, its updates are ignored',
                  style: t.bodyMedium?.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: FibusSpace.s24),
                const SectionLabel('Current trip'),
                const SizedBox(height: FibusSpace.s8),
                FibCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FibusSpace.s16,
                  ),
                  child: Column(
                    children: [
                      DetailRow(label: 'Status', value: _feed()),
                      const Divider(),
                      DetailRow(
                        label: 'Last GPS fix',
                        value: _lastFix(),
                        mono: true,
                      ),
                      const Divider(),
                      DetailRow(
                        label: 'Session',
                        value: '${_liveBus?.sessionGeneration ?? 0}',
                        mono: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _isLoading || _errorMessage != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  FibusSpace.page,
                  FibusSpace.s12,
                  FibusSpace.page,
                  FibusSpace.s12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: lifecycle.isProcessing
                          ? null
                          : _executeTakeover,
                      child: Text(
                        lifecycle.isProcessing ? 'Taking over' : 'Take over',
                      ),
                    ),
                    const SizedBox(height: FibusSpace.s8),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
