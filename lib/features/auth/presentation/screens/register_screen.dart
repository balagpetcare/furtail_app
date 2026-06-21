import 'package:bpa_app/core/analytics/analytics_events.dart';
import 'package:bpa_app/core/analytics/analytics_service.dart';
import 'package:flutter/material.dart';

import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/usecases/register_usecase.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _identifier = TextEditingController(); // email OR mobile
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;

  late final RegisterUseCase _registerUseCase;

  @override
  void initState() {
    super.initState();
    final remote = AuthRemoteDataSource();
    final repo = AuthRepositoryImpl(remote);
    _registerUseCase = RegisterUseCase(repo);
  }

  String? _nameValidator(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Please enter your full name';
    return null;
  }

  String? _idValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Please enter email or phone';
    final isEmail = s.contains('@');
    final digits = s.replaceAll(RegExp(r'\D'), '');
    final isPhone = digits.length >= 8 && digits.length <= 15;
    if (!isEmail && !isPhone) return 'Enter a valid email or phone number';
    return null;
  }

  String? _passValidator(String? v) {
    final s = (v ?? '');
    if (s.isEmpty) return 'Please enter password';
    if (s.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _confirmValidator(String? v) {
    if ((v ?? '').isEmpty) return 'Please re-enter your password';
    if (v != _password.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _handleRegister() async {
    // Avoid "Null check operator used on a null value" if the Form isn't mounted yet.
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      await _registerUseCase.execute(
        name: _name.text.trim(),
        identifier: _identifier.text.trim(),
        password: _password.text,
      );
      await AnalyticsService.instance.logRegistration(method: AnalyticsAuthMethod.email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration Successful! Please Login.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('Exception')
          ? e.toString().split('Exception: ').last
          : 'Registration Failed';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _identifier.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF00695C);
    const blue = Color(0xFF1565C0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: teal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const AuthHeader(
                  title: "Create Account",
                  subtitle: "Join the BPA community today",
                  titleColor: teal,
                  logoHeight: 120,
                ),
                const SizedBox(height: 30),

                // Register ডিজাইন: radius 30 + border visible (আগের মতো)
                AuthTextField(
                  controller: _name,
                  hintText: 'Full Name',
                  prefixIcon: Icons.person_outline,
                  radius: 30,
                  borderNone: false,
                  filled: false,
                  validator: _nameValidator,
                ),
                const SizedBox(height: 15),

                AuthTextField(
                  controller: _identifier,
                  hintText: 'Email or Mobile',
                  prefixIcon: Icons.email_outlined,
                  radius: 30,
                  borderNone: false,
                  filled: false,
                  validator: _idValidator,
                ),
                const SizedBox(height: 15),

                AuthTextField(
                  controller: _password,
                  hintText: 'Password',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  radius: 30,
                  borderNone: false,
                  filled: false,
                  validator: _passValidator,
                ),
                const SizedBox(height: 15),

                AuthTextField(
                  controller: _confirm,
                  hintText: 'Re-enter Password',
                  prefixIcon: Icons.lock_reset,
                  isPassword: true,
                  radius: 30,
                  borderNone: false,
                  filled: false,
                  validator: _confirmValidator,
                ),

                const SizedBox(height: 30),

                AuthButton(
                  text: 'Sign Up',
                  loading: _loading,
                  onPressed: _handleRegister,
                  color: blue,
                  radius: 30,
                  height: 50,
                  elevation: 2,
                ),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          color: blue,
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
    );
  }
}
