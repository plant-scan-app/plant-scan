import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A random per-install identifier, used to meter the free tier.
///
/// Deliberately not a device fingerprint or advertising ID: those carry
/// privacy obligations and Play policy restrictions we don't need. The
/// trade-off is that reinstalling earns a fresh allowance, which is a cost of
/// not requiring anyone to make an account.
class DeviceIdentity {
  DeviceIdentity._();

  static final DeviceIdentity instance = DeviceIdentity._();

  static const String _key = 'device_id';

  String? _id;

  String get idOrEmpty => _id ?? '';

  Future<String> id() async {
    final cached = _id;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null && stored.length >= 16) {
      _id = stored;
      return stored;
    }

    final fresh = _generate();
    await prefs.setString(_key, fresh);
    _id = fresh;
    return fresh;
  }

  /// 32 hex characters from a cryptographic source.
  static String _generate() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
