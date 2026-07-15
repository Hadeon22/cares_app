import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
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
        _aiSummary = 'AI Summary: Recent incidents show clustering in Purok 3; '
            'recommend resource allocation and a targeted community outreach.';
      });
      showAppToast(context, 'AI Summary generated', icon: Icons.edit_outlined);
    });
  }

  static const _purokColors = [
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
  ];

  String _timeAgo(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final stats = DashboardStats.instance;
    stats.ensureLoaded();
    AuditLog.instance.ensureLoaded();
    return AnimatedBuilder(
      animation: Listenable.merge([stats, AuditLog.instance]),
      builder: (context, _) => _buildBody(context, stats),
    );
  }

  Widget _buildBody(BuildContext context, DashboardStats stats) {
    final session = AppSession.instance;
    final recentAudit = AuditLog.instance.entries.take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, AppSpacing.xxl),
      children: [
        MisPageHeader(
          title: 'Good day, ${session.shortName.isEmpty ? 'there' : session.shortName}! 👋',
          desc: "Here's what's happening in Barangay Conde Labac today",
        ),
        if (stats.error != null)
          AlertBanner(
            kind: AlertKind.warning,
            child: Text('Could not load live stats: ${stats.error}'),
          ),
        KpiGrid(cards: [
          KpiCard(
              label: 'Registered Residents',
              value: '${stats.residents}',
              trend: '${stats.households} households'),
          KpiCard(
              label: 'Certificates Issued',
              value: '${stats.certificatesByStatus['issued'] ?? 0}',
              trend: '${stats.certificatesPending} pending',
              accent: KpiAccent.success),
          KpiCard(
              label: 'Active Incidents',
              value: '${stats.incidentsOpen}',
              trend: '${stats.incidentsThisMonth} filed this month',
              trendUp: false,
              accent: KpiAccent.danger),
          KpiCard(
              label: 'Pending Requests',
              value: '${stats.certificatesPending}',
              accent: KpiAccent.info),
          KpiCard(
              label: 'Feedback Score',
              value: stats.feedbackAvg == null
                  ? '—'
                  : stats.feedbackAvg!.toStringAsFixed(1),
              trend: '${stats.feedbackNew} unreviewed',
              trendUp: true),
          KpiCard(
              label: 'Accounts Claimed',
              value: '${stats.accountsClaimed}',
              trend: 'Resident portal logins'),
        ]),
        const SizedBox(height: AppSpacing.md),
        if (stats.incidentsOpen > 0)
          AlertBanner(
            kind: AlertKind.danger,
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: '${stats.incidentsOpen} open incident'
                      '${stats.incidentsOpen == 1 ? '' : 's'}: ',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const TextSpan(
                  text: 'review the blotter queue and dispatch/resolve where '
                      'needed.'),
            ])),
          ),
        if (stats.certificatesPending > 0)
          AlertBanner(
            kind: AlertKind.warning,
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: '${stats.certificatesPending} pending certificate '
                      'request${stats.certificatesPending == 1 ? '' : 's'} ',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const TextSpan(text: 'awaiting review and approval.'),
            ])),
          ),
        MisCard(
          title: 'Certificate Requests by Status',
          action: 'View all',
          onAction: () => widget.onNavigate('certificates'),
          child: SimpleBarChart(
            barColor: AppColors.gold,
            data: [
              for (final s in const ['pending', 'approved', 'issued', 'rejected'])
                ChartSlice(
                    s[0].toUpperCase() + s.substring(1),
                    (stats.certificatesByStatus[s] ?? 0).toDouble(),
                    AppColors.gold),
            ],
          ),
        ),
        MisCard(
          title: 'Recent Activity',
          action: 'View log',
          onAction: () => widget.onNavigate('audit'),
          child: recentAudit.isEmpty
              ? const EmptyState('No recorded activity yet.')
              : Column(
                  children: [
                    for (final e in recentAudit)
                      TimelineItem(
                        color: e.level == AuditLevel.critical ||
                                e.level == AuditLevel.warning
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF22C55E),
                        title: e.details.isEmpty ? e.action : e.details,
                        meta: '${_timeAgo(e.ts)} · ${e.user}',
                      ),
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
          title: 'Residents by Purok',
          child: stats.byPurok.isEmpty
              ? const EmptyState('No purok data yet.')
              : DonutChart(data: [
                  for (final (i, e) in stats.byPurok.entries.indexed)
                    ChartSlice(e.key, e.value.toDouble(),
                        _purokColors[i % _purokColors.length]),
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
    padding:
        const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
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
