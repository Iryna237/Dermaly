import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Appointments',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Summary Stats
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('doctorId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                int total = 0;
                int pending = 0;
                int confirmed = 0;

                if (snapshot.hasData) {
                  total = snapshot.data!.docs.length;
                  for (var doc in snapshot.data!.docs) {
                    final status = doc.get('status') ?? 'pending';
                    if (status == 'pending') pending++;
                    if (status == 'accepted' || status == 'confirmed') confirmed++;
                  }
                }

                return Row(
                  children: [
                    _buildStatCard('Total', total.toString(), AppColors.lightPurple),
                    const SizedBox(width: 12),
                    _buildStatCard('Pending', pending.toString(), AppColors.softPurple),
                    const SizedBox(width: 12),
                    _buildStatCard('Confirmed', confirmed.toString(), const Color(0xFFE8F5E9)),
                  ],
                );
              },
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('doctorId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final appointments = snapshot.data?.docs ?? [];

                if (appointments.isEmpty) {
                  return const Center(
                    child: Text('No appointment requests found', style: TextStyle(color: AppColors.greyText)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final doc = appointments[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildAppointmentCard(context, doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
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
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.greyText, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(BuildContext context, String docId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    final name = data['patientName'] ?? 'Unknown Patient';
    final type = data['type'] ?? 'Consultation';
    final date = data['date'] ?? 'No date';
    final time = data['time'] ?? 'No time';

    Color statusColor;
    switch (status) {
      case 'accepted':
      case 'confirmed':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.softGrey),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.lightPurple,
                child: Text(name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.darkPurple)),
                    Text(type, style: const TextStyle(color: AppColors.greyText, fontSize: 13)),
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
                  status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.terracotta),
                  const SizedBox(width: 8),
                  Text(date, style: const TextStyle(fontSize: 13, color: AppColors.darkPurple)),
                  const SizedBox(width: 15),
                  const Icon(Icons.access_time, size: 16, color: AppColors.terracotta),
                  const SizedBox(width: 8),
                  Text(time, style: const TextStyle(fontSize: 13, color: AppColors.darkPurple)),
                ],
              ),
            ],
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateStatus(docId, 'rejected'),
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
                    onPressed: () => _updateStatus(docId, 'accepted'),
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

  Future<void> _updateStatus(String docId, String status) async {
    await FirebaseFirestore.instance.collection('appointments').doc(docId).update({
      'status': status,
    });
  }
}
