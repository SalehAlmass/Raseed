import 'dart:convert';

enum DebtMode { block, warning }

class ProductFormConfig {
  final bool showBarcode;
  final bool showWholesale;
  final bool showReorder;
  final bool showCategory;
  final bool showExpiry;
  final bool showUnits;
  final bool showSupplier;
  final bool showPurchasePrice;
  final double autoSaleMargin;
  final double autoWholesaleMargin;

  ProductFormConfig({
    this.showBarcode = true,
    this.showWholesale = true,
    this.showReorder = true,
    this.showCategory = true,
    this.showExpiry = true,
    this.showUnits = true,
    this.showSupplier = true,
    this.showPurchasePrice = true,
    this.autoSaleMargin = 0.15,
    this.autoWholesaleMargin = 0.10,
  });

  Map<String, dynamic> toMap() {
    return {
      'showBarcode': showBarcode,
      'showWholesale': showWholesale,
      'showReorder': showReorder,
      'showCategory': showCategory,
      'showExpiry': showExpiry,
      'showUnits': showUnits,
      'showSupplier': showSupplier,
      'showPurchasePrice': showPurchasePrice,
      'autoSaleMargin': autoSaleMargin,
      'autoWholesaleMargin': autoWholesaleMargin,
    };
  }

  factory ProductFormConfig.fromMap(Map<String, dynamic> map) {
    return ProductFormConfig(
      showBarcode: map['showBarcode'] ?? true,
      showWholesale: map['showWholesale'] ?? true,
      showReorder: map['showReorder'] ?? true,
      showCategory: map['showCategory'] ?? true,
      showExpiry: map['showExpiry'] ?? true,
      showUnits: map['showUnits'] ?? true,
      showSupplier: map['showSupplier'] ?? true,
      showPurchasePrice: map['showPurchasePrice'] ?? true,
      autoSaleMargin: (map['autoSaleMargin'] as num?)?.toDouble() ?? 0.15,
      autoWholesaleMargin: (map['autoWholesaleMargin'] as num?)?.toDouble() ?? 0.10,
    );
  }
}

class ModuleConfig {
  final bool showInventory;
  final bool showCustomers;
  final bool showSuppliers;
  final bool showSales;
  final bool showReports;
  final bool showAccounting;
  final bool enableCloudBackup;

  ModuleConfig({
    this.showInventory = true,
    this.showCustomers = true,
    this.showSuppliers = true,
    this.showSales = true,
    this.showReports = true,
    this.showAccounting = true,
    this.enableCloudBackup = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'showInventory': showInventory,
      'showCustomers': showCustomers,
      'showSuppliers': showSuppliers,
      'showSales': showSales,
      'showReports': showReports,
      'showAccounting': showAccounting,
      'enableCloudBackup': enableCloudBackup,
    };
  }

  factory ModuleConfig.fromMap(Map<String, dynamic> map) {
    return ModuleConfig(
      showInventory: map['showInventory'] ?? true,
      showCustomers: map['showCustomers'] ?? true,
      showSuppliers: map['showSuppliers'] ?? true,
      showSales: map['showSales'] ?? true,
      showReports: map['showReports'] ?? true,
      showAccounting: map['showAccounting'] ?? true,
      enableCloudBackup: map['enableCloudBackup'] ?? true,
    );
  }
}

class StoreProfile {
  final String? storeName;
  final String? phone;
  final String? address;
  final String? taxNumber;
  final String? logoPath;

  StoreProfile({
    this.storeName,
    this.phone,
    this.address,
    this.taxNumber,
    this.logoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'storeName': storeName,
      'phone': phone,
      'address': address,
      'taxNumber': taxNumber,
      'logoPath': logoPath,
    };
  }

  factory StoreProfile.fromMap(Map<String, dynamic> map) {
    return StoreProfile(
      storeName: map['storeName'],
      phone: map['phone'],
      address: map['address'],
      taxNumber: map['taxNumber'],
      logoPath: map['logoPath'],
    );
  }

  StoreProfile copyWith({
    String? storeName,
    String? phone,
    String? address,
    String? taxNumber,
    String? logoPath,
  }) {
    return StoreProfile(
      storeName: storeName ?? this.storeName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      taxNumber: taxNumber ?? this.taxNumber,
      logoPath: logoPath ?? this.logoPath,
    );
  }
}

class StaffConfig {
  final bool isEnabled;
  final String? pinCode;

  StaffConfig({
    this.isEnabled = false,
    this.pinCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'pinCode': pinCode,
    };
  }

  factory StaffConfig.fromMap(Map<String, dynamic> map) {
    return StaffConfig(
      isEnabled: map['isEnabled'] ?? false,
      pinCode: map['pinCode'],
    );
  }
}

