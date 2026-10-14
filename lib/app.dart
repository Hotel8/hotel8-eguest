// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EGuest
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'package:sentin8/sentin8.dart';

import 'bff_client.dart';
import 'models.dart';
import 'screens/guest_home_page.dart';
import 'screens/service_requests_page.dart';
import 'screens/guest_messaging_page.dart';
import 'screens/guest_upsell_page.dart';

export 'screens/guest_home_page.dart';
export 'screens/mobile_check_in_page.dart';
export 'screens/service_requests_page.dart';
export 'screens/guest_messaging_page.dart';
export 'screens/digital_key_page.dart';
export 'screens/guest_upsell_page.dart';
export 'screens/guest_checkout_page.dart';

class EGuestApp extends StatelessWidget {
  const EGuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eGuest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GuestRoot(),
    );
  }
}

/// Root widget — bootstraps runtime context + BFF session and shows the
/// bottom-nav shell. The guest identity comes from the signed-in session
/// user (`id` is the subject; the PMS profile is linked to it — see
/// `eguest/DESIGN.md` §2).
class GuestRoot extends StatefulWidget {
  const GuestRoot({super.key});

  @override
  State<GuestRoot> createState() => _GuestRootState();
}

class _GuestRootState extends State<GuestRoot> {
  AppRuntimeContext? _runtimeContext;
  BffAuthProvider? _auth;
  BffClient? _client;
  String? _bootstrapError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Same-origin bootstrap — the TLS proxy injects the X-Sentin8-*
      // headers the runtime context resolves from.
      final ctx = await fetchRuntimeContext(appBaseUrl: '');
      final auth = BffAuthProvider(
        bffBaseUrl: ctx.bffBaseUrl,
        authDomain: ctx.authDomain,
        logPrefix: 'eGuest',
      );
      auth.onRedirect = (String url) {
        web.window.location.href = url;
      };
      await auth.init();
      final client = BffClient(
        baseUrl: ctx.bffBaseUrl,
        propertyId: ctx.environmentId,
      );
      setState(() {
        _runtimeContext = ctx;
        _auth = auth;
        _client = client;
      });
    } catch (e) {
      setState(() => _bootstrapError = e.toString());
    }
  }

  @override
  void dispose() {
    _auth?.dispose();
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = _auth;
    if (_bootstrapError != null) {
      return Scaffold(
        body: Center(child: Text('eGuest unavailable: $_bootstrapError')),
      );
    }
    if (auth != null && !auth.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final client = _client;
    final ctx = _runtimeContext;
    if (client == null || ctx == null || auth == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isSignedIn) {
      return _GuestLandingPage(auth: auth, name: ctx.instanceName);
    }
    // The signed-in session user id doubles as the guest profile id —
    // profile rows resolve by the subject (BFF session user id).
    final guestId = auth.user?.id ?? '';
    if (guestId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Signed-in user has no profile id')),
      );
    }
    return GuestShell(client: client, guestId: guestId);
  }
}

/// Landing page for guests who have not signed in yet — redirects through
/// the BFF to the property's Auth sign-in/sign-up.
class _GuestLandingPage extends StatelessWidget {
  const _GuestLandingPage({required this.auth, required this.name});

