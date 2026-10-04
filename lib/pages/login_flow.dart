import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/UserProvider.dart';
import '../services/api.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'homepage.dart';

/// Shared last step of OTP and password login: loads the profile (name and
/// ride OTP) from gotanbackend, asks for a name if the account has none, then
/// opens the home screen.
Future<void> finishLogin(BuildContext context, String phone) async {
  final userProvider = context.read<UserProvider>();
  final profile = await Api.getUser(phone);
  await userProvider.applyProfile(phone, profile);

  // Re-register this device so pushes stop going to a previous account.
  unawaited(NotificationService().resetFcmToken());

  if (!context.mounted) return;
  if (profile.needsName) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NameCaptureScreen()));
    if (!context.mounted) return;
  }
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const HomePage()),
    (route) => false,
  );
}

/// Shown once after signup so riders and shops see a real name.
class NameCaptureScreen extends StatefulWidget {
  const NameCaptureScreen({super.key});

  @override
  State<NameCaptureScreen> createState() => _NameCaptureScreenState();
}

class _NameCaptureScreenState extends State<NameCaptureScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.length < 2) {
      showAppSnack(context, 'Please enter your name', error: true);
      return;
    }
    setState(() => _saving = true);
    final user = context.read<UserProvider>();
    try {
      await Api.updateName(user.phone, name);
      await user.refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: AppColors.tealLight, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: const Icon(Icons.waving_hand_outlined, color: AppColors.teal),
              ),
              const SizedBox(height: 24),
              const Text('What should we call you?',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, fontFamily: AppTheme.displayFamily)),
              const SizedBox(height: 8),
              const Text(
                'Your name is shared with riders and shops so they know who to look for.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(hintText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 20),
              AppButton(label: 'Continue', loading: _saving, onPressed: _save),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Skip for now', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
