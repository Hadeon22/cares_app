import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';
import 'mis_widgets.dart';

/// Barangay Residency module (js/pages/residency.js) — KPIs + the
/// resident directory with name/purok filtering.
class ResidencyPage extends StatefulWidget {
  const ResidencyPage({super.key});

  @override
  State<ResidencyPage> createState() => _ResidencyPageState();
}

class _ResidencyPageState extends State<ResidencyPage> {
  String _query = '';
  String? _purok;

  @override
  void initState() {
    super.initState();
    ResidentStore.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ResidentStore.instance,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final store = ResidentStore.instance;
    final text = Theme.of(context).textTheme;
    final rows = store.all.where((r) {
      if (_query.isNotEmpty &&
          !r.name.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      if (_purok != null && r.purok != _purok) return false;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
          AppSpacing.gutter, AppSpacing.xxl),
      children: [
        const MisPageHeader(
          title: 'Barangay Residency',
          desc: 'Full resident database — search, view, and manage resident '
              'profiles',
        ),
        KpiGrid(cards: [
          KpiCard(
              label: 'Total Residents',
              value: '${store.all.length}',
              trend: store.loading ? 'Loading…' : 'Live from database'),
          KpiCard(
              label: 'Accounts Claimed',
              value: '${store.claimedCount}',
              accent: KpiAccent.success),
          KpiCard(
              label: 'Senior Citizens',
              value: '${store.countWithCategory('Senior Citizen')}',
              accent: KpiAccent.info),
          KpiCard(
              label: 'PWD Residents',
              value: '${store.countWithCategory('PWD')}',
              accent: KpiAccent.warning),
        ]),
        MisCard(
          title: 'Resident Directory',
          action: '⤓ Export CSV',
          onAction: () => showAppToast(context, 'Exporting results as CSV...',
              icon: Icons.download_outlined),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String?>(
                initialValue: _purok,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('All Puroks')),
                  for (var i = 1; i <= 5; i++)
                    DropdownMenuItem(
                        value: 'Purok $i', child: Text('Purok $i')),
                ],
                onChanged: (v) => setState(() => _purok = v),
              ),
              const SizedBox(height: AppSpacing.md),
              if (store.loading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold)),
                )
              else if (store.error != null)
                EmptyState('Could not load residents.\n${store.error}')
              else if (rows.isEmpty)
                const EmptyState(
                    'No residents found matching your search criteria.')
              else
                for (final r in rows)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.sm + 4),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name,
                                  style: text.titleSmall?.copyWith(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('${r.ageLabel} yrs',
                                      style: text.labelSmall?.copyWith(
                                          color: AppColors.inkMuted)),
                                  StatusBadge(r.purok, kind: BadgeKind.gray),
                                  if (r.category.isNotEmpty)
                                    StatusBadge(r.category,
                                        kind: BadgeKind.gold),
                                  StatusBadge(r.status,
                                      kind: r.status == 'Active'
                                          ? BadgeKind.success
                                          : BadgeKind.gray),
                                ],
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => showAppToast(context,
                              'Viewing ${r.name.split(',').first}'),
                          child: const Text('View'),
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
