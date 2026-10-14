// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EGuest
// SPDX-License-Identifier: Apache-2.0

// eGuest app smoke test.
//
// Pumps the real root widget (`EGuestApp`) and asserts the in-stay guest
// shell renders with its bottom navigation (Home / Services / Chat /
// Offers / Profile). The demo guest context is client-side only — no
// network calls happen while building the shell.

import 'package:flutter_test/flutter_test.dart';

import 'package:eguest/app.dart';

void main() {
  testWidgets('EGuestApp renders guest shell with bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const EGuestApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Offers'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
