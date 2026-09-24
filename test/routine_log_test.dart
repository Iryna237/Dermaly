import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/services/routine_log_storage.dart';

void main() {
  group('RoutineDayLog', () {
    const morningIds = {'cleanse|foaming cleanser', 'protect|spf 50'};
    const eveningIds = {'cleanse|foaming cleanser'};

    RoutineDayLog dayWithRoutine([RoutineDayLog log = RoutineDayLog.empty]) =>
        log.withRoutine(morningIds: morningIds, eveningIds: eveningIds);

    test('a day with nothing checked is missed', () {
      expect(dayWithRoutine().status, RoutineDayStatus.missed);
    });

    test('a single checked product makes the day partial', () {
      final day = dayWithRoutine().toggle('protect|spf 50', morning: true);
      expect(day.status, RoutineDayStatus.partial);
      expect(day.isDone('protect|spf 50', morning: true), isTrue);
      expect(day.isDone('protect|spf 50', morning: false), isFalse);
    });

    test('the day is complete once morning and evening are checked', () {
      var day = dayWithRoutine();
      for (final id in morningIds) {
        day = day.toggle(id, morning: true);
      }
      expect(day.status, RoutineDayStatus.partial);

      day = day.toggle('cleanse|foaming cleanser', morning: false);
      expect(day.status, RoutineDayStatus.complete);
    });

    test('checking again unchecks', () {
      final day = dayWithRoutine()
          .toggle('protect|spf 50', morning: true)
          .toggle('protect|spf 50', morning: true);
      expect(day.status, RoutineDayStatus.missed);
    });

    test('a product removed from the routine no longer counts', () {
      final day = dayWithRoutine().toggle('protect|spf 50', morning: true);
      final reduced = day.withRoutine(
        morningIds: const {'cleanse|foaming cleanser'},
        eveningIds: eveningIds,
      );
      expect(reduced.doneCount, 0);
      expect(reduced.totalCount, 2);
    });

    test('the day read back is the one that was saved', () {
      final day = dayWithRoutine().toggle('protect|spf 50', morning: true);
      final reloaded = RoutineDayLog.fromJson(day.toJson());
      expect(reloaded.morningDone, day.morningDone);
      expect(reloaded.eveningDone, day.eveningDone);
      expect(reloaded.morningTotal, day.morningTotal);
      expect(reloaded.eveningTotal, day.eveningTotal);
    });

    test('the day key sorts chronologically', () {
      expect(RoutineLogStorage.dayKey(DateTime(2026, 9, 7)), '2026-09-07');
      expect(
        RoutineLogStorage.dayKey(DateTime(2026, 9, 7)).compareTo(
          RoutineLogStorage.dayKey(DateTime(2026, 10, 1)),
        ),
        lessThan(0),
      );
    });
  });
}
