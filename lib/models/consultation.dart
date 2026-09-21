/// État d'une demande de consultation entre un patient et un dermatologue.
enum ConsultationStatus { pending, accepted, declined }

/// Demande de consultation.
///
/// Le chat ne s'ouvre qu'une fois la demande acceptée : c'est le dermatologue
/// qui décide avec qui il discute.
class Consultation {
  final String id;
  final String patientId;
  final String patientName;
  final String dermatologistId;
  final String dermatologistName;
  final ConsultationStatus status;
  final DateTime? createdAt;

  const Consultation({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.dermatologistId,
    required this.dermatologistName,
    required this.status,
    this.createdAt,
  });

  bool get isPending => status == ConsultationStatus.pending;
  bool get isAccepted => status == ConsultationStatus.accepted;
  bool get isDeclined => status == ConsultationStatus.declined;

  /// Identifiant déterministe : un patient ne peut pas empiler deux demandes
  /// vers le même dermatologue.
  static String idFor(String patientId, String dermatologistId) =>
      '${patientId}_$dermatologistId';

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'patientName': patientName,
        'dermatologistId': dermatologistId,
        'dermatologistName': dermatologistName,
        'status': status.name,
        'createdAt': createdAt?.millisecondsSinceEpoch,
      };

  /// Reconstruit une demande depuis Firestore, ou null si les deux identifiants
  /// ne sont pas exploitables.
  static Consultation? fromDoc(String id, Map<String, dynamic>? data) {
    if (data == null) return null;

    final patientId = (data['patientId'] as Object?)?.toString() ?? '';
    final dermatologistId = (data['dermatologistId'] as Object?)?.toString() ?? '';
    if (patientId.isEmpty || dermatologistId.isEmpty) return null;

    final createdAt = data['createdAt'];

    return Consultation(
      id: id,
      patientId: patientId,
      patientName: (data['patientName'] as Object?)?.toString() ?? 'Patient',
      dermatologistId: dermatologistId,
      dermatologistName: (data['dermatologistName'] as Object?)?.toString() ?? 'Dermatologist',
      status: _statusFrom(data['status']),
      createdAt: createdAt is int
          ? DateTime.fromMillisecondsSinceEpoch(createdAt)
          : null,
    );
  }

  /// Un état inconnu est traité comme en attente : la demande reste visible du
  /// dermatologue au lieu de disparaître silencieusement.
  static ConsultationStatus _statusFrom(Object? raw) {
    switch (raw?.toString()) {
      case 'accepted':
        return ConsultationStatus.accepted;
      case 'declined':
        return ConsultationStatus.declined;
      default:
        return ConsultationStatus.pending;
    }
  }
}
