import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/session.dart';
import '../data/stores.dart';
import 'app_toast.dart';
import 'form_widgets.dart';

/// Requirement documents for a certificate request — the app half of the web's
/// js/certificate-attachments.js.
///
/// Two widgets, for the two sides of the same thing:
///   [RequirementPicker]  the requester, filing: one row per document the
///                        certificate asks for, each taking a photo.
///   [AttachmentsPanel]   staff, reviewing: what came in, with a viewer and the
///                        retention hold.
///
/// Which documents a type asks for is declared on [CertificateType]. How long
/// they are kept is the server's business (retention-service.js); this only
/// reports it.

/// Photos are downscaled before encoding: the payload is a base64 data URL
/// inside a JSON body, and the server caps a file at 3 MB.
const int _kMaxUploadBytes = 3 * 1024 * 1024;

String _fileSize(int bytes) => bytes >= 1048576
    ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).round()} KB';

/// Reads a photo and returns it as a data URL, or null if cancelled/too big.
Future<String?> _pickAsDataUrl(BuildContext context, ImageSource source) async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 78,
    );
  } catch (e) {
    if (context.mounted) {
      showAppToast(context, 'Could not open the camera: $e',
          icon: Icons.error_outline);
    }
    return null;
  }
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > _kMaxUploadBytes) {
    if (context.mounted) {
      showAppToast(
          context,
          'That photo is ${_fileSize(bytes.length)} — the limit is 3 MB. '
          'Try again with less detail.',
          icon: Icons.error_outline);
    }
    return null;
  }
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

/// A photo the requester has chosen but not yet uploaded — an attachment needs
/// a request to belong to, so these are held until the request is filed.
class PendingRequirement {
  PendingRequirement(this.requirement, this.dataUrl, this.byteSize);

  final CertRequirement requirement;
  final String dataUrl;
  final int byteSize;
}

/// The requester's side: one card per document, each taking a photo.
class RequirementPicker extends StatefulWidget {
  const RequirementPicker({
    super.key,
    required this.type,
    required this.chosen,
    required this.onChanged,
  });

  final CertificateType type;

  /// requirement key → the photo chosen for it. Owned by the parent so it
  /// survives a rebuild and can be read at submit time.
  final Map<String, PendingRequirement> chosen;
  final VoidCallback onChanged;

  @override
  State<RequirementPicker> createState() => _RequirementPickerState();
}

