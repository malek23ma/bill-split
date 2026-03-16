import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ReceiptScanner {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> scanImage(String imagePath) async {
    // Preprocess for better OCR on thermal receipts
    final preprocessedPath = await _preprocessImage(imagePath);
    final pathToUse = preprocessedPath ?? imagePath;

    final inputImage = InputImage.fromFilePath(pathToUse);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    // Clean up temp file
    if (preprocessedPath != null) {
      try {
        await File(preprocessedPath).delete();
      } catch (_) {}
    }

    final lines = <String>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        lines.add(line.text);
      }
    }

    return lines.join('\n');
  }

  /// Converts image to high-contrast grayscale for better OCR on receipts.
  Future<String?> _preprocessImage(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return null;

      // Convert to grayscale
      image = img.grayscale(image);

      // Normalize histogram — stretches contrast to use full 0-255 range.
      // This helps with faded thermal receipt paper.
      image = img.normalize(image, min: 0, max: 255);

      // Boost contrast to make text stand out
      image = img.adjustColor(image, contrast: 1.8);

      // Save as high-quality PNG (lossless) for OCR
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/receipt_preprocessed_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(outputPath).writeAsBytes(img.encodePng(image));

      return outputPath;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
