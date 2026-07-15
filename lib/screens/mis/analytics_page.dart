import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../widgets/charts.dart';
import 'mis_widgets.dart';

/// Analytics module (js/pages/analytics.js) — descriptive statistics
/// and trend charts for evidence-based barangay reporting.
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
          AppSpacing.gutter, AppSpacing.xxl),
      children: const [
        MisPageHeader(
          title: 'Analytics',
          desc: 'Descriptive statistics and trend charts for evidence-based '
              'barangay reporting',
        ),
        KpiGrid(cards: [
          KpiCard(
              label: 'Registered Residents',
              value: '5,742',
              trend: 'As of May 2026',
              accent: KpiAccent.success),
          KpiCard(
              label: 'Certificate Efficiency',
              value: '94%',
              trend: 'On-time issuance rate',
              accent: KpiAccent.info),
          KpiCard(
              label: 'Incident Resolution Rate',
              value: '87%',
              trend: 'Within 30 days'),
          KpiCard(
              label: 'Avg. Satisfaction Score',
              value: '4.2/5',
              trend: 'From citizen feedback forms',
              accent: KpiAccent.warning),
        ]),
        MisCard(
          title: 'Monthly Service Requests (Frequency)',
          child: SimpleBarChart(
            barColor: Color(0xFFC9A227),
            data: [
              ChartSlice('Jan', 118, Color(0xFFC9A227)),
              ChartSlice('Feb', 126, Color(0xFFC9A227)),
              ChartSlice('Mar', 132, Color(0xFFC9A227)),
              ChartSlice('Apr', 124, Color(0xFFC9A227)),
              ChartSlice('May', 139, Color(0xFFC9A227)),
              ChartSlice('Jun', 145, Color(0xFFC9A227)),
            ],
          ),
        ),
        MisCard(
          title: 'Incident Types (Percentage Composition)',
          child: DonutChart(data: [
            ChartSlice('Noise', 28, Color(0xFF3B82F6)),
            ChartSlice('Property', 22, Color(0xFF22C55E)),
            ChartSlice('Physical', 15, Color(0xFFEF4444)),
            ChartSlice('Theft', 18, Color(0xFFF59E0B)),
            ChartSlice('Vandalism', 12, Color(0xFF8B5CF6)),
            ChartSlice('Flooding', 19, Color(0xFF06B6D4)),
            ChartSlice('Other', 8, Color(0xFF6B7280)),
          ]),
        ),
        MisCard(
          title: 'Certificate Type Distribution',
          child: HBarList(data: [
            ChartSlice('Brgy Clearance', 210, Color(0xFF1D4ED8)),
            ChartSlice('Residency', 168, Color(0xFF0891B2)),
            ChartSlice('Indigency', 124, Color(0xFF16A34A)),
            ChartSlice('Business Permit', 96, Color(0xFFF59E0B)),
            ChartSlice('Others', 54, Color(0xFF64748B)),
          ]),
        ),
        MisCard(
          title: 'Citizen Satisfaction Ratings (Likert Scale)',
          child: SimpleBarChart(
            data: [
              ChartSlice('1 – VD', 8, Color(0xFFDC2626)),
              ChartSlice('2 – D', 16, Color(0xFFF97316)),
              ChartSlice('3 – N', 42, Color(0xFFEAB308)),
              ChartSlice('4 – S', 138, Color(0xFF22C55E)),
              ChartSlice('5 – VS', 174, Color(0xFF15803D)),
            ],
          ),
        ),
      ],
    );
  }
}
