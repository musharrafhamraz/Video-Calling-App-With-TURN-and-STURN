import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_panel.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../utils/extensions.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signUp(
        displayName: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = AuthService.friendlyError(e));
    } catch (_) {
      setState(() => _errorMessage = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _errorMessage = null);
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = AuthService.friendlyError(e));
    } catch (_) {
      setState(() => _errorMessage = 'An unexpected error occurred with Google Sign In.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Background Atmospheric Gradients
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Color(0xFF0B1326),
                    Color(0x0DC3C0FF), // primary/5
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 384,
              height: 384,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ).blurred(120),
          ),
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ).blurred(100),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: GlassPanel(
                    padding: const EdgeInsets.all(32),
                    borderRadius: BorderRadius.circular(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Brand Header
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5).withOpacity(0.15),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Create Account',
                          style: textTheme.displayLarge?.copyWith(
                            color: AppColors.onSurface,
                            fontSize: 32,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect with anyone, anywhere, with distraction-free video calls.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CustomTextField(
                                controller: _nameCtrl,
                                label: 'Full Name',
                                hintText: 'Your Name',
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                controller: _emailCtrl,
                                label: 'Email Address',
                                hintText: 'name@company.com',
                                prefixIcon: Icons.mail_outline_rounded,
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                controller: _passwordCtrl,
                                label: 'Create Password',
                                hintText: '••••••••',
                                prefixIcon: Icons.lock_outline_rounded,
                                isPassword: true,
                              ),
                              const SizedBox(height: 24),

                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorContainer.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: textTheme.bodySmall?.copyWith(color: AppColors.error),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (_isLoading)
                                const Center(child: CircularProgressIndicator())
                              else
                                PrimaryButton(
                                  onPressed: _submit,
                                  text: 'Sign Up',
                                  icon: Icons.arrow_forward_rounded,
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Dividers
                        Row(
                          children: [
                            const Expanded(child: Divider(color: AppColors.outlineVariant)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                'OR CONTINUE WITH',
                                style: textTheme.labelSmall?.copyWith(
                                  color: AppColors.outline,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: AppColors.outlineVariant)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Social Buttons
                        PrimaryButton(
                          onPressed: _signInWithGoogle,
                          text: 'Continue with Google',
                          icon: Icons.g_mobiledata_rounded,
                          isSecondary: true,
                        ),

                        const SizedBox(height: 32),

                        // Login link
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: RichText(
                              text: TextSpan(
                                style: textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                                children: [
                                  const TextSpan(text: "Already have an account? "),
                                  TextSpan(
                                    text: 'Log In',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