class AppSettings {
  final double maxDebt;
  final int reminderDays;
  final bool strictMode; // Keep for backward compatibility or as general toggle
  final DebtMode debtMode;
  final String currency;
  final bool onboardingCompleted;
  final double vipThreshold;
  final int inactiveDays;
  final int deadDays;
  final bool enableWhatsapp;
  final bool enablePdfReceipt;
  final ProductFormConfig productFormConfig;
  final ModuleConfig moduleConfig;
  final StoreProfile storeProfile;
  final StaffConfig staffConfig;

  AppSettings({
    this.maxDebt = 100000.0,
    this.reminderDays = 30,
    this.strictMode = false,
    this.debtMode = DebtMode.block,
    this.currency = 'YER',
    this.onboardingCompleted = false,
    this.vipThreshold = 100000.0,
    this.inactiveDays = 30,
    this.deadDays = 90,
    this.enableWhatsapp = true,
    this.enablePdfReceipt = true,
    ProductFormConfig? productFormConfig,
    ModuleConfig? moduleConfig,
    StoreProfile? storeProfile,
    StaffConfig? staffConfig,
  }) : productFormConfig = productFormConfig ?? ProductFormConfig(),
       moduleConfig = moduleConfig ?? ModuleConfig(),
       storeProfile = storeProfile ?? StoreProfile(),
       staffConfig = staffConfig ?? StaffConfig();

  Map<String, dynamic> toMap() {
    return {
      'max_debt': maxDebt,
      'reminder_days': reminderDays,
      'strict_mode': strictMode ? 1 : 0,
      'debt_mode': debtMode.name,
      'currency': currency,
      'onboarding_completed': onboardingCompleted ? 1 : 0,
      'vip_threshold': vipThreshold,
      'inactive_days': inactiveDays,
      'dead_days': deadDays,
      'enable_whatsapp': enableWhatsapp ? 1 : 0,
      'enable_pdf_receipt': enablePdfReceipt ? 1 : 0,
      'product_form_config': jsonEncode(productFormConfig.toMap()),
      'module_config': jsonEncode(moduleConfig.toMap()),
      'store_profile': jsonEncode(storeProfile.toMap()),
      'staff_config': jsonEncode(staffConfig.toMap()),
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      maxDebt: (map['max_debt'] as num?)?.toDouble() ?? 100000.0,
      reminderDays: map['reminder_days'] ?? 30,
      strictMode: (map['strict_mode'] ?? 0) == 1,
      debtMode: map['debt_mode'] != null 
          ? DebtMode.values.byName(map['debt_mode']) 
          : DebtMode.block,
      currency: map['currency'] ?? 'YER',
      onboardingCompleted: (map['onboarding_completed'] ?? 0) == 1,
      vipThreshold: (map['vip_threshold'] as num?)?.toDouble() ?? 100000.0,
      inactiveDays: map['inactive_days'] ?? 30,
      deadDays: map['dead_days'] ?? 90,
      enableWhatsapp: (map['enable_whatsapp'] ?? 1) == 1,
      enablePdfReceipt: (map['enable_pdf_receipt'] ?? 1) == 1,
      productFormConfig: map['product_form_config'] != null 
          ? ProductFormConfig.fromMap(jsonDecode(map['product_form_config']))
          : ProductFormConfig(),
      moduleConfig: map['module_config'] != null 
          ? ModuleConfig.fromMap(jsonDecode(map['module_config']))
          : ModuleConfig(),
      storeProfile: map['store_profile'] != null 
          ? StoreProfile.fromMap(jsonDecode(map['store_profile']))
          : StoreProfile(),
      staffConfig: map['staff_config'] != null 
          ? StaffConfig.fromMap(jsonDecode(map['staff_config']))
          : StaffConfig(),
    );
  }

  AppSettings copyWith({
    double? maxDebt,
    int? reminderDays,
    bool? strictMode,
    DebtMode? debtMode,
    String? currency,
    bool? onboardingCompleted,
    double? vipThreshold,
    int? inactiveDays,
    int? deadDays,
    bool? enableWhatsapp,
    bool? enablePdfReceipt,
    ProductFormConfig? productFormConfig,
    ModuleConfig? moduleConfig,
    StoreProfile? storeProfile,
    StaffConfig? staffConfig,
  }) {
    return AppSettings(
      maxDebt: maxDebt ?? this.maxDebt,
      reminderDays: reminderDays ?? this.reminderDays,
      strictMode: strictMode ?? this.strictMode,
      debtMode: debtMode ?? this.debtMode,
      currency: currency ?? this.currency,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      vipThreshold: vipThreshold ?? this.vipThreshold,
      inactiveDays: inactiveDays ?? this.inactiveDays,
      deadDays: deadDays ?? this.deadDays,
      enableWhatsapp: enableWhatsapp ?? this.enableWhatsapp,
      enablePdfReceipt: enablePdfReceipt ?? this.enablePdfReceipt,
      productFormConfig: productFormConfig ?? this.productFormConfig,
      moduleConfig: moduleConfig ?? this.moduleConfig,
      storeProfile: storeProfile ?? this.storeProfile,
      staffConfig: staffConfig ?? this.staffConfig,
    );
  }
}
