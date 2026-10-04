import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// White rounded card with the website's thin border + soft shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.radius = AppRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor),
    );
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppShadows.soft,
      ),
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

enum ButtonVariant { primary, secondary, accent, destructive, ghost }

/// Button matching the website's `components/ui/Button.jsx` variants.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool loading;
  final IconData? icon;
  final bool expand;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      ButtonVariant.primary => (AppColors.teal, Colors.white, AppColors.teal),
      ButtonVariant.secondary => (AppColors.surface, AppColors.teal, AppColors.teal),
      ButtonVariant.accent => (AppColors.yellow, AppColors.navy, AppColors.yellow),
      ButtonVariant.destructive => (AppColors.error, Colors.white, AppColors.error),
      ButtonVariant.ghost => (Colors.transparent, AppColors.textPrimary, Colors.transparent),
    };
    final disabled = onPressed == null || loading;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: 19, color: fg),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      ],
    );

    final button = Opacity(
      opacity: disabled && !loading ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

enum Tone { neutral, info, success, warning, error }

class StatusChip extends StatelessWidget {
  final String label;
  final Tone tone;
  final bool dense;

  const StatusChip({super.key, required this.label, this.tone = Tone.neutral, this.dense = false});

  static (Color, Color) colors(Tone tone) => switch (tone) {
        Tone.neutral => (AppColors.background, AppColors.textSecondary),
        Tone.info => (AppColors.tealLight, AppColors.tealDark),
        Tone.success => (AppColors.successBg, AppColors.success),
        Tone.warning => (AppColors.warningBg, const Color(0xFFB7791F)),
        Tone.error => (AppColors.errorBg, AppColors.error),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colors(tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: dense ? 11 : 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: AppColors.tealLight, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: AppColors.teal),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              AppButton(label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Label/value line used in summaries and bills.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const InfoRow({super.key, required this.label, required this.value, this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: AppColors.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: bold ? style : style.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(width: 12),
          // Expanded (tight) so textAlign.right pins the value to the edge.
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: valueColor == null ? style : style.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pickup → drop route block with the website's green/orange markers.
class RouteSummary extends StatelessWidget {
  final String pickup;
  final String drop;
  final int maxLines;

  const RouteSummary({super.key, required this.pickup, required this.drop, this.maxLines = 3});

  @override
  Widget build(BuildContext context) {
    Widget stop(Color color, String label, String address) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.6)),
                const SizedBox(height: 2),
                Text(
                  address.isEmpty ? '—' : address,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        stop(AppColors.success, 'PICKUP', pickup),
        Padding(
          padding: const EdgeInsets.only(left: 5),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(width: 2, height: 18, color: AppColors.border),
          ),
        ),
        stop(const Color(0xFFF97316), 'DROP', drop),
      ],
    );
  }
}

/// Network image that upgrades Cloudinary `http://` URLs (blocked as cleartext
/// on Android 9+) and falls back to an icon.
class NetImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final IconData fallbackIcon;
  final double? width;
  final double? height;

  const NetImage(this.url, {super.key, this.fit = BoxFit.cover, this.fallbackIcon = Icons.image_outlined, this.width, this.height});

  static String? secure(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.startsWith('http://') ? 'https://${trimmed.substring(7)}' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final src = secure(url);
    final fallback = Container(
      width: width,
      height: height,
      color: AppColors.background,
      child: Icon(fallbackIcon, color: AppColors.textDisabled, size: 28),
    );
    if (src == null) return fallback;
    return CachedNetworkImage(
      imageUrl: src,
      fit: fit,
      width: width,
      height: height,
      placeholder: (_, __) => Container(width: width, height: height, color: AppColors.background),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.navy,
    ));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: cancelLabel,
                variant: ButtonVariant.secondary,
                height: 44,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: confirmLabel,
                variant: destructive ? ButtonVariant.destructive : ButtonVariant.primary,
                height: 44,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Formats a rupee amount without trailing `.0`.
String rupees(num? amount) {
  if (amount == null) return '₹--';
  if (amount == amount.roundToDouble()) return '₹${amount.round()}';
  return '₹${amount.toStringAsFixed(2)}';
}
