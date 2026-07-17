import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/pull_to_refresh.dart';
import '../widgets/service_card.dart';

/// Full catalog of barangay services in a responsive grid.
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PullToRefresh(
      child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics()),
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, 0),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              eyebrow: 'Citizen Services',
              title: AppStrings.servicesHeading,
              subtitle: '${AppStrings.servicesSub} No account required '
                  'for most services.',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.md,
              AppSpacing.gutter, AppSpacing.xxl),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.crossAxisExtent >= 560 ? 3 : 2;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: AppSpacing.sm + 4,
                  crossAxisSpacing: AppSpacing.sm + 4,
                  childAspectRatio: 0.92,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => ServiceCard(item: ServiceItem.catalog[i]),
                  childCount: ServiceItem.catalog.length,
                ),
              );
            },
          ),
        ),
      ],
      ),
    );
  }
}
