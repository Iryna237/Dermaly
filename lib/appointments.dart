import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'models/consultation.dart';
import 'services/consultation_service.dart';
import 'user_avatar.dart';

/// Demandes de consultation reçues par le dermatologue connecté.
///
/// C'est ici que la demande d'un patient arrive, et c'est l'acceptation qui la
/// fait apparaître dans la messagerie.
class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  // Flux créé une seule fois : le recréer à chaque build relance la lecture Firestore
  late final Stream<List<Consultation>> _consultations =
      ConsultationService.watchForDermatologist();

  Future<void> _respond(Consultation consultation, {required bool accept}) async {
    try {
      await ConsultationService.respond(consultation, accept: accept);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? '${consultation.patientName} added to your messages.'
              : 'Request from ${consultation.patientName} declined.'),
          backgroundColor: accept ? AppColors.primaryPurple : AppColors.greyText,
        ),
      );
    } catch (e) {
      debugPrint('Erreur réponse à la demande: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not answer the request: '
              '${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Consultation Requests',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<List<Consultation>>(
        stream: _consultations,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildMessage('Unable to load your requests.\n${snapshot.error}');
          }

          final consultations = snapshot.data ?? const <Consultation>[];
          final pending = consultations.where((c) => c.isPending).length;
          final accepted = consultations.where((c) => c.isAccepted).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    // Total : toutes les demandes reçues, refus compris
                    _buildStatCard('Total', consultations.length, AppColors.lightPurple),
                    const SizedBox(width: 12),
                    _buildStatCard('Pending', pending, AppColors.softPurple),
                    const SizedBox(width: 12),
                    _buildStatCard('Confirmed', accepted, const Color(0xFFE8F5E9)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recent Requests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
                  ),
                ),
              ),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : consultations.isEmpty
                        ? _buildMessage(
                            'No consultation request yet.\n'
                            'Patients reach you from the Consult Dermatologist screen.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: consultations.length,
                            itemBuilder: (context, index) =>
                                _buildRequestCard(consultations[index]),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.greyText, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(Consultation consultation) {
    final (statusLabel, statusColor) = switch (consultation.status) {
      ConsultationStatus.accepted => ('ACCEPTED', Colors.green),
      ConsultationStatus.declined => ('DECLINED', Colors.red),
      ConsultationStatus.pending => ('PENDING', Colors.orange),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.softGrey),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(
                userId: consultation.patientId,
                backgroundColor: AppColors.lightPurple,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consultation.patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.darkPurple,
                      ),
                    ),
                    const Text(
                      'Consultation request',
                      style: TextStyle(color: AppColors.greyText, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: AppColors.terracotta),
              const SizedBox(width: 8),
              Text(
                _formatDate(consultation.createdAt),
                style: const TextStyle(fontSize: 13, color: AppColors.darkPurple),
              ),
            ],
          ),
          // Seule une demande en attente appelle une décision
          if (consultation.isPending) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respond(consultation, accept: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _respond(consultation, accept: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.greyText, fontSize: 13, height: 1.5),
        ),
      ),
    );
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date unknown';

    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';

    return '${_months[date.month - 1]} ${date.day}, ${date.year} · $hour:$minute $amPm';
  }
}
