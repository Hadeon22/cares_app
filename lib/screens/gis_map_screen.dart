import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/stores.dart';
import '../gis/gis_map_view.dart';
import '../widgets/app_toast.dart';
import '../widgets/form_widgets.dart';
import 'services/incident_report_screen.dart';

/// Community GIS Map — the barangay's boundary, buildings, roads,
/// vegetation, and waterways rendered from the same GeoJSON data as the
/// web system. Below the map: the Recent Community Reports feed and the
/// AI Narrative Report panel (web pages/gis.html layout).
class GisMapScreen extends StatefulWidget {
  const GisMapScreen({super.key, this.focusPoint});

  /// Optional normalized point to center on (blotter "View on Map").
  final Offset? focusPoint;

  @override
  State<GisMapScreen> createState() => _GisMapScreenState();

  /// Centered dialog with the report's details (replaces the old
  /// bottom sheet).
  static void showReportDialog(BuildContext context, IncidentReport report) {
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    // Exact filing moment — date AND time.
    final filedAt = '${loc.formatMediumDate(report.createdAt)} · '
        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(report.createdAt))}';

    Widget detail(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '$label: ',
                  style: text.labelSmall?.copyWith(
                      color: AppColors.inkMuted, fontWeight: FontWeight.w800)),
              TextSpan(
                  text: value,
                  style: text.labelSmall?.copyWith(color: AppColors.ink)),
            ]),
          ),
        );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md)),
        title: Row(
          children: [
            Icon(
              kReportTypeIcons[report.typeKey] ?? Icons.priority_high,
              size: 22,
              color: report.isOfficial
                  ? kReportOfficialColor
                  : kReportResidentColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(report.typeLabel,
                  style: text.titleMedium?.copyWith(
                      color: AppColors.ink, fontWeight: FontWeight.w800)),
            ),
            StatusBadge(
              report.resolved ? 'Resolved' : 'Active',
              kind: report.resolved ? BadgeKind.success : BadgeKind.danger,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              detail('Case No', report.caseNo),
              detail('Reported', filedAt),
              detail(
                  'Filed by',
                  '${report.complainant}'
                  '${report.isOfficial ? ' (Barangay Official)' : ''}'),
              if (report.contact.isNotEmpty) detail('Contact', report.contact),
              if (report.respondent.isNotEmpty)
                detail('Respondent', report.respondent),
              if (report.witnesses.isNotEmpty)
                detail('Witnesses', report.witnesses),
              const SizedBox(height: AppSpacing.sm),
              Text(report.narration,
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.ink, height: 1.5)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Popup for a tagged building — the mobile version of the web map's
  /// building popup (name, category, notes).
  static void showBuildingDialog(BuildContext context, BuildingTag tag) {
    final text = Theme.of(context).textTheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md)),
        title: Text(tag.name.isEmpty ? 'Tagged Building' : tag.name,
            style: text.titleMedium?.copyWith(
                color: AppColors.ink, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusBadge(tag.typeLabel, kind: BadgeKind.gold),
            if (tag.notes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm + 4),
              Text(tag.notes,
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.ink, height: 1.5)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Popup for a staff-drawn map feature (hazard / accident / construction).
  static void showFeatureInfoDialog(BuildContext context, MapFeatureInfo info) {
    final text = Theme.of(context).textTheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md)),
        title: Text(info.title,
            style: text.titleMedium?.copyWith(
                color: AppColors.ink, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusBadge(info.badge, kind: BadgeKind.warning),
            if (info.body.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm + 4),
              Text(info.body,
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.ink, height: 1.5)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

}

/// Building-type filter options — GIS_BUILDING_TYPE_META on the web.
const Map<String, String> _kBuildingTypeLabels = {
  'government': 'Government Building',
  'business': 'Business',
  'households': 'Household',
};

/// Household classification options — GIS_HOUSEHOLD_SUBCAT_META on the web.
const Map<String, String> _kHouseholdClassLabels = {
  'seniors': 'Senior Citizen',
  'pwd': 'PWD',
  'solo-parent': 'Solo Parent',
  'indigent': 'Indigent Family',
};

class _GisMapScreenState extends State<GisMapScreen> {
  /// Set to a report's normalized point to fly the pinned map there
  /// (the feed rows' view-on-map buttons).
  final ValueNotifier<Offset?> _focus = ValueNotifier<Offset?>(null);

  /// Layer toggles + building filters — same controls as the web map's
  /// filter row (Map Layers, Building Type, Household Classification).
  GisMapFilters _filters = const GisMapFilters();

  /// True while a finger is down on the map. The page scroll is disabled
  /// then, so dragging on the map pans/zooms it (and never scrolls the
  /// page); dragging anywhere else scrolls the page normally.
  bool _mapInteracting = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _viewOnMap(Offset point) {
    // Reset first so focusing the same report twice still notifies.
    _focus.value = null;
    _focus.value = point;
  }

  /// Re-pulls everything the map renders (reports + shared map state).
  Future<void> _refreshMapData(BuildContext context) async {
    await Future.wait([
      IncidentStore.instance.refresh(),
      GisStateStore.instance.refresh(),
    ]);
    if (context.mounted) {
      showAppToast(context, 'Map data refreshed', icon: Icons.refresh);
    }
  }

  /// Copy [_filters] with one field changed. The set* flags let a null
  /// value ("All …") actually clear the corresponding filter.
  GisMapFilters _copyFilters({
    bool? showVegetation,
    bool? showWater,
    bool? showRoads,
    bool? showBuildings,
    bool? showHazard,
    bool? showConstruction,
    bool? showReports,
    String? buildingType,
    bool setBuildingType = false,
    String? householdClass,
    bool setHouseholdClass = false,
  }) {
    final f = _filters;
    return GisMapFilters(
      showVegetation: showVegetation ?? f.showVegetation,
      showWater: showWater ?? f.showWater,
      showRoads: showRoads ?? f.showRoads,
      showBuildings: showBuildings ?? f.showBuildings,
      showHazard: showHazard ?? f.showHazard,
      showConstruction: showConstruction ?? f.showConstruction,
      showReports: showReports ?? f.showReports,
      buildingType: setBuildingType ? buildingType : f.buildingType,
      householdClass: setHouseholdClass ? householdClass : f.householdClass,
    );
  }

  /// Building Type filter sheet (single choice), styled like Map Layers.
  void _showBuildingTypeSheet() {
    _showChoiceSheet(
      title: 'Building Type',
      allLabel: 'All Building Types',
      allIcon: Icons.apartment_outlined,
      options: {
        'government': (Icons.account_balance_outlined, 'Government Building'),
        'business': (Icons.storefront_outlined, 'Business'),
        'households': (Icons.home_outlined, 'Household'),
      },
      selected: _filters.buildingType,
      onSelected: (v) => setState(() =>
          _filters = _copyFilters(buildingType: v, setBuildingType: true)),
    );
  }

  /// Household Classification filter sheet (single choice).
  void _showClassificationSheet() {
    _showChoiceSheet(
      title: 'Classification',
      allLabel: 'All Classifications',
      allIcon: Icons.home_outlined,
      options: {
        'seniors': (Icons.elderly, 'Senior Citizen'),
        'pwd': (Icons.accessible, 'PWD'),
        'solo-parent': (Icons.family_restroom, 'Solo Parent'),
        'indigent': (Icons.volunteer_activism, 'Indigent Family'),
      },
      selected: _filters.householdClass,
      onSelected: (v) => setState(() =>
          _filters = _copyFilters(householdClass: v, setHouseholdClass: true)),
    );
  }

  /// Shared single-select filter sheet (Building Type / Classification):
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

  /// "Map Layers" bottom sheet — the web filter row's layer-toggle
  /// dropdown (Vegetation / Water / Roads / Buildings / Hazard /
  /// Construction / Reports).
  void _showLayersSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Widget toggle(String label, IconData icon, bool value,
              GisMapFilters Function(bool) apply) {
            return SwitchListTile(
              dense: true,
              activeThumbColor: AppColors.gold,
              secondary: Icon(icon, size: 20, color: AppColors.navy),
              title: Text(label,
                  style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                      color: AppColors.ink, fontWeight: FontWeight.w700)),
              value: value,
              onChanged: (v) {
                setState(() => _filters = apply(v));
                setSheetState(() {});
              },
            );
          }

          final f = _filters;
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                      AppSpacing.sm, AppSpacing.gutter, AppSpacing.sm),
                  child: Text('Map Layers',
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          color: AppColors.ink, fontWeight: FontWeight.w800)),
                ),
                toggle('Vegetation', Icons.grass, f.showVegetation,
                    (v) => _copyFilters(showVegetation: v)),
                toggle('Water', Icons.water_drop_outlined, f.showWater,
                    (v) => _copyFilters(showWater: v)),
                toggle('Roads', Icons.add_road, f.showRoads,
                    (v) => _copyFilters(showRoads: v)),
                toggle('Buildings', Icons.apartment_outlined, f.showBuildings,
                    (v) => _copyFilters(showBuildings: v)),
                toggle('Hazard', Icons.warning_amber_outlined, f.showHazard,
                    (v) => _copyFilters(showHazard: v)),
                toggle('Construction', Icons.engineering_outlined,
                    f.showConstruction,
                    (v) => _copyFilters(showConstruction: v)),
                toggle('Reports', Icons.place_outlined, f.showReports,
                    (v) => _copyFilters(showReports: v)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openReportIncident() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const IncidentReportScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // Everything scrolls together: the map is no longer pinned, so pulling
    // the page up scrolls it away to reveal the reports/AI panels. Page
    // scroll is suppressed while a finger is on the map (see
    // [_mapInteracting]) so map panning never fights the page scroll.
    // Pull-to-refresh re-pulls the map data.
    return RefreshIndicator(
      onRefresh: () => _refreshMapData(context),
      color: AppColors.navy,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: _mapInteracting
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        children: [
        // ── Above the map: the web filter row's controls ────────
        // Map Layers toggles + Building Type + Household Classification
        // (js/gis-map.js filter row), plus refresh.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter, AppSpacing.sm + 4, AppSpacing.gutter, 0),
          // All three filter controls in one row, sharing the same button
          // style (matching the web map's filter row). Building Type /
          // Classification show the current choice; an active filter is
          // highlighted. (Reloading is handled by pull-to-refresh.)
          child: Row(
            children: [
              Expanded(
                child: _FilterButton(
                  icon: Icons.layers_outlined,
                  label: 'Layers',
                  active: !_filters.allLayersOn,
                  onPressed: _showLayersSheet,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _FilterButton(
                  icon: Icons.apartment_outlined,
                  label: _filters.buildingType == null
                      ? 'Building'
                      : _kBuildingTypeLabels[_filters.buildingType]!,
                  active: _filters.buildingType != null,
                  onPressed: _showBuildingTypeSheet,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _FilterButton(
                  icon: Icons.home_outlined,
                  label: _filters.householdClass == null
                      ? 'Class'
                      : _kHouseholdClassLabels[_filters.householdClass]!,
                  active: _filters.householdClass != null,
                  onPressed: _showClassificationSheet,
                ),
              ),
            ],
          ),
        ),
        // ── Map ─────────────────────────────────────────────────
        // Full-bleed to the screen edges; slightly taller than the
        // boundary's true aspect so the map gets more breathing room —
        // the fitted view stays the zoom-out limit either way. Wrapped in a
        // Listener that turns off page scroll while the map is touched, so
        // map panning wins over the page's scroll.
        Listener(
          onPointerDown: (_) {
            if (!_mapInteracting) setState(() => _mapInteracting = true);
          },
          onPointerUp: (_) {
            if (_mapInteracting) setState(() => _mapInteracting = false);
          },
          onPointerCancel: (_) {
            if (_mapInteracting) setState(() => _mapInteracting = false);
          },
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm + 4),
            child: SizedBox(
                // A fixed, generous height — the map view fits the whole
                // barangay boundary into it. A concrete height (vs. an
                // AspectRatio inside the scroll view) guarantees the map's
                // own LayoutBuilder gets a finite viewport to fit against.
                height: MediaQuery.sizeOf(context).height * 0.48,
                child: Stack(
                  children: [
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(color: AppColors.divider),
                        ),
                      ),
                      child: GisMapView(
                        focusPoint: widget.focusPoint,
                        focusRequest: _focus,
                        filters: _filters,
                        onPinTap: (r) =>
                            GisMapScreen.showReportDialog(context, r),
                        onTaggedBuildingTap: (tag) =>
                            GisMapScreen.showBuildingDialog(context, tag),
                        onFeatureTap: (info) =>
                            GisMapScreen.showFeatureInfoDialog(context, info),
                      ),
                    ),
                    // Compact, low-key "Report Incident" in the map's
                    // bottom-right corner.
                    Positioned(
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: Material(
                        color: AppColors.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        elevation: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          onTap: _openReportIncident,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.campaign_outlined,
                                    size: 16, color: AppColors.flagRed),
                                const SizedBox(width: 5),
                                Text(
                                  'Report Incident',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: AppColors.flagRed,
                                          fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Marker color legend (who filed the report).
                    Positioned(
                      left: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LegendRow(
                                color: kReportResidentColor,
                                label: 'Resident report'),
                            SizedBox(height: 4),
                            _LegendRow(
                                color: kReportOfficialColor,
                                label: 'Official report'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
          child: Text(
            'This map is for reference only. Tap a pin, tagged building, or '
            'marker to view its details.',
            style: text.labelSmall?.copyWith(color: AppColors.inkMuted),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Reports feed + AI panels (scroll below the map) ─────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.xxl),
          child: _buildFeedAndPanels(context, text),
        ),
        ],
      ),
    );
  }

  Widget _buildFeedAndPanels(BuildContext context, TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Recent community reports (web renderReportFeed) ─────
        _SectionCard(
          title: 'Recent Community Reports',
          child: AnimatedBuilder(
            animation: IncidentStore.instance,
            builder: (context, _) {
              // Latest five only — the full history lives in the Blotter.
              final reports =
                  IncidentStore.instance.all.take(5).toList();
              if (reports.isEmpty) {
                return Text(
                  'No community reports yet. Reports filed through the '
                  'Blotter service appear here and as pins on the map.',
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.inkMuted, height: 1.5),
                );
              }
              return Column(
                children: [
                  for (final r in reports)
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      onTap: () => GisMapScreen.showReportDialog(context, r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            // The report type's own icon, in the same color
                            // language as the map markers: resident green /
                            // official navy, muted when resolved or when
                            // the stored location can't be pinned.
                            Icon(
                              r.mapPoint == null
                                  ? Icons.location_off_outlined
                                  : kReportTypeIcons[r.typeKey] ??
                                      Icons.priority_high,
                              size: 20,
                              color: r.mapPoint == null || r.resolved
                                  ? AppColors.inkMuted
                                  : r.isOfficial
                                      ? kReportOfficialColor
                                      : kReportResidentColor,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.typeLabel,
                                      style: text.labelLarge?.copyWith(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                    '${r.caseNo} · ${r.complainant} · '
                                    '${MaterialLocalizations.of(context).formatShortMonthDay(r.createdAt)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.labelSmall?.copyWith(
                                        color: AppColors.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              r.resolved ? 'Resolved' : 'Active',
                              kind: r.resolved
                                  ? BadgeKind.success
                                  : BadgeKind.danger,
                            ),
                            // Icon-only "view on map": flies the pinned
                            // map above to this report's marker.
                            if (r.mapPoint != null)
                              IconButton(
                                tooltip: 'View on map',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.map_outlined,
                                    size: 19, color: AppColors.navy),
                                onPressed: () => _viewOnMap(r.mapPoint!),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── AI narrative report (placeholder container) ─────────
        _SectionCard(
          title: 'AI Narrative Report',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              'No narrative report generated yet.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ),
        ),
      ],
    );
  }
}

/// One legend entry: report-type icon swatch in its classification color.
/// One filter-row button (Map Layers / Building Type / Classification):
/// a compact outlined button that opens a sheet, highlighted when its
/// filter is active.
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
        backgroundColor:
            active ? AppColors.navy.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        side: BorderSide(
            color: active ? AppColors.navy : AppColors.divider,
            width: active ? 1.4 : 1),
      ),
      onPressed: onPressed,
      // Icon + label share the slot; the label ellipsizes so three buttons
      // fit one row on a phone.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.place, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.ink, fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm + 4),
          child,
        ],
      ),
    );
  }
}
