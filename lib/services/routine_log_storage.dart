import 'package:cloud_firestore/cloud_firestore.dart';
import 'skin_analysis_storage.dart';

/// Etat d'une journee de routine, tel que le Weekly Progress le colore.
enum RoutineDayStatus { missed, partial, complete }

/// Produits coches dans la journee, matin et soir.
///
/// Les totaux sont ceux de la routine au moment ou la journee a ete cochee :
/// une routine modifiee plus tard ne doit pas repeindre les jours passes.
class RoutineDayLog {
  final Set<String> morningDone;
  final Set<String> eveningDone;
  final int morningTotal;
  final int eveningTotal;

  const RoutineDayLog({
    this.morningDone = const {},
    this.eveningDone = const {},
    this.morningTotal = 0,
    this.eveningTotal = 0,
  });

  /// Journee sans aucun produit coche : c'est l'etat de chaque nouveau jour,
  /// puisqu'aucun document n'existe encore pour lui.
  static const RoutineDayLog empty = RoutineDayLog();

  int get doneCount => morningDone.length + eveningDone.length;
  int get totalCount => morningTotal + eveningTotal;

  RoutineDayStatus get status {
    if (totalCount == 0 || doneCount == 0) return RoutineDayStatus.missed;
    return doneCount >= totalCount
        ? RoutineDayStatus.complete
        : RoutineDayStatus.partial;
  }

  bool isDone(String productId, {required bool morning}) =>
      (morning ? morningDone : eveningDone).contains(productId);

  /// Coche ou decoche [productId] pour le moment demande.
  RoutineDayLog toggle(String productId, {required bool morning}) {
    final done = {...morning ? morningDone : eveningDone};
    if (!done.remove(productId)) done.add(productId);
    return RoutineDayLog(
      morningDone: morning ? done : morningDone,
      eveningDone: morning ? eveningDone : done,
      morningTotal: morningTotal,
      eveningTotal: eveningTotal,
    );
  }

  /// Aligne la journee sur la routine actuelle : les produits qui n'en font
  /// plus partie ne comptent plus, ni dans les coches ni dans les totaux.
  RoutineDayLog withRoutine({
    required Set<String> morningIds,
    required Set<String> eveningIds,
  }) {
    return RoutineDayLog(
      morningDone: morningDone.intersection(morningIds),
      eveningDone: eveningDone.intersection(eveningIds),
      morningTotal: morningIds.length,
      eveningTotal: eveningIds.length,
    );
  }

  Map<String, dynamic> toJson() => {
        'morningDone': morningDone.toList(),
        'eveningDone': eveningDone.toList(),
        'morningTotal': morningTotal,
        'eveningTotal': eveningTotal,
      };

  static RoutineDayLog fromJson(Map<String, dynamic> raw) {
    Set<String> ids(Object? value) => {
          for (final id in value as List? ?? const []) id.toString(),
        };

    return RoutineDayLog(
      morningDone: ids(raw['morningDone']),
      eveningDone: ids(raw['eveningDone']),
      morningTotal: (raw['morningTotal'] as num?)?.toInt() ?? 0,
      eveningTotal: (raw['eveningTotal'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Journal quotidien de la routine : un document par jour,
/// `users/{uid}/routineLog/{yyyy-MM-dd}`.
///
/// Une journee sans document est une journee ou rien n'a ete coche, ce qui
/// remet naturellement les cases a zero a chaque changement de date.
class RoutineLogStorage {
  static const String _collection = 'routineLog';

  /// Nombre de jours charges : les 7 du Weekly Progress, plus de quoi
  /// remonter une serie de plusieurs semaines.
  static const int historyDays = 120;

  static CollectionReference<Map<String, dynamic>>? _logs() {
    return SkinAnalysisStorage.userDoc()?.collection(_collection);
  }

  /// Cle du jour (date locale), utilisee comme identifiant du document.
  /// Son ordre alphabetique est l'ordre chronologique.
  static String dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Journees cochees depuis [start] inclus, indexees par [dayKey]
  static Future<Map<String, RoutineDayLog>> loadSince(DateTime start) async {
    final logs = _logs();
    if (logs == null) return {};

    final snapshot = await logs
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: dayKey(start))
        .get();

    return {
      for (final doc in snapshot.docs) doc.id: RoutineDayLog.fromJson(doc.data()),
    };
  }

  /// Enregistre la journee [day] en remplacant ce qui y etait coche
  static Future<void> saveDay(DateTime day, RoutineDayLog log) async {
    final logs = _logs();
    if (logs == null) return;

    await SkinAnalysisStorage.writeWithTimeout(
      logs.doc(dayKey(day)).set(log.toJson()),
    );
  }
}
