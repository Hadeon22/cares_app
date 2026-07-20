import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

/// Renders a long list one page at a time (default 10 rows) with a compact
/// prev/next footer — the shared paging used by every MIS list. Give it the
/// full [items] and an [itemBuilder]; it slices the current page and shows
/// the arrow controls only when there's more than one page.
///
/// The page index is clamped whenever [items] shrinks (e.g. after a search
/// filter or a delete), so the view never lands on an empty page.
class PaginatedColumn<T> extends StatefulWidget {
  const PaginatedColumn({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.pageSize = 10,
    this.itemLabel = 'item',
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final int pageSize;

  /// Noun shown in the footer count ("12 residents"); pluralized with 's'.
  final String itemLabel;

  @override
  State<PaginatedColumn<T>> createState() => _PaginatedColumnState<T>();
}

class _PaginatedColumnState<T> extends State<PaginatedColumn<T>> {
  int _page = 0;

  int get _pageCount =>
      widget.items.isEmpty ? 1 : ((widget.items.length - 1) ~/ widget.pageSize) + 1;

  @override
  void didUpdateWidget(covariant PaginatedColumn<T> old) {
    super.didUpdateWidget(old);
    // The list can shrink under us (filter / delete) — keep the page valid.
    if (_page >= _pageCount) _page = _pageCount - 1;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    final start = _page * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, total);
    final pageItems = widget.items.sublist(start.clamp(0, total), end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in pageItems) widget.itemBuilder(context, item),
        if (_pageCount > 1) _footer(context, total, start, end),
      ],
    );
  }

  Widget _footer(BuildContext context, int total, int start, int end) {
    final text = Theme.of(context).textTheme;
    final label = widget.itemLabel + (total == 1 ? '' : 's');
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ArrowButton(
            icon: Icons.chevron_left,
            tooltip: 'Previous page',
            onPressed: _page > 0 ? () => setState(() => _page--) : null,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Page ${_page + 1} of $_pageCount',
                  style: text.labelMedium?.copyWith(
                      color: AppColors.ink, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${start + 1}–$end of $total $label',
                  style:
                      text.labelSmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          _ArrowButton(
            icon: Icons.chevron_right,
            tooltip: 'Next page',
            onPressed:
                _page < _pageCount - 1 ? () => setState(() => _page++) : null,
          ),
        ],
      ),
    );
  }
}

/// Round outlined arrow for the pager; disabled (muted) at the ends.
class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: enabled ? AppColors.navy : AppColors.divider,
        foregroundColor: enabled ? AppColors.onNavy : AppColors.inkMuted,
        minimumSize: const Size(40, 40),
      ),
      icon: Icon(icon, size: 22),
    );
  }
}
