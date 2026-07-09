import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/app_config.dart';
import '../domain/flowtrack_models.dart';
import 'pdf_export_service.dart';

class ReportPdfService {
  const ReportPdfService({
    PdfExportService exportService = const PdfExportService(),
  }) : _exportService = exportService;

  final PdfExportService _exportService;

  Future<Uint8List> buildReportPdf({
    required String reportTitle,
    required DateTime start,
    required DateTime end,
    required ReportSummary summary,
  }) async {
    final pdf = pw.Document(
      title: reportPdfFileName(start: start, end: end),
    );
    final endInclusive = end.subtract(const Duration(days: 1));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                AppConfig.appName,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4 * PdfPageFormat.mm),
              pw.Text(
                reportTitle,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2 * PdfPageFormat.mm),
              pw.Text(
                '${_dateFormat.format(start)} - ${_dateFormat.format(endInclusive)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 10 * PdfPageFormat.mm),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600),
                ),
                child: pw.Column(
                  children: [
                    _summaryRow('Total Sales', summary.totalSales),
                    _summaryRow('Total Expenses', summary.totalExpenses),
                    _summaryRow('Net Income', summary.netIncome),
                    _summaryRow('Total Credit Given', summary.totalCreditGiven),
                    _summaryRow(
                      'Total Credit Collected',
                      summary.totalCreditCollected,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10 * PdfPageFormat.mm),
              pw.Text(
                'Generated offline from local transaction data.',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  String reportPdfFileName({required DateTime start, required DateTime end}) {
    final startDate = _fileDateFormat.format(start);
    final endDate = _fileDateFormat.format(
      end.subtract(const Duration(days: 1)),
    );
    return 'flowtrack-report-$startDate-$endDate.pdf';
  }

  Future<String?> saveReportPdf({
    required String reportTitle,
    required DateTime start,
    required DateTime end,
    required ReportSummary summary,
  }) async {
    final bytes = await buildReportPdf(
      reportTitle: reportTitle,
      start: start,
      end: end,
      summary: summary,
    );
    return _exportService.save(
      fileName: reportPdfFileName(start: start, end: end),
      bytes: bytes,
    );
  }

  Future<void> shareReportPdf({
    required String reportTitle,
    required DateTime start,
    required DateTime end,
    required ReportSummary summary,
  }) async {
    final bytes = await buildReportPdf(
      reportTitle: reportTitle,
      start: start,
      end: end,
      summary: summary,
    );
    await _exportService.share(
      fileName: reportPdfFileName(start: start, end: end),
      bytes: bytes,
    );
  }

  static final _dateFormat = DateFormat('MMM d, yyyy');
  static final _fileDateFormat = DateFormat('yyyyMMdd');

  pw.Widget _summaryRow(String label, int amount) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text('PHP ${(amount / 100).toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}
