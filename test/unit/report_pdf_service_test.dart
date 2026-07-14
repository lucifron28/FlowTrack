import 'package:flowtrack/core/domain/flowtrack_models.dart';
import 'package:flowtrack/core/services/report_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a valid offline report PDF for a date range', () async {
    const summary = ReportSummary(
      totalSales: 12500,
      totalExpenses: 2500,
      netIncome: 10000,
      totalCreditGiven: 3000,
      totalCreditCollected: 1500,
    );
    final service = const ReportPdfService();
    final start = DateTime(2026, 7, 1);
    final end = DateTime(2026, 8, 1);

    final bytes = await service.buildReportPdf(
      reportTitle: 'Monthly Report',
      start: start,
      end: end,
      summary: summary,
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(
      service.reportPdfFileName(start: start, end: end),
      'flowtrack-report-20260701-20260731.pdf',
    );
  });
}
