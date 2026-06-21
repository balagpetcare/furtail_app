import 'package:bpa_app/core/analytics/analytics_events.dart';
import 'package:bpa_app/core/analytics/analytics_service.dart';
import 'package:bpa_app/core/theme/theme_extensions.dart';
import 'package:bpa_app/core/theme/app_typography.dart';
import 'package:bpa_app/core/theme/typography.dart';
import 'package:bpa_app/features/notifications/presentation/providers/notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/usecases/login_usecase.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';
import 'register_screen.dart';

// ✅ আপনার প্রকৃত HomeScreen path দিন:
import 'package:bpa_app/features/home/presentation/screens/bpa_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController(); // email OR mobile
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  late final LoginUseCase _loginUseCase;
  late final AuthRepositoryImpl _repo;

  @override
  void initState() {
    super.initState();
    final remote = AuthRemoteDataSource();
    _repo = AuthRepositoryImpl(remote);
    _loginUseCase = LoginUseCase(_repo);
  }

  String? _idValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Please enter email or mobile';
    final isEmail = s.contains('@');
    final isPhone = RegExp(r'^[0-9]+$').hasMatch(s);
    if (!isEmail && !isPhone) return 'Enter a valid email or phone number';
    return null;
  }

  String? _passValidator(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return 'Please enter password';
    if (s.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  final _formKey = GlobalKey<FormState>();

  Future<void> _handleLogin() async {
    // Avoid "Null check operator used on a null value" if the Form isn't mounted yet.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await _loginUseCase.execute(
        identifier: _idController.text.trim(),
        password: _passwordController.text,
      );
      await AnalyticsService.instance.logLogin(method: AnalyticsAuthMethod.email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Login Successful!'),
          backgroundColor: context.bpaSuccess,
        ),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        try {
          ProviderScope.containerOf(context)
              .read(notificationControllerProvider.notifier)
              .registerPushAfterAuth();
        } catch (_) {}
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BPAHomeScreen()),
        );
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('Exception')
          ? e.toString().split('Exception: ').last
          : 'Login failed. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    try {
      setState(() => _isLoading = true);

      final google = GoogleSignIn(
        scopes: const ['email', 'profile'],
      );
      final account = await google.signIn();
      if (account == null) {
        // user cancelled
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google token not found');
      }

      await _repo.loginWithGoogle(idToken: idToken);
      await AnalyticsService.instance.logLogin(method: AnalyticsAuthMethod.google);
      if (!mounted) return;
      try {
        ProviderScope.containerOf(context)
            .read(notificationControllerProvider.notifier)
            .registerPushAfterAuth();
      } catch (_) {}

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BPAHomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFacebookLogin() async {
    try {
      setState(() => _isLoading = true);

      final result = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
      );

      if (result.status != LoginStatus.success) {
        throw Exception(result.message ?? 'Facebook login cancelled');
      }

      final accessToken = result.accessToken?.tokenString;
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Facebook access token not found');
      }

      await _repo.loginWithFacebook(accessToken: accessToken);
      await AnalyticsService.instance.logLogin(method: AnalyticsAuthMethod.facebook);
      if (!mounted) return;
      try {
        ProviderScope.containerOf(context)
            .read(notificationControllerProvider.notifier)
            .registerPushAfterAuth();
      } catch (_) {}

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BPAHomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _comingSoon(String platform) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$platform login'),
        content: const Text(
          'এই সোশ্যাল লগইনটি পরবর্তী আপডেটে যুক্ত হবে।\n\nএখন Google / Facebook দিয়ে লগইন করুন।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  AuthHeader(
                    title: "Welcome Back!",
                    subtitle: "Sign in to continue to BPA",
                    titleColor: primary,
                    logoHeight: 120,
                  ),
                  const SizedBox(height: 30),

                  // ✅ Email or Mobile field (আগের login ডিজাইন + new hint)
                  AuthTextField(
                    controller: _idController,
                    hintText: 'Email or Mobile',
                    prefixIcon: Icons.email_outlined,
                    radius: 15,
                    borderNone: true,
                    validator: _idValidator,
                  ),
                  const SizedBox(height: 15),

                  AuthTextField(
                    controller: _passwordController,
                    hintText: 'Password',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    radius: 15,
                    borderNone: true,
                    validator: _passValidator,
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        "Forgot Password?",
                        style: AppTypography.bodyRegular(context).copyWith(color: primary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  AuthButton(
                    text: 'Login',
                    loading: _isLoading,
                    onPressed: _handleLogin,
                    color: primary,
                    radius: 15,
                    height: 55,
                    elevation: 3,
                  ),

                  const SizedBox(height: 30),

                  Row(
                    children: [
                      Expanded(child: Divider(color: context.outlineColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          "Or connected with",
                          style: AppTypography.caption(context).copyWith(
                            color: context.mutedTextColor,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: context.outlineColor)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _social(FontAwesomeIcons.google, Colors.red, _handleGoogleLogin),
                      const SizedBox(width: 15),
                      _social(
                        FontAwesomeIcons.facebookF,
                        const Color(0xFF1877F2),
                        _handleFacebookLogin,
                      ),
                      const SizedBox(width: 15),
                      _social(
                        FontAwesomeIcons.instagram,
                        const Color(0xFFE1306C),
                        () => _comingSoon('Instagram'),
                      ),
                      const SizedBox(width: 15),
                      _social(FontAwesomeIcons.tiktok, Colors.black, () => _comingSoon('TikTok')),
                      const SizedBox(width: 15),
                      _social(FontAwesomeIcons.whatsapp, const Color(0xFF25D366), () => _comingSoon('WhatsApp')),
                    ],
                  ),

                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: AppTypography.bodyRegular(context).copyWith(
                          color: context.mutedTextColor,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Text(
                          "Create",
                          style: context.appText.bodyLarge!.copyWith(
                            color: primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _social(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
