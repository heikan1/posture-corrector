import 'package:flutter/material.dart';
import 'package:posture_corrector/core/utils/app_sizes.dart';
import 'package:posture_corrector/core/widgets/base_page_layout.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _isLoginMode = true;

  bool _isPasswordComplex(String password) {
    final complexRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$');
    return complexRegex.hasMatch(password);
  }

  Future<void> _checkAndCreateUserProfile(User user) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      await docRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? 'İsimsiz Kullanıcı',
        'photoURL': user.photoURL ?? '',
        'bio': 'Postürümü iyileştirmeye çalışıyorum!',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  bool _validateInput() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        (!_isLoginMode && confirmPassword.isEmpty)) {
      SmartDialog.showToast('Lütfen tüm alanları doldur!'.tr());
      return false;
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      SmartDialog.showToast('Lütfen geçerli bir e-posta adresi girin!'.tr());
      return false;
    }

    if (!_isLoginMode) {
      if (password != confirmPassword) {
        SmartDialog.showToast('passwordsDoNotMatch'.tr());
        return false;
      }
      if (!_isPasswordComplex(password)) {
        SmartDialog.showToast('passwordComplexityError'.tr());
        return false;
      }
    } else if (password.length < 6) {
      SmartDialog.showToast('Şifreniz en az 6 karakter olmalıdır!'.tr());
      return false;
    }

    return true;
  }

  Future<void> _handleAuth() async {
    if (!_validateInput()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential credential;

      if (_isLoginMode) {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (credential.user != null && !credential.user!.emailVerified) {
          await FirebaseAuth.instance.signOut();
          SmartDialog.showToast('emailNotVerified'.tr());
          setState(() => _isLoading = false);
          return;
        }
        SmartDialog.showToast('loginSuccess'.tr());
      } else {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (credential.user != null) {
          await credential.user!.sendEmailVerification();
          SmartDialog.showToast('registerSuccess'.tr());

          await FirebaseAuth.instance.signOut();
          setState(() {
            _isLoginMode = true;
          });
          return;
        }
      }

      if (credential.user != null && _isLoginMode) {
        await _checkAndCreateUserProfile(credential.user!);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BasePageLayout()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      SmartDialog.showToast(
        '${_isLoginMode ? "logIn".tr() : "signUp".tr()} ${"errorOccurred".tr()}: ${e.message}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final GoogleSignInClientAuthorization? authZ = await googleUser
          .authorizationClient
          .authorizationForScopes(['email', 'profile']);

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authZ?.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      if (userCredential.user != null) {
        SmartDialog.showToast('loginSuccess'.tr());
        await _checkAndCreateUserProfile(userCredential.user!);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BasePageLayout()),
          );
        }
      }
    } catch (e) {
      SmartDialog.showToast('Google ile giriş başarısız: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    var elevatedButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: colors.primary,
      foregroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    var googleButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/app_icon.png',
                  height: 120,
                  width: 120,
                ),
                const SizedBox(height: 24),

                Text(
                  _isLoginMode ? 'splashHeader'.tr() : 'registerTitle'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoginMode ? 'splashDesc'.tr() : 'registerDesc'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 48),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'email'.tr(),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: colors.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: _isLoginMode
                      ? TextInputAction.done
                      : TextInputAction.next,
                  onSubmitted: (_) {
                    if (_isLoginMode && !_isLoading) _handleAuth();
                  },
                  decoration: InputDecoration(
                    labelText: 'password'.tr(),
                    prefixIcon: Icon(Icons.lock_outline, color: colors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (!_isLoginMode) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_isLoading) _handleAuth();
                    },
                    decoration: InputDecoration(
                      labelText: 'confirmPassword'.tr(),
                      prefixIcon: Icon(
                        Icons.lock_reset_outlined,
                        color: colors.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: elevatedButtonStyle,
                    onPressed: _isLoading ? null : _handleAuth,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isLoginMode ? 'logIn'.tr() : 'signUp'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    style: googleButtonStyle,
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    icon: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
                      height: 24,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.g_mobiledata,
                        size: 24,
                        color: Colors.blue,
                      ),
                    ),
                    label: const Text(
                      'Google ile Giriş Yap',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                AppSizes.gapH8,
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                      });
                    },
                    child: Text(
                      _isLoginMode
                          ? "noAccountSignIn".tr()
                          : "alreadyHaveAccount".tr(),
                      style: const TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
