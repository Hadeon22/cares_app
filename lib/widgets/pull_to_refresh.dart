import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../data/stores.dart';

/// Re-pulls the shared data stores that have already been loaded this
/// session. Only touching loaded stores keeps a resident's pull-to-refresh
/// from kicking off staff-only fetches they never opened.
Future<void> refreshLoadedStores() async {
  final stores = <ApiStore>[
    ResidentStore.instance,
    CertificateStore.instance,
    FeedbackStore.instance,
    IncidentStore.instance,
    GisStateStore.instance,
    NotificationStore.instance,
    AuditLog.instance,
  ];
  await Future.wait([
    for (final s in stores)
      if (s.loaded) s.refresh(),
  ]);
}

/// Makes every scrollable in the subtree that doesn't set its own physics
/// always-scrollable (clamping, so no iOS-style overscroll glow past the
/// ends). Wrap a page in a `ScrollConfiguration` with this so a
/// [RefreshIndicator] above it can be pulled even when the content fits the
/// screen.
class AlwaysScrollableBehavior extends MaterialScrollBehavior {
  const AlwaysScrollableBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());
}

/// Wraps a scrollable in the app's standard swipe-down-to-reload gesture.
/// The [child] must be a scrollable with always-scrollable physics (so the
/// pull works even when the content fits the screen) — [child] is expected
/// to already set that; this widget just supplies the indicator + action.
class PullToRefresh extends StatelessWidget {
  const PullToRefresh({super.key, required this.child, this.onRefresh});

  final Widget child;

  /// Defaults to refreshing every loaded store. Pass a page-specific action
  /// to refresh just that page's data.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: onRefresh ?? refreshLoadedStores,
      child: child,
    );
  }
}
