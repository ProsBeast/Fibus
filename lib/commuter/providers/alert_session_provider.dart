import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:fibus/commuter/providers/commute_provider.dart';
import 'package:fibus/models/alert_session.dart';
import 'package:fibus/models/commute_preference.dart';
import 'package:fibus/services/bus_eta_estimator.dart';
import 'package:fibus/services/firestore_service.dart';
import 'package:fibus/services/notification_service.dart';
import 'package:fibus/services/route_service.dart';
import 'package:fibus/services/service_calendar.dart';

/// What the alert state machine should do at a given moment (PRD §9.7).
enum AlertAction { none, sendAdvance, sendLeaveNow, sendPlanChanged, complete }

/// Pure decision step of the alert state machine, kept separate so it can be
/// unit-tested without Firebase or notifications.
AlertAction decideAlertAction({
  required AlertSessionStatus status,
  required DateTime now,
  required DateTime leaveBy,
  required int advanceWarningMinutes,
  required LiveEtaStatus etaStatus,
  DateTime? leaveByWhenLeaveNowSent,
  DateTime? lastPlanChangeSentAt,
  bool isDelaySignificant = false,
}) {
  final active =
      status == AlertSessionStatus.monitoring ||
      status == AlertSessionStatus.advanceSent ||
      status == AlertSessionStatus.leaveNowSent;
  if (!active) return AlertAction.none;

  // The bus already went past the stop: stop all pending alerts.
  if (etaStatus == LiveEtaStatus.passedStop) return AlertAction.complete;

  if (status != AlertSessionStatus.leaveNowSent) {
    if (!now.isBefore(leaveBy)) return AlertAction.sendLeaveNow;
    final advanceAt = leaveBy.subtract(
      Duration(minutes: advanceWarningMinutes),
    );
    if (status == AlertSessionStatus.monitoring && !now.isBefore(advanceAt)) {
      return AlertAction.sendAdvance;
    }
    return AlertAction.none;
  }

  // Leave now already sent: one rate-limited update if a significant delay
  // moved the plan at least 5 minutes later.
  if (isDelaySignificant && leaveByWhenLeaveNowSent != null) {
    final shift = leaveBy.difference(leaveByWhenLeaveNowSent);
    final rateOk =
        lastPlanChangeSentAt == null ||
        now.difference(lastPlanChangeSentAt) >= const Duration(minutes: 10);
    if (shift >= const Duration(minutes: 5) && rateOk) {
      return AlertAction.sendPlanChanged;
    }
  }
  return AlertAction.none;
}

/// Provider managing the commuter's daily alert session lifecycle: monitoring,
/// advance warning, Leave now, plan-change update, completion and cancel.
///
/// It follows the live recommendation from [CommuteProvider] (see
/// [syncFromCommute]), so the leave-by time moves with the bus's live ETA.
/// While the app is running it sends alerts itself; it also keeps both alerts
/// scheduled with the OS at the current leave-by time so they still arrive if
/// the app is backgrounded or closed (using the last known ETA).
class AlertSessionProvider extends ChangeNotifier {
  AlertSessionProvider({
    FirestoreService? firestoreService,
    NotificationService? notificationService,
  }) : _firestore = firestoreService ?? FirestoreService.instance,
       _notifications = notificationService ?? NotificationService.instance;

  final FirestoreService _firestore;
  final NotificationService _notifications;

  AlertSession? _activeSession;
  bool _isLoading = false;
  String? _errorMessage;
  String? _activeUserId;
  StreamSubscription<AlertSession?>? _sessionSubscription;
  Timer? _notificationWatcherTimer;

  // Latest inputs from CommuteProvider.
  DepartureRecommendation? _recommendation;
  CommutePreference? _preference;
  LiveEtaStatus _etaStatus = LiveEtaStatus.noTracker;
  String _busName = 'Your bus';
  String _stopName = 'your stop';

  // Reconciliation bookkeeping.
  DateTime? _osScheduledLeaveBy;
  AlertSessionStatus? _osScheduledForStatus;
  DateTime? _persistedLeaveBy;
  DateTime? _lastPersistAt;
  DateTime? _leaveByWhenLeaveNowSent;
  DateTime? _lastPlanChangeSentAt;
  bool _acting = false;
  bool _notificationsEnabled = true;
  DateTime? _permissionCheckedAt;

  // Getters
  AlertSession? get activeSession => _activeSession;

