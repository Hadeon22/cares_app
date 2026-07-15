import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

/// Form + alert building blocks shared by the service flows and MIS
/// modules — mobile equivalents of the web's .form-group, .alert-*,
/// .badge-* and .modal-* styles.

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
    this.obscureText = false,
    this.helper,
    this.onTap,
    this.onChanged,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool readOnly;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? helper;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onTap: onTap,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            filled: true,
            fillColor: readOnly ? AppColors.cream : AppColors.surface,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
  });

  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T)? itemLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item,
                child: Text(
                  itemLabel?.call(item) ?? '$item',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

enum AlertKind { info, success, warning, danger }

/// Web .alert-info / -success / -warning / -danger equivalent.
class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.kind,
    required this.child,
  });

  AlertBanner.text({super.key, required this.kind, required String text,
      TextStyle? style})
      : child = Text(text, style: style);

  final AlertKind kind;
  final Widget child;

  static const _colors = {
    AlertKind.info: (Color(0xFFEFF6FF), Color(0xFF1D4ED8), Icons.info_outline),
    AlertKind.success:
        (Color(0xFFF0FDF4), Color(0xFF15803D), Icons.check_circle_outline),
    AlertKind.warning: (
      Color(0xFFFFFBEB),
      Color(0xFFB45309),
      Icons.warning_amber_rounded
    ),
    AlertKind.danger: (
      Color(0xFFFEF2F2),
      Color(0xFFB91C1C),
      Icons.error_outline
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = _colors[kind]!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: DefaultTextStyle(
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: fg, height: 1.45),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

enum BadgeKind { success, warning, danger, info, gold, gray }

/// Web .badge-* pill equivalent.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.text, {super.key, required this.kind});
  final String text;
  final BadgeKind kind;

  static const _colors = {
    BadgeKind.success: (Color(0xFFDCFCE7), Color(0xFF15803D)),
    BadgeKind.warning: (Color(0xFFFEF3C7), Color(0xFFB45309)),
    BadgeKind.danger: (Color(0xFFFEE2E2), Color(0xFFB91C1C)),
    BadgeKind.info: (Color(0xFFDBEAFE), Color(0xFF1D4ED8)),
    BadgeKind.gold: (AppColors.goldSoft, AppColors.goldDeep),
    BadgeKind.gray: (Color(0xFFF1F5F9), Color(0xFF475569)),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors[kind]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Header used at the top of full-screen service flows — icon chip +
/// title, mirroring the web modal header.
class ServiceFlowHeader extends StatelessWidget {
  const ServiceFlowHeader({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.inkMuted, height: 1.5),
      ),
    );
  }
}
