import '../database/app_database.dart';
import '../domain/flowtrack_models.dart';

class SampleDataService {
  const SampleDataService(this._database);

  static const loadedSettingKey = 'qa_sample_data_loaded';

  final AppDatabase _database;

  Future<bool> isLoaded() async {
    return (await _database.getSetting(loadedSettingKey)) == 'true';
  }

  Future<void> load() async {
    if (await isLoaded()) {
      throw StateError('Sample data is already loaded.');
    }

    final products = <_SampleProduct>[
      const _SampleProduct(
        name: 'Lucky Me Pancit Canton Chilimansi',
        barcode: '4807770271137',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 1800,
        costPrice: 1450,
        initialStock: 35,
        lowStockLevel: 40,
      ),
      const _SampleProduct(
        name: '555 Sardines Tomato Sauce',
        barcode: '4800110020307',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 2800,
        costPrice: 2350,
        initialStock: 24,
        lowStockLevel: 30,
      ),
      const _SampleProduct(
        name: 'Nescafe Original Stick',
        barcode: '4800361417406',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 800,
        costPrice: 620,
        initialStock: 60,
        lowStockLevel: 50,
      ),
      const _SampleProduct(
        name: 'Great Taste White Sachet',
        barcode: '4800016112306',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 900,
        costPrice: 700,
        initialStock: 52,
        lowStockLevel: 50,
      ),
      const _SampleProduct(
        name: 'SkyFlakes Crackers',
        barcode: '4800016640706',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 1200,
        costPrice: 950,
        initialStock: 30,
        lowStockLevel: 30,
      ),
      const _SampleProduct(
        name: 'C2 Green Tea Apple 230ml',
        barcode: '4804888801234',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 2200,
        costPrice: 1800,
        initialStock: 18,
        lowStockLevel: 24,
      ),
      const _SampleProduct(
        name: 'Safeguard White Bar 60g',
        barcode: '4800888206019',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 3200,
        costPrice: 2650,
        initialStock: 14,
        lowStockLevel: 20,
      ),
      const _SampleProduct(
        name: 'Piattos Cheese 40g',
        barcode: '4800016060218',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 1800,
        costPrice: 1450,
        initialStock: 4,
        lowStockLevel: 20,
      ),
      const _SampleProduct(
        name: 'Coke Sakto 200ml',
        barcode: '4801981111112',
        barcodeType: BarcodeType.manufacturer,
        sellingPrice: 1500,
        costPrice: 1200,
        initialStock: 0,
        lowStockLevel: 24,
      ),
      const _SampleProduct(
        name: 'Asukal Tingi 1/4 kilo',
        barcode: 'FT-TINGI-ASUKAL',
        barcodeType: BarcodeType.storeGenerated,
        sellingPrice: 2500,
        costPrice: 2100,
        initialStock: 16,
        lowStockLevel: 20,
      ),
      const _SampleProduct(
        name: 'Mantika Tingi 100ml',
        barcode: 'FT-TINGI-MANTIKA',
        barcodeType: BarcodeType.storeGenerated,
        sellingPrice: 2000,
        costPrice: 1650,
        initialStock: 20,
        lowStockLevel: 16,
      ),
      const _SampleProduct(
        name: 'Bigas Tingi 1 kilo',
        barcode: 'FT-TINGI-BIGAS',
        barcodeType: BarcodeType.storeGenerated,
        sellingPrice: 5800,
        costPrice: 5200,
        initialStock: 12,
        lowStockLevel: 12,
      ),
    ];

    final productIds = <String, String>{};
    for (final product in products) {
      productIds[product.barcode] = await _ensureProduct(product);
    }

    final alingNenaId = await _database.createCustomer(
      name: 'Aling Nena',
      contactNumber: '0917 111 2233',
    );
    final mangLitoId = await _database.createCustomer(
      name: 'Mang Lito',
      contactNumber: '0928 444 5566',
    );
    await _database.createCustomer(
      name: 'Ate Joy',
      contactNumber: '0999 777 8888',
    );

    final now = DateTime.now();
    await _database.completeSale(
      items: [
        _cartLine(products, productIds, '4807770271137', 2),
        _cartLine(products, productIds, '4804888801234', 1),
        _cartLine(products, productIds, '4800016640706', 1),
      ],
      paymentType: PaymentType.cash,
      saleDate: now,
      amountReceived: 7000,
    );

    await _database.completeSale(
      items: [
        _cartLine(products, productIds, 'FT-TINGI-ASUKAL', 1),
        _cartLine(products, productIds, '4800361417406', 4),
        _cartLine(products, productIds, '4800110020307', 1),
      ],
      paymentType: PaymentType.credit,
      saleDate: now.subtract(const Duration(days: 1)),
      customerId: alingNenaId,
    );

    await _database.completeSale(
      items: [
        _cartLine(products, productIds, 'FT-TINGI-BIGAS', 1),
        _cartLine(products, productIds, 'FT-TINGI-MANTIKA', 1),
        _cartLine(products, productIds, '4800016112306', 3),
      ],
      paymentType: PaymentType.credit,
      saleDate: now.subtract(const Duration(days: 3)),
      customerId: mangLitoId,
    );

    await _database.recordCreditPayment(
      customerId: mangLitoId,
      amount: 5000,
      paymentDate: now.subtract(const Duration(days: 1)),
      notes: 'Partial bayad after work',
    );

    await _database.createExpense(
      category: 'Restocking',
      description: 'Puregold restock: noodles, coffee, crackers',
      amount: 185000,
      expenseDate: now.subtract(const Duration(days: 2)),
    );
    await _database.createExpense(
      category: 'Utilities',
      description: 'Electric bill share',
      amount: 45000,
      expenseDate: now,
    );
    await _database.createExpense(
      category: 'Transportation',
      description: 'Tricycle fare for palengke run',
      amount: 8000,
      expenseDate: now,
    );

    await _database.setSetting(loadedSettingKey, 'true');
  }

  Future<String> _ensureProduct(_SampleProduct product) async {
    final existing = await _database.findProductByBarcode(product.barcode);
    if (existing != null) {
      return existing.id;
    }
    return _database.createProduct(
      name: product.name,
      barcode: product.barcode,
      barcodeType: product.barcodeType,
      sellingPrice: product.sellingPrice,
      costPrice: product.costPrice,
      initialStock: product.initialStock,
      lowStockLevel: product.lowStockLevel,
    );
  }

  SaleCartLine _cartLine(
    List<_SampleProduct> products,
    Map<String, String> productIds,
    String barcode,
    int quantity,
  ) {
    final product = products.firstWhere((item) => item.barcode == barcode);
    return SaleCartLine(
      productId: productIds[barcode]!,
      productName: product.name,
      barcode: product.barcode,
      unitPrice: product.sellingPrice,
      costPrice: product.costPrice,
      quantity: quantity,
    );
  }
}

class _SampleProduct {
  const _SampleProduct({
    required this.name,
    required this.barcode,
    required this.barcodeType,
    required this.sellingPrice,
    required this.costPrice,
    required this.initialStock,
    required this.lowStockLevel,
  });

  final String name;
  final String barcode;
  final BarcodeType barcodeType;
  final int sellingPrice;
  final int costPrice;
  final int initialStock;
  final int lowStockLevel;
}
