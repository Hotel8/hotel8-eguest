// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EGuest
// SPDX-License-Identifier: Apache-2.0

// eGuest room-service ordering screen - the F&B funnel through the
// Hotel8:POS guest-ordering surface (eguest/DESIGN.md §4 Room service).
//
// Menu reads order from the property's `ROOM_SERVICE` outlet; the order binds
// to the in-house stay (reservation + room come from the stay, never free
// input). Status read-back drives the prep stepper (SENT → PREPARING → READY
// → SERVED).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class RoomServicePage extends StatefulWidget {
  const RoomServicePage({
    super.key,
    required this.client,
    required this.stayId,
  });

  final BffClient client;
  final String stayId;

  @override
  State<RoomServicePage> createState() => _RoomServicePageState();
}

class _RoomServicePageState extends State<RoomServicePage> {
  List<RoomServiceMenuItem> _menu = [];
  final _cart = <RoomServiceMenuItem, int>{};
  RoomServiceOrder? _lastOrder;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _menu = await widget.client.getRoomServiceMenu();
      if (mounted) setState(() => _loading = false);
    } on BffException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  double get _cartTotal =>
      _cart.entries.fold(0.0, (sum, e) => sum + e.key.price * e.value);

  Future<void> _submit() async {
    if (_cart.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final outletId = await _roomServiceOutletId();
      final order = await widget.client.placeRoomServiceOrder(
        outletId: outletId,
        reservationId: widget.stayId,
        items: [
          for (final e in _cart.entries)
            {'menu_item_id': e.key.id, 'quantity': e.value},
        ],
      );
      if (mounted) {
        setState(() {
          _lastOrder = order;
          _cart.clear();
          _submitting = false;
        });
      }
    } on BffException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// The ordering client targets the property's room-service outlet; the
  /// server resolves it when `outlet_id` is omitted from the menu call, but
  /// the order call requires it - read it back from a menu probe.
  Future<String> _roomServiceOutletId() async {
    final json = await widget.client.getRawJson(
      '/proxy/hotel8-pos/v1/guest/${widget.client.propertyId}/menu',
    );
    return (json['outlet_id'] as String?) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.room_service_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              'Room service unavailable: $_error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadMenu, child: const Text('Retry')),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final item in _menu)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: item.description.isEmpty
                        ? null
                        : Text(
                            item.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          NumberFormat.simpleCurrency(decimalDigits: 2)
                              .format(item.price),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(
                            () => _cart[item] = (_cart[item] ?? 0) + 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_cart.values.fold(0, (a, b) => a + b)} item(s) · '
                      '${NumberFormat.simpleCurrency(decimalDigits: 2).format(_cartTotal)}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Order to Room'),
                  ),
                ],
              ),
            ),
          ),
        if (_lastOrder != null) _OrderStatusBar(order: _lastOrder!),
      ],
    );
  }
}

class _OrderStatusBar extends StatelessWidget {
  const _OrderStatusBar({required this.order});

  final RoomServiceOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = order.lines
        .map((l) => '${l.quantity}× ${l.name} (${l.status})')
        .join(', ');
    return Container(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(12),
      child: SafeArea(
        child: Text(
          '${order.checkNumber}: $lines - ${order.total} · ${order.status}',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
