import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/i18n/app_text.dart';
import '../core/utils/fade_slide.dart';
import '../data/session.dart';
import '../data/stores.dart';
import '../models/models.dart';
import '../widgets/announcement_card.dart';
import '../widgets/barangay_hall_card.dart';
import '../widgets/common.dart';
import '../widgets/gis_banner.dart';
import '../widgets/hero_section.dart';
import '../widgets/info_card_row.dart';
import '../widgets/official_card.dart';
import '../widgets/pull_to_refresh.dart';
import '../widgets/service_card.dart';

/// Home: hero → hall card → quick info → services grid → GIS → news →
/// barangay officials.
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
    final announcements = AnnouncementStore.instance..ensureLoaded();
    final officials = OfficialStore.instance..ensureLoaded();

    // Clamping physics (via the always-scrollable parent): the iOS-style
    // bounce revealed the bare scaffold background past the last section
    // when pulling up at the page end. Always-scrollable keeps swipe-down
    // reload working even when the content fits the screen.
    return PullToRefresh(
      child: AnimatedBuilder(
        animation: Listenable.merge([announcements, officials]),
        builder: (context, _) => CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics()),
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
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, 0),
          sliver: SliverToBoxAdapter(
            child: FadeSlide(
              delay: Duration(milliseconds: 380),
              child: BarangayHallCard(),
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
              eyebrow: L.text.citizenServices,
              title: L.text.servicesHeading,
              subtitle: '${L.text.servicesSub} ${L.text.chooseService}',
              trailing: TextButton(
                onPressed: onExploreServices,
                child: Text(L.text.seeAll),
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

        // ── Latest announcements (live, /api/announcements) ────
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter, AppSpacing.xl, AppSpacing.gutter, 0),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              eyebrow: 'Community Bulletin',
              title: 'Latest announcements',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, 0),
          sliver: _storeSliver(
            store: announcements,
            isEmpty: announcements.all.isEmpty,
            emptyMessage: 'No announcements posted yet. Barangay '
                'bulletins will appear here.',
            sliver: SliverList.separated(
              // The bulletin shows the newest posts; the full history
              // stays manageable from MIS → Site Content.
              itemCount: announcements.all.take(5).length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm + 4),
              itemBuilder: (context, i) =>
                  AnnouncementCard(announcement: announcements.all[i]),
            ),
          ),
        ),

        // ── Barangay officials (live, /api/officials) ──────────
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter, AppSpacing.xl, AppSpacing.gutter, 0),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              eyebrow: 'Leadership',
              title: 'Barangay Officials',
              subtitle:
                  'The current elected officials serving Barangay Conde Labac.',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md,
              AppSpacing.gutter, AppSpacing.xxl),
          sliver: _storeSliver(
            store: officials,
            isEmpty: officials.all.isEmpty,
            emptyMessage: 'The officials list has not been published yet.',
            sliver: SliverList.separated(
              itemCount: officials.all.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm + 4),
              itemBuilder: (context, i) =>
                  OfficialCard(official: officials.all[i]),
            ),
          ),
        ),
      ],
        ),
      ),
    );
  }

  /// Loading / error / empty plumbing shared by the two live sections:
  /// spinner on first load, muted message when empty or unreachable,
  /// otherwise the real [sliver].
  Widget _storeSliver({
    required ApiStore store,
    required bool isEmpty,
    required String emptyMessage,
    required Widget sliver,
  }) {
    if (store.loading && isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
        ),
      );
    }
    if (isEmpty) {
      return SliverToBoxAdapter(
        child: _SectionMessage(
          store.error != null
              ? 'Could not load this section. Pull down to retry.'
              : emptyMessage,
        ),
      );
    }
    return sliver;
  }
}

/// Muted cream box for a section with nothing to show (empty or offline).
class _SectionMessage extends StatelessWidget {
  const _SectionMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.inkMuted, height: 1.5),
      ),
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
                    text: name, style: const TextStyle(color: AppColors.gold)),
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
