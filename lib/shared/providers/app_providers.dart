import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_routes.dart';
import '../../core/database/app_database.dart';
import '../../core/services/barcode_service.dart';
import '../../core/services/barcode_print_service.dart';
import '../../core/services/local_auth_service.dart';
import '../../core/services/sample_data_service.dart';
import '../../features/auth/screens/auth_gate.dart';
import '../../features/credits/screens/credits_screen.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/inventory/screens/barcode_print_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/sales/screens/sales_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(database.close);
  return database;
});

final barcodeServiceProvider = Provider<BarcodeService>((ref) {
  return BarcodeService();
});

final barcodePrintServiceProvider = Provider<BarcodePrintService>((ref) {
  return const BarcodePrintService();
});

final localAuthServiceProvider = Provider<LocalAuthService>((ref) {
  return LocalAuthService();
});

final sampleDataServiceProvider = Provider<SampleDataService>((ref) {
  return SampleDataService(ref.watch(appDatabaseProvider));
});

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadSavedTheme();
    return ThemeMode.system;
  }

  Future<void> _loadSavedTheme() async {
    final val = await ref.read(appDatabaseProvider).getSetting('theme_mode');
    if (val != null) {
      state = ThemeMode.values.firstWhere(
        (e) => e.name == val,
        orElse: () => ThemeMode.system,
      );
    }
  }

  void setThemeMode(ThemeMode value) {
    state = value;
    ref.read(appDatabaseProvider).setSetting('theme_mode', value.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.root,
    routes: [
      GoRoute(
        name: AppRoutes.rootName,
        path: AppRoutes.root,
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        name: AppRoutes.newSaleName,
        path: AppRoutes.newSale,
        builder: (context, state) => const NewSaleScreen(),
      ),
      GoRoute(
        name: AppRoutes.saleDetailsName,
        path: AppRoutes.saleDetails,
        builder: (context, state) =>
            SaleDetailsScreen(saleId: state.pathParameters['saleId'] ?? ''),
      ),
      GoRoute(
        name: AppRoutes.addProductName,
        path: AppRoutes.addProduct,
        builder: (context, state) => const AddProductScreen(),
      ),
      GoRoute(
        name: AppRoutes.productDetailsName,
        path: AppRoutes.productDetails,
        builder: (context, state) => ProductDetailsScreen(
          productId: state.pathParameters['productId'] ?? '',
        ),
      ),
      GoRoute(
        name: AppRoutes.editProductName,
        path: AppRoutes.editProduct,
        builder: (context, state) {
          final product = state.extra;
          return product is Product
              ? EditProductScreen(product: product)
              : const _MissingRouteExtraScreen(label: 'product');
        },
      ),
      GoRoute(
        name: AppRoutes.addStockName,
        path: AppRoutes.addStock,
        builder: (context, state) =>
            AddStockScreen(productId: state.pathParameters['productId'] ?? ''),
      ),
      GoRoute(
        name: AppRoutes.adjustStockName,
        path: AppRoutes.adjustStock,
        builder: (context, state) {
          final product = state.extra;
          return product is Product
              ? AdjustStockScreen(product: product)
              : const _MissingRouteExtraScreen(label: 'product');
        },
      ),
      GoRoute(
        name: AppRoutes.barcodePrintName,
        path: AppRoutes.barcodePrint,
        builder: (context, state) => BarcodePrintScreen(
          productId: state.pathParameters['productId'] ?? '',
        ),
      ),
      GoRoute(
        name: AppRoutes.addCustomerName,
        path: AppRoutes.addCustomer,
        builder: (context, state) => const AddCustomerScreen(),
      ),
      GoRoute(
        name: AppRoutes.customerDetailsName,
        path: AppRoutes.customerDetails,
        builder: (context, state) => CustomerDetailsScreen(
          customerId: state.pathParameters['customerId'] ?? '',
        ),
      ),
      GoRoute(
        name: AppRoutes.editCustomerName,
        path: AppRoutes.editCustomer,
        builder: (context, state) {
          final customer = state.extra;
          return customer is Customer
              ? EditCustomerScreen(customer: customer)
              : const _MissingRouteExtraScreen(label: 'customer');
        },
      ),
      GoRoute(
        name: AppRoutes.recordPaymentName,
        path: AppRoutes.recordPayment,
        builder: (context, state) {
          final customer = state.extra;
          return customer is Customer
              ? RecordPaymentScreen(customer: customer)
              : const _MissingRouteExtraScreen(label: 'customer');
        },
      ),
      GoRoute(
        name: AppRoutes.addExpenseName,
        path: AppRoutes.addExpense,
        builder: (context, state) => const AddExpenseScreen(),
      ),
      GoRoute(
        name: AppRoutes.editExpenseName,
        path: AppRoutes.editExpense,
        builder: (context, state) {
          final expense = state.extra;
          return expense is Expense
              ? AddExpenseScreen(expense: expense)
              : const _MissingRouteExtraScreen(label: 'expense');
        },
      ),
      GoRoute(
        name: AppRoutes.expensesName,
        path: AppRoutes.expenses,
        builder: (context, state) => const ExpensesScreen(showAppBar: true),
      ),
      GoRoute(
        name: AppRoutes.reportsName,
        path: AppRoutes.reports,
        builder: (context, state) => const ReportsScreen(showAppBar: true),
      ),
      GoRoute(
        name: AppRoutes.settingsName,
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(showAppBar: true),
      ),
    ],
  );
});

