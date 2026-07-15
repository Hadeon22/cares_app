import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../screens/claim_account_screen.dart';
import '../../screens/gis_map_screen.dart';
import '../../screens/services/certificate_request_screen.dart';
import '../../screens/services/feedback_screen.dart';
import '../../screens/services/incident_report_screen.dart';
import '../../screens/services/residency_search_screen.dart';

/// Opens the screen for a service — the mobile counterpart of the web's
/// openServicePopup(service).
void openService(BuildContext context, ServiceAction action) {
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
