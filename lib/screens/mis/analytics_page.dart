import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/stores.dart';
import '../../gis/gis_data.dart';
import '../../gis/gis_map_view.dart' show kReportTypeIcons;
import '../../widgets/charts.dart';
import '../../widgets/pull_to_refresh.dart';
import 'mis_widgets.dart';

/// Analytics module (js/pages/analytics.js) — descriptive statistics and
/// trend charts, all computed from live data (GET /api/stats/analytics).
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  static const _incidentLabels = {
    'noise': 'Noise', 'dispute': 'Dispute', 'altercation': 'Altercation',
    'theft': 'Theft', 'vandalism': 'Vandalism', 'domestic': 'Domestic',
    'flooding': 'Flooding', 'vehicular': 'Vehicular', 'fire': 'Fire',
    'medical': 'Medical', 'other': 'Other',
  };

  static const _certLabels = {
    'barangay-clearance': 'Brgy Clearance', 'indigency': 'Indigency',
    'residency': 'Residency', 'solo-parent': 'Solo Parent',
    'good-moral': 'Good Moral', 'business-clearance': 'Business Clearance',
  };

  static const _palette = [
    Color(0xFF1D4ED8), Color(0xFF22C55E), Color(0xFFEF4444), Color(0xFFF59E0B),
    Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFEC4899), Color(0xFF84CC16),
    Color(0xFFF97316), Color(0xFF64748B), Color(0xFF14B8A6),
  ];

  static const _ratingColors = [
    Color(0xFFDC2626), Color(0xFFF97316), Color(0xFFEAB308),
    Color(0xFF22C55E), Color(0xFF15803D),
  ];

  @override
  Widget build(BuildContext context) {
    final stats = AnalyticsStats.instance..ensureLoaded();

    return PullToRefresh(
      onRefresh: AnalyticsStats.instance.refresh,
      child: AnimatedBuilder(
        animation: stats,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
                AppSpacing.gutter, AppSpacing.xxl),
            children: [
              const MisPageHeader(
                title: 'Analytics',
                desc: 'Descriptive statistics and trend charts for '
                    'evidence-based barangay reporting',
              ),
              if (stats.loading && !stats.loaded)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold)),
                )
              else if (stats.error != null && !stats.loaded)
                EmptyState('Could not load analytics.\n${stats.error}')
              else
                ..._content(context, stats),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _content(BuildContext context, AnalyticsStats s) {
    final monthly = s.monthly;
    final inc = s.incidentByType;
    final cert = s.certByType;
    return [
      KpiGrid(cards: [
        KpiCard(
            label: 'Registered Residents',
            value: '${s.residents}',
            trend: 'Active records',
            accent: KpiAccent.success),
        KpiCard(
            label: 'Certificate Efficiency',
            value: '${s.certEfficiency}%',
            trend: 'Issued of all requests',
            accent: KpiAccent.info),
        KpiCard(
            label: 'Incident Resolution Rate',
            value: '${s.incidentResolutionRate}%',
            trend: 'Resolved or dismissed'),
        KpiCard(
            label: 'Avg. Satisfaction Score',
            value: s.satisfactionAvg != null ? '${s.satisfactionAvg}/5' : 'N/A',
            trend: 'From citizen feedback',
            accent: KpiAccent.warning),
      ]),
      MisCard(
        title: 'Monthly Service Requests (Frequency)',
        child: monthly.isEmpty
            ? const EmptyState('No service requests recorded yet.')
            : SimpleBarChart(
                barColor: const Color(0xFFC9A227),
                data: [
                  for (final m in monthly)
                    ChartSlice(
                        m.label, m.total.toDouble(), const Color(0xFFC9A227)),
                ],
              ),
      ),
      MisCard(
        title: 'Incident Types (Percentage Composition)',
        child: inc.isEmpty
            ? const EmptyState('No incidents recorded yet.')
            : DonutChart(data: [
                for (var i = 0; i < inc.length; i++)
                  ChartSlice(_incidentLabels[inc[i].type] ?? inc[i].type,
                      inc[i].n.toDouble(), _palette[i % _palette.length]),
              ]),
      ),
      const IncidentHeatmapCard(typeLabels: _incidentLabels),
      MisCard(
        title: 'Certificate Type Distribution',
        child: cert.isEmpty
            ? const EmptyState('No certificate requests recorded yet.')
            : HBarList(data: [
                for (var i = 0; i < cert.length; i++)
                  ChartSlice(_certLabels[cert[i].type] ?? cert[i].type,
                      cert[i].n.toDouble(), _palette[i % _palette.length]),
              ]),
      ),
      MisCard(
        title: 'Citizen Satisfaction Ratings (Likert Scale)',
        child: s.satisfactionByRating.every((n) => n == 0)
            ? const EmptyState('No feedback recorded yet.')
            : SimpleBarChart(
                data: [
                  for (var i = 0; i < 5; i++)
                    ChartSlice('${i + 1} ★',
                        s.satisfactionByRating[i].toDouble(), _ratingColors[i]),
                ],
              ),
      ),
    ];
  }
}

