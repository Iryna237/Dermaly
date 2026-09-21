import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'ai_chat.dart';
import 'app_colors.dart';
import 'models/app_notification.dart';
import 'notifications_page.dart';
import 'pages/profile_page.dart';
import 'questionnaire.dart';
import 'routine.dart';
import 'services/gemini_service.dart';
import 'services/notification_log.dart';
import 'services/skin_analysis_storage.dart';
import 'skin_progress.dart';
import 'skin_result.dart';

class SkinCareHomePage extends StatefulWidget {
  final String? userName;
  final String profileImagePath;
  final VoidCallback? onProfileTap;

  const SkinCareHomePage({
    super.key,
    this.userName,
    this.profileImagePath = 'assets/images/iryna.jpeg',
    this.onProfileTap,
  });

  @override
  State<SkinCareHomePage> createState() => _SkinCareHomePageState();
}

class _SkinCareHomePageState extends State<SkinCareHomePage> {
  String _displayName = '';
  String? _photoUrl;
  Uint8List? _photoBytes;

  // Flux créé une seule fois : le recréer à chaque build relance la lecture Firestore
  late final Stream<List<AppNotification>> _notifications = NotificationLog.watch();
  bool _isOpeningAnalysis = false;

  /// Première analyse : questionnaire puis scan.
  /// Analyses suivantes : affiche directement le dernier résultat sauvegardé.
  Future<void> _openSkinAnalysis() async {
    if (_isOpeningAnalysis) return;
    setState(() => _isOpeningAnalysis = true);

    SkinAnalysisResult? saved;
    try {
      saved = await SkinAnalysisStorage.load();
    } catch (e) {
      debugPrint('Erreur chargement analyse sauvegardée: $e');
    }

    if (!mounted) return;
    setState(() => _isOpeningAnalysis = false);

    final result = saved;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => result != null
            ? SkinResultPage.fromResult(result)
            : const QuestionnairePage(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initUserData();
  }

  @override
  void didUpdateWidget(covariant SkinCareHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _initUserData();
    }
  }

  void _initUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _photoUrl = user.photoURL;
      
