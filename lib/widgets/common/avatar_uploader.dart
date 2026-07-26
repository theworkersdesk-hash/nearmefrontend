import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import 'avatar.dart';

/// Tappable avatar that picks → crops → uploads a new profile photo.
class AvatarUploader extends ConsumerStatefulWidget {
  const AvatarUploader({super.key, this.radius = 48});
  final double radius;

  @override
  ConsumerState<AvatarUploader> createState() => _AvatarUploaderState();
}

class _AvatarUploaderState extends ConsumerState<AvatarUploader> {
  bool _uploading = false;

  Future<void> _choose() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final path =
        await ref.read(imageServiceProvider).pickAndCrop(source: source);
    if (path == null) return;

    setState(() => _uploading = true);
    final ok = await ref.read(authProvider.notifier).uploadAvatar(path);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ref.read(authProvider).error ?? 'Upload failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Avatar(
            url: user?.profilePhotoUrl,
            name: user?.fullName ?? user?.email,
            radius: widget.radius),
        if (_uploading)
          Positioned.fill(
            child: CircleAvatar(
              radius: widget.radius,
              backgroundColor: Colors.black26,
              child: const CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
          ),
        InkWell(
          onTap: _uploading ? null : _choose,
          customBorder: const CircleBorder(),
          child: const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.edit, size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