class _RequirementPickerState extends State<RequirementPicker> {
  Future<void> _pick(CertRequirement r) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Text(r.label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            if (widget.chosen.containsKey(r.key))
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppColors.flagRed),
                title: const Text('Remove',
                    style: TextStyle(color: AppColors.flagRed)),
                onTap: () => Navigator.of(context).pop(),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final dataUrl = await _pickAsDataUrl(context, source);
    if (dataUrl == null || !mounted) return;
    // The data URL is base64: 4 characters per 3 bytes.
    final b64 = dataUrl.split(',').last;
    setState(() {
      widget.chosen[r.key] =
          PendingRequirement(r, dataUrl, (b64.length * 3) ~/ 4);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final reqs = widget.type.requirements;
    if (reqs.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final anyHealth = reqs.any((r) => r.isHealth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Requirements'),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Photos of these are checked against your request before the '
            'certificate is printed. Clear phone photos are fine. They are '
            'deleted ${anyHealth ? "30–90 days" : "90 days"} after your '
            'request is finished.',
            style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        ),
        for (final r in reqs) _card(context, r),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _card(BuildContext context, CertRequirement r) {
    final text = Theme.of(context).textTheme;
    final chosen = widget.chosen[r.key];
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: chosen != null ? AppColors.success : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.label,
                    style: text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              StatusBadge(r.required ? 'Required' : 'Optional',
                  kind: r.required ? BadgeKind.warning : BadgeKind.gray),
              if (r.isHealth) ...[
                const SizedBox(width: 4),
                const StatusBadge('Kept 30 days', kind: BadgeKind.info),
              ],
            ],
          ),
          if (r.note != null) ...[
            const SizedBox(height: 2),
            Text(r.note!,
                style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _pick(r),
                icon: Icon(
                    chosen == null
                        ? Icons.add_a_photo_outlined
                        : Icons.check_circle_outline,
                    size: 16),
                label: Text(chosen == null ? 'Attach photo' : 'Replace'),
              ),
              if (chosen != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(_fileSize(chosen.byteSize),
                      style: text.bodySmall
                          ?.copyWith(color: AppColors.inkMuted)),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() => widget.chosen.remove(r.key));
                    widget.onChanged();
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Required documents with no photo chosen — the submit path warns about these
/// rather than blocking, since a walk-in can still bring the paper.
List<String> missingRequirements(
        CertificateType type, Map<String, PendingRequirement> chosen) =>
    type.requirements
        .where((r) => r.required && !chosen.containsKey(r.key))
        .map((r) => r.label)
        .toList();

/// Uploads everything chosen, once the request exists to attach it to.
/// Returns what failed: a request that is already filed must not look like it
/// failed because one photo didn't upload.
Future<List<String>> uploadPending(
    CertificateRequest request, Map<String, PendingRequirement> chosen) async {
  final failed = <String>[];
  for (final p in chosen.values) {
    try {
      await CertificateStore.instance.upload(
        request: request,
        requirementKey: p.requirement.key,
        label: p.requirement.label,
        dataUrl: p.dataUrl,
        fileName: '${p.requirement.key}.jpg',
        sensitivity: p.requirement.sensitivity,
        accountId: AppSession.instance.accountId,
      );
    } catch (e) {
      failed.add('${p.requirement.label} ($e)');
    }
  }
  return failed;
}

/// Staff's side: what came in, with a viewer and the retention hold.
class AttachmentsPanel extends StatefulWidget {
  const AttachmentsPanel({super.key, required this.request});

  final CertificateRequest request;

  @override
  State<AttachmentsPanel> createState() => _AttachmentsPanelState();
}

class _AttachmentsPanelState extends State<AttachmentsPanel> {
  List<CertificateAttachment>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows =
          await CertificateStore.instance.attachments(widget.request.id);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _view(CertificateAttachment a) async {
    final CertificateAttachment full;
    try {
      full = await CertificateStore.instance
          .attachment(widget.request.id, a.id);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Could not open that document: $e',
            icon: Icons.error_outline);
      }
      return;
    }
    if (!mounted || full.dataUrl == null) return;
    final b64 = full.dataUrl!.split(',').last;
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(full.label,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: full.isPdf
                  // No PDF renderer in the app; the web viewer opens these.
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'This requirement was uploaded as a PDF. Open it from '
                        'the web system to view it.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : InteractiveViewer(
                      maxScale: 5,
                      child: Image.memory(base64Decode(b64)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleHold(CertificateAttachment a) async {
    try {
      await CertificateStore.instance.setRetentionHold(
          widget.request.id, a, !a.retentionHold,
          accountId: AppSession.instance.accountId);
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Could not change the hold: $e',
            icon: Icons.error_outline);
      }
      return;
    }
    AuditLog.instance.log(
      a.retentionHold ? 'CERT_ATTACHMENT_HOLD' : 'CERT_ATTACHMENT_UNHOLD',
      'Retention hold ${a.retentionHold ? "placed on" : "released for"} '
      'attachment #${a.id}',
      category: AuditCategory.certificate,
    );
    if (mounted) {
      setState(() {});
      showAppToast(
          context,
          a.retentionHold
              ? 'Held — this document will not be deleted on schedule.'
              : 'Hold released — the retention schedule applies again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reqs = widget.request.type.requirements;
    if (_error != null) {
      return Text('Could not load the attached documents.\n$_error',
          style: text.bodySmall?.copyWith(color: AppColors.flagRed));
    }
    if (_rows == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    final byKey = {for (final a in _rows!) a.requirementKey: a};
    final got = reqs.where((r) => byKey.containsKey(r.key)).length;
    final disposed = _rows!.where((a) => !a.available).length;
    final extra = _rows!
        .where((a) => !reqs.any((r) => r.key == a.requirementKey))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Requirements — $got of ${reqs.length} submitted'
          '${disposed > 0 ? " · $disposed disposed of" : ""}',
          style: text.labelSmall?.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final r in reqs)
          _item(context, r.label, r.required, r.isHealth, byKey[r.key]),
        for (final a in extra)
          _item(context, a.label, false, a.isHealth, a),
      ],
    );
  }

  Widget _item(BuildContext context, String label, bool required, bool health,
      CertificateAttachment? a) {
    final text = Theme.of(context).textTheme;
    final loc = MaterialLocalizations.of(context);
    final BadgeKind kind;
    final String state;
    if (a == null) {
      kind = required ? BadgeKind.warning : BadgeKind.gray;
      state = 'Not submitted';
    } else if (!a.available) {
      kind = BadgeKind.gray;
      state = 'Disposed of';
    } else {
      kind = BadgeKind.success;
      state = 'Submitted';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              StatusBadge(state, kind: kind),
              if (health) ...[
                const SizedBox(width: 4),
                const StatusBadge('Health record', kind: BadgeKind.info),
              ],
            ],
          ),
          if (a != null && a.available) ...[
            const SizedBox(height: 2),
            Text(
              '${a.fileName ?? a.mimeType} · ${_fileSize(a.byteSize)} · '
              'uploaded ${loc.formatMediumDate(a.uploadedAt)}'
              '${a.purgeAfter != null && !a.retentionHold ? " · deleted ${loc.formatMediumDate(a.purgeAfter!)}" : ""}',
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _view(a),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View'),
                ),
                const SizedBox(width: AppSpacing.sm),
                // A pressed toggle, not a label that flips: the hold is a state
                // of the document, so the control shows whether it is on.
                Expanded(
                  child: a.retentionHold
                      ? FilledButton.icon(
                          onPressed: () => _toggleHold(a),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.navy),
                          icon: const Icon(Icons.lock_outline, size: 16),
                          label: const Text('Held from deletion',
                              overflow: TextOverflow.ellipsis),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => _toggleHold(a),
                          icon: const Icon(Icons.lock_open_outlined, size: 16),
                          label: const Text('Hold from deletion',
                              overflow: TextOverflow.ellipsis),
                        ),
                ),
              ],
            ),
          ] else if (a != null && !a.available) ...[
            const SizedBox(height: 2),
            Text(
              'Deleted ${a.purgedAt == null ? "" : loc.formatMediumDate(a.purgedAt!)} '
              'under the retention rule. The record that it was submitted remains.',
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}
