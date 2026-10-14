// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EGuest
// SPDX-License-Identifier: Apache-2.0

/// Service Requests.
///
/// Guest can create and track service requests: housekeeping, maintenance,
/// room service, concierge, wake-up calls, extra amenities. Shows status
/// tracking with timestamps.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class ServiceRequestsPage extends StatefulWidget {
  const ServiceRequestsPage({
    super.key,
    required this.client,
    required this.stayId,
    this.roomNumber,
  });

  final BffClient client;
  final String stayId;
  final String? roomNumber;

  @override
  State<ServiceRequestsPage> createState() => _ServiceRequestsPageState();
}

class _ServiceRequestsPageState extends State<ServiceRequestsPage> {
  late Future<List<ServiceRequest>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = widget.client.getServiceRequests(widget.stayId);
  }

  Future<void> _refresh() async {
    setState(() {
      _requestsFuture = widget.client.getServiceRequests(widget.stayId);
    });
    await _requestsFuture;
  }

  void _showNewRequestSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _NewRequestSheet(
        stayId: widget.stayId,
        roomNumber: widget.roomNumber,
        onSubmit: (request) async {
          Navigator.pop(ctx);
          try {
            await widget.client.createServiceRequest(request);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Service request submitted.')),
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
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Request',
            onPressed: _showNewRequestSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ServiceRequest>>(
          future: _requestsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(snap.error is BffException
                          ? (snap.error as BffException).message
                          : '${snap.error}'),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _refresh, child: const Text('Retry')),
                    ],
                  ),
                ),
              );
            }
            final requests = snap.data ?? const [];
            if (requests.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.room_service_outlined,
                      size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No Service Requests',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(
                      'Tap + to request housekeeping, maintenance,\nroom service, and more.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _RequestCard(request: requests[i]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewRequestSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Request Card
// ═══════════════════════════════════════════════════════════════════════════

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});
  final ServiceRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('MMM d, h:mm a');
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(request.type.icon, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(request.type.label,
                      style: theme.textTheme.titleMedium),
                ),
                _StatusChip(status: request.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(request.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (request.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(request.description,
                  style: TextStyle(color: Colors.grey.shade700)),
            ],
            const Divider(height: 16),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('Submitted ${fmt.format(request.createdAt)}',
                    style: theme.textTheme.bodySmall),
                if (request.assignedTo != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('Assigned: ${request.assignedTo}',
                      style: theme.textTheme.bodySmall),
                ],
              ],
            ),
            if (request.staffNote != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.comment, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(request.staffNote!,
                          style: const TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ServiceRequestStatus status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ServiceRequestStatus.submitted:
        color = Colors.orange;
      case ServiceRequestStatus.acknowledged:
        color = Colors.blue;
      case ServiceRequestStatus.inProgress:
        color = Colors.indigo;
      case ServiceRequestStatus.completed:
        color = Colors.green;
      case ServiceRequestStatus.cancelled:
        color = Colors.grey;
    }
    return Chip(
      label: Text(status.label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// New Request Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════

class _NewRequestSheet extends StatefulWidget {
  const _NewRequestSheet({
    required this.stayId,
    required this.roomNumber,
    required this.onSubmit,
  });

  final String stayId;
  final String? roomNumber;
  final void Function(ServiceRequest request) onSubmit;

  @override
  State<_NewRequestSheet> createState() => _NewRequestSheetState();
}

class _NewRequestSheetState extends State<_NewRequestSheet> {
  ServiceRequestType _type = ServiceRequestType.housekeeping;
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _scheduledFor;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduledTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now()),
    );
    if (time == null) return;
    setState(() {
      _scheduledFor = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a subject.')),
      );
      return;
    }
    widget.onSubmit(ServiceRequest(
      id: '',
      stayId: widget.stayId,
      roomNumber: widget.roomNumber,
      type: _type,
      subject: subject,
      description: description,
      createdAt: DateTime.now(),
      scheduledFor: _scheduledFor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('MMM d, h:mm a');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Service Request', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            // Type selector
            Wrap(
              spacing: 8,
              children: ServiceRequestType.values.map((type) {
                final isSelected = type == _type;
                return FilterChip(
                  selected: isSelected,
                  onSelected: (_) => setState(() => _type = type),
                  avatar: Icon(type.icon, size: 18),
                  label: Text(type.label),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule, color: Colors.blue),
                title: const Text('Schedule (optional)'),
                subtitle: Text(_scheduledFor != null
                    ? fmt.format(_scheduledFor!)
                    : 'Tap to select a date and time'),
                trailing: _scheduledFor != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _scheduledFor = null),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _pickScheduledTime,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send),
                label: const Text('Submit Request'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}