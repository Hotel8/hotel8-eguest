// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EGuest
// SPDX-License-Identifier: Apache-2.0

// eGuest rewards + payment-methods screens (eguest/DESIGN.md §4 Rewards /
// Payment methods).
//
// Rewards: loyalty catalog with redeemable flags against the member balance;
// redemption exchanges points for a voucher code presented at the desk.
// Payment methods: guest-held bill8 token references (add/remove/default) —
// folio payments default to the card on file.

import 'package:flutter/material.dart';

import '../bff_client.dart';
import '../models.dart';

/// Member rewards catalog + redemption (embedded in the Offers tab).
class RewardsPanel extends StatefulWidget {
  const RewardsPanel({super.key, required this.client, required this.guestId});

  final BffClient client;

  /// The signed-in guest's profile id — the panel resolves the loyalty member
  /// through the profile chain (loyalty number → member read).
  final String guestId;

  @override
  State<RewardsPanel> createState() => _RewardsPanelState();
}

class _RewardsPanelState extends State<RewardsPanel> {
  List<Reward> _rewards = [];
  int _balance = 0;
  bool _loading = true;
  RewardRedemption? _lastRedemption;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _memberId;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Resolve the loyalty member through the guest profile chain.
      if (_memberId == null) {
        try {
          final profile =
              await widget.client.getGuestProfile(widget.guestId);
          final loyaltyNumber = profile.loyaltyNumber;
          if (loyaltyNumber != null && loyaltyNumber.isNotEmpty) {
            final json = await widget.client
                .getRawJson('/proxy/hotel8-loyalty/v1/members/$loyaltyNumber');
            _memberId = json['id'] as String?;
          }
        } on BffException {
          // Member resolution is best-effort — catalog shows empty state.
        }
      }
      if (_memberId != null) {
        // Catalog carries the member's balance alongside the items.
        final json = await widget.client
            .getRawJson('/proxy/hotel8-loyalty/v1/members/$_memberId/rewards');
        _balance = (json['points_balance'] as num?)?.toInt() ?? 0;
        final list = (json['rewards'] as List<dynamic>?) ??
            (json['items'] as List<dynamic>?) ??
            const [];
        _rewards =
            list.map((e) => Reward.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _rewards = const [];
      }
      if (mounted) setState(() => _loading = false);
    } on BffException {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redeem(Reward reward) async {
    try {
      final r = await widget.client.redeemReward(
        memberId: _memberId!,
        catalogItemId: reward.id,
      );
      if (mounted) {
        setState(() => _lastRedemption = r);
        await _load();
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Reward redeemed'),
            content: Text(
              '${r.itemName}\nVoucher: ${r.voucherCode}\n'
              '${r.pointsSpent} pts · ${r.remainingBalance} remaining',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_memberId == null || _rewards.isEmpty) {
      return _EmptyRewards(onRetry: _load);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Your rewards · $_balance pts',
              style: theme.textTheme.titleMedium),
        ),
        if (_lastRedemption != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.redeem, color: Colors.amber),
                title: Text(_lastRedemption!.voucherCode),
                subtitle: Text('${_lastRedemption!.itemName} — show at the desk'),
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final r in _rewards)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      switch (r.category) {
                        'DINING' => Icons.restaurant,
                        'SPA' => Icons.spa,
                        'STAY' => Icons.hotel,
                        _ => Icons.card_giftcard,
                      },
                      color: r.redeemable ? Colors.amber : Colors.grey,
                    ),
                    title: Text(r.name),
                    subtitle: Text('${r.pointsCost} pts${r.redeemable ? '' : ' — need more points'}'),
                    trailing: FilledButton.tonal(
                      onPressed: r.redeemable ? () => _redeem(r) : null,
                      child: const Text('Redeem'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Saved payment methods management (Profile tab → Payment Methods).
class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key, required this.client});

  final BffClient client;

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  List<PaymentMethodInfo> _methods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _methods = await widget.client.getPaymentMethods();
      if (mounted) setState(() => _loading = false);
    } on BffException {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final labelCtrl = TextEditingController();
    final tokenCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add payment method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            TextField(
              controller: tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'Card token',
                helperText: 'Your card is tokenized by Payments — the app stores the token reference only',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.client.savePaymentMethod(
        label: labelCtrl.text.trim(),
        paymentMethodId: tokenCtrl.text.trim(),
      );
      await _load();
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _remove(PaymentMethodInfo m) async {
    try {
      await widget.client.deletePaymentMethod(m.id);
      await _load();
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final m in _methods)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.credit_card),
                      title: Text(m.label),
                      subtitle: Text('Token …${m.paymentMethodId.length > 4 ? m.paymentMethodId.substring(m.paymentMethodId.length - 4) : m.paymentMethodId}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(m),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text('Add method'),
                ),
              ],
            ),
    );
  }
}

class _EmptyRewards extends StatelessWidget {
  const _EmptyRewards({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.card_giftcard, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text('No rewards available yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Join the loyalty program or link your member number in Profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Refresh')),
        ],
      ),
    );
  }
}
