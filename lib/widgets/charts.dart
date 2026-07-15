import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// Lightweight dependency-free charts mirroring the web system's
/// Chart.js visuals (vertical/horizontal bars, doughnut, pie).

class ChartSlice {
  const ChartSlice(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// Vertical bar chart (web: cert requests, analytics frequency charts).
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.data,
    this.height = 180,
    this.barColor,
  });

  final List<ChartSlice> data;
  final double height;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final maxValue =
        data.fold<double>(0, (m, d) => math.max(m, d.value));
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in data)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      d.value == d.value.roundToDouble()
                          ? '${d.value.toInt()}'
                          : d.value.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.inkMuted,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: maxValue == 0
                            ? 0
                            : (d.value / maxValue).clamp(0.02, 1.0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: barColor ?? d.color,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.inkMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal bar rows (web: analytics certificate distribution,
/// feedback "By Category" stat rows).
class HBarList extends StatelessWidget {
  const HBarList({super.key, required this.data, this.showValue = true});

  final List<ChartSlice> data;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final maxValue =
        data.fold<double>(0, (m, d) => math.max(m, d.value));
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final d in data)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 118,
                  child: Text(
                    d.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                        color: AppColors.ink, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: maxValue == 0 ? 0 : d.value / maxValue,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation(d.color),
                    ),
                  ),
                ),
                if (showValue) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${d.value.toInt()}',
                      textAlign: TextAlign.right,
                      style: text.labelSmall?.copyWith(
                          color: AppColors.inkMuted,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Doughnut / pie chart with legend (web: incident heatmap by purok,
/// sentiment breakdown, incident type composition).
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.data,
    this.size = 140,
    this.thickness = 26,
    this.isPie = false,
  });

  final List<ChartSlice> data;
  final double size;
  final double thickness;

  /// True renders a full pie instead of a doughnut ring.
  final bool isPie;

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0, (s, d) => s + d.value);
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DonutPainter(
              data: data,
              thickness: isPie ? size / 2 : thickness,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final d in data)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: d.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          d.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall
                              ?.copyWith(color: AppColors.inkMuted),
                        ),
                      ),
                      Text(
                        total == 0
                            ? '—'
                            : '${(d.value / total * 100).round()}%',
                        style: text.labelSmall?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.data, required this.thickness});

  final List<ChartSlice> data;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold<double>(0, (s, d) => s + d.value);
    if (total <= 0) return;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final rect =
        Rect.fromCircle(center: center, radius: radius - thickness / 2);
    var start = -math.pi / 2;
    for (final d in data) {
      final sweep = d.value / total * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = d.color;
      canvas.drawArc(rect, start, sweep - 0.03, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.data != data || old.thickness != thickness;
}
