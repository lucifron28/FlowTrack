import 'dart:async';

import 'package:flowtrack/core/database/app_database.dart';
import 'package:flowtrack/core/domain/flowtrack_models.dart' as domain;
import 'package:flowtrack/features/sales/screens/sales_screen.dart';
import 'package:flowtrack/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  testWidgets(
    'continuous scan updates cart, guards duplicates and stock, and returns to sale',
    (tester) async {
      final previousPlatform = MobileScannerPlatform.instance;
      final scanner = _FakeScanner();
      MobileScannerPlatform.instance = scanner;
      addTearDown(() => MobileScannerPlatform.instance = previousPlatform);
      final db = AppDatabase.inMemory();
      addTearDown(db.close);
      await db.createProduct(
        name: 'Test item',
        barcode: '12345',
        barcodeType: domain.BarcodeType.manufacturer,
        sellingPrice: 1700,
        initialStock: 3,
        lowStockLevel: 1,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: NewSaleScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan Barcode'));
      await tester.pump(const Duration(seconds: 1));
      scanner.scan('12345');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Test item × 1'), findsOneWidget);
      expect(find.textContaining('1 items'), findsOneWidget);
      scanner.scan('12345');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Test item × 1'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      scanner.scan('12345');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Test item × 2'), findsOneWidget);
      await tester.tap(find.text('Set quantity'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '4');
      await tester.tap(find.text('Apply'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Not enough stock available.'), findsOneWidget);
      expect(find.text('Test item × 2'), findsOneWidget);
      await tester.tap(find.text('Set quantity'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '3');
      await tester.tap(find.text('Apply'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Test item × 3'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      scanner.scan('12345');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Not enough stock available.'), findsOneWidget);
      expect(find.text('Test item × 3'), findsOneWidget);
      scanner.scan('unknown');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Product not found'), findsOneWidget);
      scanner.scan('12345');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Test item × 3'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Test item'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _FakeScanner extends MobileScannerPlatform {
  final _stream = StreamController<BarcodeCapture>.broadcast();
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  void scan(String value) =>
      _stream.add(BarcodeCapture(barcodes: [Barcode(rawValue: value)]));
  @override
  Stream<BarcodeCapture?> get barcodesStream => _stream.stream;
  @override
  Stream<TorchState> get torchStateStream =>
      Stream.value(TorchState.unavailable);
  @override
  Stream<double> get zoomScaleStateStream => Stream.value(1);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
        cameraDirection: CameraFacing.back,
        currentTorchMode: TorchState.unavailable,
        size: Size(200, 200),
        numberOfCameras: 1,
      );
  @override
  Widget buildCameraView() => const SizedBox();
  @override
  Future<void> dispose() => _stream.close();
}
