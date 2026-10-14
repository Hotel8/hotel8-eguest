// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EGuest
// SPDX-License-Identifier: Apache-2.0

/// Guest Home.
///
/// Property info header, my stay summary card, quick actions grid
/// (check-in, services, chat, digital key), and loyalty points teaser.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';
import 'mobile_check_in_page.dart';
import 'service_requests_page.dart';
import 'guest_messaging_page.dart';
import 'digital_key_page.dart';
import 'guest_upsell_page.dart';
import 'guest_checkout_page.dart';

class GuestHomePage extends StatefulWidget {
  const GuestHomePage({super.key, required this.client, required this.guestId});

  final BffClient client;
  final String guestId;

  @override
  State<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends State<GuestHomePage> {
  late Future<List<StayInfo>> _staysFuture;
  GuestProfile? _profile;

  @override
  void initState() {
    super.initState();
    _staysFuture = widget.client.getReservations(
      guestId: widget.guestId,
      upcoming: true,
    );
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.client.getGuestProfile(widget.guestId);
      if (mounted) setState(() => _profile = profile);
    } on BffException {
      // Profile is optional for the home view.
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _staysFuture = widget.client.getReservations(
        guestId: widget.guestId,
        upcoming: true,
      );
    });
    await _staysFuture;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stay'),
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
        child: FutureBuilder<List<StayInfo>>(
          future: _staysFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorView(
                error: snap.error!,
                onRetry: _refresh,
              );
            }
            final stays = snap.data ?? const [];
            if (stays.isEmpty) {
              return const _EmptyStaysView();
            }
            final stay = stays.first;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PropertyHeader(stay: stay),
                const SizedBox(height: 16),
                _StaySummaryCard(stay: stay),
                const SizedBox(height: 16),
                Text('Quick Actions',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _QuickActionsGrid(stay: stay, client: widget.client),
                const SizedBox(height: 24),
                if (_profile?.loyaltyNumber != null) ...[
                  _LoyaltyTeaserCard(
                    client: widget.client,
                    loyaltyNumber: _profile!.loyaltyNumber!,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Property Header
// ═══════════════════════════════════════════════════════════════════════════

class _PropertyHeader extends StatelessWidget {
  const _PropertyHeader({required this.stay});
  final StayInfo stay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.hotel, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stay.propertyName,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (stay.propertyAddress != null) ...[
                    const SizedBox(height: 2),
                    Text(stay.propertyAddress!,
                        style: theme.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(stay.status.label),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Stay Summary Card
// ═══════════════════════════════════════════════════════════════════════════

class _StaySummaryCard extends StatelessWidget {
  const _StaySummaryCard({required this.stay});
  final StayInfo stay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmtDate = DateFormat('MMM d, yyyy');
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Stay', style: theme.textTheme.titleMedium),
            const Divider(),
            _row('Confirmation', stay.confirmationNumber),
            _row('Check-in', fmtDate.format(stay.arrivalDate)),
            _row('Check-out', fmtDate.format(stay.departureDate)),
            _row('Nights', stay.numberOfNights.toString()),
            _row('Room Type', stay.roomTypeName),
            if (stay.roomNumber != null) _row('Room', stay.roomNumber!),
            _row(
              'Rate',
              '${stay.currencyCode} ${stay.rateAmount.toStringAsFixed(2)} / night',
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Quick Actions Grid
// ═══════════════════════════════════════════════════════════════════════════

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.stay, required this.client});
  final StayInfo stay;
  final BffClient client;

  @override
  Widget build(BuildContext context) {
    final canCheckIn = stay.status.isUpcoming;
    final isInStay = stay.status.isInStay;

    final actions = <_QuickAction>[
      if (canCheckIn)
        _QuickAction(
          icon: Icons.phone_iphone,
          label: 'Check In',
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MobileCheckInPage(
                client: client,
                stay: stay,
              ),
            ),
          ),
        ),
      _QuickAction(
        icon: Icons.room_service,
        label: 'Services',
        color: Colors.orange,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceRequestsPage(
              client: client,
              stayId: stay.id,
              roomNumber: stay.roomNumber,
            ),
          ),
        ),
      ),
      _QuickAction(
        icon: Icons.chat,
        label: 'Chat',
        color: Colors.teal,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuestMessagingPage(
              client: client,
              stayId: stay.id,
              guestName: stay.guestName,
            ),
          ),
        ),
      ),
      if (isInStay || stay.digitalKeyEligible)
        _QuickAction(
          icon: Icons.key,
          label: 'Digital Key',
          color: Colors.green,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DigitalKeyPage(
                client: client,
                stay: stay,
              ),
            ),
          ),
        ),
      _QuickAction(
        icon: Icons.local_offer,
        label: 'Offers',
        color: Colors.purple,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GuestUpsellPage(
              client: client,
              stayId: stay.id,
            ),
          ),
        ),
      ),
      if (isInStay)
        _QuickAction(
          icon: Icons.logout,
          label: 'Check Out',
          color: Colors.red,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GuestCheckoutPage(
                client: client,
                stay: stay,
              ),
            ),
          ),
        ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: actions.length,
      itemBuilder: (context, i) => actions[i],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Loyalty Teaser
// ═══════════════════════════════════════════════════════════════════════════

class _LoyaltyTeaserCard extends StatefulWidget {
  const _LoyaltyTeaserCard({
    required this.client,
    required this.loyaltyNumber,
  });
  final BffClient client;
  final String loyaltyNumber;

  @override
  State<_LoyaltyTeaserCard> createState() => _LoyaltyTeaserCardState();
}

class _LoyaltyTeaserCardState extends State<_LoyaltyTeaserCard> {
  late Future<LoyaltyInfo> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.client.getLoyaltyInfo(widget.loyaltyNumber);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<LoyaltyInfo>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snap.hasError || snap.data == null) return const SizedBox.shrink();
        final loyalty = snap.data!;
        return Card(
          elevation: 2,
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.star, color: theme.colorScheme.primary, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${loyalty.tier} Member',
                          style: theme.textTheme.titleSmall),
                      Text('${loyalty.currentPoints} points',
                          style: theme.textTheme.headlineSmall),
                      if (loyalty.pointsToNextTier > 0)
                        Text(
                          '${loyalty.pointsToNextTier} pts to ${loyalty.nextTier ?? "next tier"}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty / Error
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyStaysView extends StatelessWidget {
  const _EmptyStaysView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.hotel_outlined, size: 80, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text('No Upcoming Stays',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Your upcoming reservations will appear here once booked.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Something went wrong', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error is BffException ? (error as BffException).message : '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}