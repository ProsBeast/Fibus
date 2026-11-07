import 'package:flutter_test/flutter_test.dart';
import 'package:fibus/services/route_service.dart';

void main() {
  group('RouteService.computeDeparture', () {
    final service = RouteService.instance;
    final scheduled = DateTime(2026, 11, 3, 7, 50);

    test('leave-by = busEta - 5 min boarding - scooter - safety margin', () {
      final rec = service.computeDeparture(
        busEta: scheduled,
        scooterDurationSeconds: 600,
        scheduledArrival: scheduled,
      );

      expect(rec.targetStopArrival, DateTime(2026, 11, 3, 7, 45));
      expect(
        rec.recommendedLeaveBy,
        rec.targetStopArrival.subtract(
          Duration(seconds: 600 + rec.safetyMarginSeconds),
        ),
      );
    });

    test('safety margin is 2 min base plus at most 5 min', () {
      final short = service.computeDeparture(
        busEta: scheduled,
        scooterDurationSeconds: 60,
      );
      final long = service.computeDeparture(
        busEta: scheduled,
        scooterDurationSeconds: 36000,
      );

      expect(short.safetyMarginSeconds, greaterThanOrEqualTo(120));
      expect(long.safetyMarginSeconds, 120 + 300);
    });

    test('a bus 5+ minutes late is a significant delay', () {
      final late = service.computeDeparture(
        busEta: scheduled.add(const Duration(minutes: 5)),
        scooterDurationSeconds: 600,
        scheduledArrival: scheduled,
      );
      final slightlyLate = service.computeDeparture(
        busEta: scheduled.add(const Duration(minutes: 4)),
        scooterDurationSeconds: 600,
        scheduledArrival: scheduled,
      );

      expect(late.isDelaySignificant, isTrue);
      expect(late.delayMinutes, 5);
      expect(slightlyLate.isDelaySignificant, isFalse);
    });
  });
}
