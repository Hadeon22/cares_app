import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/session.dart';
import '../data/stores.dart';
import 'app_toast.dart';
import 'form_widgets.dart';

/// The blanks on the printed certificate — the app's half of the web's
/// fill-in form (js/certificate-export.js).
///
/// The app does not draw the A4 sheet; the web does that and prints it. What
/// matters here is the *data*: whatever is typed goes to certificate.form_fields
/// on the server, so a resident filling this in on their phone is what the
/// barangay prints from the web, and anything staff typed on the web shows up
/// here. One row, either direction.
///
/// Which blanks a certificate has comes from [CertificateType.fields], mirrored
/// from the web's js/certificate-templates.js.
Future<void> showCertificateFieldsSheet(
  BuildContext context,
  CertificateRequest request, {
  bool readOnly = false,
}) async {
  final type = request.type;
  if (type.fields.isEmpty) {
    showAppToast(
        context, 'There is no printable form for ${type.name} yet.',
        icon: Icons.info_outline);
    return;
  }
  // Edit the *current* values, not a cached copy: staff may have typed on the
  // web since this list was loaded, and saving stale values would quietly
  // overwrite theirs. Best-effort — offline still opens what we have.
  CertificateRequest current = request;
  if (request.id > 0) {
    try {
      current = await CertificateStore.instance.reload(request.id);
    } catch (_) {
      /* keep the cached copy */
    }
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
    ),
    builder: (_) => _CertificateFieldsSheet(
      request: current,
      readOnly: readOnly,
    ),
  );
}

class _CertificateFieldsSheet extends StatefulWidget {
  const _CertificateFieldsSheet({
    required this.request,
    required this.readOnly,
  });

  final CertificateRequest request;
  final bool readOnly;

  @override
  State<_CertificateFieldsSheet> createState() =>
      _CertificateFieldsSheetState();
}

class _CertificateFieldsSheetState extends State<_CertificateFieldsSheet> {
  late final Map<String, TextEditingController> _text;
  late final Map<String, String> _choice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final saved = widget.request.formFields;
    _text = {};
    _choice = {};
    for (final f in widget.request.type.fields) {
      if (f.isChoice) {
        // An unrecognised stored value (an older option, say) falls back to the
        // first rather than throwing inside the dropdown.
        final v = saved[f.key];
        _choice[f.key] =
            v != null && f.options!.contains(v) ? v : f.options!.first;
      } else {
        _text[f.key] = TextEditingController(text: saved[f.key] ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _collect() {
    final out = <String, String>{};
    _text.forEach((k, c) => out[k] = c.text.trim());
    _choice.forEach((k, v) => out[k] = v);
    // Anything the web filled in that this version of the app doesn't know
    // about is carried through untouched, rather than silently dropped.
    widget.request.formFields.forEach((k, v) {
      if (!out.containsKey(k)) out[k] = v;
    });
    return out;
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await CertificateStore.instance.saveFields(widget.request, _collect(),
          accountId: AppSession.instance.accountId);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAppToast(context, 'Could not save: $e', icon: Icons.error_outline);
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppToast(context, 'Certificate details saved.');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fields = widget.request.type.fields;
    String? lastGroup;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, scrollCtrl) => Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                  AppSpacing.md, AppSpacing.gutter, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('The certificate',
                      style: text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    widget.readOnly
                        ? 'What the barangay will print on your '
                            '${widget.request.type.shortName}.'
                        : 'Fill in the blanks on the barangay\'s form. This is '
                            'saved with the request, so the office prints '
                            'exactly what is entered here.',
                    style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0,
                    AppSpacing.gutter, AppSpacing.lg),
                children: [
                  for (final f in fields) ...[
                    if (f.group != null && f.group != lastGroup) ...[
                      Builder(builder: (_) {
                        lastGroup = f.group;
                        return const SizedBox.shrink();
                      }),
                      Padding(
                        padding: const EdgeInsets.only(
                            top: AppSpacing.sm, bottom: 2),
                        child: Text(
                          f.group!.toUpperCase(),
                          style: text.labelSmall?.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8),
                        ),
                      ),
                    ],
                    if (f.isChoice)
                      // AppDropdown takes a non-null callback, so read-only is
                      // enforced by ignoring pointers rather than by disabling.
                      IgnorePointer(
                        ignoring: widget.readOnly,
                        child: AppDropdown<String>(
                          label: f.label,
                          value: _choice[f.key],
                          items: f.options!,
                          onChanged: (v) => setState(
                              () => _choice[f.key] = v ?? _choice[f.key]!),
                        ),
                      )
                    else
                      AppTextField(
                        label: f.label,
                        controller: _text[f.key],
                        hint: f.hint,
                        readOnly: widget.readOnly,
                      ),
                  ],
                ],
              ),
            ),
            if (!widget.readOnly)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0,
                      AppSpacing.gutter, AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _save,
                          icon: _busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_outlined, size: 16),
                          label: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
