import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/consultation.dart';
import 'skin_analysis_storage.dart';

/// Demandes de consultation entre patients et dermatologues.
///
/// Collection `consultations`, un document par couple patient/dermatologue.
/// Les requêtes n'utilisent que des égalités et sont triées côté application :
/// Firestore n'exige alors aucun index composite à créer à la main.
class ConsultationService {
  static const String _collectionName = 'consultations';

  static CollectionReference<Map<String, dynamic>> _collection() =>
      FirebaseFirestore.instance.collection(_collectionName);

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static List<Consultation> _decode(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final consultations = [
      for (final doc in snapshot.docs) ?Consultation.fromDoc(doc.id, doc.data()),
    ];
    // La plus récente d'abord ; les demandes sans date passent à la fin
    consultations.sort((a, b) {
      final dateA = a.createdAt, dateB = b.createdAt;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
    return consultations;
  }

  /// Demandes envoyées par le patient connecté, tous états confondus
  static Stream<List<Consultation>> watchForPatient() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    return _collection()
        .where('patientId', isEqualTo: uid)
        .snapshots()
        .map(_decode);
  }

  /// Demandes reçues par le dermatologue connecté, tous états confondus
  static Stream<List<Consultation>> watchForDermatologist() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    return _collection()
        .where('dermatologistId', isEqualTo: uid)
        .snapshots()
        .map(_decode);
  }

  /// Envoie une demande au dermatologue choisi.
  /// Redemander au même dermatologue réécrit la demande existante plutôt que
  /// d'en créer une seconde.
  static Future<void> request({
    required String dermatologistId,
    required String dermatologistName,
    required String patientName,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Please sign in to request a consultation.');
    }

    final consultation = Consultation(
      id: Consultation.idFor(uid, dermatologistId),
      patientId: uid,
      patientName: patientName,
      dermatologistId: dermatologistId,
      dermatologistName: dermatologistName,
      status: ConsultationStatus.pending,
      createdAt: DateTime.now(),
    );

    await SkinAnalysisStorage.writeWithTimeout(
      _collection().doc(consultation.id).set(consultation.toJson()),
    );
  }

  /// Réponse du dermatologue : accepter ouvre le chat côté patient.
  static Future<void> respond(Consultation consultation, {required bool accept}) async {
    await SkinAnalysisStorage.writeWithTimeout(
      _collection().doc(consultation.id).update({
        'status': accept ? ConsultationStatus.accepted.name : ConsultationStatus.declined.name,
        'respondedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }
}
