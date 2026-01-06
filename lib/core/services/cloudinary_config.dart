// lib/core/cloudinary_config.dart

class CloudinaryConfig {
  static const String cloudName = 'dntnzraxh';
  static const String uploadPreset = 'gym_uploads';

  // Upload settings for profile photos
  static const String uploadFolder = 'profile_photos';
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const int imageQuality = 80;
  static const int maxWidth = 800;
  static const int maxHeight = 800;
}