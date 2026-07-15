import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

/// Featured navy banner promoting the community GIS map, with a
/// lightweight custom-painted "map" illustration (no asset required).
class GisBanner extends StatelessWidget {
  const GisBanner({super.key, required this.onOpenMap});

  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navyLight, AppColors.navyDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative map illustration filling the banner.
          Positioned.fill(
            child: CustomPaint(painter: _MapSketchPainter()),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: const Icon(Icons.travel_explore,
                          color: AppColors.gold, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Text(
                      'COMMUNITY GIS',
                      style: text.labelSmall?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Explore Conde Labac on the map',
                  style: text.titleLarge?.copyWith(color: AppColors.onNavy),
                ),
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  'View puroks, landmarks, evacuation sites and household '
                  'zones in the interactive barangay map.',
                  style: text.bodySmall?.copyWith(color: AppColors.onNavyMuted),
                ),
                const SizedBox(height: AppSpacing.md + 4),
                FilledButton.icon(
                  onPressed: onOpenMap,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Open GIS Map'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Abstract street-grid + pin sketch, drawn in translucent brand colors.
class _MapSketchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = AppColors.royalBlue.withValues(alpha: 0.22)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Curvy "roads"
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.55, 0)
        ..quadraticBezierTo(w * 0.7, h * 0.4, w * 0.62, h)
        ..moveTo(w * 0.75, 0)
        ..quadraticBezierTo(w * 0.88, h * 0.55, w * 0.8, h)
        ..moveTo(w * 0.5, h * 0.3)
        ..quadraticBezierTo(w * 0.8, h * 0.25, w, h * 0.35)
        ..moveTo(w * 0.55, h * 0.7)
        ..quadraticBezierTo(w * 0.85, h * 0.75, w, h * 0.62),
      road,
    );

    // Gold location pin
    final pin = Paint()..color = AppColors.gold.withValues(alpha: 0.85);
    final pinCenter = Offset(w * 0.82, h * 0.38);
    canvas.drawCircle(pinCenter, 7, pin);
    canvas.drawCircle(pinCenter, 3, Paint()..color = AppColors.navyDeep);
    canvas.drawCircle(
      pinCenter,
      13,
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
