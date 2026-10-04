import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../services/api.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'login_flow.dart';

class OTPVerificationPage extends StatefulWidget {
  final String verificationId;
  final String phone;
  final int? resendToken;

  const OTPVerificationPage({super.key, required this.verificationId, required this.phone, this.resendToken});

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> with CodeAutoFill {
  final _otpController = TextEditingController();
  late String _verificationId = widget.verificationId;
  late int? _resendToken = widget.resendToken;
  bool _isVerifying = false;
  int _secondsLeft = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    SmsAutoFill().listenForCode();
    _startCountdown();
  }

  @override
  void dispose() {
    cancel();
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) t.cancel();
      if (mounted) setState(() => _secondsLeft--);
    });
  }

  @override
  void codeUpdated() {
    final c = code;
    if (c != null && c.length == 6) {
      _otpController.text = c;
      _verify();
    }
  }

  Future<void> _verify() async {
    if (_isVerifying) return;
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      showAppSnack(context, 'Please enter the 6-digit OTP', error: true);
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final credential = PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: otp);
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);

      // Trust the number Firebase verified, not the text field.
      final verified = (userCred.user?.phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');
      final phone = verified.length >= 10 ? verified.substring(verified.length - 10) : widget.phone;

      await Api.authenticate(phone, deviceToken: await Session.deviceToken());
      if (!mounted) return;
      await finishLogin(context, phone);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'invalid-verification-code' => 'Incorrect OTP. Please check and try again.',
        'session-expired' => 'This OTP has expired. Tap Resend to get a new one.',
        _ => e.message ?? 'OTP verification failed.',
      };
      showAppSnack(context, msg, error: true);
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    _startCountdown();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+91${widget.phone}',
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        if (mounted) showAppSnack(context, e.message ?? 'Could not resend OTP', error: true);
      },
      codeSent: (id, token) {
        _verificationId = id;
        _resendToken = token;
        if (mounted) showAppSnack(context, 'OTP sent again');
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Verify your number',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, fontFamily: AppTheme.displayFamily)),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'Enter the 6-digit code sent to ',
                  children: [
                    TextSpan(
                      text: '+91 ${widget.phone}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 32),
              PinFieldAutoFill(
                codeLength: 6,
                controller: _otpController,
                autoFocus: true,
                decoration: BoxLooseDecoration(
                  textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  strokeColorBuilder: const FixedColorBuilder(AppColors.border),
                  bgColorBuilder: const FixedColorBuilder(AppColors.background),
                  radius: const Radius.circular(AppRadius.md),
                ),
                onCodeChanged: (c) {
                  if (c != null && c.length == 6) _verify();
                },
              ),
              const SizedBox(height: 28),
              AppButton(label: 'Verify & continue', height: 54, loading: _isVerifying, onPressed: _verify),
              const SizedBox(height: 16),
              Center(
                child: _secondsLeft > 0
                    ? Text('Resend OTP in ${_secondsLeft}s', style: const TextStyle(color: AppColors.textSecondary))
                    : TextButton(onPressed: _resend, child: const Text('Resend OTP')),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Change number', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
