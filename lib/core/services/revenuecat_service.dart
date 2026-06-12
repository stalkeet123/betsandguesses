import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../constants/revenuecat_constants.dart';

class RevenueCatPurchaseResult {
  final bool success;
  final bool cancelled;
  final bool isPremium;
  final String? message;

  const RevenueCatPurchaseResult({
    required this.success,
    required this.cancelled,
    required this.isPremium,
    this.message,
  });
}

class RevenueCatService {
  bool _isConfigured = false;
  Offerings? _offerings;
  CustomerInfo? _customerInfo;

  bool get isConfigured => _isConfigured;

  Future<void> initialize({String? appUserId}) async {
    if (_isConfigured) return;
    if (!RevenueCatConstants.hasApiKey) return;

    await Purchases.setLogLevel(LogLevel.warn);

    final configuration = PurchasesConfiguration(RevenueCatConstants.apiKey);
    if (appUserId != null && appUserId.trim().isNotEmpty) {
      configuration.appUserID = appUserId.trim();
    }

    await Purchases.configure(configuration);
    _isConfigured = true;
    await refreshCustomerInfo();
  }

  Future<CustomerInfo?> refreshCustomerInfo() async {
    if (!_isConfigured) return null;
    _customerInfo = await Purchases.getCustomerInfo();
    return _customerInfo;
  }

  Future<bool> isPremium() async {
    final customerInfo = _customerInfo ?? await refreshCustomerInfo();
    return _hasPremiumEntitlement(customerInfo);
  }

  Future<Map<String, String>> packagePrices() async {
    final packages = await _configuredPackages();
    return {
      for (final package in packages)
        package.identifier: package.storeProduct.priceString,
    };
  }

  Future<RevenueCatPurchaseResult> purchasePackage(
    String packageIdentifier,
  ) async {
    if (!_isConfigured) {
      await initialize();
    }

    if (!_isConfigured) {
      return const RevenueCatPurchaseResult(
        success: false,
        cancelled: false,
        isPremium: false,
        message: 'RevenueCat API key is missing.',
      );
    }

    final package = await _findPackage(packageIdentifier);
    if (package == null) {
      return RevenueCatPurchaseResult(
        success: false,
        cancelled: false,
        isPremium: await isPremium(),
        message: 'Package not found: $packageIdentifier',
      );
    }

    try {
      final purchaseResult = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      final customerInfo = purchaseResult.customerInfo;
      _customerInfo = customerInfo;
      final premium = _hasPremiumEntitlement(customerInfo);

      return RevenueCatPurchaseResult(
        success: premium,
        cancelled: false,
        isPremium: premium,
        message: premium
            ? null
            : 'Purchase completed, but premium entitlement is not active yet.',
      );
    } on PlatformException catch (error) {
      final errorCode = PurchasesErrorHelper.getErrorCode(error);
      final cancelled = errorCode == PurchasesErrorCode.purchaseCancelledError;

      return RevenueCatPurchaseResult(
        success: false,
        cancelled: cancelled,
        isPremium: await isPremium(),
        message: cancelled ? null : error.message,
      );
    } catch (error) {
      return RevenueCatPurchaseResult(
        success: false,
        cancelled: false,
        isPremium: await isPremium(),
        message: error.toString(),
      );
    }
  }

  Future<RevenueCatPurchaseResult> restorePurchases() async {
    if (!_isConfigured) {
      await initialize();
    }

    if (!_isConfigured) {
      return const RevenueCatPurchaseResult(
        success: false,
        cancelled: false,
        isPremium: false,
        message: 'RevenueCat API key is missing.',
      );
    }

    try {
      final customerInfo = await Purchases.restorePurchases();
      _customerInfo = customerInfo;
      final premium = _hasPremiumEntitlement(customerInfo);

      return RevenueCatPurchaseResult(
        success: premium,
        cancelled: false,
        isPremium: premium,
        message: premium ? null : 'No active premium purchase found.',
      );
    } catch (error) {
      return RevenueCatPurchaseResult(
        success: false,
        cancelled: false,
        isPremium: await isPremium(),
        message: error.toString(),
      );
    }
  }

  Future<Package?> _findPackage(String packageIdentifier) async {
    final packages = await _configuredPackages();
    for (final package in packages) {
      if (package.identifier == packageIdentifier) {
        return package;
      }
    }
    return null;
  }

  Future<List<Package>> _configuredPackages() async {
    if (!_isConfigured) return const [];

    final offerings = _offerings ?? await Purchases.getOfferings();
    _offerings = offerings;

    final offering =
        offerings.all[RevenueCatConstants.offeringIdentifier] ??
        offerings.current;
    return offering?.availablePackages ?? const [];
  }

  bool _hasPremiumEntitlement(CustomerInfo? customerInfo) {
    return customerInfo?.entitlements.active.containsKey(
          RevenueCatConstants.entitlementIdentifier,
        ) ??
        false;
  }
}
