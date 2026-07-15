class AppRoutes {
  const AppRoutes._();

  static const root = '/';
  static const login = '/login';
  static const ownerSetup = '/owner-setup';
  static const newSale = '/sales/new';
  static const saleDetails = '/sales/:saleId';
  static const addProduct = '/inventory/add';
  static const productDetails = '/inventory/:productId';
  static const editProduct = '/inventory/:productId/edit';
  static const addStock = '/inventory/:productId/add-stock';
  static const adjustStock = '/inventory/:productId/adjust-stock';
  static const barcodePrint = '/inventory/:productId/barcode-print';
  static const addCustomer = '/credits/add';
  static const customerDetails = '/credits/:customerId';
  static const editCustomer = '/credits/:customerId/edit';
  static const recordPayment = '/credits/:customerId/payment';
  static const addExpense = '/expenses/add';
  static const editExpense = '/expenses/:expenseId/edit';
  static const expenses = '/expenses';
  static const reports = '/reports';
  static const settings = '/settings';

  static const rootName = 'root';
  static const loginName = 'login';
  static const ownerSetupName = 'owner-setup';
  static const newSaleName = 'new-sale';
  static const saleDetailsName = 'sale-details';
  static const addProductName = 'add-product';
  static const productDetailsName = 'product-details';
  static const editProductName = 'edit-product';
  static const addStockName = 'add-stock';
  static const adjustStockName = 'adjust-stock';
  static const barcodePrintName = 'barcode-print';
  static const addCustomerName = 'add-customer';
  static const customerDetailsName = 'customer-details';
  static const editCustomerName = 'edit-customer';
  static const recordPaymentName = 'record-payment';
  static const addExpenseName = 'add-expense';
  static const editExpenseName = 'edit-expense';
  static const expensesName = 'expenses';
  static const reportsName = 'reports';
  static const settingsName = 'settings';
}
