// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EGuest
// SPDX-License-Identifier: Apache-2.0

/// Guest Messaging.
///
/// Real-time chat with the front desk. Shows message history with bubbles,
/// text input, and push notification support.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class GuestMessagingPage extends StatefulWidget {
  const GuestMessagingPage({
    super.key,
    required this.client,
    required this.stayId,
    required this.guestName,
  });

  final BffClient client;
  final String stayId;
  final String guestName;

  @override
  State<GuestMessagingPage> createState() => _GuestMessagingPageState();
}

class _GuestMessagingPageState extends State<GuestMessagingPage> {
  late Future<List<Message>> _messagesFuture;
  final _inputController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messagesFuture = widget.client.getMessages(widget.stayId);
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _messagesFuture = widget.client.getMessages(widget.stayId);
    });
    await _messagesFuture;
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    _inputController.clear();
    try {
      await widget.client.sendMessage(Message(
        id: '',
        stayId: widget.stayId,
        senderName: widget.guestName,
        senderRole: 'guest',
        body: text,
        sentAt: DateTime.now(),
        direction: MessageDirection.outgoing,
      ));
      _refresh();
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.support_agent),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Front Desk', style: TextStyle(fontSize: 16)),
                Text('Typically replies in 5 min',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Message>>(
              future: _messagesFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
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
                final messages = snap.data ?? const [];
                if (messages.isEmpty) {
                  return const _EmptyChat();
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[messages.length - 1 - i];
                    return _MessageBubble(message: msg);
                  },
                );
              },
            ),
          ),
          _InputBar(
            controller: _inputController,
            sending: _sending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No messages yet',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Start a conversation with the front desk.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.direction == MessageDirection.outgoing;
    final theme = Theme.of(context);
    final fmt = DateFormat('h:mm a');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOutgoing) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.support_agent, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isOutgoing
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isOutgoing
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isOutgoing
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.body,
                    style: TextStyle(
                      color: isOutgoing
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmt.format(message.sentAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isOutgoing
                          ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Message front desk...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  suffixIcon: sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}