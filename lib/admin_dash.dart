import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'pages/auth/login.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Dermaly Admin',
          style: TextStyle(
              color: AppColors.darkPurple, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: AppColors.terracotta),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LoginPage()),
                      (route) => false,
                );
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedTabIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            selectedIconTheme:
            const IconThemeData(color: AppColors.primaryPurple),
            selectedLabelTextStyle: const TextStyle(
                color: AppColors.primaryPurple,
                fontWeight: FontWeight.bold),
            unselectedIconTheme:
            const IconThemeData(color: AppColors.greyText),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.verified_user_outlined),
                selectedIcon: Icon(Icons.verified_user),
                label: Text('Requests'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Users'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildSelectedTab()),
        ],
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedTabIndex) {
      case 0:
        return const AdminOverviewTab();
      case 1:
        return const AdminRequestsTab();
      case 2:
        return const AdminUsersTab();
      default:
        return const AdminOverviewTab();
    }
  }
}

// ---------------------------------------------------------------------------
// OVERVIEW
// ---------------------------------------------------------------------------
class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Overview',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.darkPurple),
          ),
          const SizedBox(height: 25),
          StreamBuilder<QuerySnapshot>(
            stream:
            FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Erreur: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }

              final docs = snapshot.data!.docs;

              // ✅ Lecture sûre : on caste en Map et on utilise ?.['key']
              int totalClients = 0;
              int totalDoctors = 0;
              int pendingRequests = 0;
              int totalAdmins = 0;

              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null) continue;

                final role = data['role'] as String?;
                final status = data['status'] as String?;

                switch (role) {
                  case 'client':
                    totalClients++;
                    break;
                  case 'dermatologist':
                    if (status == 'accepted') totalDoctors++;
                    if (status == 'pending') pendingRequests++;
                    break;
                  case 'admin':
                    totalAdmins++;
                    break;
                }
              }

              return GridView.count(
                shrinkWrap: true,
                crossAxisCount:
                MediaQuery.of(context).size.width > 600 ? 3 : 1,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 2.5,
                children: [
                  _buildStatCard('Total Clients', totalClients.toString(),
                      Icons.person, Colors.blue),
                  _buildStatCard('Active Doctors', totalDoctors.toString(),
                      Icons.medical_services, Colors.green),
                  _buildStatCard(
                      'Pending Requests',
                      pendingRequests.toString(),
                      Icons.hourglass_top,
                      Colors.orange),
                  _buildStatCard('Admins', totalAdmins.toString(),
                      Icons.admin_panel_settings, Colors.purple),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 15),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.greyText, fontSize: 14)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkPurple)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// REQUESTS
// ---------------------------------------------------------------------------
class AdminRequestsTab extends StatelessWidget {
  const AdminRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'dermatologist')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('No pending requests',
                    style: TextStyle(
                        color: AppColors.greyText, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildRequestCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(
      BuildContext context, String docId, Map<String, dynamic> data) {
    // ✅ Support des deux formats : ancien (URL) et nouveau (base64)
    final docUrl = data['professionalDocUrl'] as String?;
    final docBase64 = data['professionalDocBase64'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.lightPurple,
                child: Text(
                  (data['fullName'] as String?)?.isNotEmpty == true
                      ? data['fullName'][0]
                      : 'D',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['fullName'] ?? 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(data['email'] ?? '',
                        style: const TextStyle(
                            color: AppColors.greyText, fontSize: 14)),
                  ],
                ),
              ),
              const Icon(Icons.access_time,
                  color: Colors.orange, size: 20),
            ],
          ),
          const Divider(height: 30),
          Row(
            children: [
              _buildInfoChip(
                  Icons.badge, 'ONMC: ${data['onmcNumber'] ?? '-'}'),
              const SizedBox(width: 10),
              _buildInfoChip(Icons.location_city,
                  data['city'] as String? ?? 'Unknown'),
            ],
          ),
          const SizedBox(height: 10),
          Text('Degree: ${data['degree'] ?? '-'}',
              style: const TextStyle(fontSize: 14)),
          Text('Establishment: ${data['establishment'] ?? '-'}',
              style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 20),

          // Aperçu du document : base64 en priorité, sinon URL
          if (docBase64 != null && docBase64.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullImageBase64(context, docBase64),
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black12,
                ),
                child: const Center(
                  child: Text('View Document (base64)',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            )
          else if (docUrl != null && docUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _showFullImageUrl(context, docUrl),
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                      image: NetworkImage(docUrl), fit: BoxFit.cover),
                ),
                child: Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Text('View Document',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            )
          else
            const Text('Aucun document fourni',
                style: TextStyle(color: AppColors.greyText)),

          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _updateStatus(docId, 'rejected'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Reject Request'),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateStatus(docId, 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Accept & Verify'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: AppColors.softPurple,
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryPurple),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.darkPurple,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String docId, String status) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(docId)
        .update({'status': status});
  }

  void _showFullImageUrl(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(url),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  void _showFullImageBase64(BuildContext context, String base64Str) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(
              base64Decode(base64Str),
              fit: BoxFit.contain,
            ),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// USERS
// ---------------------------------------------------------------------------
class AdminUsersTab extends StatelessWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>?;
            if (data == null) return const SizedBox.shrink();

            // ✅ Lecture sûre avec valeurs par défaut
            final role = data['role'] as String? ?? 'unknown';
            final status = data['status'] as String? ?? 'accepted';
            final fullName = data['fullName'] as String? ?? 'User';
            final email = data['email'] as String? ?? '';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.lightPurple,
                child: Icon(_iconForRole(role)),
              ),
              title: Text(fullName),
              subtitle: Text('$role • $email'),
              trailing: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _iconForRole(String role) {
    switch (role) {
      case 'client':
        return Icons.person;
      case 'dermatologist':
        return Icons.medical_services;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}