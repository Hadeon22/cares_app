import 'package:flutter/material.dart';

import '../../data/session.dart';
import '../../models/models.dart';
import '../../screens/claim_account_screen.dart';
import '../../screens/gis_map_screen.dart';
import '../../screens/login_screen.dart';
import '../../screens/services/certificate_request_screen.dart';
import '../../screens/services/feedback_screen.dart';
import '../../screens/services/incident_report_screen.dart';
import '../../screens/services/residency_search_screen.dart';
import '../constants/app_colors.dart';

/// Services that file something under your name — these require an account,
/// so requests can be tracked, auto-filled and notified. The GIS map stays
/// public and Account Claiming must work signed-out by definition.
const _requiresSignIn = {
  ServiceAction.residency,
  ServiceAction.certificates,
  ServiceAction.incidents,
  ServiceAction.feedback,
};

/// Opens the screen for a service — the mobile counterpart of the web's
/// openServicePopup(service).
void openService(BuildContext context, ServiceAction action) {
  if (_requiresSignIn.contains(action) && !AppSession.instance.isSignedIn) {
    _showSignInFirst(context);
    return;
  }
  final Widget screen;
  switch (action) {
    case ServiceAction.residency:
      screen = const ResidencySearchScreen();
    case ServiceAction.certificates:
      screen = const CertificateRequestScreen();
    case ServiceAction.incidents:
      screen = const IncidentReportScreen();
    case ServiceAction.feedback:
      screen = const FeedbackScreen();
    case ServiceAction.gis:
      screen = Scaffold(
        appBar: AppBar(title: const Text('Community GIS Map')),
        body: const GisMapScreen(),
      );
    case ServiceAction.accounts:
      screen = const ClaimAccountScreen();
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

void _showSignInFirst(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.lock_outline, color: AppColors.gold, size: 32),
      title: const Text('Sign in required'),
      content: const Text(
        'Please sign in to your C.A.R.E.S. account first to use this '
        'service. Your requests are linked to your barangay record so you '
        'can track them and get notified.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
          icon: const Icon(Icons.login, size: 16),
          label: const Text('Sign In'),
        ),
      ],
    ),
  );
}
