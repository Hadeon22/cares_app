import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/fade_slide.dart';
import '../data/session.dart';
import '../models/models.dart';
import '../widgets/announcement_card.dart';
import '../widgets/barangay_hall_card.dart';
import '../widgets/common.dart';
import '../widgets/gis_banner.dart';
import '../widgets/hero_section.dart';
import '../widgets/info_card_row.dart';
import '../widgets/service_card.dart';

/// Home: hero → hall card → quick info → services grid → GIS → news.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onExploreServices,
    required this.onViewGisMap,
  });

  final VoidCallback onExploreServices;
  final VoidCallback onViewGisMap;

  @override
  Widget build(BuildContext context) {
    // Show the first 6 services on Home; the full catalog lives in
    // the Services tab.
    final featured = ServiceItem.catalog.take(6).toList();
    final session = AppSession.instance;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: HeroSection(
            onExploreServices: onExploreServices,
            onViewGisMap: onViewGisMap,
          ),
        ),

        // ── Resident portal welcome (signed in) ────────────────
        if (session.role == UserRole.resident)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, 0),
            sliver: SliverToBoxAdapter(
              child: FadeSlide(
                child: _ResidentWelcomeCard(name: session.displayName),
              ),
            ),
          ),

        // ── Barangay Hall showcase ─────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, 0),
          sliver: SliverToBoxAdapter(
            child: FadeSlide(
              delay: const Duration(milliseconds: 380),
              child: const BarangayHallCard(),
            ),
          ),
        ),

        // ── Quick info strip ───────────────────────────────────
        const SliverPadding(
          padding: EdgeInsets.only(top: AppSpacing.lg),
          sliver: SliverToBoxAdapter(child: InfoCardRow()),
        ),

        // ── Citizen services ───────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter, AppSpacing.xl, AppSpacing.gutter, 0),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              eyebrow: 'Citizen Services',
              title: AppStrings.servicesHeading,
              subtitle:
                  '${AppStrings.servicesSub} Choose a service to get started.',
              trailing: TextButton(
                onPressed: onExploreServices,
                child: const Text('See all'),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, 0),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              // Responsive: 2 columns on phones, 3 on large phones/tablets.
              final columns = constraints.crossAxisExtent >= 560 ? 3 : 2;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: AppSpacing.sm + 4,
                  crossAxisSpacing: AppSpacing.sm + 4,
                  childAspectRatio: 0.92,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => ServiceCard(item: featured[i]),
                  childCount: featured.length,
                ),
              );
            },
          ),
        ),

        // ── Featured GIS banner ────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter, AppSpacing.xl, AppSpacing.gutter, 0),
          sliver: SliverToBoxAdapter(
            child: GisBanner(onOpenMap: onViewGisMap),
          ),
        ),

        // ── Latest announcements ───────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter, AppSpacing.xl, AppSpacing.gutter, 0),
          sliver: const SliverToBoxAdapter(
            child: SectionHeader(
              eyebrow: 'Community Bulletin',
              title: 'Latest announcements',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md,
              AppSpacing.gutter, AppSpacing.xxl),
          sliver: SliverList.separated(
            itemCount: Announcement.latest.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm + 4),
            itemBuilder: (context, i) =>
                AnnouncementCard(announcement: Announcement.latest[i]),
          ),
        ),
      ],
    );
  }
}

/// "Mabuhay, Pedro S. Santos!" welcome — the web resident portal's
/// portal-welcome banner.
class _ResidentWelcomeCard extends StatelessWidget {
  const _ResidentWelcomeCard({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.navyDeep],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.navyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Mabuhay, '),
                TextSpan(
                    text: name,
                    style: const TextStyle(color: AppColors.gold)),
                const TextSpan(text: '!'),
              ],
            ),
            style: text.headlineSmall?.copyWith(color: AppColors.onNavy),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Welcome to the Barangay Conde Labac Resident Portal. Access '
            'your barangay services below — request certificates, file '
            'reports, and stay connected with your community.',
            style: text.bodySmall
                ?.copyWith(color: AppColors.onNavyMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}