class _MissingRouteExtraScreen extends StatelessWidget {
  const _MissingRouteExtraScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route unavailable')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Missing $label data for this screen.'),
        ),
      ),
    );
  }
}

class AuthState {
  const AuthState({
    required this.hasOwner,
    required this.isAuthenticated,
    this.ownerName,
  });

  final bool hasOwner;
  final bool isAuthenticated;
  final String? ownerName;

  AuthState copyWith({
    bool? hasOwner,
    bool? isAuthenticated,
    String? ownerName,
  }) {
    return AuthState(
      hasOwner: hasOwner ?? this.hasOwner,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      ownerName: ownerName ?? this.ownerName,
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthController extends AsyncNotifier<AuthState> {
  LocalAuthService get _authService => ref.read(localAuthServiceProvider);

  @override
  Future<AuthState> build() async {
    final hasOwner = await _authService.hasOwnerAccount();
    final ownerName = await _authService.ownerName();
    return AuthState(
      hasOwner: hasOwner,
      isAuthenticated: !hasOwner,
      ownerName: ownerName,
    );
  }

  Future<void> setupOwner({
    required String ownerName,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.setupOwner(ownerName: ownerName, password: password);
      return AuthState(
        hasOwner: true,
        isAuthenticated: true,
        ownerName: ownerName.trim(),
      );
    });
  }

  Future<void> updateOwnerName(String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.updateOwnerName(name);
      return AuthState(
        hasOwner: true,
        isAuthenticated: true,
        ownerName: name.trim(),
      );
    });
  }

  Future<void> login(String password) async {
    final current =
        state.asData?.value ??
        AuthState(
          hasOwner: await _authService.hasOwnerAccount(),
          isAuthenticated: false,
          ownerName: await _authService.ownerName(),
        );
    final success = await _authService.verifyPassword(password);
    if (!success) {
      state = AsyncValue.data(current);
      throw const AuthException('Invalid password. Please try again.');
    }
    state = AsyncValue.data(
      AuthState(
        hasOwner: true,
        isAuthenticated: true,
        ownerName: await _authService.ownerName(),
      ),
    );
  }

  void logout() {
    final current = state.asData?.value;
    state = AsyncValue.data(
      AuthState(
        hasOwner: true,
        isAuthenticated: false,
        ownerName: current?.ownerName,
      ),
    );
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final todayProvider = Provider<DateTime>((ref) => DateTime.now());

final storeNameProvider = FutureProvider<String>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final name = await db.getSetting('store_name');
  return name ?? AppConfig.appName;
});
