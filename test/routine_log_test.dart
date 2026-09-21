import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/services/routine_log_storage.dart';

void main() {
  group('RoutineDayLog', () {
    const morningIds = {'cleanse|foaming cleanser', 'protect|spf 50'};
    const eveningIds = {'cleanse|foaming cleanser'};

    RoutineDayLog dayWithRoutine([RoutineDayLog log = RoutineDayLog.empty]) =>
        log.withRoutine(morningIds: morningIds, eveningIds: eveningIds);

    test('une journee sans rien de coche est manquee', () {
      expect(dayWithRoutine().status, RoutineDayStatus.missed);
    });

    test('un seul produit coche rend la journee partielle', () {
      final day = dayWithRoutine().toggle('protect|spf 50', morning: true);
      expect(day.status, RoutineDayStatus.partial);
      expect(day.isDone('protect|spf 50', morning: true), isTrue);
      expect(day.isDone('protect|spf 50', morning: false), isFalse);
    });

    test('la journee est complete une fois matin et soir coches', () {
      var day = dayWithRoutine();
      for (final id in morningIds) {
        day = day.toggle(id, morning: true);
      }
      expect(day.status, RoutineDayStatus.partial);

      day = day.toggle('cleanse|foaming cleanser', morning: false);
      expect(day.status, RoutineDayStatus.complete);
    });

    test('recocher decoche', () {
      final day = dayWithRoutine()
          .toggle('protect|spf 50', morning: true)
          .toggle('protect|spf 50', morning: true);
      expect(day.status, RoutineDayStatus.missed);
    });

    test('un produit retire de la routine ne compte plus', () {
      final day = dayWithRoutine().toggle('protect|spf 50', morning: true);
      final reduced = day.withRoutine(
        morningIds: const {'cleanse|foaming cleanser'},
        eveningIds: eveningIds,
      );
      expect(reduced.doneCount, 0);
      expect(reduced.totalCount, 2);
    });

    test('la journee relue est celle qui a ete enregistree', () {
      final day = dayWithRoutine().toggle('protect|spf 50', morning: true);
      final reloaded = RoutineDayLog.fromJson(day.toJson());
      expect(reloaded.morningDone, day.morningDone);
      expect(reloaded.eveningDone, day.eveningDone);
      expect(reloaded.morningTotal, day.morningTotal);
      expect(reloaded.eveningTotal, day.eveningTotal);
    });

    test('la cle du jour est chronologique', () {
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