/// Incident report heatmap: a density overlay on the barangay boundary showing
/// where incidents were filed. Filterable by incident type and by month.
class IncidentHeatmapCard extends StatefulWidget {
  const IncidentHeatmapCard({super.key, required this.typeLabels});

  final Map<String, String> typeLabels;

  @override
  State<IncidentHeatmapCard> createState() => _IncidentHeatmapCardState();
}

class _IncidentHeatmapCardState extends State<IncidentHeatmapCard> {
  String? _type; // null = all types
  String? _monthKey; // 'yyyy-MM', null = all months

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _ymKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
  String _ymLabel(String key) {
    final parts = key.split('-');
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
    return '${_monthNames[(m - 1).clamp(0, 11)]} ${parts.first}';
  }

  @override
  void initState() {
    super.initState();
    IncidentStore.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: IncidentStore.instance,
      builder: (context, _) {
        // Only incidents pinned on the map can be plotted.
        final all =
            IncidentStore.instance.all.where((r) => r.mapPoint != null).toList();

        final types = <String>{for (final r in all) r.typeKey}.toList()..sort();
        final monthKeys = <String>{for (final r in all) _ymKey(r.createdAt)}
            .toList()
          ..sort((a, b) => b.compareTo(a));

        final filtered = all.where((r) =>
            (_type == null || r.typeKey == _type) &&
            (_monthKey == null || _ymKey(r.createdAt) == _monthKey));
        final points = [for (final r in filtered) r.mapPoint!];

        String typeLabel(String t) => widget.typeLabels[t] ?? t;

        // No card box — the barangay shape floats on the page. Filter row uses
        // the same outlined-button + bottom-sheet style as the GIS map.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 2),
              child: Text('Incident Heatmap',
                  style: text.titleSmall?.copyWith(
                      color: AppColors.ink, fontWeight: FontWeight.w800)),
            ),
            Text(
              'Where incidents were reported across the barangay. Warmer areas '
              'have more reports.',
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _FilterButton(
                    icon: Icons.warning_amber_outlined,
                    label: _type == null ? 'Type' : typeLabel(_type!),
                    active: _type != null,
                    onPressed: () => _showTypeSheet(types, typeLabel),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _FilterButton(
                    icon: Icons.calendar_today_outlined,
                    label: _monthKey == null ? 'Month' : _ymLabel(_monthKey!),
                    active: _monthKey != null,
                    onPressed: () => _showMonthSheet(monthKeys),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _HeatmapMap(points: points),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text('${points.length} report${points.length == 1 ? '' : 's'}',
                    style: text.labelSmall?.copyWith(
                        color: AppColors.ink, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('Fewer',
                    style: text.labelSmall?.copyWith(color: AppColors.inkMuted)),
                const SizedBox(width: 6),
                Container(
                  width: 96,
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: const LinearGradient(
                        colors: [Color(0x22EF4444), Color(0xFFB91C1C)]),
                  ),
                ),
                const SizedBox(width: 6),
                Text('More',
                    style: text.labelSmall?.copyWith(color: AppColors.inkMuted)),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showTypeSheet(List<String> types, String Function(String) label) {
    _showChoiceSheet(
      title: 'Incident Type',
      allLabel: 'All Types',
      allIcon: Icons.warning_amber_outlined,
      options: {
        for (final t in types)
          t: (kReportTypeIcons[t] ?? Icons.report_gmailerrorred_outlined,
              label(t)),
      },
      selected: _type,
      onSelected: (v) => setState(() => _type = v),
    );
  }

  void _showMonthSheet(List<String> monthKeys) {
    _showChoiceSheet(
      title: 'Month',
      allLabel: 'All Months',
      allIcon: Icons.calendar_today_outlined,
      options: {
        for (final k in monthKeys) k: (Icons.event_outlined, _ymLabel(k)),
      },
      selected: _monthKey,
      onSelected: (v) => setState(() => _monthKey = v),
    );
  }

  /// Single-select filter sheet, styled exactly like the GIS map's sheets:
  /// an "All …" row followed by the options, the current one check-marked.
  void _showChoiceSheet({
    required String title,
    required String allLabel,
    required IconData allIcon,
    required Map<String, (IconData, String)> options,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (ctx) {
        Widget row(String? value, IconData icon, String label) {
          final isSelected = value == selected;
          return ListTile(
            dense: true,
            leading: Icon(icon, size: 20, color: AppColors.navy),
            title: Text(label,
                style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                    color: AppColors.ink, fontWeight: FontWeight.w700)),
            trailing: isSelected
                ? const Icon(Icons.check, size: 20, color: AppColors.gold)
                : null,
            onTap: () {
              onSelected(value);
              Navigator.of(ctx).pop();
            },
          );
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                    AppSpacing.sm, AppSpacing.gutter, AppSpacing.sm),
                child: Text(title,
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        color: AppColors.ink, fontWeight: FontWeight.w800)),
              ),
              row(null, allIcon, allLabel),
              for (final e in options.entries)
                row(e.key, e.value.$1, e.value.$2),
            ],
          ),
        );
      },
    );
  }
}

