import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:posture_corrector/core/utils/notification_service.dart';
import 'firebase_options.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:posture_corrector/core/utils/theme_manager.dart';
import 'package:posture_corrector/core/utils/themes_and_colors.dart';
import 'package:posture_corrector/core/utils/app_logger.dart';
import 'package:posture_corrector/view/splash/splash_auth_screen.dart';
import 'package:posture_corrector/core/repository/firebase_posture_repository.dart';
import 'package:posture_corrector/core/repository/posture_persistence_manager.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppLogger.i("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await NotificationService().init();
  } catch (e) {
    AppLogger.w("Notification init warning: $e");
  }

  try {
    await GoogleSignIn.instance.initialize();
  } catch(e) {
    AppLogger.w("GoogleSignIn initialization warning: $e");
  }

  PosturePersistenceManager().init();

  runApp(
    EasyLocalization(
      supportedLocales: [Locale('en'), Locale('tr')],
      path: 'assets/translations',
      fallbackLocale: Locale('en'),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final FirebasePostureRepository _firebaseRepo = FirebasePostureRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {

      _firebaseRepo.syncOfflineData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, _) {

        final brightness = View.of(context).platformDispatcher.platformBrightness;
        final isDark = currentMode == ThemeMode.dark ||
                      (currentMode == ThemeMode.system && brightness == Brightness.dark);
        final colorScheme = isDark ? darkColorScheme : lightColorScheme;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: colorScheme.surface,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: MaterialApp(
            navigatorObservers: [FlutterSmartDialog.observer],
            builder: FlutterSmartDialog.init(),
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            title: 'Posture & Activity Tracker',
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: currentMode,
            home: const SplashAuthScreen(),
          ),
        );
      },
    );
  }
}
