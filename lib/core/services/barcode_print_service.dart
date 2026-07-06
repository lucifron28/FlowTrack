import 'package:barcode/barcode.dart' as barcode;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/app_config.dart';
import '../database/app_database.dart';

class BarcodeLabelData {
  const BarcodeLabelData({
    required this.name,
    required this.barcode,
    required this.sellingPrice,
  });

  final String name;
  final String barcode;
  final int sellingPrice;

  factory BarcodeLabelData.fromProduct(Product product) {
    return BarcodeLabelData(
      name: product.name,
      barcode: product.barcode,
      sellingPrice: product.sellingPrice,
    );
  }
}

class BarcodePrintService {
  const BarcodePrintService();

  static const labelCopies = 10;
  static const _channel = MethodChannel('flowtrack/barcode_pdf');

  Future<Uint8List> buildProductBarcodePdf(Product product) async {
    return buildBarcodePdf(BarcodeLabelData.fromProduct(product));
  }

  Future<Uint8List> buildBarcodePdf(BarcodeLabelData label) async {
    final pdf = pw.Document(title: barcodePdfFileName(label));
    final code128 = barcode.Barcode.code128();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${AppConfig.appName} Tingi Barcode Sheet',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3 * PdfPageFormat.mm),
              pw.Text(
                'Print once and place on the sintra board. One barcode is for one product type, not each piece or batch.',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 7 * PdfPageFormat.mm),
              pw.Wrap(
                spacing: 5 * PdfPageFormat.mm,
                runSpacing: 5 * PdfPageFormat.mm,
                children: List.generate(
                  labelCopies,
                  (_) => _barcodeLabel(label, code128),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  String barcodePdfFileName(BarcodeLabelData label) {
    final safeName = label.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final name = safeName.isEmpty ? 'product' : safeName;
    return '$name-barcode.pdf';
  }

  Future<String?> saveProductBarcodePdf(Product product) async {
    final bytes = await buildProductBarcodePdf(product);
    return _channel.invokeMethod<String>('savePdf', {
      'fileName': barcodePdfFileName(BarcodeLabelData.fromProduct(product)),
      'bytes': bytes,
    });
  }

  Future<void> shareProductBarcodePdf(Product product) async {
    final bytes = await buildProductBarcodePdf(product);
    await _channel.invokeMethod<void>('sharePdf', {
      'fileName': barcodePdfFileName(BarcodeLabelData.fromProduct(product)),
      'bytes': bytes,
    });
  }

  pw.Widget _barcodeLabel(BarcodeLabelData label, barcode.Barcode code128) {
    return pw.Container(
      width: 90 * PdfPageFormat.mm,
      height: 45 * PdfPageFormat.mm,
      padding: const pw.EdgeInsets.all(5 * PdfPageFormat.mm),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            label.name,
            maxLines: 2,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Text(
            'Price: PHP ${(label.sellingPrice / 100).toStringAsFixed(2)}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Expanded(
            child: pw.BarcodeWidget(
              barcode: code128,
              data: label.barcode,
              drawText: false,
            ),
          ),
          pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
          pw.Text(
            label.barcode,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
  }
}
