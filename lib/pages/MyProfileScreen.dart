import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../global/common.dart';
import '../model/booking.dart';
import '../providers/UserProvider.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../utils/launch.dart';
import '../widgets/ui.dart';
import 'BookingHistoryScreen.dart';
import 'OrderHistoryPage.dart';
import 'PhoneInputPage.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(silent: true));
  }

  Future<void> _refresh({bool silent = false}) async {
    try {
      await context.read<UserProvider>().refresh();
    } catch (e) {
      if (!silent && mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    if (picked == null || !mounted) return;
    final user = context.read<UserProvider>();
    setState(() => _uploading = true);
    try {
      final url = await Api.uploadProfileImage(user.phone, File(picked.path));
      await user.setProfileImage(url);
      if (mounted) showAppSnack(context, 'Profile photo updated');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _editName() async {
    final user = context.read<UserProvider>();
    final controller = TextEditingController(text: user.name == 'Customer' ? '' : user.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Full name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await Api.updateName(user.phone, name);
      await user.refresh();
      if (mounted) showAppSnack(context, 'Name updated');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _setPassword() async {
    final user = context.read<UserProvider>();
    final pass = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set a password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Use it to log in without an OTP.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            TextField(controller: pass, obscureText: true, decoration: const InputDecoration(hintText: 'New password')),
            const SizedBox(height: 10),
            TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(hintText: 'Confirm password')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (pass.text.length < 6) {
      showAppSnack(context, 'Password must be at least 6 characters', error: true);
      return;
    }
    if (pass.text != confirm.text) {
      showAppSnack(context, 'Passwords do not match', error: true);
      return;
    }
    try {
      await Api.setPassword(user.phone, pass.text);
      if (mounted) showAppSnack(context, 'Password saved');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(context, title: 'Log out?', message: 'You can log back in with OTP or password.', confirmLabel: 'Log out');
    if (!ok || !mounted) return;
    await context.read<UserProvider>().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PhoneInputPage()), (_) => false);
  }

  Future<void> _deleteAccount() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete your account?',
      message: 'Your Gotan account, ride and parcel history will be permanently deleted. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final user = context.read<UserProvider>();
    try {
      await Api.deleteAccount(user.phone);
      await user.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PhoneInputPage()), (_) => false);
      showAppSnack(context, 'Your account has been deleted');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
  }

  void _showHelp() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Help & support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              ListTile(
                leading: const Icon(Icons.call_outlined, color: AppColors.teal),
                title: const Text('Call us'),
                subtitle: const Text('+91 ${Common.supportPhone}'),
                onTap: () => callNumber(context, Common.supportPhone),
              ),
              ListTile(
                leading: const Icon(Icons.chat_outlined, color: AppColors.success),
                title: const Text('WhatsApp'),
                onTap: () => openWhatsApp(context, Common.supportPhone, text: 'Hi, I need help with the Gotan app.'),
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline_rounded, color: AppColors.textSecondary),
                title: const Text('Email'),
                subtitle: const Text(Common.supportEmail),
                onTap: () => emailSupport(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    if (!user.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('My profile')),
        body: EmptyState(
          icon: Icons.person_outline_rounded,
          title: 'You are not logged in',
          actionLabel: 'Login',
          onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneInputPage())),
        ),
      );
    }

    Widget tile(IconData icon, String title, VoidCallback onTap, {Color? color, String? subtitle}) => ListTile(
          leading: Icon(icon, color: color ?? AppColors.textSecondary),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: color)),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _uploading ? null : _changePhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.tealLight,
                          child: ClipOval(
                            child: _uploading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
                                : user.profileImage.isEmpty
                                    ? Text(
                                        user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.teal),
                                      )
                                    : NetImage(user.profileImage, width: 72, height: 72, fallbackIcon: Icons.person),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.teal,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        Text('+91 ${user.phone}', style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(user.city, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: _editName, icon: const Icon(Icons.edit_outlined, color: AppColors.teal)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RIDE OTP',
                            style: TextStyle(color: AppColors.yellow, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        SizedBox(height: 2),
                        Text('Riders ask for this before starting a ride or picking up a parcel',
                            style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    user.otp.isEmpty ? '----' : user.otp.split('').join(' '),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, fontFamily: AppTheme.displayFamily),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  tile(Icons.pedal_bike_rounded, 'Ride history',
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingHistoryScreen()))),
                  tile(
                    Icons.inventory_2_outlined,
                    'Parcel history',
                    () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const BookingHistoryScreen(initialKind: BookingKind.parcel))),
                  ),
                  tile(Icons.receipt_long_outlined, 'Shop orders',
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryPage()))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  tile(Icons.lock_outline_rounded, 'Set password', _setPassword, subtitle: 'Log in without OTP'),
                  tile(Icons.support_agent_rounded, 'Help & support', _showHelp),
                  tile(Icons.privacy_tip_outlined, 'Privacy policy', () => openExternal(context, Common.privacyUrl)),
                  tile(Icons.description_outlined, 'Terms & conditions', () => openExternal(context, Common.termsUrl)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  tile(Icons.logout_rounded, 'Log out', _logout),
                  tile(Icons.delete_forever_outlined, 'Delete account', _deleteAccount, color: AppColors.error),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
