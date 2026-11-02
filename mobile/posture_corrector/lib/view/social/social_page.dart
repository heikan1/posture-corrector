import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:posture_corrector/core/models/user_model.dart';
import 'package:posture_corrector/core/repository/social_repository.dart';
import 'package:posture_corrector/core/repository/achievement_service.dart';
import 'package:posture_corrector/view/social/notifications_page.dart';
import 'package:posture_corrector/view/widgets/weekly_progress_header.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  final SocialRepository _socialRepo = SocialRepository();
  final AchievementService _achievementService = AchievementService();

  List<UserModel> _friends = [];
  bool _isLoading = true;
  Set<String> _congratulatedToday = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadCongratulated();
  }

  Future<void> _loadCongratulated() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'congratulated_$today';
    final List<String>? list = prefs.getStringList(key);
    if (list != null) {
      if (mounted) {
        setState(() {
          _congratulatedToday = list.toSet();
        });
      }
    }
  }

  Future<void> _markCongratulated(String friendUid) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'congratulated_$today';

    setState(() {
      _congratulatedToday.add(friendUid);
    });

    await prefs.setStringList(key, _congratulatedToday.toList());
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    try {
      final friends = await _socialRepo.getFriends();
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddFriendDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("addFriend".tr()),
          content: TextField(
            controller: emailController,
            decoration: InputDecoration(
              labelText: "friendEmailLabel".tr(),
              hintText: "exampleEmailHint".tr(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("cancel".tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) return;

                Navigator.pop(context);
                SmartDialog.showLoading(msg: "searching".tr());

                try {
                  final user = await _socialRepo.searchUserByEmail(email);
                  SmartDialog.dismiss();

                  if (user == null) {
                    SmartDialog.showToast("userNotFound".tr());
                  } else {
                    _showUserFoundDialog(user);
                  }
                } catch (e) {
                  SmartDialog.dismiss();
                  SmartDialog.showToast("Hata: $e");
                }
              },
              child: Text("search".tr()),
            ),
          ],
        );
      },
    );
  }

  void _showUserFoundDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("userFound".tr()),
          content: ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  (user.photoBase64 != null && user.photoBase64!.isNotEmpty)
                  ? MemoryImage(base64Decode(user.photoBase64!))
                  : (user.photoURL != null && user.photoURL!.isNotEmpty
                        ? NetworkImage(user.photoURL!)
                        : null),
              child:
                  (user.photoBase64 == null || user.photoBase64!.isEmpty) &&
                      (user.photoURL == null || user.photoURL!.isEmpty)
                  ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : "?",
                    )
                  : null,
            ),
            title: Text(user.displayName),
            subtitle: Text(user.email),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("cancel".tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                SmartDialog.showLoading();
                try {
                  await _socialRepo.sendFriendRequest(user.uid);
                  SmartDialog.dismiss();
                  SmartDialog.showToast("friendRequestSent".tr());
                } catch (e) {
                  SmartDialog.dismiss();
                  SmartDialog.showToast("Hata: $e");
                }
              },
              child: Text("sendRequest".tr()),
            ),
          ],
        );
      },
    );
  }

  void _showAchievementsBottomSheet() async {
    SmartDialog.showLoading();
    final userAchievements = await _achievementService.getUserAchievements();
    SmartDialog.dismiss();

    if (!mounted) return;

    final allAchievements = AchievementService.allAchievements;
    final earnedIds = userAchievements.map((a) => a.id).toList();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "myAchievements".tr(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: allAchievements.length,
                    itemBuilder: (context, index) {
                      final ach = allAchievements[index];
                      final isEarned = earnedIds.contains(ach.id);

                      return Opacity(
                        opacity: isEarned ? 1.0 : 0.4,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isEarned
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isEarned
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ach.icon,
                                style: const TextStyle(fontSize: 40),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ach.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isEarned
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Text(
                                  ach.description,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[800],
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Kapat"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: colors.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              "Henüz arkadaşın yok",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Arkadaşlarını ekleyerek onlarla rekabet et ve birlikte dik durma hedeflerinize ulaşın!",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddFriendDialog,
              icon: const Icon(Icons.person_add),
              label: const Text("Hemen Arkadaş Ekle"),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFriendProfile(UserModel friend) {
    ImageProvider? avatarProvider;
    if (friend.photoBase64 != null && friend.photoBase64!.isNotEmpty) {
      avatarProvider = MemoryImage(base64Decode(friend.photoBase64!));
    } else if (friend.photoURL != null && friend.photoURL!.isNotEmpty) {
      avatarProvider = NetworkImage(friend.photoURL!);
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null
                      ? Text(
                          friend.displayName.isNotEmpty
                              ? friend.displayName[0].toUpperCase()
                              : "?",
                          style: const TextStyle(fontSize: 32),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  friend.displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (friend.bio != null && friend.bio!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      friend.bio!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  "${friend.displayName}'in Başarımları",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: AchievementService.allAchievements.length,
                    itemBuilder: (context, index) {
                      final ach = AchievementService.allAchievements[index];
                      final isEarned = friend.achievements.contains(ach.id);
                      return Opacity(
                        opacity: isEarned ? 1.0 : 0.2,
                        child: Column(
                          children: [
                            Text(
                              ach.icon,
                              style: const TextStyle(fontSize: 24),
                            ),
                            Text(
                              ach.title,
                              style: const TextStyle(fontSize: 8),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Kapat"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendList(ColorScheme colors) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 16),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        final stats = friend.weeklyStats;

        final now = DateTime.now();
        int todaySteps = 0;
        int todayStandingDuration = 0;
        int todayPostureDuration = 0;
        if (stats.containsKey(now.weekday.toString()) &&
            stats[now.weekday.toString()] is Map) {
          todaySteps = stats[now.weekday.toString()]['steps'] ?? 0;
          todayStandingDuration =
              stats[now.weekday.toString()]['standingMins'] ?? 0;
          todayPostureDuration =
              stats[now.weekday.toString()]['uprightMins'] ?? 0;
        }

        ImageProvider? avatarProvider;
        if (friend.photoBase64 != null && friend.photoBase64!.isNotEmpty) {
          avatarProvider = MemoryImage(base64Decode(friend.photoBase64!));
        } else if (friend.photoURL != null && friend.photoURL!.isNotEmpty) {
          avatarProvider = NetworkImage(friend.photoURL!);
        }

        return GestureDetector(
          onTap: () => _showFriendProfile(friend),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: avatarProvider,
                        child: avatarProvider == null
                            ? Text(
                                friend.displayName.isNotEmpty
                                    ? friend.displayName[0].toUpperCase()
                                    : "?",
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  friend.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.celebration),
                                  iconSize: 20,
                                  color:
                                      _congratulatedToday.contains(friend.uid)
                                      ? colors.onSurface.withValues(alpha: 0.2)
                                      : colors.secondary,
                                  tooltip:
                                      _congratulatedToday.contains(friend.uid)
                                      ? "congratulatedToday".tr()
                                      : "congratulateFriend".tr(),
                                  onPressed:
                                      _congratulatedToday.contains(friend.uid)
                                      ? null
                                      : () async {
                                          try {
                                            await _socialRepo
                                                .congratulateFriend(friend.uid);
                                            await _markCongratulated(
                                              friend.uid,
                                            );
                                            SmartDialog.showToast(
                                              "${friend.displayName} tebrik edildi!",
                                            );
                                          } catch (e) {
                                            SmartDialog.showToast("Hata: $e");
                                          }
                                        },
                                ),
                              ],
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.accessibility,
                                      size: 14,
                                      color: colors.outline,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$todayPostureDuration/${friend.targetDuration}",
                                      style: TextStyle(
                                        color: colors.outline,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.directions_walk,
                                      size: 14,
                                      color: colors.outline,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$todaySteps/${friend.targetSteps}",
                                      style: TextStyle(
                                        color: colors.outline,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.man,
                                      size: 14,
                                      color: colors.outline,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$todayStandingDuration/${friend.targetStandingDuration}",
                                      style: TextStyle(
                                        color: colors.outline,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    spacing: 8,
                    children: [
                      ...List.generate(7, (i) {
                        int dayIndex = i + 1;
                        double postureP = 0.0;
                        double stepsP = 0.0;
                        double standingP = 0.0;
                        String dayKey = dayIndex.toString();
                        dynamic dayData = stats[dayKey];

                        if (dayData != null && dayData is Map) {
                          postureP = (dayData['postureProgress'] ?? 0.0)
                              .toDouble();
                          int stp = dayData['steps'] ?? 0;
                          int stndMins = dayData['standingMins'] ?? 0;
                          stepsP = friend.targetSteps > 0
                              ? stp / friend.targetSteps
                              : 0.0;
                          standingP = friend.targetStandingDuration > 0
                              ? stndMins / friend.targetStandingDuration
                              : 0.0;
                        }
                        bool isFuture = now.weekday < dayIndex;
                        return CircularDayProgressIndicator(
                          progressPosture: postureP,
                          progressSteps: stepsP,
                          progressStanding: standingP,
                          isFuture: isFuture,
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sosyal"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddFriendDialog,
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseAuth.instance.currentUser != null
                ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .collection('notifications')
                      .where('isRead', isEqualTo: false)
                      .snapshots()
                : null,
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData) {
                unreadCount = snapshot.data!.docs.length;
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      ).then((_) => _loadFriends());
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_friends.isEmpty)
            _buildEmptyState(colors)
          else
            RefreshIndicator(
              onRefresh: _loadFriends,
              child: _buildFriendList(colors),
            ),

          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: _showAchievementsBottomSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, color: colors.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      "Başarımlarımı Görüntüle",
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
