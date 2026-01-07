import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Result from scanning a receipt
class ScanResult {
  final String imagePath;
  final String rawText;
  final double? extractedAmount;
  final String? extractedTitle;

  ScanResult({
    required this.imagePath,
    required this.rawText,
    this.extractedAmount,
    this.extractedTitle,
  });
}

class ReceiptScannerService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Capture image from camera
  Future<File?> captureFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        return File(photo.path);
      }
    } catch (e) {
      debugPrint('Error capturing from camera: $e');
    }
    return null;
  }

  /// Pick image from gallery
  Future<File?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        return File(image.path);
      }
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
    }
    return null;
  }

  /// Copy image to app's permanent storage
  Future<String> saveImageToStorage(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${directory.path}/receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final fileName =
        'receipt_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
    final savedFile = await imageFile.copy('${receiptsDir.path}/$fileName');
    return savedFile.path;
  }

  /// Perform OCR on the image
  Future<String> extractText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      debugPrint('Error extracting text: $e');
      return '';
    }
  }

  /// Parse extracted text to find amount and title
  ScanResult parseReceiptText(String rawText, String imagePath) {
    double? amount;
    String? title;

    // Split text into lines
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Try to find the store name (usually first non-empty line)
    if (lines.isNotEmpty) {
      title = lines.first;
    }

    // Look for total amount - common patterns
    final totalPatterns = [
      RegExp(
          r'(?:total|amount|sum|grand total|subtotal)[:\s]*[\$€£]?\s*(\d+[.,]\d{2})',
          caseSensitive: false),
      RegExp(r'[\$€£]\s*(\d+[.,]\d{2})'),
      RegExp(r'(\d+[.,]\d{2})\s*(?:total|amount)', caseSensitive: false),
    ];

    // Search from bottom up (totals usually at bottom)
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      for (final pattern in totalPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final amountStr = match.group(1)?.replaceAll(',', '.');
          if (amountStr != null) {
            amount = double.tryParse(amountStr);
            if (amount != null) break;
          }
        }
      }
      if (amount != null) break;
    }

    return ScanResult(
      imagePath: imagePath,
      rawText: rawText,
      extractedAmount: amount,
      extractedTitle: title,
    );
  }

  /// Full scan workflow: capture/pick -> save -> OCR -> parse
  Future<ScanResult?> scanReceipt({required bool fromCamera}) async {
    // 1. Get image
    final File? imageFile =
        fromCamera ? await captureFromCamera() : await pickFromGallery();

    if (imageFile == null) return null;

    // 2. Save to permanent storage
    final savedPath = await saveImageToStorage(imageFile);

    // 3. Extract text
    final rawText = await extractText(imageFile);

    // 4. Parse and return result
    return parseReceiptText(rawText, savedPath);
  }

  void dispose() {
    _textRecognizer.close();
  }
}
