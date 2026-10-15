// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EGuest
// SPDX-License-Identifier: Apache-2.0

/// Digital Key.
///
/// BLE/NFC room key management. Activate/deactivate keys, view multiple
/// room keys, unlock door with a tap.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class DigitalKeyPage extends StatefulWidget {
  const DigitalKeyPage({super.key, required this.client, required this.stay});

  final BffClient client;
  final StayInfo stay;

  @override
  State<DigitalKeyPage> createState() => _DigitalKeyPageState();
}

class _DigitalKeyPageState extends State<DigitalKeyPage> {
  late Future<List<DigitalKey>> _keysFuture;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    _keysFuture = widget.client.getDigitalKeys(widget.stay.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _keysFuture = widget.client.getDigitalKeys(widget.stay.id);
    });
    await _keysFuture;
  }

  Future<void> _activateKey(String roomNumber) async {
    setState(() => _activating = true);
    try {
      await widget.client.activateDigitalKey(
        stayId: widget.stay.id,
        roomNumber: roomNumber,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Digital key activated! 🔑')),
        );
        _refresh();
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activation failed: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  Future<void> _deactivateKey(DigitalKey key) async {
    try {
      await widget.client.deactivateDigitalKey(key.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Key deactivated.')));
        _refresh();
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: ${e.message}')));
      }
    }
  }

  Future<void> _unlockDoor(DigitalKey key) async {
    // In production, this triggers the BLE/NFC door unlock handshake.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unlocking room ${key.roomNumber}... 🚪')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Digital Key')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DigitalKey>>(
          future: _keysFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snap.error is BffException
                          ? (snap.error as BffException).message
                          : '${snap.error}',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            final keys = snap.data ?? const [];
            if (keys.isEmpty) {
              return _NoKeysView(
                stay: widget.stay,
                activating: _activating,
                onActivate: () => _activateKey(
                  widget.stay.roomNumber ?? widget.stay.roomTypeName,
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...keys.map(
                  (dk) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _KeyCard(
                      digitalKey: dk,
                      onUnlock: () => _unlockDoor(dk),
                      onDeactivate: () => _deactivateKey(dk),
                    ),
                  ),
                ),
                if (widget.stay.digitalKeyEligible)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.add_circle, color: Colors.blue),
                      title: const Text('Activate Another Room'),
                      subtitle: const Text('Add a key for a connecting room'),
                      trailing: _activating
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : const Icon(Icons.chevron_right),
                      onTap: _activating
                          ? null
                          : () => _activateKey(
                              widget.stay.roomNumber ??
                                  widget.stay.roomTypeName,
                            ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class _NoKeysView extends StatelessWidget {
  const _NoKeysView({
    required this.stay,
    required this.activating,
    required this.onActivate,
  });

  final StayInfo stay;
  final bool activating;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.nfc, size: 80, color: Colors.green.shade300),
        const SizedBox(height: 16),
        const Text(
          'No Digital Keys Active',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Activate a digital key for ${stay.propertyName} to unlock your '
          'room with your phone using Bluetooth or NFC.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        if (stay.digitalKeyEligible)
          FilledButton.icon(
            onPressed: activating ? null : onActivate,
            icon: activating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.key),
            label: Text(activating ? 'Activating...' : 'Activate Digital Key'),
          )
        else
          Card(
            color: Colors.orange.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This property does not support digital keys. '
                      'Please collect a physical key at the front desk.',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _KeyCard extends StatelessWidget {
  const _KeyCard({
    required this.digitalKey,
    required this.onUnlock,
    required this.onDeactivate,
  });
  final DigitalKey digitalKey;
  final VoidCallback onUnlock;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmtDate = DateFormat('MMM d, h:mm a');
    final k = digitalKey;
    final isActive = k.isActive;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.key : Icons.key_off,
                  size: 32,
                  color: isActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room ${k.roomNumber}',
                        style: theme.textTheme.titleLarge,
                      ),
                      if (k.floorNumber != null)
                        Text(
                          '${k.floorNumber} Floor',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(k.status.label),
                  padding: EdgeInsets.zero,
                  backgroundColor: isActive
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(k.keyType.toUpperCase()),
                  padding: EdgeInsets.zero,
                  avatar: Icon(
                    k.keyType == 'nfc' ? Icons.nfc : Icons.bluetooth,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                if (k.lockSystem != null)
                  Text(k.lockSystem!, style: theme.textTheme.bodySmall),
              ],
            ),
            if (k.activatedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Activated: ${fmtDate.format(k.activatedAt!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (k.expiresAt != null) ...[
              const SizedBox(height: 2),
              Text(
                'Expires: ${fmtDate.format(k.expiresAt!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            if (isActive)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onUnlock,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Unlock Door'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onDeactivate,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Deactivate'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
