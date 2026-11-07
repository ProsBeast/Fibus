import 'package:flutter_test/flutter_test.dart';
import 'package:fibus/commuter/providers/alert_session_provider.dart';
import 'package:fibus/models/alert_session.dart';
import 'package:fibus/services/bus_eta_estimator.dart';

void main() {
  final leaveBy = DateTime(2026, 11, 5, 7, 20);

  AlertAction decide(
    AlertSessionStatus status,
    DateTime now, {
    LiveEtaStatus eta = LiveEtaStatus.live,
    DateTime? leaveByNow,
    DateTime? sentAt,
    DateTime? lastPlanChange,
    bool delayed = false,
  }) =>
      decideAlertAction(
        status: status,
        now: now,
        leaveBy: leaveByNow ?? leaveBy,
        advanceWarningMinutes: 10,
        etaStatus: eta,
        leaveByWhenLeaveNowSent: sentAt,
        lastPlanChangeSentAt: lastPlanChange,
        isDelaySignificant: delayed,
      );

  test('nothing before the advance window', () {
    expect(decide(AlertSessionStatus.monitoring, DateTime(2026, 11, 5, 7, 5)),
        AlertAction.none);
  });

  test('advance warning at leave-by minus the lead time', () {
    expect(decide(AlertSessionStatus.monitoring, DateTime(2026, 11, 5, 7, 10)),
        AlertAction.sendAdvance);
  });

  test('advance is not repeated once sent', () {
    expect(decide(AlertSessionStatus.advanceSent, DateTime(2026, 11, 5, 7, 15)),
        AlertAction.none);
  });

  test('leave now at leave-by, even if advance was skipped', () {
    expect(decide(AlertSessionStatus.advanceSent, leaveBy), AlertAction.sendLeaveNow);
    expect(decide(AlertSessionStatus.monitoring, DateTime(2026, 11, 5, 7, 30)),
        AlertAction.sendLeaveNow);
  });

  test('a later live ETA pushes the alerts later', () {
    final later = leaveBy.add(const Duration(minutes: 8));
    expect(
      decide(AlertSessionStatus.advanceSent, DateTime(2026, 11, 5, 7, 21),
          leaveByNow: later),
      AlertAction.none,
    );
  });

  test('completes once the bus passed the stop', () {
    expect(
      decide(AlertSessionStatus.monitoring, DateTime(2026, 11, 5, 7, 0),
          eta: LiveEtaStatus.passedStop),
      AlertAction.complete,
    );
  });

  test('one plan-change update after leave now when a delay moves the plan', () {
    final now = DateTime(2026, 11, 5, 7, 22);
    final moved = leaveBy.add(const Duration(minutes: 6));
    expect(
      decide(AlertSessionStatus.leaveNowSent, now,
          leaveByNow: moved, sentAt: leaveBy, delayed: true),
      AlertAction.sendPlanChanged,
    );
    // Rate limited.
    expect(
      decide(AlertSessionStatus.leaveNowSent, now,
          leaveByNow: moved, sentAt: leaveBy, delayed: true,
          lastPlanChange: now.subtract(const Duration(minutes: 2))),
      AlertAction.none,
    );
    // Small shifts do not notify.
    expect(
      decide(AlertSessionStatus.leaveNowSent, now,
          leaveByNow: leaveBy.add(const Duration(minutes: 2)),
          sentAt: leaveBy, delayed: true),
      AlertAction.none,
    );
  });

  test('cancelled or completed sessions do nothing', () {
    for (final s in [AlertSessionStatus.cancelled, AlertSessionStatus.completed]) {
      expect(decide(s, DateTime(2026, 11, 5, 7, 30)), AlertAction.none);
    }
  });
}