  /// True only for a pending session that belongs to the service day the
  /// dashboard is showing, never for a leftover from an earlier day.
  bool get isActive {
    final s = _activeSession;
    return s != null && s.isActive && s.serviceDate == _targetServiceDate;
  }

  AlertSessionStatus get currentState =>
      _activeSession?.status ?? AlertSessionStatus.inactive;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// False when Android notifications are blocked for Fibus (FR-29).
  bool get notificationsEnabled => _notificationsEnabled;

  DateTime? _serviceDay;
  String? _subscribedDate;

  /// The service date (`yyyy-MM-dd`) alerts are for: today, or the next
  /// service day once today's bus has gone. Follows [CommuteProvider].
  String get _targetServiceDate =>
      serviceDateKey(_serviceDay ?? DateTime.now());

  /// Initializes provider for current logged-in user.
  void initForUser(String uid) {
    if (_activeUserId == uid) return;
    _activeUserId = uid;
    _subscribeToActiveSession();
    _startNotificationWatcher();
  }

  /// Receives the latest recommendation and ETA quality from [commute].
  /// Called by the ProxyProvider whenever the commute state changes.
  void syncFromCommute(CommuteProvider commute) {
    _recommendation = commute.departureRecommendation;
    _preference = commute.currentPreference;
    _etaStatus = commute.etaEstimate.status;
    _serviceDay = commute.serviceDay;
    final bus = commute.currentBus?.displayName;
    if (bus != null && bus.isNotEmpty) _busName = bus;
    final stop = commute.currentStop?.name;
    if (stop != null && stop.isNotEmpty) _stopName = stop;
  }

  /// Listens to the alert session for the target service date.
  void _subscribeToActiveSession() {
    if (_activeUserId == null) return;

    final date = _targetServiceDate;
    _subscribedDate = date;
    _sessionSubscription?.cancel();
    _sessionSubscription = _firestore
        .streamActiveAlertSession(_activeUserId!, date)
        .listen(
          (session) {
            _activeSession = session;
            if (session == null) _resetBookkeeping();
            notifyListeners();
          },
          onError: (err) {
            developer.log('Alert session stream error', error: err);
          },
        );
  }

  /// Moves to a new service date: when midnight passes, or when today's bus
  /// has gone and the dashboard turns to the next service day. The previous
  /// day's session is closed so it can never look like live alerts.
  Future<void> _rollOver() async {
    final old = _activeSession;
    _activeSession = null;
    _resetBookkeeping();
    if (old != null && old.isActive && old.id.isNotEmpty) {
      await _cancelScheduled();
      _persist(old.copyWith(status: AlertSessionStatus.completed));
    }
    _subscribeToActiveSession();
    notifyListeners();
  }

  /// Saves without waiting. Firestore only completes a write when the
  /// server confirms it, so awaiting here would stall alerts while offline.
  void _persist(AlertSession session) {
    unawaited(
      _firestore.updateAlertSession(session).catchError((Object e) {
        developer.log('Failed to persist alert session', error: e);
      }),
    );
  }

  void _resetBookkeeping() {
    _osScheduledLeaveBy = null;
    _osScheduledForStatus = null;
    _persistedLeaveBy = null;
    _lastPersistAt = null;
    _leaveByWhenLeaveNowSent = null;
    _lastPlanChangeSentAt = null;
  }

