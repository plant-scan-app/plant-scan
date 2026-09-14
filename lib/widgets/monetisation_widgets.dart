import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../screens/paywall_screen.dart';
import '../services/ads_service.dart';
import '../services/entitlements.dart';
import '../theme.dart';
import 'scan_tile.dart';

/// Says how many scans are left, and what to do when there are none.
///
/// The wording is deliberately matter-of-fact. A limit explained plainly reads
/// as a free tier; the same limit dressed up reads as a trick.
class QuotaBar extends StatelessWidget {
  const QuotaBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: EntitlementService.instance,
      builder: (context, _) {
        final service = EntitlementService.instance;
        if (!service.metered) return const SizedBox.shrink();

        final quota = service.quota;
        final text = Theme.of(context).textTheme;

        if (quota.entitled) {
          return SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.all_inclusive,
                  size: 18,
                  color: Botanic.chlorophyll,
                ),
                const SizedBox(width: 10),
                Text('Unlimited scans', style: text.titleMedium),
              ],
            ),
          );
        }

        return SurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    quota.exhausted
                        ? Icons.hourglass_bottom
                        : Icons.camera_outlined,
                    size: 18,
                    color: quota.exhausted ? Botanic.apricot : Botanic.inkSoft,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      quota.exhausted
                          ? 'No scans left today'
                          : '${quota.remaining} '
                                '${quota.remaining == 1 ? 'scan' : 'scans'} '
                                'left today',
                      style: text.titleMedium,
                    ),
                  ),
                ],
              ),
              if (quota.exhausted) ...[
                const SizedBox(height: 12),
                const QuotaActions(),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The two ways past the daily limit: watch an ad, or subscribe.
class QuotaActions extends StatefulWidget {
  const QuotaActions({this.onGranted, super.key});

  /// Called after the server has granted extra scans.
  final VoidCallback? onGranted;

  @override
  State<QuotaActions> createState() => _QuotaActionsState();
}

class _QuotaActionsState extends State<QuotaActions> {
  bool _watching = false;

  Future<void> _watchAd() async {
    setState(() => _watching = true);

    final outcome = await AdsService.instance.showRewarded();
    if (!mounted) return;

    switch (outcome) {
      case RewardOutcome.earned:
        try {
          await EntitlementService.instance.claimAdCredit();
          if (!mounted) return;
          setState(() => _watching = false);
          widget.onGranted?.call();
        } catch (error) {
          if (!mounted) return;
          setState(() => _watching = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Those extra scans could not be added.'),
            ),
          );
        }

      case RewardOutcome.dismissed:
        setState(() => _watching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The ad needs to finish to earn extra scans.'),
          ),
        );

      case RewardOutcome.unavailable:
        setState(() => _watching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No ad available right now.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quota = EntitlementService.instance.quota;
    final canWatch =
        quota.adCreditAvailable && AdsService.instance.supported;

    return Column(
      children: [
        if (canWatch)
          OutlinedButton.icon(
            onPressed: _watching ? null : _watchAd,
            icon: _watching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle_outline),
            label: Text(
              _watching
                  ? 'Loading the ad'
                  : 'Watch an ad for ${quota.scansPerAd} more scans',
            ),
          ),
        if (canWatch) const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaywallScreen()),
          ),
          icon: const Icon(Icons.all_inclusive),
          label: const Text('Go unlimited'),
        ),
      ],
    );
  }
}

/// A banner that renders nothing at all unless an ad actually loads, so there
/// is never an empty grey strip in the layout.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = AdsService.instance.createBanner(
      onLoaded: () {
        if (mounted) setState(() => _loaded = true);
      },
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();

    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
