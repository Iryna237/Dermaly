import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/models/consultation.dart';

void main() {
  group('Consultation', () {
    test('the id pairs the patient with the dermatologist', () {
      expect(Consultation.idFor('patient-1', 'derma-1'), 'patient-1_derma-1');
    });

    test('a missing document gives no consultation', () {
      expect(Consultation.fromDoc('c1', null), isNull);
    });

    test('a request without both ids is ignored', () {
      expect(Consultation.fromDoc('c1', {'dermatologistId': 'derma-1'}), isNull);
      expect(
        Consultation.fromDoc('c1', {'patientId': 'patient-1', 'dermatologistId': ''}),
        isNull,
      );
    });

    test('missing names fall back to generic labels', () {
      final consultation = Consultation.fromDoc('c1', {
        'patientId': 'patient-1',
        'dermatologistId': 'derma-1',
      })!;

      expect(consultation.patientName, 'Patient');
      expect(consultation.dermatologistName, 'Dermatologist');
      expect(consultation.createdAt, isNull);
    });

    test('an unknown or missing status stays pending', () {
      Consultation withStatus(Object? status) => Consultation.fromDoc('c1', {
            'patientId': 'patient-1',
            'dermatologistId': 'derma-1',
            'status': status,
          })!;

      expect(withStatus(null).status, ConsultationStatus.pending);
      expect(withStatus('archived').status, ConsultationStatus.pending);
      expect(withStatus('accepted').status, ConsultationStatus.accepted);
      expect(withStatus('declined').status, ConsultationStatus.declined);
    });

    test('the status flags match the status', () {
      Consultation withStatus(ConsultationStatus status) => Consultation(
            id: 'c1',
            patientId: 'patient-1',
            patientName: 'Moussa',
            dermatologistId: 'derma-1',
            dermatologistName: 'Awa',
            status: status,
          );

      final pending = withStatus(ConsultationStatus.pending);
      final accepted = withStatus(ConsultationStatus.accepted);
      final declined = withStatus(ConsultationStatus.declined);

      expect([pending.isPending, pending.isAccepted, pending.isDeclined], [true, false, false]);
      expect([accepted.isPending, accepted.isAccepted, accepted.isDeclined], [false, true, false]);
      expect([declined.isPending, declined.isAccepted, declined.isDeclined], [false, false, true]);
    });

    test('a saved consultation reads back the same', () {
      final original = Consultation(
        id: 'patient-1_derma-1',
        patientId: 'patient-1',
        patientName: 'Moussa Diop',
        dermatologistId: 'derma-1',
        dermatologistName: 'Awa Ndiaye',
        status: ConsultationStatus.accepted,
        createdAt: DateTime(2026, 9, 20, 9, 30),
      );

      final copy = Consultation.fromDoc(original.id, original.toJson())!;

      expect(copy.id, original.id);
      expect(copy.patientId, original.patientId);
      expect(copy.patientName, original.patientName);
      expect(copy.dermatologistId, original.dermatologistId);
      expect(copy.dermatologistName, original.dermatologistName);
      expect(copy.status, original.status);
      expect(copy.createdAt, original.createdAt);
    });
  });
}
