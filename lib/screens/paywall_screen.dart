import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/entitlements.dart';
import '../services/subscription_service.dart';
import '../theme.dart';
import '../widgets/scan_tile.dart';

/// The subscription offer.
///
/// Prices are read from the store rather than written here, so they arrive in
/// the user's own currency and stay correct when you change them in Play
/// Console.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    SubscriptionService.instance.initialise();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Unlimited scans')),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          SubscriptionService.instance,
          EntitlementService.instance,
        ]),
        builder: (context, _) {
          final service = SubscriptionService.instance;

          if (EntitlementService.instance.entitled) {
            return const _AlreadySubscribed();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text('Scan as much as you like', style: text.displaySmall),
              const SizedBox(height: 10),
              Text(
                'The free version covers three plants a day. A subscription '
                'lifts the limit and removes every ad.',
                style: text.bodyLarge?.copyWith(color: Botanic.inkSoft),
              ),
              const SizedBox(height: 24),
              const _Benefit(
                icon: Icons.all_inclusive,
                title: 'No daily limit',
                detail: 'Work through a whole garden in one go.',
              ),
              const _Benefit(
                icon: Icons.block_outlined,
                title: 'No ads',
                detail: 'No banners, no interruptions.',
              ),
              const _Benefit(
                icon: Icons.eco_outlined,
                title: 'Your plants, kept',
                detail: 'Every scan saved with its care notes.',
              ),
              const SizedBox(height: 26),
              if (!service.available)
                const _BillingUnavailable()
              else if (service.products.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      color: Botanic.chlorophyll,
                    ),
                  ),
                )
              else
                for (final product in service.products) ...[
                  _PlanCard(
                    product: product,
                    highlighted: product.id == SubscriptionService.yearlyId,
                    busy: service.busy,
                    onTap: () => service.buy(product),
                  ),
                  const SizedBox(height: 12),
                ],
              if (service.error != null) ...[
                const SizedBox(height: 6),
                Text(
                  service.error!,
                  style: text.bodyMedium?.copyWith(color: Botanic.rust),
                ),
              ],
              const SizedBox(height: 10),
              TextButton(
                onPressed: service.busy ? null : service.restore,
                child: const Text('Restore a purchase'),
              ),
              const SizedBox(height: 14),
              Text(
                'Billed through Google Play and renews until cancelled. Cancel '
                'any time in Play Store subscriptions.',
                style: text.labelSmall?.copyWith(color: Botanic.inkSoft),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.product,
    required this.highlighted,
    required this.busy,
    required this.onTap,
  });

  final ProductDetails product;
  final bool highlighted;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final yearly = product.id == SubscriptionService.yearlyId;

    return Material(
      color: highlighted ? Botanic.chlorophyllDeep : Botanic.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted ? Botanic.chlorophyllDeep : Botanic.hairline,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      yearly ? 'Yearly' : 'Monthly',
                      style: text.titleMedium?.copyWith(
                        color: highlighted
                            ? const Color(0xFFF2F5EE)
                            : Botanic.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      yearly
                          ? '${product.price} a year, billed once'
                          : '${product.price} a month',
                      style: text.bodyMedium?.copyWith(
                        color: highlighted
                            ? const Color(0xFFCBD9CE)
                            : Botanic.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: highlighted
                      ? const Color(0xFFF2F5EE)
                      : Botanic.inkSoft,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: Botanic.chlorophyll),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: text.bodyMedium?.copyWith(color: Botanic.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingUnavailable extends StatelessWidget {
  const _BillingUnavailable();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Text(
        'Purchases are not available on this device. Subscriptions work in the '
        'app installed from Google Play.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Botanic.inkSoft,
        ),
      ),
    );
  }
}

class _AlreadySubscribed extends StatelessWidget {
  const _AlreadySubscribed();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final until = EntitlementService.instance.quota.entitledUntil;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 44,
              color: Botanic.chlorophyll,
            ),
            const SizedBox(height: 16),
            Text('Subscription active', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text(
              until == null
                  ? 'Unlimited scans, no ads.'
                  : 'Unlimited scans, no ads. Renews '
                        '${until.day}/${until.month}/${until.year}.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: Botanic.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
