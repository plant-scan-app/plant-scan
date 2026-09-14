import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/plant_identification.dart';
import '../models/quota.dart';
import 'backend_client.dart';
import 'plant_identifier.dart';

/// Holds what the server last told us about this install's allowance, and is
/// the only thing the UI reads. Every server reply carries a fresh quota, so
/// this stays current without polling.
///
/// Treat it as a cache of a server decision, never as the decision itself: the
/// server refuses over-quota scans regardless of what this object says.
class EntitlementService extends ChangeNotifier {
  EntitlementService({BackendClient? backend}) : _backend = backend;

  static EntitlementService instance = EntitlementService();

  final BackendClient? _backend;

  Quota _quota = Quota.unknown;
  bool _loading = false;

  Quota get quota => _quota;
  bool get loading => _loading;

  /// False when the app is running without a backend, in which case there is
  /// no metering and no paywall.
  bool get metered => _backend != null;

  bool get entitled => _quota.entitled;

  void apply(Quota quota) {
    _quota = quota;
    notifyListeners();
  }

  Future<void> refresh() async {
    final backend = _backend;
    if (backend == null || _loading) return;

    _loading = true;
    notifyListeners();

    try {
      apply(await backend.quota());
    } catch (error) {
      // An unreachable server should not block the UI; the scan attempt will
      // surface the real problem.
      debugPrint('Quota refresh failed: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Claims the rewarded-ad bonus. Call only after an ad was watched through.
  Future<void> claimAdCredit() async {
    final backend = _backend;
    if (backend == null) return;
    apply(await backend.claimAdCredit());
  }

  Future<void> submitPurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    final backend = _backend;
    if (backend == null) return;
    apply(
      await backend.submitPurchase(
        purchaseToken: purchaseToken,
        productId: productId,
      ),
    );
  }
}

/// Identifies through the backend, keeping [EntitlementService] up to date
/// with the quota that comes back on every reply.
class BackendPlantIdentifier implements PlantIdentifier {
  BackendPlantIdentifier({
    required this.backend,
    required this.entitlements,
  });

  final BackendClient backend;
  final EntitlementService entitlements;

  @override
  Future<PlantIdentification> identify(Uint8List jpegBytes) async {
    try {
      final result = await backend.identify(jpegBytes);
      entitlements.apply(result.quota);
      return result.identification;
    } on QuotaExhaustedException catch (exhausted) {
      entitlements.apply(exhausted.quota);
      rethrow;
    }
  }
}
