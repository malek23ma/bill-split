import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressService {
  /// Compress image to max 1200px wide, 70% JPEG quality
  static Future<File> compress(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      minWidth: 1200,
      minHeight: 1200,
      quality: 70,
    );
    if (result == null) return file; // fallback to original if compression fails
    return File(result.path);
  }
}
