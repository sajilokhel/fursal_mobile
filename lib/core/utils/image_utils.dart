import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;

class ImageUtils {
  static Future<File> compressImage(File file) async {
    final tempDir = await path_provider.getTemporaryDirectory();
    final extension = p.extension(file.path).toLowerCase();
    // Ensure we use .jpg or .png for the target path to avoid compression issues
    final outExtension = (extension == '.png' || extension == '.jpg' || extension == '.jpeg') ? extension : '.jpg';
    final targetPath = p.join(tempDir.path, "compressed_${DateTime.now().millisecondsSinceEpoch}$outExtension");

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
    );

    if (result == null) {
      return file;
    }

    return File(result.path);
  }
}
