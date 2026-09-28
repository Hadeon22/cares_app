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
    AnnouncementStore.instance,
    OfficialStore.instance,
    DashboardStats.instance,
    AnalyticsStats.instance,
  ];
  await Future.wait([
    for (final s in stores)
      if (s.loaded) s.refresh(),
  ]);
}

/// Re-pulls the loaded stores whenever the app comes back to the foreground.
///
/// The stores are fetched once and then held, which is right for a phone but
/// means anything changed in the web system while the app sat in the
/// background — a request approved, a certificate's blanks filled in, a
/// document attached — would still be showing its old value. Coming back to
/// the app is the natural moment to catch up, and it costs one round trip per
/// store the user has actually opened.
///
/// Mount once, high in the tree. Safe to mount more than once: the refresh is
/// idempotent and [ApiStore.refresh] coalesces concurrent calls.
class RefreshOnResume extends StatefulWidget {
  const RefreshOnResume({super.key, required this.child});

  final Widget child;

  @override
  State<RefreshOnResume> createState() => _RefreshOnResumeState();
}

class _RefreshOnResumeState extends State<RefreshOnResume>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Fire and forget — a failed catch-up must never surface as an error on
      // a screen the user has only just returned to.
      refreshLoadedStores().catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
