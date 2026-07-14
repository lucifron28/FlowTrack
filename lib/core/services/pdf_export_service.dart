import 'package:flutter/services.dart';

class PdfExportService {
  const PdfExportService();

  static const _channel = MethodChannel('flowtrack/pdf_export');

  Future<String?> save({required String fileName, required Uint8List bytes}) {
    return _channel.invokeMethod<String>('savePdf', {
      'fileName': fileName,
      'bytes': bytes,
    });
  }

  Future<void> share({required String fileName, required Uint8List bytes}) {
    return _channel.invokeMethod<void>('sharePdf', {
      'fileName': fileName,
      'bytes': bytes,
    });
  }
}