/// Filter-row button copied from the GIS map (js filter row parity): a compact
/// outlined button that opens a sheet, highlighted when its filter is active.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 32),
        foregroundColor: AppColors.navy,
        backgroundColor: active ? AppColors.navy.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        side: BorderSide(
            color: active ? AppColors.navy : AppColors.divider,
            width: active ? 1.4 : 1),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Loads the barangay map data and paints the incident density overlay,
/// sized to the barangay's own aspect ratio so the box hugs the border with
/// no wasted space (no inner box — the shape sits directly on the page).
class _HeatmapMap extends StatelessWidget {
  const _HeatmapMap({required this.points});

  /// Normalized (0..1) incident positions within the map.
  final List<Offset> points;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GisMapData>(
      future: GisMapData.load(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const SizedBox(
            height: 220,
            child: Center(child: EmptyState('Map data failed to load.')),
          );
        }
        if (!snap.hasData) {
          return const SizedBox(
            height: 220,
            child:
                Center(child: CircularProgressIndicator(color: AppColors.gold)),
          );
        }
        final bounds = snap.data!.boundary.getBounds();
        final aspect = (bounds.height <= 0) ? 1.0 : bounds.width / bounds.height;
        return AspectRatio(
          aspectRatio: aspect,
          child: CustomPaint(
            size: Size.infinite,
            painter: _HeatmapPainter(snap.data!, points),
          ),
        );
      },
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter(this.data, this.points);

  final GisMapData data;
  final List<Offset> points;

  // Near-1 so the border almost fills the box but stays fully visible.
  static const double _fitMargin = 0.97;

  @override
  void paint(Canvas canvas, Size size) {
    // Fit the barangay boundary's own bounding box (not the padded map canvas)
    // so the shape fills the widget and the height hugs the border.
    final b = data.boundary.getBounds();
    if (b.isEmpty) return;
    final fit = _fitMargin *
        math.min(size.width / b.width, size.height / b.height);
    final originX = (size.width - b.width * fit) / 2;
    final originY = (size.height - b.height * fit) / 2;

    canvas.save();
    canvas.translate(originX - b.left * fit, originY - b.top * fit);
    canvas.scale(fit);

    // Faint barangay fill + a clip so the heat never bleeds past the border.
    canvas.drawPath(data.boundary, Paint()..color = const Color(0x0A0D1B3E));
    canvas.save();
    canvas.clipPath(data.boundary);

    final r = 34 / fit; // ~34 screen px per blob
    for (final p in points) {
      final c = Offset(p.dx * data.size.width, p.dy * data.size.height);
      final shader = const RadialGradient(
        colors: [Color(0x59EF4444), Color(0x00EF4444)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, Paint()..shader = shader);
    }
    canvas.restore(); // clip

    // Border outline on top.
    canvas.drawPath(
      data.boundary,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / fit
        ..color = const Color(0xFF0D1B3E),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) =>
      old.data != data || !identical(old.points, points);
}
