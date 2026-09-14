import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'entitlements.dart';

/// Subscription purchasing.
///
/// The purchase token is never trusted here — it goes to the server, which
/// asks Google whether it is real and active. A client-side entitlement check
/// is bypassed by patching the APK, so this class only starts purchases and
/// forwards tokens.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  /// Must match the base plan IDs created in Play Console.
  static const String monthlyId = 'plant_scan_monthly';
  static const String yearlyId = 'plant_scan_yearly';
  static const Set<String> _productIds = {monthlyId, yearlyId};

  final InAppPurchase _billing = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchases;
  List<ProductDetails> _products = const [];
  bool _available = false;
  bool _busy = false;
  String? _error;

  /// Store products, cheapest period first. Prices come from the store in the
  /// user's own currency, so nothing is hardcoded.
  List<ProductDetails> get products => _products;
  bool get available => _available;
  bool get busy => _busy;
  String? get error => _error;

  ProductDetails? productFor(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  Future<void> initialise() async {
    if (kIsWeb) return;

    try {
      _available = await _billing.isAvailable();
    } catch (error) {
      debugPrint('Billing unavailable: $error');
      _available = false;
    }
    if (!_available) {
      notifyListeners();
      return;
    }

    _purchases ??= _billing.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) => debugPrint('Purchase stream error: $error'),
    );

    await _loadProducts();

    // Picks up a subscription bought on another install of the same account.
    try {
      await _billing.restorePurchases();
    } catch (error) {
      debugPrint('Restore failed: $error');
    }
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _billing.queryProductDetails(_productIds);
      if (response.error != null) {
        debugPrint('Product query error: ${response.error}');
      }
      _products = response.productDetails
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    } catch (error) {
      debugPrint('Product query failed: $error');
    }
    notifyListeners();
  }

  /// Starts the Play purchase sheet. The result arrives on the purchase
  /// stream, not from this future.
  Future<void> buy(ProductDetails product) async {
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      await _billing.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (error) {
      _busy = false;
      _error = 'The purchase could not be started.';
      notifyListeners();
      debugPrint('buyNonConsumable failed: $error');
    }
  }

  Future<void> restore() async {
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      await _billing.restorePurchases();
    } catch (error) {
      _error = 'Nothing to restore on this account.';
      debugPrint('Restore failed: $error');
    }

    _busy = false;
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _busy = true;
          notifyListeners();

        case PurchaseStatus.error:
          _busy = false;
          _error = purchase.error?.message ?? 'The purchase failed.';
          notifyListeners();
          await _finish(purchase);

        case PurchaseStatus.canceled:
          _busy = false;
          _error = null;
          notifyListeners();
          await _finish(purchase);

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(purchase);
          await _finish(purchase);
      }
    }
  }

  Future<void> _verify(PurchaseDetails purchase) async {
    try {
      await EntitlementService.instance.submitPurchase(
        purchaseToken: purchase.verificationData.serverVerificationData,
        productId: purchase.productID,
      );
      _error = null;
    } catch (error) {
      // The purchase is real but the server could not confirm it yet. The
      // entitlement refresh on next launch will pick it up.
      _error =
          'Payment went through. It can take a moment to appear — reopen the '
          'app if it has not.';
      debugPrint('Server verification failed: $error');
    }

    _busy = false;
    notifyListeners();
  }

  /// Play requires every purchase be acknowledged, or it is refunded
  /// automatically after three days.
  Future<void> _finish(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _billing.completePurchase(purchase);
    } catch (error) {
      debugPrint('completePurchase failed: $error');
    }
  }

  @override
  void dispose() {
    _purchases?.cancel();
    super.dispose();
  }
}
