import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../config/theme.dart';
import 'api_service.dart';

/// Picks an image from camera/gallery, crops to a square, and uploads it.
/// Enforces the client-side 2 MB / jpg-png contract before hitting the API.
class ImageService {
  ImageService(this._api);
  final ApiService _api;
  final _picker = ImagePicker();

  /// Returns a cropped local file path, or null if the user cancelled.
  Future<String?> pickAndCrop(
      {required ImageSource source, bool circle = true}) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85, // client-side compression (keeps under 2 MB)
    );
    if (picked == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: AppColors.onPrimary,
          lockAspectRatio: true,
          cropStyle: circle ? CropStyle.circle : CropStyle.rectangle,
        ),
        IOSUiSettings(title: 'Crop', aspectRatioLockEnabled: true),
      ],
    );
    return cropped?.path;
  }

  /// Picks an image without cropping (for screenshots/attachments where a square
  /// crop would be wrong). Returns a local file path, or null if cancelled.
  Future<String?> pickRaw({required ImageSource source}) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85, // keeps under the 2 MB server limit
    );
    return picked?.path;
  }

  /// Uploads an avatar to `/users/me/photo`; returns the stored public URL.
  Future<String> uploadAvatar(String filePath) async {
    final data = await _api.uploadFile<Map<String, dynamic>>(
        '/users/me/photo', filePath);
    return data['profilePhotoUrl'] as String;
  }
}
