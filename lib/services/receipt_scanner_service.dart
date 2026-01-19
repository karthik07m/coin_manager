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
  final DateTime? extractedDate;

  ScanResult({
    required this.imagePath,
    required this.rawText,
    this.extractedAmount,
    this.extractedTitle,
    this.extractedDate,
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

  /// Parse extracted text to find amount, title, and date
  ScanResult parseReceiptText(String rawText, String imagePath) {
    double? amount;
    String? title;
    DateTime? date;

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

    // Look for date - common patterns
    final datePatterns = [
      // MM/DD/YYYY or DD/MM/YYYY
      RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b'),
      // YYYY-MM-DD
      RegExp(r'\b(\d{4})[/-](\d{1,2})[/-](\d{1,2})\b'),
      // MMM DD, YYYY (e.g., Jan 15, 2024)
      RegExp(
          r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b',
          caseSensitive: false),
    ];

    for (final line in lines) {
      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          try {
            // Attempt to parse based on pattern
            // This is a simplified parse, could refer to a robust date parser
            // For now, let's just return the current date if found, or improve parsing
            // Given the limited context, returning "some" date if patterns match is complex without intl
            // but we can try to be smart.

            // Just flagging we found a date candidate string often works well enough
            // if we pass it to user to confirm. But let's try to parse if possible.
            // For now, let's assume if we match YYYY-MM-DD or MM/DD/YYYY
            if (match.groupCount >= 3) {
              // Very basic heuristic parsing
              // If year is first group:
              if (match.group(1)!.length == 4) {
                date = DateTime(int.parse(match.group(1)!),
                    int.parse(match.group(2)!), int.parse(match.group(3)!));
              } else if (match.group(3)!.length == 4) {
                // Year is last group
                // Ambiguity between MM/DD and DD/MM.
                // Default to US format MM/DD/YYYY for now or try both
                final p1 = int.parse(match.group(1)!);
                final p2 = int.parse(match.group(2)!);
                final y = int.parse(match.group(3)!);
                // Simple check: if p1 > 12, it must be DD/MM
                if (p1 > 12) {
                  date = DateTime(y, p2, p1);
                } else {
                  date = DateTime(y, p1, p2);
                }
              }
            }
          } catch (e) {
            // Ignore parse errors
          }
          if (date != null) break;
        }
      }
      if (date != null) break;
    }

    return ScanResult(
      imagePath: imagePath,
      rawText: rawText,
      extractedAmount: amount,
      extractedTitle: title,
      extractedDate: date,
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
