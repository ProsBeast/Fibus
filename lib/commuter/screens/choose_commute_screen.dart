import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fibus/commuter/providers/commute_provider.dart';
import 'package:fibus/core/constants/app_constants.dart';
import 'package:fibus/core/theme/fibus_palette.dart';
import 'package:fibus/core/theme/fibus_theme.dart';
import 'package:fibus/core/widgets/error_display.dart';
import 'package:fibus/core/widgets/fib_card.dart';
import 'package:fibus/models/bus_model.dart';
import 'package:fibus/models/route_model.dart';
import 'package:fibus/models/stop_model.dart';
import 'package:fibus/services/firestore_service.dart';

/// Choose route, bus, boarding stop and the advance-warning lead time.
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
  double _advanceWarningMinutes =
      AppConstants.defaultAdvanceWarningMinutes.toDouble();
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
    final saved = context.read<CommuteProvider>().currentPreference;
    try {
      // Only backend-configured routes are listed (PRD FR-02); never invent any.
      _routes = await _firestore.getActiveRoutes();
      if (saved != null) {
        _advanceWarningMinutes = saved.advanceWarningMinutes.toDouble();
      }
      if (_routes.isEmpty) {
        _loadError = 'No bus routes are set up yet. Ask your Fibus admin to add yours';
      } else {
        _selectedRoute = _routes.firstWhere(
          (r) => r.id == saved?.routeId,
          orElse: () => _routes.first,
        );
        await _loadBusesAndStopsForRoute(_selectedRoute!);
      }
    } catch (_) {
      _routes = [];
      _loadError = 'Could not load bus routes. Check your connection';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBusesAndStopsForRoute(RouteModel route) async {
    try {
      _buses = await _firestore.getBusesForRoute(route.id);
      _stops = await _firestore.getStopsForRoute(route);
    } catch (_) {
      _buses = [];
      _stops = [];
      _loadError = 'Could not load buses and stops for ${route.name}';
      return;
    }
    final saved = mounted ? context.read<CommuteProvider>().currentPreference : null;
    _selectedBus = _buses.isEmpty
        ? null
        : _buses.firstWhere((b) => b.id == saved?.busId, orElse: () => _buses.first);
    _selectedStop = _stops.isEmpty
        ? null
        : _stops.firstWhere((st) => st.id == saved?.boardingStopId,
            orElse: () => _stops.first);
    if (_buses.isEmpty || _stops.isEmpty) {
      _loadError =
          '${route.name} has no ${_buses.isEmpty ? 'buses' : 'stops'} set up yet';
    }
  }

  Future<void> _saveCommute() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_selectedRoute == null || _selectedBus == null || _selectedStop == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Pick a route, bus and stop')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<CommuteProvider>().saveCommutePreference(
            route: _selectedRoute!,
            bus: _selectedBus!,
            stop: _selectedStop!,
            advanceWarningMinutes: _advanceWarningMinutes.round(),
          );
      if (mounted) context.go('/dashboard');
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save your commute. Try again')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectRoute(RouteModel r) async {
    setState(() {
      _selectedRoute = r;
      _isLoading = true;
    });
    await _loadBusesAndStopsForRoute(r);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final ready = _routes.isNotEmpty && _buses.isNotEmpty && _stops.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your commute'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : !ready
              ? ErrorDisplay(
                  title: 'Nothing to choose yet',
                  message: _loadError ?? 'No routes, buses or stops are set up',
                  icon: Icons.directions_bus_outlined,
                  onRetry: _loadCatalog,
                )
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(FibusSpace.page,
                        FibusSpace.s8, FibusSpace.page, FibusSpace.s32),
                    children: [
                      const SectionLabel('Route'),
                      const SizedBox(height: FibusSpace.s8),
                      _OptionGroup(children: [
                        for (final r in _routes)
                          _OptionRow(
                            title: r.name,
                            subtitle: r.id == _selectedRoute?.id
                                ? '${_stops.length} stops'
                                : null,
                            selected: r.id == _selectedRoute?.id,
                            onTap: () => _selectRoute(r),
                          ),
                      ]),
                      const SizedBox(height: FibusSpace.s24),
                      const SectionLabel('Bus'),
                      const SizedBox(height: FibusSpace.s8),
                      _OptionGroup(children: [
                        for (final b in _buses)
                          _OptionRow(
                            title: b.displayName,
                            selected: b.id == _selectedBus?.id,
                            onTap: () => setState(() => _selectedBus = b),
                          ),
                      ]),
                      const SizedBox(height: FibusSpace.s24),
                      const SectionLabel('Where you get on'),
                      const SizedBox(height: FibusSpace.s8),
                      _StopLine(
                        stops: _stops,
                        selectedId: _selectedStop?.id,
                        onSelect: (s) => setState(() => _selectedStop = s),
                      ),
                      const SizedBox(height: FibusSpace.s24),
                      const SectionLabel('Heads-up before you leave'),
                      const SizedBox(height: FibusSpace.s8),
                      FibCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text('First alert', style: t.bodyMedium),
                                ),
                                Text(
                                  '${_advanceWarningMinutes.round()} min before',
                                  style: FibusType.figure(context, size: 14),
                                ),
                              ],
                            ),
                            Slider(
                              value: _advanceWarningMinutes,
                              min: 5,
                              max: 30,
                              divisions: 5,
                              label: '${_advanceWarningMinutes.round()} min',
                              onChanged: (v) =>
                                  setState(() => _advanceWarningMinutes = v),
                            ),
                            Text(
                              'Then a Leave now alert at your leave-by time',
                              style: t.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: FibusSpace.s32),
                      FilledButton(
                        onPressed: _isSaving ? null : _saveCommute,
                        child: Text(_isSaving ? 'Saving' : 'Save commute'),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// A card holding a list of choices separated by hairlines.
class _OptionGroup extends StatelessWidget {
  const _OptionGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FibCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: FibusSpace.s16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.type.bodyMedium),
                    if (subtitle != null) Text(subtitle!, style: context.type.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: selected ? c.accentInk : c.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stops listed down a route line, timetable time on the left, like the
/// board at the stop. The chosen stop gets a ring and "Your stop".
class _StopLine extends StatelessWidget {
  const _StopLine({
    required this.stops,
    required this.selectedId,
    required this.onSelect,
  });

  final List<StopModel> stops;
  final String? selectedId;
  final ValueChanged<StopModel> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.fib;
    return FibCard(
      padding: const EdgeInsets.symmetric(vertical: FibusSpace.s8),
      child: Column(
        children: [
          for (var i = 0; i < stops.length; i++)
            _row(context, c, stops[i], first: i == 0, last: i == stops.length - 1),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, FibusPalette c, StopModel s,
      {required bool first, required bool last}) {
    final selected = s.id == selectedId;
    return Semantics(
      selected: selected,
      button: true,
      label: '${s.name}, timetable ${s.scheduledArrivalLocalTime}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => onSelect(s),
          child: Container(
            height: 48,
            color: selected ? c.accentSoft : null,
            padding: const EdgeInsets.symmetric(horizontal: FibusSpace.s16),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(s.scheduledArrivalLocalTime,
                      style: FibusType.figure(context,
                          size: 13,
                          color: selected ? c.textPrimary : c.textSecondary)),
                ),
                SizedBox(
                  width: 24,
                  height: 48,
                  child: CustomPaint(
                    painter: _TickPainter(
                      first: first,
                      last: last,
                      selected: selected,
                      line: c.textMuted.withValues(alpha: 0.4),
                      ink: c.textPrimary,
                      fill: c.surface,
                    ),
                  ),
                ),
                const SizedBox(width: FibusSpace.s12),
                Expanded(
                  child: Text(s.name,
                      style: context.type.bodyMedium?.copyWith(
                          fontWeight: selected ? FontWeight.w500 : FontWeight.w400)),
                ),
                if (selected)
                  Text('Your stop',
                      style: context.type.labelMedium?.copyWith(color: c.accentInk)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter({
    required this.first,
    required this.last,
    required this.selected,
    required this.line,
    required this.ink,
    required this.fill,
  });

  final bool first, last, selected;
  final Color line, ink, fill;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final stroke = Paint()
      ..color = line
      ..strokeWidth = 2;
    canvas.drawLine(Offset(cx, first ? cy : 0), Offset(cx, last ? cy : size.height), stroke);
    if (selected) {
      canvas.drawCircle(Offset(cx, cy), 7, Paint()..color = fill);
      canvas.drawCircle(
          Offset(cx, cy),
          7,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = ink);
    } else {
      canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = fill);
      canvas.drawCircle(
          Offset(cx, cy),
          4,
          Paint()
            ..color = ink.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.selected != selected || old.ink != ink || old.line != line;
}
