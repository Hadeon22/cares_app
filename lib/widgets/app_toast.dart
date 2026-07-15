import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

/// Floating dark toast styled after the web system's #toast
/// (navy pill, gold icon, bottom of the screen).
void showAppToast(BuildContext context, String message,
    {IconData icon = Icons.check_circle_outline}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navyDeep,
        duration: const Duration(milliseconds: 3500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: AppColors.navyBorder),
        ),
        content: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 20),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.onNavy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}