  final BffAuthProvider auth;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hotel, size: 64, color: Colors.blueGrey[300]),
            const SizedBox(height: 16),
            Text(name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Sign in to your stay',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => auth.signInWithAuth(),
              icon: const Icon(Icons.login),
              label: const Text('Sign In'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => auth.signUpWithAuth(),
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shell with a bottom navigation bar: Home, Services, Chat, Offers,
/// Digital Key. Shown after the guest has authenticated.
class GuestShell extends StatefulWidget {
  const GuestShell({
    super.key,
    required this.client,
    required this.guestId,
  });

  final BffClient client;
  final String guestId;

  @override
  State<GuestShell> createState() => _GuestShellState();
}

class _GuestShellState extends State<GuestShell> {
  int _index = 0;
  String? _activeStayId;

  @override
  void initState() {
    super.initState();
    _resolveActiveStay();
  }

  Future<void> _resolveActiveStay() async {
    try {
      final stays = await widget.client.getReservations(
        guestId: widget.guestId,
        upcoming: true,
      );
      if (mounted && stays.isNotEmpty) {
        setState(() => _activeStayId = stays.first.id);
      }
    } on BffException {
      // Non-fatal — tabs that need a stay will show an empty state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      GuestHomePage(
        client: widget.client,
        guestId: widget.guestId,
      ),
      _ServicesTab(
        client: widget.client,
        stayId: _activeStayId ?? '',
      ),
      _ChatTab(
        client: widget.client,
        stayId: _activeStayId ?? '',
      ),
      _OffersTab(
        client: widget.client,
        stayId: _activeStayId ?? '',
        guestId: widget.guestId,
      ),
      _ProfileTab(
        client: widget.client,
        guestId: widget.guestId,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.room_service_outlined),
            selectedIcon: Icon(Icons.room_service),
            label: 'Services',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer),
            label: 'Offers',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab wrappers
// ═══════════════════════════════════════════════════════════════════════════

class _ServicesTab extends StatelessWidget {
  const _ServicesTab({required this.client, required this.stayId});
  final BffClient client;
  final String stayId;

  @override
  Widget build(BuildContext context) {
    if (stayId.isEmpty) {
      return _Placeholder(
        icon: Icons.room_service_outlined,
        title: 'No Active Stay',
        message: 'Service requests will appear here once you have an active stay.',
      );
    }
    return ServiceRequestsPage(client: client, stayId: stayId);
  }
}

class _ChatTab extends StatelessWidget {
  const _ChatTab({required this.client, required this.stayId});
  final BffClient client;
  final String stayId;

  @override
  Widget build(BuildContext context) {
    if (stayId.isEmpty) {
      return _Placeholder(
        icon: Icons.chat_outlined,
        title: 'No Active Stay',
        message: 'Messaging with the front desk will appear here during your stay.',
      );
    }
    return GuestMessagingPage(
      client: client,
      stayId: stayId,
      guestName: 'Guest',
    );
  }
}

class _OffersTab extends StatelessWidget {
  const _OffersTab({required this.client, required this.stayId, required this.guestId});
  final BffClient client;
  final String stayId;
  final String guestId;

  @override
  Widget build(BuildContext context) {
    if (stayId.isEmpty) {
      return _Placeholder(
        icon: Icons.local_offer_outlined,
        title: 'No Active Stay',
        message: 'Upsell offers will appear here once you have an active reservation.',
      );
    }
    return GuestUpsellPage(client: client, stayId: stayId);
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.client, required this.guestId});
  final BffClient client;
  final String guestId;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  GuestProfile? _profile;
  LoyaltyInfo? _loyalty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await widget.client.getGuestProfile(widget.guestId);
      LoyaltyInfo? loyalty;
      if (profile.loyaltyNumber != null) {
        try {
          loyalty = await widget.client.getLoyaltyInfo(profile.loyaltyNumber!);
        } on BffException {
          // Loyalty is optional.
        }
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _loyalty = loyalty;
          _loading = false;
        });
      }
    } on BffException {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profile == null) {
      return _Placeholder(
        icon: Icons.person_outline,
        title: 'Profile Unavailable',
        message: 'Unable to load your profile. Please try again later.',
        onAction: _loadProfile,
        actionLabel: 'Retry',
      );
    }
    final p = _profile!;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      '${p.firstName[0]}${p.lastName[0]}',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(p.fullName, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(p.email, style: TextStyle(color: Colors.grey.shade600)),
                  if (p.phone != null) ...[
                    const SizedBox(height: 2),
                    Text(p.phone!, style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Loyalty card
          if (_loyalty != null)
            Card(
              elevation: 2,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 28),
                        const SizedBox(width: 8),
                        Text('${_loyalty!.tier} Member',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Current Points: ${_loyalty!.currentPoints}',
                        style: theme.textTheme.titleSmall),
                    Text('Lifetime Points: ${_loyalty!.lifetimePoints}',
                        style: theme.textTheme.bodyMedium),
                    if (_loyalty!.pointsToNextTier > 0)
                      Text(
                        '${_loyalty!.pointsToNextTier} pts to ${_loyalty!.nextTier ?? "next tier"}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Preferences card
          if (p.preferences.isNotEmpty)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Preferences', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: p.preferences
                          .map((pref) => Chip(label: Text(pref)))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Settings
          Card(
            elevation: 2,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit profile — coming soon')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notification Preferences'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notification preferences — coming soon')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: const Text('Payment Methods'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment methods — coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.title,
    required this.message,
    this.onAction,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}