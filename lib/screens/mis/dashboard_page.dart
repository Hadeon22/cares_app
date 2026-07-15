import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/session.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/charts.dart';
import '../../widgets/form_widgets.dart';
import 'mis_widgets.dart';

/// MIS Dashboard (js/pages/dashboard.js): KPIs, alerts, certificate
/// chart, recent activity, quick access, incident heatmap, AI summary.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.onNavigate});

  /// Navigate to another MIS module by key (web: nav(null, module)).
  final void Function(String module) onNavigate;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _aiSummary;

  void _generateAiSummary() {
    showAppToast(context, 'Generating AI summary...',
        icon: Icons.auto_awesome_outlined);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _aiSummary =
            'AI Summary: Recent incidents show clustering in Purok 3; '
            'recommend resource allocation and a targeted community outreach.';
      });
      showAppToast(context, 'AI Summary generated',
          icon: Icons.edit_outlined);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOfficer = AppSession.instance.role == UserRole.officer;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
          AppSpacing.gutter, AppSpacing.xxl),
      children: [
        MisPageHeader(
          title:
              'Good morning, ${isOfficer ? 'Officer Reyes' : 'Administrator'}! 👋',
          desc: "Here's what's happening in Barangay Conde Labac today",
        ),
        const KpiGrid(cards: [
          KpiCard(
              label: 'Registered Residents',
              value: '1,248',
              trend: '↑ +23 this month',
              trendUp: true),
          KpiCard(
              label: 'Certificates Issued',
              value: '87',
              trend: '↑ +12% vs last month',
              trendUp: true,
              accent: KpiAccent.success),
          KpiCard(
              label: 'Active Incidents',
              value: '3',
              trend: '↑ +2 this week',
              trendUp: false,
              accent: KpiAccent.danger),
          KpiCard(
              label: 'Pending Requests',
              value: '19',
              trend: '−5 resolved today',
              trendUp: false,
              accent: KpiAccent.info),
          KpiCard(
              label: 'Feedback Score',
              value: '4.2',
              trend: '↑ 0.3 vs last quarter',
              trendUp: true),
          KpiCard(
              label: 'Resident Population',
              value: '5,612',
              trend: 'Last census: Jan 2025'),
        ]),
        const SizedBox(height: AppSpacing.md),
        const AlertBanner(
          kind: AlertKind.danger,
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: 'Critical Incident: ',
                style: TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(
                text: 'Flooding reported at Purok 3 — Sitio Malinis. '
                    '14 families affected. Response team dispatched.'),
          ])),
        ),
        const AlertBanner(
          kind: AlertKind.warning,
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: '12 pending account claims ',
                style: TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: 'require document verification before approval.'),
          ])),
        ),
        MisCard(
          title: 'Certificate Requests (30 days)',
          action: 'View all',
          onAction: () => widget.onNavigate('certificates'),
          child: const SimpleBarChart(
            barColor: AppColors.gold,
            data: [
              ChartSlice('Wk 1', 18, AppColors.gold),
              ChartSlice('Wk 2', 24, AppColors.gold),
              ChartSlice('Wk 3', 21, AppColors.gold),
              ChartSlice('Wk 4', 24, AppColors.gold),
            ],
          ),
        ),
        MisCard(
          title: 'Recent Activity',
          action: 'View log',
          onAction: () => widget.onNavigate('audit'),
          child: const Column(
            children: [
              TimelineItem(
                  color: Color(0xFF22C55E),
                  title: 'Barangay Clearance issued — Pedro Santos',
                  meta: 'Today, 10:45 AM · Officer Reyes'),
              TimelineItem(
                  color: Color(0xFFEF4444),
                  title: 'Incident #INC-2025-041 logged — Flooding, Purok 3',
                  meta: 'Today, 09:12 AM · System'),
              TimelineItem(
                  color: Color(0xFF22C55E),
                  title: 'Account claim approved — Maria dela Cruz',
                  meta: 'Today, 08:55 AM · Admin'),
              TimelineItem(
                  color: Color(0xFF94A3B8),
                  title: 'Certificate request submitted — Jose Reyes',
                  meta: 'Yesterday, 4:30 PM · Self-service'),
              TimelineItem(
                  color: Color(0xFF94A3B8),
                  title: 'Feedback received — 4★ rating, Barangay Services',
                  meta: 'Yesterday, 3:12 PM · Anonymous'),
            ],
          ),
        ),
        MisCard(
          title: 'Services Quick Access',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _quickBtn(Icons.holiday_village_outlined, 'Residency',
                  () => widget.onNavigate('residency')),
              _quickBtn(Icons.description_outlined, 'Certificates',
                  () => widget.onNavigate('certificates')),
              _quickBtn(Icons.campaign_outlined, 'Blotter',
                  () => widget.onNavigate('incidents')),
              _quickBtn(Icons.chat_bubble_outline, 'Feedback',
                  () => widget.onNavigate('feedback')),
              _quickBtn(Icons.map_outlined, 'GIS Map',
                  () => widget.onNavigate('gis')),
              _quickBtn(Icons.vpn_key_outlined, 'Account Claiming',
                  () => widget.onNavigate('accounts')),
            ],
          ),
        ),
        MisCard(
          title: 'Incident Heatmap by Purok',
          child: const DonutChart(data: [
            ChartSlice('Purok 1', 4, Color(0xFF3B82F6)),
            ChartSlice('Purok 2', 7, Color(0xFF22C55E)),
            ChartSlice('Purok 3', 12, Color(0xFFEF4444)),
            ChartSlice('Purok 4', 3, Color(0xFFF59E0B)),
            ChartSlice('Purok 5', 6, Color(0xFF8B5CF6)),
          ]),
        ),
        MisCard(
          title: 'AI Summaries',
          action: 'Generate',
          onAction: _generateAiSummary,
          child: Text(
            _aiSummary ??
                'No summary generated yet. Use the Generate button to '
                    'request an AI-assisted summary of incidents and feedback.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.inkMuted, height: 1.5),
          ),
        ),
        MisCard(
          title: 'Quick Actions',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: AppColors.onNavy,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 10),
                ),
                onPressed: () => widget.onNavigate('residency'),
                child: const Text('Open Residency'),
              ),
              OutlinedButton(
                style: _outlineStyle,
                onPressed: () => widget.onNavigate('gis'),
                child: const Text('Open GIS Map'),
              ),
              OutlinedButton(
                style: _outlineStyle,
                onPressed: () => widget.onNavigate('analytics'),
                child: const Text('Open Analytics'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static final _outlineStyle = OutlinedButton.styleFrom(
    foregroundColor: AppColors.navy,
    side: const BorderSide(color: AppColors.divider),
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: 10),
  );

  Widget _quickBtn(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      style: _outlineStyle,
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: AppColors.goldDeep),
      label: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
