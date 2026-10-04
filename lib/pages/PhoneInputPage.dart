import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'OTPVerificationPage.dart';
import 'homepage.dart';
import 'login_flow.dart';

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  static const countryCode = '+91';

  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _usePassword = false;
  bool _obscure = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validPhone() {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      showAppSnack(context, 'Enter a valid 10-digit mobile number', error: true);
      return null;
    }
    return phone;
  }

  Future<void> _loginWithPassword() async {
    final phone = _validPhone();
    if (phone == null) return;
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      showAppSnack(context, 'Please enter your password', error: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Api.loginWithPassword(phone, password);
      if (!mounted) return;
      await finishLogin(context, phone);
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.statusCode == 404
          ? 'No account found for this number. Log in with OTP to create one.'
          : e.statusCode == 401
              ? 'Incorrect password. Try again or log in with OTP.'
              : e.message;
      showAppSnack(context, msg, error: true);
    } catch (e) {
      if (mounted) showAppSnack(context, 'Login failed. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    final phone = _validPhone();
    if (phone == null) return;
    setState(() => _isLoading = true);

    var handled = false;
    try {
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '$countryCode$phone',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android can verify the SMS automatically; skip the OTP screen.
          if (handled) return;
          handled = true;
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            await Api.authenticate(phone, deviceToken: await Session.deviceToken());
            if (!mounted) return;
            await finishLogin(context, phone);
          } catch (e) {
            if (mounted) {
              setState(() => _isLoading = false);
              showAppSnack(context, e.toString(), error: true);
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          final msg = switch (e.code) {
            'invalid-phone-number' => 'That phone number looks invalid.',
            'too-many-requests' => 'Too many attempts. Please try again later or use password login.',
            'network-request-failed' => 'No internet connection.',
            _ => e.message ?? 'Could not send OTP. Please try again.',
          };
          showAppSnack(context, msg, error: true);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted || handled) return;
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OTPVerificationPage(
                verificationId: verificationId,
                phone: phone,
                resendToken: resendToken,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAppSnack(context, 'Could not send OTP. Please try again.', error: true);
    }
  }

  Future<void> _skip() async {
    await Session.skipLogin();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomePage()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightStatusBar,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Stack(
          children: [
            Positioned(
              top: -80,
              left: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.10), shape: BoxShape.circle),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        if (canPop)
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: _isLoading ? null : _skip,
                          child: const Text('Skip', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Column(
                          children: [
                            Image.asset('assets/images/gologo.png', height: 52),
                            const SizedBox(height: 28),
                            _buildCard(),
                            const SizedBox(height: 20),
                            const Text(
                              'By continuing you agree to our Terms & Privacy Policy.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          const Text.rich(
            TextSpan(
              text: 'Welcome to ',
              children: [TextSpan(text: 'Gotan', style: TextStyle(color: AppColors.teal))],
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _usePassword ? 'Log in with your password' : 'We will send a 6-digit OTP to your number',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Row(
                    children: [
                      Image.asset('assets/images/india.png', width: 22),
                      const SizedBox(width: 6),
                      const Text(countryCode, style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 1),
                    decoration: const InputDecoration(
                      hintText: '10 digit phone number',
                      counterText: '',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_usePassword) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              onSubmitted: (_) => _loginWithPassword(),
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: _usePassword ? 'Log in' : 'Send OTP',
            height: 54,
            loading: _isLoading,
            onPressed: _usePassword ? _loginWithPassword : _sendOtp,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLoading ? null : () => setState(() => _usePassword = !_usePassword),
            child: Text(
              _usePassword ? 'Log in with OTP instead' : 'Log in with password',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
