import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/cloudinary_config.dart';

class CloudinaryHelper {
  /// Compresses an image file before upload.
  /// Aims for < 1MB and high quality.
  static Future<File> compressImage(File file) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'.png|.jp'));
    if (lastIndex == -1) return file;

    final outPath = "${filePath.substring(0, lastIndex)}_compressed.jpg";
    
    // Compress logic: Quality 80 with moderate scaling if needed
    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path, 
      outPath,
      quality: 80,
      format: CompressFormat.jpeg,
    );

    if (result == null) return file;
    
    final compressedFile = File(result.path);
    debugPrint('🌅 Image Compressed: ${(file.lengthSync() / 1024).toStringAsFixed(1)}KB -> ${(compressedFile.lengthSync() / 1024).toStringAsFixed(1)}KB');
    
    return compressedFile;
  }

  /// Uploads an image file to Cloudinary with AUTOMATIC compression.
  static Future<String?> uploadImage(File imageFile, {String? folder}) async {
    try {
      // 1. Compress first (to save storage)
      File finalFile = imageFile;
      
      // Only compress if it's not already small enough or if it's a raw file
      if (imageFile.lengthSync() > 500 * 1024) { 
        finalFile = await compressImage(imageFile);
      }

      final cloudName = CloudinaryConfig.cloudName;
      final uploadPreset = CloudinaryConfig.uploadPreset;
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = folder ?? CloudinaryConfig.uploadFolder
        ..files.add(await http.MultipartFile.fromPath('file', finalFile.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final respString = await response.stream.bytesToString();
        final json = jsonDecode(respString);
        
        // Clean up compressed temp file if it was created
        if (finalFile.path.contains('_compressed.jpg')) {
          await finalFile.delete().catchError((e) => null);
        }
        
        return json['secure_url'];
      } else {
        debugPrint('Cloudinary upload failed with status: ${response.statusCode}');
        final respString = await response.stream.bytesToString();
        debugPrint('Response: $respString');
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
    }
    return null;
  }

  /// Uploads image bytes (for Web support) with compression logic.
  static Future<String?> uploadBytes(Uint8List bytes, {String? folder}) async {
    try {
      Uint8List finalBytes = bytes;

      // Compress bytes if larger than 500KB
      if (bytes.length > 500 * 1024) {
        finalBytes = await FlutterImageCompress.compressWithList(
          bytes,
          minHeight: 1080,
          minWidth: 1080,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        debugPrint('🌅 Bytes Compressed: ${(bytes.length / 1024).toStringAsFixed(1)}KB -> ${(finalBytes.length / 1024).toStringAsFixed(1)}KB');
      }

      final cloudName = CloudinaryConfig.cloudName;
      final uploadPreset = CloudinaryConfig.uploadPreset;
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = folder ?? CloudinaryConfig.uploadFolder
        ..files.add(http.MultipartFile.fromBytes('file', finalBytes, filename: 'upload.jpg'));

      final response = await request.send();
      if (response.statusCode == 200) {
        final respString = await response.stream.bytesToString();
        final json = jsonDecode(respString);
        return json['secure_url'];
      } else {
        debugPrint('Cloudinary upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
    }
    return null;
  }
}
