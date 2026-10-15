// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EGuest
// SPDX-License-Identifier: Apache-2.0

/// Mobile Check-Out.
///
/// Review folio (all charges and payments), express checkout with one-tap
/// pay, settle outstanding charges, and rate the stay.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class GuestCheckoutPage extends StatefulWidget {
  const GuestCheckoutPage({
    super.key,
    required this.client,
    required this.stay,
  });

  final BffClient client;
  final StayInfo stay;

  @override
  State<GuestCheckoutPage> createState() => _GuestCheckoutPageState();
}

class _GuestCheckoutPageState extends State<GuestCheckoutPage> {
  late Future<Folio> _folioFuture;
  bool _checkingOut = false;
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _emailReceipt = true;

  @override
  void initState() {
    super.initState();
    _folioFuture = widget.client.getFolio(widget.stay.id);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _refreshFolio() async {
    setState(() {
      _folioFuture = widget.client.getFolio(widget.stay.id);
    });
    await _folioFuture;
  }

  Future<void> _expressCheckout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Express Check-Out'),
        content: const Text(
          'You will be checked out and your folio will be settled using '
          'your payment method on file. A receipt will be emailed to you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Check Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _checkingOut = true);
    try {
      await widget.client.checkOut(
        CheckOutRequest(stayId: widget.stay.id, emailReceipt: _emailReceipt),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checked out. Thank you for your stay! 🏁'),
          ),
        );
        Navigator.pop(context, true);
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-out failed: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rating.')));
      return;
    }
    try {
      await widget.client.submitStayRating(
        StayRating(
          stayId: widget.stay.id,
          overallScore: _rating,
          comment: _commentController.text.trim().isEmpty
              ? null
              : _commentController.text.trim(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback! ⭐')),
        );
        setState(() => _rating = 0);
        _commentController.clear();
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: ${e.message}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-Out')),
      body: FutureBuilder<Folio>(
        future: _folioFuture,
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
                  Text(
                    snap.error is BffException
                        ? (snap.error as BffException).message
                        : '${snap.error}',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refreshFolio,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final folio = snap.data ?? Folio(id: '', stayId: widget.stay.id);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StayHeader(stay: widget.stay),
              const SizedBox(height: 16),
              _FolioCard(folio: folio),
              const SizedBox(height: 16),
              _ExpressCheckoutCard(
                balance: folio.balance,
                currencyCode: folio.currencyCode,
                emailReceipt: _emailReceipt,
                onToggleEmail: (v) => setState(() => _emailReceipt = v),
                onCheckout: _expressCheckout,
                loading: _checkingOut,
              ),
              const SizedBox(height: 16),
              _RateYourStayCard(
                rating: _rating,
                onRatingChanged: (v) => setState(() => _rating = v),
                commentController: _commentController,
                onSubmit: _submitRating,
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class _StayHeader extends StatelessWidget {
  const _StayHeader({required this.stay});
  final StayInfo stay;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.hotel, color: Colors.blue, size: 40),
        title: Text(stay.propertyName),
        subtitle: Text(
          'Room ${stay.roomNumber ?? "—"} • '
          '${DateFormat('MMM d').format(stay.arrivalDate)} – '
          '${DateFormat('MMM d').format(stay.departureDate)}',
        ),
      ),
    );
  }
}

class _FolioCard extends StatelessWidget {
  const _FolioCard({required this.folio});
  final Folio folio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('MMM d');
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Folio Review', style: theme.textTheme.titleMedium),
            const Divider(),
            if (folio.charges.isEmpty)
              const Text('No charges on this folio.')
            else ...[
              Text('Charges', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              ...folio.charges.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        fmt.format(item.date),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.description)),
                      Text(
                        '${item.currencyCode} ${item.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (folio.payments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Payments', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              ...folio.payments.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        fmt.format(item.date),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.description)),
                      Text(
                        '${item.currencyCode} ${item.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Divider(),
            _SummaryRow(
              'Total Charges',
              '${folio.currencyCode} ${folio.totalCharges.toStringAsFixed(2)}',
            ),
            _SummaryRow(
              'Total Payments',
              '${folio.currencyCode} ${folio.totalPayments.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 4),
            _SummaryRow(
              folio.balance > 0 ? 'Balance Due' : 'Credit',
              '${folio.currencyCode} ${folio.balance.abs().toStringAsFixed(2)}',
              bold: true,
              color: folio.balance > 0 ? Colors.red : Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.bold = false, this.color});
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpressCheckoutCard extends StatelessWidget {
  const _ExpressCheckoutCard({
    required this.balance,
    required this.currencyCode,
    required this.emailReceipt,
    required this.onToggleEmail,
    required this.onCheckout,
    required this.loading,
  });

  final double balance;
  final String currencyCode;
  final bool emailReceipt;
  final ValueChanged<bool> onToggleEmail;
  final VoidCallback onCheckout;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: balance > 0 ? Colors.red.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: balance > 0 ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Express Check-Out',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (balance > 0)
              Text(
                'Balance of $currencyCode ${balance.toStringAsFixed(2)} will be '
                'charged to your payment method on file.',
                style: TextStyle(color: Colors.red.shade700),
              )
            else
              Text(
                'No balance due. Your folio is settled.',
                style: TextStyle(color: Colors.green.shade700),
              ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: emailReceipt,
              onChanged: (v) => onToggleEmail(v ?? false),
              title: const Text('Email my receipt'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: loading ? null : onCheckout,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.logout),
                label: Text(loading ? 'Processing...' : 'Check Out Now'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateYourStayCard extends StatelessWidget {
  const _RateYourStayCard({
    required this.rating,
    required this.onRatingChanged,
    required this.commentController,
    required this.onSubmit,
  });

  final int rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController commentController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rate Your Stay',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starValue = i + 1;
                return IconButton(
                  icon: Icon(
                    starValue <= rating ? Icons.star : Icons.star_border,
                    size: 40,
                    color: starValue <= rating ? Colors.amber : Colors.grey,
                  ),
                  onPressed: () => onRatingChanged(starValue),
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comments (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.comment),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.send),
                label: const Text('Submit Feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
