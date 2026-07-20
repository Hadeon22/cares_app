import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../data/session.dart';

/// Decodes a `data:image/...;base64,...` URL into bytes for [MemoryImage].
/// Returns null for anything that isn't a data URL.
Uint8List? photoBytesFromDataUrl(String? dataUrl) {
  if (dataUrl == null || !dataUrl.startsWith('data:image')) return null;
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return null;
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

/// Circular resident photo — the photo when one is on record, otherwise the
/// gold initials avatar used across the app.
class ResidentAvatar extends StatelessWidget {
  const ResidentAvatar({
    super.key,
    required this.initials,
    this.photo,
    this.radius = 24,
  });

  final String initials;

  /// base64 data URL (resident.photo) or null.
  final String? photo;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = photoBytesFromDataUrl(photo);
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.gold,
      backgroundImage: bytes == null ? null : MemoryImage(bytes),
      child: bytes != null
          ? null
          : Text(
              initials,
              style: TextStyle(
                color: AppColors.navyDeep,
                fontWeight: FontWeight.w900,
                fontSize: radius * 0.66,
              ),
            ),
    );
  }
}

/// The signed-in user's avatar — their resident profile photo when one is
/// on record (kept fresh via [AppSession.photoNotifier]), otherwise the
/// gold initials. Used by the navbar, profile header, and MIS drawer.
class SessionAvatar extends StatelessWidget {
  const SessionAvatar({super.key, this.radius = 16});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: AppSession.instance.photoNotifier,
      builder: (context, photo, _) => ResidentAvatar(
        initials: AppSession.instance.initials,
        photo: photo,
        radius: radius,
      ),
    );
  }
}

/// Profile-photo input for the resident forms: avatar preview + change /
/// remove actions. Emits the picked image as a base64 data URL through
/// [onChanged] (null = photo removed). Images are downscaled on pick
/// (640px, ~70% quality) so the JSON payload stays small.
class ResidentPhotoPicker extends StatelessWidget {
  const ResidentPhotoPicker({
    super.key,
    required this.photo,
    required this.onChanged,
    this.initials = '?',
  });

  final String? photo;
  final ValueChanged<String?> onChanged;
  final String initials;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 70,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open the image picker: $e')));
      }
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    onChanged('data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.navy),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheet).pop();
                _pick(context, ImageSource.gallery);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_camera_outlined, color: AppColors.navy),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(sheet).pop();
                _pick(context, ImageSource.camera);
              },
            ),
            if (photo != null)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.flagRed),
                title: const Text('Remove photo',
                    style: TextStyle(color: AppColors.flagRed)),
                onTap: () {
                  Navigator.of(sheet).pop();
                  onChanged(null);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Stack(
          children: [
            ResidentAvatar(initials: initials, photo: photo, radius: 34),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_camera,
                    size: 13, color: AppColors.onNavy),
              ),
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile Photo',
                  style: text.labelLarge?.copyWith(
                      color: AppColors.ink, fontWeight: FontWeight.w700)),
              Text(
                photo == null
                    ? 'Optional — tap to add a photo'
                    : 'Tap to change or remove',
                style: text.labelSmall?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
        OutlinedButton(
          // Navy on light — the theme's outlined style is for navy
          // backdrops and would be invisible on the form's background.
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.navy,
            side: const BorderSide(color: AppColors.navy, width: 1.2),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: () => _showOptions(context),
          child: Text(photo == null ? 'Add' : 'Change'),
        ),
      ],
    );
  }
}
