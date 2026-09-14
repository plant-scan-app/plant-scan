/// What the server says this install may do today.
class Quota {
  const Quota({
    required this.limit,
    required this.remaining,
    required this.adCreditAvailable,
    required this.scansPerAd,
    required this.entitled,
    this.entitledUntil,
  });

  /// Free scans per day, before any earned by watching an ad.
  final int limit;

  /// Scans left today. Meaningless when [entitled] — read that first.
  final int remaining;

  /// True while a rewarded ad would still earn extra scans today.
  final bool adCreditAvailable;

  /// How many scans one rewarded ad is worth.
  final int scansPerAd;

  /// Subscribed: no limit, no ads.
  final bool entitled;

  final DateTime? entitledUntil;

  bool get exhausted => !entitled && remaining <= 0;

  /// Shown before any server round-trip has happened.
  static const Quota unknown = Quota(
    limit: 3,
    remaining: 3,
    adCreditAvailable: true,
    scansPerAd: 2,
    entitled: false,
  );

  static Quota fromJson(Map<String, Object?> json) {
    final until = json['entitled_until'];

    return Quota(
      limit: _int(json['limit'], 3),
      remaining: _int(json['remaining'], 0),
      adCreditAvailable: json['ad_credit_available'] == true,
      scansPerAd: _int(json['scans_per_ad'], 2),
      entitled: json['entitled'] == true,
      entitledUntil: until is num
          ? DateTime.fromMillisecondsSinceEpoch(until.toInt())
          : null,
    );
  }

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;
}
