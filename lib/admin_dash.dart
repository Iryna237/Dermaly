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
          style: TextStyle(color: AppColors.darkPurple, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.terracotta),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
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
          // Sidebar for larger screens, but we'll use a simple layout for now
          NavigationRail(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: AppColors.primaryPurple),
            selectedLabelTextStyle: const TextStyle(color: AppColors.primaryPurple, fontWeight: FontWeight.bold),
            unselectedIconTheme: const IconThemeData(color: AppColors.greyText),
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
          Expanded(
            child: _buildSelectedTab(),
          ),
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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
          ),
          const SizedBox(height: 25),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              
              final docs = snapshot.data!.docs;
              int totalClients = docs.where((d) => d.get('role') == 'client').length;
              int totalDoctors = docs.where((d) => d.get('role') == 'dermatologist' && d.get('status') == 'accepted').length;
              int pendingRequests = docs.where((d) => d.get('role') == 'dermatologist' && d.get('status') == 'pending').length;

              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 1,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 2.5,
                children: [
                  _buildStatCard('Total Clients', totalClients.toString(), Icons.person, Colors.blue),
                  _buildStatCard('Active Doctors', totalDoctors.toString(), Icons.medical_services, Colors.green),
                  _buildStatCard('Pending Requests', pendingRequests.toString(), Icons.hourglass_top, Colors.orange),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 15),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.greyText, fontSize: 14)),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
            ],
          )
        ],
      ),
    );
  }
}

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('No pending requests', style: TextStyle(color: AppColors.greyText, fontSize: 16)),
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

  Widget _buildRequestCard(BuildContext context, String docId, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.lightPurple,
                child: Text(data['fullName']?[0] ?? 'D', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['fullName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(data['email'] ?? '', style: const TextStyle(color: AppColors.greyText, fontSize: 14)),
                  ],
                ),
              ),
              const Icon(Icons.access_time, color: Colors.orange, size: 20),
            ],
          ),
          const Divider(height: 30),
          Row(
            children: [
              _buildInfoChip(Icons.badge, 'ONMC: ${data['onmcNumber']}'),
              const SizedBox(width: 10),
              _buildInfoChip(Icons.location_city, data['city'] ?? 'Unknown'),
            ],
          ),
          const SizedBox(height: 10),
          Text('Degree: ${data['degree']}', style: const TextStyle(fontSize: 14)),
          Text('Establishment: ${data['establishment']}', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 20),
          
          if (data['professionalDocUrl'] != null)
            GestureDetector(
              onTap: () => _showFullImage(context, data['professionalDocUrl']),
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(image: NetworkImage(data['professionalDocUrl']), fit: BoxFit.cover),
                ),
                child: Container(
                  color: Colors.black26,
                  child: const Center(child: Text('View Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ),
            ),
          
          const SizedBox(height: 25),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      decoration: BoxDecoration(color: AppColors.softPurple, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryPurple),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 12, color: AppColors.darkPurple, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String docId, String status) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).update({'status': status});
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(url),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
          ],
        ),
      ),
    );
  }
}

class AdminUsersTab extends StatelessWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.lightPurple,
                child: Icon(data['role'] == 'client' ? Icons.person : Icons.medical_services),
              ),
              title: Text(data['fullName'] ?? 'User'),
              subtitle: Text('${data['role']} • ${data['email']}'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(data['status'] ?? 'accepted').withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  (data['status'] ?? 'accepted').toUpperCase(),
                  style: TextStyle(color: _getStatusColor(data['status'] ?? 'accepted'), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }
}
