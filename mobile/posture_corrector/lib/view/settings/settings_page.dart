import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:posture_corrector/core/repository/sqlite_posture_repository.dart';
import 'package:posture_corrector/core/utils/app_events.dart';
import 'package:posture_corrector/core/utils/app_sizes.dart';
import 'package:posture_corrector/core/utils/theme_manager.dart';
import 'package:posture_corrector/core/utils/app_settings.dart';
import 'package:posture_corrector/core/utils/notification_service.dart';
import 'package:posture_corrector/view/reports/ai_onboarding_dialog.dart';
import 'package:posture_corrector/view/splash/login_screen.dart';
import 'package:posture_corrector/view/settings/edit_profile_page.dart';
import 'package:posture_corrector/core/repository/ble_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final BleService _bleService = BleService();
  int _targetDurationMins = 120;
  int _targetSteps = 5000;
  int _targetStandingMins = 60;
  double _uprightThreshold = 15.0;
  bool _notificationsEnabled = true;
  bool _postureSyncEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final mins = await AppSettings.getTargetDurationMins();
    final steps = await AppSettings.getTargetSteps();
    final standing = await AppSettings.getTargetStandingMins();
    final threshold = await AppSettings.getUprightThreshold();
    final notifs = await AppSettings.getNotificationsEnabled();
    final postureSync = await AppSettings.getPostureSyncEnabled();
    if (mounted) {
      setState(() {
        _targetDurationMins = mins;
        _targetSteps = steps;
        _targetStandingMins = standing;
        _uprightThreshold = threshold;
        _notificationsEnabled = notifs;
        _postureSyncEnabled = postureSync;
      });
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    SmartDialog.showLoading(msg: "syncing".tr());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dummy_token');

    await NotificationService().cancelAll();

    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    SmartDialog.dismiss();

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: AppSizes.pagePadding,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildProfileHeader(context, colors),
          AppSizes.gapH16,

          Text(
            'postureAndDeviceSettings'.tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          AppSizes.gapH8,

          _buildSettingsTile(
            context,
            icon: Icons.timer,
            title: 'targetDurationTitle'.tr(),
            subtitle: 'targetDurationSubtitle'.tr(
              namedArgs: {'mins': _targetDurationMins.toString()},
            ),
            onTap: () {
              if (!_bleService.isConnected) {
                SmartDialog.showToast("bleNotConnectedToast".tr());
              } else {
                _showDurationDialog();
              }
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.directions_walk,
            title: 'targetStepsTitle'.tr(),
            subtitle: 'targetStepsSubtitle'.tr(
              namedArgs: {'steps': _targetSteps.toString()},
            ),
            onTap: () {
              _showStepsDialog();
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.accessibility_new_rounded,
            title: 'targetStandingTitle'.tr(),
            subtitle: 'targetStandingSubtitle'.tr(
              namedArgs: {'mins': _targetStandingMins.toString()},
            ),
            onTap: () {
              _showStandingDialog();
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.rotate_right_rounded,
            title: 'slopeToleranceTitle'.tr(),
            subtitle: 'slopeToleranceSubtitle'.tr(
              namedArgs: {'angle': _uprightThreshold.toStringAsFixed(1)},
            ),
            onTap: () {
              if (!_bleService.isConnected) {
                SmartDialog.showToast("bleNotConnectedToast".tr());
              } else {
                _showThresholdDialog();
              }
            },
          ),

          const SizedBox(height: 16),

          Text(
            'applicationSettings'.tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          AppSizes.gapH8,

          _buildSettingsTile(
            context,
            icon: Icons.dark_mode_outlined,
            title: 'theme'.tr(),
            subtitle: 'themeDesc'.tr(),
            trailing: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, currentMode, _) {
                bool isDark = currentMode == ThemeMode.dark;

                return Switch(
                  value: isDark,
                  activeThumbColor: colors.primary,
                  onChanged: (bool newValue) {
                    themeNotifier.value = newValue
                        ? ThemeMode.dark
                        : ThemeMode.light;
                  },
                );
              },
            ),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.language,
            title: 'language'.tr(),
            subtitle: context.locale.toString(),
            onTap: () {
              _showLanguageDialog();
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.notifications_active_outlined,
            title: 'notifications'.tr(),
            subtitle: 'notificationDesc'.tr(),
            trailing: Switch(
              value: _notificationsEnabled,
              activeThumbColor: colors.primary,
              onChanged: (val) async {
                await AppSettings.setNotificationsEnabled(val);
                setState(() {
                  _notificationsEnabled = val;
                });
              },
            ),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.cloud_sync_outlined,
            title: 'postureSyncTitle'.tr(),
            subtitle: 'postureSyncSubtitle'.tr(),
            trailing: Switch(
              value: _postureSyncEnabled,
              activeThumbColor: colors.primary,
              onChanged: (val) async {
                await AppSettings.setPostureSyncEnabled(val);
                setState(() => _postureSyncEnabled = val);
                SmartDialog.showToast(
                  val ? 'postureSyncEnabled'.tr() : 'postureSyncDisabled'.tr(),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'aiReportSettings'.tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          AppSizes.gapH8,

          _buildSettingsTile(
            context,
            icon: Icons.smart_toy_rounded,
            title: 'aiProfileTitle'.tr(),
            subtitle: 'aiProfileSubtitle'.tr(),
            onTap: () {
              showAiOnboardingDialog(context);
            },
          ),

          const SizedBox(height: 24),

          Text(
            'accountSection'.tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 16),

          _buildSettingsTile(
            context,
            icon: Icons.logout,
            title: 'logOut'.tr(),
            iconColor: colors.error,
            textColor: colors.error,
            onTap: () => _handleLogout(context),
          ),

          const SizedBox(height: 32),

          _buildSettingsTile(
            context,
            icon: Icons.bug_report_rounded,
            title: 'Örnek Veri Üret (Test)',
            subtitle:
                'Son 1 ay için veritabanını doldurur. (Daha sonra kaldırılacak)',
            iconColor: Colors.orange,
            textColor: Colors.orange,
            onTap: () async {
              SmartDialog.showLoading(msg: "Veriler Üretiliyor...");
              await SqlitePostureRepository().generateMockData();
              AppEvents.fireRefresh();
              SmartDialog.dismiss();
              SmartDialog.showToast("Örnek veriler başarıyla eklendi.");
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showDurationDialog() async {
    final TextEditingController controller = TextEditingController(
      text: _targetDurationMins.toString(),
    );
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("targetDurationTitle".tr()),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: "totalDurationLabel".tr(),
              hintText: "120",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("cancel".tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = int.tryParse(controller.text);
                if (val != null && val > 0) {
                  await AppSettings.setTargetDurationMins(val);
                  _bleService.sendData('{"targetDuration": $val}');

                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'targetDuration': val});
                  }

                  setState(() {
                    _targetDurationMins = val;
                  });
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text("save".tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showStepsDialog() async {
    final TextEditingController controller = TextEditingController(
      text: _targetSteps.toString(),
    );
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("targetStepsTitle".tr()),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: "stepCountLabel".tr(),
              hintText: "5000",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("cancel".tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = int.tryParse(controller.text);
                if (val != null && val > 0) {
                  await AppSettings.setTargetSteps(val);

                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'targetSteps': val});
                  }

                  setState(() {
                    _targetSteps = val;
                  });
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text("save".tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showStandingDialog() async {
    final TextEditingController controller = TextEditingController(
      text: _targetStandingMins.toString(),
    );
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("targetStandingTitle".tr()),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: "standingDurationLabel".tr(),
              hintText: "60",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("cancel".tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = int.tryParse(controller.text);
                if (val != null && val > 0) {
                  await AppSettings.setTargetStandingMins(val);

                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'targetStandingDuration': val});
                  }

                  setState(() {
                    _targetStandingMins = val;
                  });
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text("save".tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showThresholdDialog() async {
    final TextEditingController controller = TextEditingController(
      text: _uprightThreshold.toStringAsFixed(1),
    );
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("slopeToleranceTitle".tr()),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: "angleToleranceLabel".tr(),
              hintText: "15.0",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("cancel".tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                final val = double.tryParse(
                  controller.text.replaceAll(',', '.'),
                );
                if (val != null && val >= 0) {
                  await AppSettings.setUprightThreshold(val);
                  _bleService.sendData('{"thresholdAngle": $val}');
                  setState(() {
                    _uprightThreshold = val;
                  });
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text("save".tr()),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageDialog() {
    final colors = Theme.of(context).colorScheme;
    SmartDialog.show(
      alignment: Alignment.bottomCenter,
      builder: (context) {
        return Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                'selectLanguage'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              ListTile(
                leading: const Text('🇹🇷', style: TextStyle(fontSize: 24)),
                title: Text(
                  'turkish'.tr(),
                  style: TextStyle(color: colors.onSurface),
                ),
                onTap: () {
                  context.setLocale(const Locale('tr'));
                  SmartDialog.dismiss();
                },
              ),
              ListTile(
                leading: const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                title: Text(
                  'english'.tr(),
                  style: TextStyle(color: colors.onSurface),
                ),
                onTap: () {
                  context.setLocale(const Locale('en'));
                  SmartDialog.dismiss();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, ColorScheme colors) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 100,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Text('profileLoadError'.tr()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String displayName = data['displayName'] ?? 'anonymousUser'.tr();
        final String bio = data['bio'] ?? 'noBio'.tr();
        final String photoBase64 = data['photoBase64'] ?? '';
        final String photoURL = data['photoURL'] ?? '';

        ImageProvider? avatarProvider;
        if (photoBase64.isNotEmpty) {
          avatarProvider = MemoryImage(base64Decode(photoBase64));
        } else if (photoURL.isNotEmpty) {
          avatarProvider = NetworkImage(photoURL);
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.primaryContainer),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: colors.surface,
                backgroundImage: avatarProvider,
                child: avatarProvider == null
                    ? Icon(Icons.person, size: 40, color: colors.primary)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfilePage(),
                    ),
                  );
                },
                style: IconButton.styleFrom(
                  backgroundColor: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.edit_outlined, color: colors.primary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (iconColor ?? colors.primary).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? colors.primary),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor ?? colors.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
