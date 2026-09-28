import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/session.dart';
import '../../data/stores.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/form_widgets.dart';

/// Resident Feedback — mobile version of the web's modal-feedback:
/// category, 5-star satisfaction rating, comment, optional identity.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String _category = kFeedbackCategories.first;

  /// 0 = nothing chosen. The screen used to open with four stars lit, so a
  /// resident who never touched the row had their submission filed as "Good" —
  /// an opinion they never gave, counted into the barangay's average rating.
  /// Submitting without a rating is refused below.
  int _rating = 0;

  /// Set when submit is pressed with no rating, so the row turns amber and
  /// says what is missing rather than only flashing a toast.
  bool _ratingMissing = false;
  final _comment = TextEditingController();
  final _name = TextEditingController();
  final _contact = TextEditingController();

  @override
  void dispose() {
    for (final c in [_comment, _name, _contact]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _busy = false;

  Future<void> _submit() async {
    if (_busy) return;
    if (_rating == 0) {
      setState(() => _ratingMissing = true);
      showAppToast(context, 'Choose a star rating — one to five.',
          icon: Icons.error_outline);
      return;
    }
    if (_comment.text.trim().isEmpty) {
      showAppToast(context, 'Please enter a comment or suggestion.',
          icon: Icons.error_outline);
      return;
    }
    setState(() => _busy = true);
    try {
      await FeedbackStore.instance.add(
        rating: _rating,
        category: _category,
        comment: _comment.text.trim(),
        name: _name.text,
        contact: _contact.text.trim(),
        accountId: AppSession.instance.accountId,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAppToast(context, e.toString(), icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      'FEEDBACK_SUBMIT',
      'Feedback submitted — rated $_rating/5 (${kRatingLabels[_rating]})',
      category: AuditCategory.feedback,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppToast(context, 'Feedback submitted! Thank you for your input.',
        icon: Icons.chat_bubble_outline);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Resident Feedback')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, AppSpacing.lg,
            AppSpacing.gutter, AppSpacing.xxl),
        children: [
          const ServiceFlowHeader(
            icon: Icons.chat_bubble_outline,
            text: 'Your feedback helps the barangay improve its services. '
                'All submissions are confidential and reviewed monthly by '
                'barangay officials.',
          ),
          AppDropdown<String>(
            label: 'Category',
            value: _category,
            items: kFeedbackCategories,
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const FieldLabel('Overall Satisfaction'),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() {
                    _rating = i;
                    _ratingMissing = false;
                  }),
                  iconSize: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  icon: Icon(
                    i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    // Only the OUTLINE stars carry the refusal colour, never a
                    // filled one — a red outline cannot be mistaken for a star
                    // that is selected, which a red fill could.
                    color: i <= _rating
                        ? AppColors.gold
                        : (_ratingMissing
                            ? AppColors.emergency
                            : AppColors.divider),
                  ),
                ),
            ],
          ),
          Text(
            _rating == 0
                ? (_ratingMissing
                    ? 'Choose a star rating — one to five.'
                    : 'Select a rating')
                : '$_rating out of 5 – ${kRatingLabels[_rating]}',
            style: text.labelMedium?.copyWith(
                color: _ratingMissing ? AppColors.emergency : AppColors.inkMuted,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Your Comment or Suggestion',
            controller: _comment,
            maxLines: 4,
            hint: 'Share your experience, suggestions, or concerns about '
                'barangay services...',
          ),
          AppTextField(
            label: 'Your Name (optional)',
            controller: _name,
            hint: 'Leave blank to submit anonymously',
          ),
          AppTextField(
            label: 'Contact (optional)',
            controller: _contact,
            hint: 'Email or phone number',
          ),
          const AlertBanner(
            kind: AlertKind.success,
            child: Text('Feedback is reviewed by the Barangay Chairperson '
                'and department heads during monthly meetings.'),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check, size: 18),
            label: const Text('Submit Feedback'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
