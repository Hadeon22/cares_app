import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';

/// Barangay Residency — resident search. Mobile version of the web's
/// modal-residency (filters + result cards).
class ResidencySearchScreen extends StatefulWidget {
  const ResidencySearchScreen({super.key});

  @override
  State<ResidencySearchScreen> createState() => _ResidencySearchScreenState();
}

class _ResidencySearchScreenState extends State<ResidencySearchScreen> {
  String _name = '';
  String? _purok;
  String? _category;
  String? _status;

  List<ResidentRecord> get _filtered {
    final nameQ = _name.toLowerCase();
    return kResidents.where((r) {
      if (nameQ.isNotEmpty && !r.name.toLowerCase().contains(nameQ)) {
        return false;
      }
      if (_purok != null && r.purok != _purok!.split(' – ').first) return false;
      if (_category != null && r.category != _category) return false;
      if (_status != null && r.status != _status) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Barangay Residency')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppSpacing.xxl),
        children: [
          const ServiceFlowHeader(
            icon: Icons.holiday_village_outlined,
            text: 'Search for registered residents in the Barangay Conde '
                'Labac system. Lookups are logged per RA 10173.',
          ),
          AppTextField(
            label: 'Full Name',
            hint: 'e.g. Santos, Pedro',
            onChanged: (v) => setState(() => _name = v),
          ),
          AppDropdown<String?>(
            label: 'Purok / Zone',
            value: _purok,
            items: [null, ...kPuroks],
            itemLabel: (v) => v ?? 'All Puroks',
            onChanged: (v) => setState(() => _purok = v),
          ),
          Row(
            children: [
              Expanded(
                child: AppDropdown<String?>(
                  label: 'Category',
                  value: _category,
                  items: const [null, ...kResidentCategories],
                  itemLabel: (v) => v ?? 'All Categories',
                  onChanged: (v) => setState(() => _category = v),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: AppDropdown<String?>(
                  label: 'Status',
                  value: _status,
                  items: const [null, ...kResidentStatuses],
                  itemLabel: (v) => v ?? 'All Statuses',
                  onChanged: (v) => setState(() => _status = v),
                ),
              ),
            ],
          ),
          Text(
            'Showing ${results.length} result${results.length == 1 ? '' : 's'}',
            style: text.labelMedium?.copyWith(
                color: AppColors.inkMuted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (results.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                'No residents found matching your search criteria.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            )
          else
            for (final r in results)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ResidentCard(record: r),
              ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              side: const BorderSide(color: AppColors.divider),
            ),
            onPressed: () => showAppToast(
                context, 'Exporting results as CSV...',
                icon: Icons.download_outlined),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Export Results'),
          ),
        ],
      ),
    );
  }
}

class _ResidentCard extends StatelessWidget {
  const _ResidentCard({required this.record});
  final ResidentRecord record;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.navy,
            child: Text(
              record.initials,
              style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.name,
                    style: text.titleSmall?.copyWith(
                        color: AppColors.ink, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${record.age} yrs · ${record.purok}'
                  '${record.category.isNotEmpty ? ' · ${record.category}' : ''}',
                  style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          StatusBadge(
            record.status,
            kind: record.status == 'Active'
                ? BadgeKind.success
                : BadgeKind.gray,
          ),
        ],
      ),
    );
  }
}
