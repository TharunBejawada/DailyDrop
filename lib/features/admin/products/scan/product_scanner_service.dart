// lib/features/admin/products/scan/product_scanner_service.dart
//
// Two different recognition problems, tried in order:
//   1. OCR (packaging text) — works for anything with a printed label.
//   2. Image labeling (no text) — works for loose produce like a tomato
//      or banana with nothing printed on it.
// Both run fully on-device — no network call, no per-scan cost, works
// offline. Android/iOS only (see pubspec note — no Flutter Web support).

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class ScanResult {
  final String? suggestedName;
  final String source; // 'packaging text', 'image recognition', or 'none'
  ScanResult({required this.suggestedName, required this.source});
}

class ProductScannerService {
  Future<ScanResult> scan(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);

    final textRecognizer = TextRecognizer();
    String? nameFromText;
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final cleaned = recognizedText.text.replaceAll('\n', ' ').trim();
      if (cleaned.length > 3) {
        // Admin edits this before saving, so "good enough starting point"
        // is the bar, not a perfectly clean name.
        nameFromText = cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
      }
    } finally {
      textRecognizer.close();
    }

    if (nameFromText != null) {
      return ScanResult(suggestedName: _titleCase(nameFromText), source: 'packaging text');
    }

    final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.6));
    try {
      final labels = await labeler.processImage(inputImage);
      if (labels.isNotEmpty) {
        labels.sort((a, b) => b.confidence.compareTo(a.confidence));
        return ScanResult(
          suggestedName: _titleCase(labels.first.label),
          source: 'image recognition',
        );
      }
    } finally {
      labeler.close();
    }

    return ScanResult(suggestedName: null, source: 'none');
  }

  String _titleCase(String input) {
    return input
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}