      if (widget.userName != null && widget.userName!.trim().isNotEmpty) {
        _displayName = widget.userName!.trim();
      } else {
        if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
          _displayName = user.displayName!.trim().split(' ')[0];
        } else if (user.email != null && user.email!.trim().isNotEmpty) {
          _displayName = user.email!.trim().split('@')[0];
        } else {
          _displayName = 'Utilisateur';
        }
      }
      _fetchDataFromFirestore(user.uid);
    } else {
      _displayName = 'Utilisateur';
    }
  }

  Future<void> _fetchDataFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final fullName = (data['fullName'] ?? data['name'] ?? '')
            .toString()
            .trim();
        final photoBase64 = data['photoBase64'] as String?;
        final photoUrl = data['photoUrl'] as String?;

        if (mounted) {
          setState(() {
            if (fullName.isNotEmpty) {
              _displayName = fullName.split(' ')[0];
            }
            // 👇 Priorité au base64, fallback URL
            if (photoBase64 != null && photoBase64.isNotEmpty) {
              try {
                _photoBytes = base64Decode(photoBase64);
                _photoUrl = null;
              } catch (e) {
                debugPrint('❌ Base64 decode error: $e');
              }
            } else if (photoUrl != null) {
              _photoUrl = photoUrl;
              _photoBytes = null;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Erreur récupération données utilisateur: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softPurple,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/images/logo.png',
          height: 30,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.terracotta),
          onPressed: () {
            if (widget.onProfileTap != null) {
              widget.onProfileTap!();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildNotificationBell(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Hello, ${_displayName.isNotEmpty ? _displayName : 'Utilisateur'}👋',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkPurple,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.auto_awesome, color: AppColors.terracotta, size: 24),
                        ],
                      ),
                      const Text(
                        'Ready to glow today?',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.greyText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    if (widget.onProfileTap != null) {
                      widget.onProfileTap!();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfilePage()),
                      );
                    }
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.lightPurple,
                    backgroundImage: _photoBytes != null
                        ? MemoryImage(_photoBytes!)
                        : (_photoUrl != null
                        ? NetworkImage(_photoUrl!) as ImageProvider
                        : null),
                    child: (_photoBytes == null && _photoUrl == null)
                        ? ClipOval(
                      child: Image.asset(
                        widget.profileImagePath,
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.person,
                          color: AppColors.terracotta,
                          size: 30,
                        ),
                      ),
                    )
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Skin Score Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.lightPurple,
                    AppColors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.terracotta.withAlpha(26),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Skin Score',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkPurple,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: 78),
                              duration: const Duration(seconds: 2),
                              builder: (context, value, child) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.terracotta,
                                  ),
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                ' / 100',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: AppColors.greyText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Good',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.greyText,
                          ),
                        ),
                        const SizedBox(height: 15),
                        // Horizontal Progress Bar
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.softPurple,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.78,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.terracotta, AppColors.brandPink],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Counter Circle
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.lightPurple, width: 8),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: 0.78),
                            duration: const Duration(seconds: 2),
                            builder: (context, value, child) {
                              return CircularProgressIndicator(
                                value: value,
                                strokeWidth: 8,
                                backgroundColor: AppColors.transparent,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.terracotta),
                              );
                            },
                          ),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 78),
                          duration: const Duration(seconds: 2),
                          builder: (context, value, child) {
                            return Text(
                              '${value.toInt()}%',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkPurple,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Section: Your Skin Journey
            const Text(
              'Your Skin Journey',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkPurple,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 0.9,
              children: [
                _buildJourneyCard(
                  title: 'Skin Analysis',
                  subtitle: 'Analyze your skin with AI',
                  icon: Icons.arrow_forward,
                  color: AppColors.white,
                  showBadge: true,
                  isLoading: _isOpeningAnalysis,
                  onTap: _openSkinAnalysis,
                ),
                _buildJourneyCard(
                  title: 'Skin Progress',
                  subtitle: 'Track your improvement',
                  icon: Icons.bar_chart,
                  color: AppColors.brandPink,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SkinProgressPage()),
                    );
                  },
                ),
                _buildJourneyCard(
                  title: 'Routine',
                  subtitle: 'Personalized skincare routine',
                  icon: Icons.calendar_today,
                  color: AppColors.white,
                  borderColor: AppColors.lightPurple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RoutinePage()),
                    );
                  },
                ),
                _buildJourneyCard(
                  title: 'Consult Dermatologist',
                  subtitle: 'Get expert advice',
                  icon: Icons.chat_bubble_outline,
                  color: AppColors.terracotta,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ClientChatListPage()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Daily Tip Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.lightPurple,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.softPurple),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Daily Tip',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.terracotta,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Drink water, stay hydrated and your skin will thank you 💧',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.darkPurple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/tip_image.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        color: AppColors.white,
                        child: const Icon(Icons.local_drink, color: AppColors.terracotta, size: 40),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// Cloche de l'accueil : le point ne s'affiche que s'il reste des
  /// notifications non lues, et disparaît dès que la page les a marquées lues.
  Widget _buildNotificationBell() {
    return StreamBuilder<List<AppNotification>>(
      stream: _notifications,
      builder: (context, snapshot) {
        final unread = snapshot.data?.where((n) => !n.read).length ?? 0;

        return IconButton(
          tooltip: 'Notifications',
          icon: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none, color: AppColors.terracotta, size: 28),
              if (unread > 0)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.brandPink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationsPage()),
          ),
        );
      },
    );
  }

  Widget _buildJourneyCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    Color? borderColor,
    bool showBadge = false,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color == AppColors.white ? color : color.withAlpha(51),
          borderRadius: BorderRadius.circular(25),
          border: borderColor != null ? Border.all(color: borderColor) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBadge)

            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.darkPurple,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.greyText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.terracotta,
                      ),
                    )
                  : Icon(icon, color: AppColors.terracotta.withAlpha(153), size: 22),
            ),
          ],
        ),
      ),
    );
  }

}
