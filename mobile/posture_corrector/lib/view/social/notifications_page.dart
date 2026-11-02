import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:posture_corrector/core/repository/social_repository.dart';
import 'package:posture_corrector/core/models/user_model.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:posture_corrector/core/utils/app_logger.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final SocialRepository _socialRepo = SocialRepository();
  List<UserModel> _friendRequests = [];
  bool _isLoadingRequests = true;

  @override
  void initState() {
    super.initState();
    _loadFriendRequests();
    _markAllRead();
  }

  Future<void> _markAllRead() async {
    try {
      await _socialRepo.markAllNotificationsAsRead();
    } catch (e) {
      AppLogger.e("Error marking notifications as read", e);
    }
  }

  Future<void> _loadFriendRequests() async {
    try {
      final requests = await _socialRepo.getFriendRequests();
      if (mounted) {
        setState(() {
          _friendRequests = requests;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
        });
      }
    }
  }

  Future<void> _acceptRequest(String uid) async {
    SmartDialog.showLoading();
    try {
      await _socialRepo.acceptFriendRequest(uid);
      await _loadFriendRequests();
      SmartDialog.dismiss();
      SmartDialog.showToast("Arkadaşlık isteği kabul edildi!");
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast("Hata: $e");
    }
  }

  Future<void> _declineRequest(String uid) async {
    SmartDialog.showLoading();
    try {
      await _socialRepo.declineFriendRequest(uid);
      await _loadFriendRequests();
      SmartDialog.dismiss();
      SmartDialog.showToast("İstek reddedildi.");
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast("Hata: $e");
    }
  }

  Widget _buildFriendRequestsSection(ColorScheme colors) {
    if (_isLoadingRequests) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_friendRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "friendRequests".tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _friendRequests.length,
          itemBuilder: (context, index) {
            final user = _friendRequests[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : "?",
                ),
              ),
              title: Text(
                user.displayName,
                style: TextStyle(color: colors.onSurface),
              ),
              subtitle: Text(
                user.email,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.check_circle, color: colors.primary),
                    onPressed: () => _acceptRequest(user.uid),
                  ),
                  IconButton(
                    icon: Icon(Icons.cancel, color: colors.error),
                    onPressed: () => _declineRequest(user.uid),
                  ),
                ],
              ),
            );
          },
        ),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text("notifications".tr()),
        backgroundColor: colors.surface,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildFriendRequestsSection(colors)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "congratulationsAndAchievements".tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _socialRepo.getNotificationsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        "noNotifications".tr(),
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final data = docs[index].data();
                  final id = docs[index].id;
                  final isRead = data['isRead'] ?? false;
                  final title = data['title'] ?? 'notification'.tr();
                  final message = data['message'] ?? '';

                  return ListTile(
                    tileColor: isRead
                        ? null
                        : colors.secondaryContainer.withValues(alpha: 0.5),
                    leading: Icon(
                      data['type'] == 'achievement'
                          ? Icons.emoji_events
                          : Icons.celebration,
                      color: colors.primary,
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      message,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    onTap: () {
                      if (!isRead) _socialRepo.markNotificationAsRead(id);
                    },
                  );
                }, childCount: docs.length),
              );
            },
          ),
        ],
      ),
    );
  }
}
