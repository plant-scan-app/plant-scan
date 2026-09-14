import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'entitlements.dart';

enum RewardOutcome {
  /// Watched through — the server may now grant extra scans.
  earned,

  /// Closed early, so nothing is owed.
  dismissed,

  /// No ad available, or ads unsupported on this platform.
  unavailable,
}

/// All ad behaviour in one place, so the policy rules live somewhere you can
/// read them rather than being spread across screens.
///
/// Two rules matter, both from Google Play's ads policy:
///
///  * No full-screen ad may block the thing the user asked for. Results are
///    never gated behind an ad — the interstitial fires after a result has
///    been read and dismissed, never before it appears.
///  * Rewarded ads are opt-in. The user is told what they get, then chooses.
///
/// Breaking either risks AdMob account termination, which is generally not
/// appealable. Treat these as fixed.
class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();

  /// Google's public test units. Real IDs are supplied at build time so no
  /// account details land in the repository.
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const String bannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: _testBanner,
  );
  static const String interstitialUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
    defaultValue: _testInterstitial,
  );
  static const String rewardedUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_ID',
    defaultValue: _testRewarded,
  );

  /// Show an interstitial after every third result rather than every one.
  /// Frequency, not just placement, is what makes ads tolerable.
  static const int interstitialEveryNResults = 3;

  bool _ready = false;
  int _resultsSeen = 0;

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// True when ads should be shown at all: supported platform, initialised,
  /// and the user is not a subscriber.
  bool get _shouldShowAds =>
      supported && _ready && !EntitlementService.instance.entitled;

  Future<void> initialise() async {
    if (!supported || _ready) return;
    try {
      await MobileAds.instance.initialize();
      _ready = true;
    } catch (error) {
      debugPrint('AdMob init failed: $error');
    }
  }

  /// Offers extra scans for watching an ad. Resolves once the ad closes.
  Future<RewardOutcome> showRewarded() async {
    if (!supported || !_ready) return RewardOutcome.unavailable;

    final outcome = Completer<RewardOutcome>();

    RewardedAd.load(
      adUnitId: rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          var earned = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!outcome.isCompleted) {
                outcome.complete(
                  earned ? RewardOutcome.earned : RewardOutcome.dismissed,
                );
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (!outcome.isCompleted) {
                outcome.complete(RewardOutcome.unavailable);
              }
            },
          );

          ad.show(onUserEarnedReward: (_, __) => earned = true);
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          if (!outcome.isCompleted) outcome.complete(RewardOutcome.unavailable);
        },
      ),
    );

    return outcome.future;
  }

  /// Call after the user has finished with a result and navigated away.
  void noteResultDismissed() {
    if (!_shouldShowAds) return;

    _resultsSeen++;
    if (_resultsSeen % interstitialEveryNResults != 0) return;

    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, _) => ad.dispose(),
          );
          ad.show();
        },
        onAdFailedToLoad: (error) =>
            debugPrint('Interstitial failed to load: $error'),
      ),
    );
  }

  /// Returns null when a banner should not be shown, so callers can render
  /// nothing rather than an empty strip.
  BannerAd? createBanner({required VoidCallback onLoaded}) {
    if (!_shouldShowAds) return null;

    return BannerAd(
      adUnitId: bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }
}
