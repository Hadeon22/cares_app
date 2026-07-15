import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'data/session.dart';
import 'screens/main_shell.dart';
import 'screens/mis/mis_shell.dart';

void main() {
  runApp(const CaresApp());
}

/// C.A.R.E.S. — Conde Labac Residents System
/// Official mobile portal of Barangay Conde Labac, Batangas City.
///
/// Routing mirrors the web system: visitors and Residents get the
/// public portal (index.html), while Admin/Officer staff land on the
/// MIS dashboard (pages/dashboard.html).
class CaresApp extends StatelessWidget {
  const CaresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'C.A.R.E.S. · Barangay Conde Labac',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AnimatedBuilder(
        animation: AppSession.instance,
        builder: (context, _) {
          final session = AppSession.instance;
          final isStaff = session.role?.isStaff ?? false;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: isStaff
                ? const MisShell(key: ValueKey('mis'))
                : const MainShell(key: ValueKey('portal')),
          );
        },
      ),
    );
  }
}
