// lib/features/admin/products/scan/image_upload_service.dart
//
// Uses uploadBinary (bytes) rather than a File path — this works on both
// Android and Web, so the same service can be reused if image upload
// (without the ML scan step) is ever added to the web admin flow too.

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase_client.dart';

final imageUploadServiceProvider = Provider((ref) => ImageUploadService());

class ImageUploadService {
  Future<String> uploadProductImage(Uint8List bytes, String fileName) async {
    final path = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await supabase.storage.from('product-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return supabase.storage.from('product-images').getPublicUrl(path);
  }
}