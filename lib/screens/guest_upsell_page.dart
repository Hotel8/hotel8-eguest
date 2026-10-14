// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EGuest
// SPDX-License-Identifier: Apache-2.0

/// Upsell Offers.
///
/// Browse available upgrades and offers: room upgrades, spa, dining,
/// experiences. Accept or decline each offer with one tap.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class GuestUpsellPage extends StatefulWidget {
  const GuestUpsellPage({
    super.key,
    required this.client,
    required this.stayId,
  });

  final BffClient client;
  final String stayId;

  @override
  State<GuestUpsellPage> createState() => _GuestUpsellPageState();
}

class _GuestUpsellPageState extends State<GuestUpsellPage> {
  late Future<List<UpsellOffer>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _offersFuture = widget.client.getUpsellOffers(widget.stayId);
  }

  Future<void> _refresh() async {
    setState(() {
      _offersFuture = widget.client.getUpsellOffers(widget.stayId);
    });
    await _offersFuture;
  }

  Future<void> _acceptOffer(UpsellOffer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept Offer'),
        content: Text(
            'Accept "${offer.title}" for ${offer.currencyCode} '
            '${offer.price.toStringAsFixed(2)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.acceptOffer(offer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accepted: ${offer.title} 🎉')),
        );
        _refresh();
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.message}')),
        );
      }
    }
  }

  Future<void> _declineOffer(UpsellOffer offer) async {
    try {
      await widget.client.declineOffer(offer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Declined: ${offer.title}')),
        );
        _refresh();
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upsell Offers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<UpsellOffer>>(
          future: _offersFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(snap.error is BffException
                        ? (snap.error as BffException).message
                        : '${snap.error}'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _refresh, child: const Text('Retry')),
                  ],
                ),
              );
            }
            final offers = snap.data ?? const [];
            if (offers.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.local_offer_outlined,
                      size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No Offers Available',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  const Text(
                      'Check back later for room upgrades, spa, dining\nand special experiences.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) => _OfferCard(
                offer: offers[i],
                onAccept: () => _acceptOffer(offers[i]),
                onDecline: () => _declineOffer(offers[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.onAccept,
    required this.onDecline,
  });
  final UpsellOffer offer;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('MMM d');
    final isAvailable = offer.status == OfferStatus.available;
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _categoryColor(offer.category).withValues(alpha: 0.15),
            child: Row(
              children: [
                Icon(_categoryIcon(offer.category), size: 32,
                    color: _categoryColor(offer.category)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(offer.category.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: _categoryColor(offer.category),
                          fontWeight: FontWeight.bold)),
                ),
                if (offer.validUntil != null)
                  Text(
                    'Valid until ${fmt.format(offer.validUntil!)}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(offer.description,
                    style: TextStyle(color: Colors.grey.shade700)),
                if (offer.roomTypeFrom != null && offer.roomTypeTo != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(
                        label: Text(offer.roomTypeFrom!),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Icon(Icons.arrow_forward, size: 16),
                      Chip(
                        label: Text(offer.roomTypeTo!),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '${offer.currencyCode} ${offer.price.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (isAvailable) ...[
                      TextButton(onPressed: onDecline, child: const Text('Decline')),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: onAccept, child: const Text('Accept')),
                    ] else
                      Chip(label: Text(offer.status.name.toUpperCase())),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(UpsellCategory category) => switch (category) {
        UpsellCategory.roomUpgrade => Colors.purple,
        UpsellCategory.spa => Colors.pink,
        UpsellCategory.dining => Colors.deepOrange,
        UpsellCategory.experience => Colors.amber,
        UpsellCategory.lateCheckout => Colors.indigo,
        UpsellCategory.earlyCheckIn => Colors.teal,
        UpsellCategory.parking => Colors.blueGrey,
        UpsellCategory.breakfast => Colors.brown,
      };

  IconData _categoryIcon(UpsellCategory category) => category.icon;
}