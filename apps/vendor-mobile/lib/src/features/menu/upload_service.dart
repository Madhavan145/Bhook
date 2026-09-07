import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';

class UploadResult {
  const UploadResult({required this.uploadId, required this.objectKey});
  final String uploadId;
  final String objectKey;
}

class UploadService {
  UploadService(this._ref);
  final Ref _ref;

  /// Web- and mobile-compatible: reads bytes from the picked [XFile] rather
  /// than relying on dart:io File, which is unavailable on Flutter web.
  Future<UploadResult> uploadPickedImage(XFile file) async {
    final bytes = await file.readAsBytes();
    return uploadBytes(bytes, contentType: _detectContentType(file.name), purpose: 'CATALOG_IMAGE');
  }

  Future<UploadResult> uploadBytes(Uint8List bytes,
      {required String contentType, required String purpose}) async {
    final upload = _ref.read(uploadClientProvider);
    final createRes = await upload.dio.post('/api/v1/uploads', data: {
      'purpose': purpose,
      'contentType': contentType,
      'sizeBytes': bytes.length,
    });
    final created = createRes.data as Map<String, dynamic>;
    final uploadId = created['uploadId'] as String;
    final objectKey = created['objectKey'] as String;
    await upload.dio.put(
      '/api/v1/uploads/$uploadId/content',
      data: bytes,
      options: Options(
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        contentType: contentType,
        headers: {
          Headers.contentTypeHeader: contentType,
        },
      ),
    );

    final sha = sha256.convert(bytes).toString();
    await upload.dio.post('/api/v1/uploads/$uploadId/commit', data: {'sha256': sha});
    return UploadResult(uploadId: uploadId, objectKey: objectKey);
  }

  String _detectContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

final uploadServiceProvider = Provider<UploadService>((ref) => UploadService(ref));