  /// Starts the ticker that checks alert thresholds while a session is active.
  void _startNotificationWatcher() {
    _notificationWatcherTimer?.cancel();
    _notificationWatcherTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _tick(),
    );
  }

  Future<void> _tick() async {
    if (_acting) return;
    _acting = true;
    try {
      if (_activeUserId != null && _subscribedDate != _targetServiceDate) {
        await _rollOver();
      }
      await _refreshPermission();
      await _checkAlertTriggers();
    } catch (e, stack) {
      developer.log('Alert check failed', error: e, stackTrace: stack);
    } finally {
      _acting = false;
    }
  }

  Future<void> _refreshPermission({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _permissionCheckedAt != null &&
        now.difference(_permissionCheckedAt!) < const Duration(seconds: 30)) {
      return;
    }
    _permissionCheckedAt = now;
    final enabled = await _notifications.areNotificationsEnabled();
    if (enabled != _notificationsEnabled) {
      _notificationsEnabled = enabled;
      notifyListeners();
    }
  }

  String _fmt(DateTime t) => DateFormat('hh:mm a').format(t);

  Future<void> _checkAlertTriggers() async {
    final session = _activeSession;
    if (session == null || !isActive) return;

    final rec = _recommendation;
    // "The bus passed your stop" is about today's run only; it must not
    // close a session armed for the next service day.
    final sessionIsToday =
        session.serviceDate == serviceDateKey(DateTime.now());
    final leaveBy = rec?.recommendedLeaveBy ?? session.recommendedLeaveBy;
    if (leaveBy == null) return;
    final now = DateTime.now();
    final lead = _preference?.advanceWarningMinutes ?? 10;

    final action = decideAlertAction(
      status: session.status,
      now: now,
      leaveBy: leaveBy,
      advanceWarningMinutes: lead,
      etaStatus: sessionIsToday ? _etaStatus : LiveEtaStatus.noTracker,
      leaveByWhenLeaveNowSent:
          _leaveByWhenLeaveNowSent ?? session.recommendedLeaveBy,
      lastPlanChangeSentAt: _lastPlanChangeSentAt,
      isDelaySignificant: rec?.isDelaySignificant ?? false,
    );

    switch (action) {
      case AlertAction.sendAdvance:
        final minutes = (leaveBy.difference(now).inSeconds / 60).ceil();
        await _notifications.cancel(
          NotificationService.advanceWarningNotificationId,
        );
        await _notifications.showAdvanceWarningNotification(
          busName: _busName,
          minutesRemaining: minutes < 1 ? 1 : minutes,
          leaveTimeFormatted: _fmt(leaveBy),
        );
        await _saveSession(
          session.copyWith(
            status: AlertSessionStatus.advanceSent,
            advanceNotificationStatus: 'sent',
          ),
          rec,
        );
        break;
      case AlertAction.sendLeaveNow:
        await _notifications.cancel(NotificationService.leaveNowNotificationId);
        await _notifications.showLeaveNowNotification(
          busName: _busName,
          stopName: _stopName,
          etaFormatted: _fmt(rec?.busEta ?? session.busEta ?? leaveBy),
        );
        _leaveByWhenLeaveNowSent = leaveBy;
        await _saveSession(
          session.copyWith(
            status: AlertSessionStatus.leaveNowSent,
            leaveNowStatus: 'sent',
          ),
          rec,
        );
        break;
      case AlertAction.sendPlanChanged:
        _lastPlanChangeSentAt = now;
        _leaveByWhenLeaveNowSent = leaveBy;
        await _notifications.showPlanChangedNotification(
          busName: _busName,
          delayMinutes: rec?.delayMinutes ?? 0,
          leaveTimeFormatted: _fmt(leaveBy),
        );
        await _saveSession(session, rec);
        break;
      case AlertAction.complete:
        await _cancelScheduled();
        await _saveSession(
          session.copyWith(status: AlertSessionStatus.completed),
          rec,
        );
        break;
      case AlertAction.none:
        await _reconcileScheduled(session, leaveBy, lead);
        await _maybePersistRecommendation(session, rec);
        break;
    }
  }

  /// Keeps OS-scheduled alerts at the current leave-by time (best effort).
  Future<void> _reconcileScheduled(
    AlertSession session,
    DateTime leaveBy,
    int lead,
  ) async {
    final moved =
        _osScheduledLeaveBy == null ||
        leaveBy.difference(_osScheduledLeaveBy!).abs() >=
            const Duration(seconds: 60);
    if (!moved && _osScheduledForStatus == session.status) return;

    final now = DateTime.now();
    final advanceAt = leaveBy.subtract(Duration(minutes: lead));
    if (session.status == AlertSessionStatus.monitoring &&
        advanceAt.isAfter(now)) {
      await _notifications.scheduleDepartureAlert(
        id: NotificationService.advanceWarningNotificationId,
        when: advanceAt,
        title: 'Leave in about $lead minutes',
        body: 'Head out by ${_fmt(leaveBy)} to catch $_busName.',
      );
    }
    if (session.status != AlertSessionStatus.leaveNowSent &&
        leaveBy.isAfter(now)) {
      await _notifications.scheduleDepartureAlert(
        id: NotificationService.leaveNowNotificationId,
        when: leaveBy,
        title: 'Leave now',
        body: 'Leave now to catch $_busName at $_stopName.',
      );
    }
    _osScheduledLeaveBy = leaveBy;
    _osScheduledForStatus = session.status;
  }

  Future<void> _cancelScheduled() async {
    await _notifications.cancel(
      NotificationService.advanceWarningNotificationId,
    );
    await _notifications.cancel(NotificationService.leaveNowNotificationId);
    _osScheduledLeaveBy = null;
    _osScheduledForStatus = null;
  }

  /// Stores the moving recommendation on the session (versioned), at most
  /// once a minute and only when leave-by shifted by a minute or more.
  Future<void> _maybePersistRecommendation(
    AlertSession session,
    DepartureRecommendation? rec,
  ) async {
    if (rec == null) return;
    final now = DateTime.now();
    final shifted =
        _persistedLeaveBy == null ||
        rec.recommendedLeaveBy.difference(_persistedLeaveBy!).abs() >=
            const Duration(minutes: 1);
    final throttled =
        _lastPersistAt != null &&
        now.difference(_lastPersistAt!) < const Duration(minutes: 1);
    if (!shifted || throttled) return;
    await _saveSession(session, rec);
  }

  Future<void> _saveSession(
    AlertSession session,
    DepartureRecommendation? rec,
  ) async {
    final changed =
        rec != null &&
        session.recommendedLeaveBy != null &&
        rec.recommendedLeaveBy.difference(session.recommendedLeaveBy!).abs() >=
            const Duration(minutes: 1);
    final updated = rec == null
        ? session
        : session.copyWith(
            busEta: rec.busEta,
            recommendedLeaveBy: rec.recommendedLeaveBy,
            scooterDurationSeconds: rec.scooterDurationSeconds,
            safetyMarginSeconds: rec.safetyMarginSeconds,
            recommendationVersion:
                session.recommendationVersion + (changed ? 1 : 0),
          );
    _activeSession = updated;
    _persistedLeaveBy = updated.recommendedLeaveBy;
    _lastPersistAt = DateTime.now();
    notifyListeners();
    _persist(updated);
  }

  /// Turns alerts on for the target service date. One session per commuter
  /// per date (a fixed document id), so repeated taps cannot create copies.
  /// Works offline: alerts are local, and the record syncs later.
  Future<void> activateAlerts({
    required CommutePreference preference,
    DepartureRecommendation? recommendation,
  }) async {
    if (_activeUserId == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _notifications.requestPermission();
      await _refreshPermission(force: true);

      if (_subscribedDate != _targetServiceDate) await _rollOver();

      final rec = recommendation ?? _recommendation;
      final date = _targetServiceDate;
      final session = AlertSession(
        id: '${_activeUserId!}_$date',
        commuterUid: _activeUserId!,
        preferenceId: preference.id,
        serviceDate: date,
        busId: preference.busId,
        routeId: preference.routeId,
        boardingStopId: preference.boardingStopId,
        status: AlertSessionStatus.monitoring,
        scheduledArrival: rec == null
            ? null
            : rec.busEta.subtract(Duration(minutes: rec.delayMinutes)),
        busEta: rec?.busEta,
        scooterDurationSeconds: rec?.scooterDurationSeconds ?? 600,
        safetyMarginSeconds: rec?.safetyMarginSeconds ?? 120,
        recommendedLeaveBy: rec?.recommendedLeaveBy,
      );

      _resetBookkeeping();
      _activeSession = session;
      _persistedLeaveBy = session.recommendedLeaveBy;
      unawaited(
        _firestore.createAlertSession(session).catchError((Object e) {
          developer.log('Failed to save alert session', error: e);
          return session.id;
        }),
      );

      _isLoading = false;
      notifyListeners();
      // Evaluate immediately: if leave-by is already past, Leave now goes out
      // right away (PRD §9.6).
      unawaited(_tick());
    } catch (e, stack) {
      developer.log('Failed to activate alerts', error: e, stackTrace: stack);
      _errorMessage = 'Could not turn on alerts';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Cancels the currently active alert session.
  Future<void> cancelAlerts() async {
    final sessionId = _activeSession?.id;
    if (sessionId == null || sessionId.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _notifications.cancelAll();
      _activeSession = _activeSession?.copyWith(
        status: AlertSessionStatus.cancelled,
      );
      _resetBookkeeping();
      _isLoading = false;
      notifyListeners();
      unawaited(
        _firestore.cancelAlertSession(sessionId).catchError((Object e) {
          developer.log('Failed to save alert cancellation', error: e);
        }),
      );
    } catch (e, stack) {
      developer.log('Failed to cancel alerts', error: e, stackTrace: stack);
      _errorMessage = 'Could not cancel alerts.';
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _notificationWatcherTimer?.cancel();
    super.dispose();
  }
}
