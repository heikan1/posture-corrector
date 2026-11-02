import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:posture_corrector/core/widgets/base_page_layout.dart';
import 'package:posture_corrector/view/splash/login_screen.dart';

class SplashAuthScreen extends StatefulWidget {
  const SplashAuthScreen({super.key});

  @override
  State<SplashAuthScreen> createState() => _SplashAuthScreenState();
}

class _SplashAuthScreenState extends State<SplashAuthScreen> {
  Future<bool> checkLoginStatus() async {
    await Future.delayed(
      const Duration(seconds: 2),
    );

    final user = FirebaseAuth.instance.currentUser;

    if (user == null || !user.emailVerified) {

      if (user != null && !user.emailVerified) {
        await FirebaseAuth.instance.signOut();
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: FutureBuilder<bool>(
        future: checkLoginStatus(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.health_and_safety,
                    size: 80,
                    color: Colors.white,
                  ),
                  SizedBox(height: 20),
                  CircularProgressIndicator(color: Colors.white),
                ],
              ),
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (snapshot.data == true) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const BasePageLayout(),
                ),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }
          });

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
