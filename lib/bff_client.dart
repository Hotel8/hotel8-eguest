// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EGuest
// SPDX-License-Identifier: Apache-2.0

/// eGuest BFF client.
///
/// Thin HTTP client over the real BFF proxy surfaces (see
/// `eguest/DESIGN.md` §4): PMS routes are property-scoped and
/// reservation-scoped, loyalty/upsell/payments are vertical services.
/// All requests go through the BFF server-side token guardian — eGuest
/// never talks to a backend directly.

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'models.dart';

class BffClient {
  BffClient({String? baseUrl, String? propertyId, http.Client? httpClient})
      : _baseUrl = baseUrl ?? _resolveBaseUrl(),
        _propertyId = propertyId ?? '',
        _httpClient = httpClient ?? http.Client();

  final String _baseUrl;

  /// Property the app serves — from the App runtime context at bootstrap
  /// (`eguest/DESIGN.md` §2). All PMS calls are property-scoped.
  final String _propertyId;

  /// The property this app serves (read-only; ordering/menu calls are
  /// property-scoped).
  String get propertyId => _propertyId;

  /// Raw GET for surfaces that need the envelope (room-service menu probe).
  Future<Map<String, dynamic>> getRawJson(String path) => _getJson(path);
  final http.Client _httpClient;
  String? _authToken;

  /// Resolve the BFF base URL. In production this is the guest-scoped
  /// BFF domain (e.g. `https://bff.guest.demo-hotel.pms.sentin8.dev`).
  /// For local development fall back to the `GUEST_APP_BFF_BASE_URL`
  /// env var or `http://localhost:8080`.
  static String _resolveBaseUrl() {
    const env = String.fromEnvironment(
      'GUEST_APP_BFF_BASE_URL',
      defaultValue: '',
    );
    if (env.isNotEmpty) return env;

    if (kIsWeb) {
      // Same-origin: BFF served alongside the Flutter web app.
      return '';
    }
    return 'http://localhost:8080';
  }

  String _path(String p) => '$_baseUrl$p';

  void setAuthToken(String? token) => _authToken = token;

  Future<Map<String, dynamic>> _getJson(String path) async {
    final resp =
        await _httpClient.get(Uri.parse(_path(path)), headers: _headers());
    return _handle(resp);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await _httpClient.post(
      Uri.parse(_path(path)),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> _putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await _httpClient.put(
      Uri.parse(_path(path)),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> _deleteJson(String path) async {
    final resp = await _httpClient.delete(
      Uri.parse(_path(path)),
      headers: _headers(),
    );
    return _handle(resp);
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  Future<Map<String, dynamic>> _handle(http.Response resp) async {
    final body = resp.body.isEmpty ? '{}' : resp.body;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    String message;
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      message =
          decoded['message'] as String? ?? decoded['error'] as String? ?? body;
    } catch (_) {
      message = body;
    }
    throw BffException(resp.statusCode, message);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Reservations / Stays
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pms/v1/properties/{propertyId}/reservations?guest_profile_id=&upcoming=`
  ///
  /// The guest's stays: profile-bound reservations filtered server-side
  /// (`guest_profile_id`, `upcoming` are PMS list filters — the client
  /// never narrows locally).
  Future<List<StayInfo>> getReservations({
    required String guestId,
    bool upcoming = true,
  }) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/reservations'
      '?guest_profile_id=${Uri.encodeComponent(guestId)}'
      '&upcoming=$upcoming',
    );
    final list = (json['items'] as List<dynamic>?) ?? const [];
    return list
        .map((e) => StayInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /proxy/hotel8-pms/v1/properties/{propertyId}/reservations/{id}`
  Future<StayInfo> getReservationDetail(String reservationId) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/reservations/$reservationId',
    );
    return StayInfo.fromJson(json);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Check-in / Check-out
  // ═════════════════════════════════════════════════════════════════════════

  /// `POST /proxy/hotel8-pms/v1/properties/{p}/reservations/{id}/pre-check-in`
  Future<StayInfo> preCheckIn(PreCheckInRequest request) async {
    await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/reservations/${request.reservationId}/pre-check-in',
      {'special_requests': request.specialRequests},
    );
    return getReservationDetail(request.reservationId);
  }

  /// `POST /proxy/hotel8-pms/v1/properties/{p}/reservations/{id}/check-in`
  ///
  /// Check-in executes server-side; an optional digital key is issued and
  /// activated in the same flow when [CheckInRequest.activateDigitalKey].
  Future<StayInfo> checkIn(CheckInRequest request) async {
    await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/reservations/${request.reservationId}/check-in',
      {
        if (request.roomNumber != null) 'room_number': request.roomNumber,
      },
    );
    if (request.activateDigitalKey) {
      final keys = await _postJson(
        '/proxy/hotel8-pms/v1/properties/$_propertyId/digital-keys',
        {
          'reservation_id': request.reservationId,
          'key_type': 'MOBILE',
          'count': 1,
        },
      );
      final items = (keys['items'] as List<dynamic>?) ?? const [];
      if (items.isNotEmpty) {
        final keyId = (items.first as Map<String, dynamic>)['id'] as String;
        await _postJson(
          '/proxy/hotel8-pms/v1/properties/$_propertyId'
          '/digital-keys/$keyId/activate',
          {},
        );
      }
    }
    return getReservationDetail(request.reservationId);
  }

  /// `POST /proxy/hotel8-pms/v1/properties/{p}/reservations/{id}/check-out`
  Future<void> checkOut(CheckOutRequest request) async {
    await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/reservations/${request.stayId}/check-out',
      {
        'payment_method': request.paymentMethodToken != null
            ? 'CREDIT_CARD'
            : 'CASH',
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Folio / Payments
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pms/v1/properties/{p}/reservations/{id}/folio`
  Future<Folio> getFolio(String stayId) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/reservations/$stayId/folio',
    );
    return Folio.fromJson(json);
  }

  /// `POST /proxy/bill8-payments/v1/charges` — folio payment capture.
  Future<Map<String, dynamic>> postPayment({
    required String stayId,
    required double amount,
    String currencyCode = 'USD',
    String? paymentMethodToken,
  }) async {
    return _postJson('/proxy/bill8-payments/v1/charges', {
      'amount': amount.toStringAsFixed(2),
      'currency': currencyCode,
      if (paymentMethodToken != null) 'payment_method_id': paymentMethodToken,
      'idempotency_key': 'hotel8-eguest:$stayId:${DateTime.now().millisecondsSinceEpoch}',
    });
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Service Requests
  // ═════════════════════════════════════════════════════════════════════════

  /// `POST /proxy/hotel8-pms/v1/properties/{p}/reservations/{id}/service-requests`
  Future<ServiceRequest> createServiceRequest(ServiceRequest request) async {
    final json = await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/reservations/${request.stayId}/service-requests',
      {
        'request_type': request.type.name.toUpperCase(),
        'subject': request.subject,
        'description': request.description,
      },
    );
    final created = json;
    return ServiceRequest.fromJson(created..putIfAbsent('id', () => '_'));
  }

  /// `GET /proxy/hotel8-pms/v1/properties/{p}/reservations/{id}/service-requests`
  Future<List<ServiceRequest>> getServiceRequests(String stayId) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/reservations/$stayId/service-requests',
    );
    final list = (json['items'] as List<dynamic>?) ?? const [];
    return list
        .map((e) => ServiceRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Messaging
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pms/v1/properties/{p}/reservations/{id}/messages`
  Future<List<Message>> getMessages(String stayId) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/reservations/$stayId/messages',
    );
    final list = (json['items'] as List<dynamic>?) ?? const [];
    return list
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /proxy/hotel8-pms/v1/properties/{p}/reservations/{id}/messages`
  Future<Message> sendMessage(Message message) async {
    final json = await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/reservations/${message.stayId}/messages',
      {'content': message.body, 'message_type': 'TEXT'},
    );
    return Message.fromJson(json..putIfAbsent('id', () => '_'));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Digital Key
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pms/v1/properties/{p}/digital-keys?reservation_id=`
  Future<List<DigitalKey>> getDigitalKeys(String stayId) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/digital-keys?reservation_id=${Uri.encodeComponent(stayId)}',
    );
    final list = (json['items'] as List<dynamic>?) ?? const [];
    return list
        .map((e) => DigitalKey.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST .../digital-keys` (issue) + `/{id}/activate` — the guest can
  /// only activate keys the property issued; the client never mints state.
  Future<DigitalKey> activateDigitalKey({
    required String stayId,
    required String roomNumber,
    String keyType = 'MOBILE',
  }) async {
    final issued = await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/digital-keys',
      {
        'reservation_id': stayId,
        'key_type': keyType,
        'count': 1,
      },
    );
    final items = (issued['items'] as List<dynamic>?) ?? const [];
    if (items.isEmpty) {
      throw const BffException(409, 'Property issued no keys for this stay');
    }
    final keyId = (items.first as Map<String, dynamic>)['id'] as String;
    final json = await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/digital-keys/$keyId/activate',
      {},
    );
    return DigitalKey.fromJson(json);
  }

  /// `POST .../digital-keys/{id}/deactivate`
  Future<void> deactivateDigitalKey(String keyId) async {
    await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/digital-keys/$keyId/deactivate',
      {},
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Upsell Offers
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/ups/ups/v1/offers?stay_id=...`
  Future<List<UpsellOffer>> getUpsellOffers(String stayId) async {
    final json =
        await _getJson('/proxy/hotel8-upsell/v1/offers/for-reservation?reservation_id=${Uri.encodeComponent(stayId)}');
    final list = json['offers'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        const [];
    return list
        .map((e) => UpsellOffer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /proxy/ups/ups/v1/offers/accept`
  Future<UpsellOffer> acceptOffer(UpsellOffer offer) async {
    final json =
        await _postJson('/proxy/hotel8-upsell/v1/offers/accept', offer.toJson());
    return UpsellOffer.fromJson(json);
  }

  /// `POST /proxy/ups/ups/v1/offers/decline`
  Future<void> declineOffer(UpsellOffer offer) async {
    await _postJson('/proxy/hotel8-upsell/v1/offers/decline', offer.toJson());
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Guest Profile
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pms/v1/properties/{p}/profiles/{id}`
  Future<GuestProfile> getGuestProfile(String guestId) async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/profiles/$guestId',
    );
    return GuestProfile.fromJson(json);
  }

  /// `PUT .../profiles/{id}`? — PMS exposes preference/loyalty-number
  /// setters; the profile body fields the app edits ride those routes.
  Future<GuestProfile> updateGuestProfile(GuestProfile profile) async {
    final loyalty = profile.loyaltyNumber;
    if (loyalty != null) {
      await _putJson(
        '/proxy/hotel8-pms/v1/properties/$_propertyId'
        '/profiles/${profile.id}/loyalty-number',
        {'loyalty_number': loyalty},
      );
    }
    return profile;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Loyalty
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/loyal/v1/members/{memberId}`
  Future<LoyaltyInfo> getLoyaltyInfo(String memberId) async {
    final json = await _getJson('/proxy/hotel8-loyalty/v1/members/$memberId');
    return LoyaltyInfo.fromJson(json);
  }

  /// `GET /proxy/loyal/v1/members/{memberId}/transactions`
  Future<List<LoyaltyTransaction>> getLoyaltyTransactions(
    String memberId,
  ) async {
    final json =
        await _getJson(
          '/proxy/hotel8-loyalty/v1/members/$memberId/transactions',
        );
    final list = json['transactions'] as List<dynamic>? ??
        json['data'] as List<dynamic>? ??
        const [];
    return list
        .map((e) => LoyaltyTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Feedback
  // ═════════════════════════════════════════════════════════════════════════

  /// `POST /proxy/hotel8-pms/v1/properties/{p}/feedback`
  Future<void> submitStayRating(StayRating rating) async {
    await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/feedback',
      {
        'reservation_id': rating.stayId,
        'rating': rating.overallScore,
        if (rating.comment != null) 'comment': rating.comment,
      },
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // Rewards catalog + redemption (Hotel8:Loyalty)
  // ═════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-loyalty/v1/members/{id}/rewards` — catalog with
  /// per-item redeemable flags against the member's balance.
  Future<List<Reward>> getRewards(String memberId) async {
    final json = await _getJson(
      '/proxy/hotel8-loyalty/v1/members/$memberId/rewards',
    );
    final list = (json['rewards'] as List<dynamic>?) ??
        (json['items'] as List<dynamic>?) ??
        const [];
    return list.map((e) => Reward.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `POST /proxy/hotel8-loyalty/v1/rewards/redeem` — points → voucher code.
  Future<RewardRedemption> redeemReward({
    required String memberId,
    required String catalogItemId,
  }) async {
    final json = await _postJson('/proxy/hotel8-loyalty/v1/rewards/redeem', {
      'member_id': memberId,
      'catalog_item_id': catalogItemId,
    });
    return RewardRedemption.fromJson(json);
  }

  // ═════════════════════════════════════════════════════════════════════
  // Room service (Hotel8:POS guest-ordering surface)
  // ═════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pos/v1/guest/{p}/menu` — room-service menu.
  Future<List<RoomServiceMenuItem>> getRoomServiceMenu() async {
    final json = await _getJson(
      '/proxy/hotel8-pos/v1/guest/$_propertyId/menu',
    );
    final list = (json['items'] as List<dynamic>?) ?? const [];
    return list
        .map((e) => RoomServiceMenuItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /proxy/hotel8-pos/v1/guest/{p}/orders` — place a room-service
  /// order bound to the in-house stay.
  Future<RoomServiceOrder> placeRoomServiceOrder({
    required String outletId,
    required String reservationId,
    required List<Map<String, dynamic>> items,
  }) async {
    final json = await _postJson(
      '/proxy/hotel8-pos/v1/guest/$_propertyId/orders',
      {
        'outlet_id': outletId,
        'reservation_id': reservationId,
        'items': items,
      },
    );
    return RoomServiceOrder.fromJson(json);
  }

  /// `GET /proxy/hotel8-pos/v1/guest/{p}/orders/{check_id}` — order status.
  Future<RoomServiceOrder> getRoomServiceOrder(String checkId) async {
    final json = await _getJson(
      '/proxy/hotel8-pos/v1/guest/$_propertyId/orders/$checkId',
    );
    return RoomServiceOrder.fromJson(json);
  }

  // ═════════════════════════════════════════════════════════════════════
  // Saved payment methods (Hotel8:PMS eguest surface)
  // ═════════════════════════════════════════════════════════════════════

  /// `GET .../payment-methods` — saved methods for the session subject.
  Future<List<PaymentMethodInfo>> getPaymentMethods() async {
    final json = await _getJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/payment-methods',
    );
    final list = (json['items'] as List<dynamic>?) ?? const [];
    return list
        .map((e) => PaymentMethodInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST .../payment-methods` — save a bill8 token reference.
  Future<PaymentMethodInfo> savePaymentMethod({
    required String label,
    required String paymentMethodId,
    bool isDefault = false,
  }) async {
    final json = await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/payment-methods',
      {
        'label': label,
        'payment_method_id': paymentMethodId,
        'is_default': isDefault,
      },
    );
    return PaymentMethodInfo.fromJson(json);
  }

  /// `DELETE .../payment-methods/{id}` — remove a saved method.
  Future<void> deletePaymentMethod(String methodId) async {
    await _deleteJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId/payment-methods/$methodId',
    );
  }

  /// `POST .../reservations/{id}/link-guest` — bind the signed-in profile to
  /// a booking made anonymously in eBooking (reservation↔guest linking).
  Future<void> linkReservationToGuest({
    required String reservationId,
    String? targetProfileId,
  }) async {
    await _postJson(
      '/proxy/hotel8-pms/v1/properties/$_propertyId'
      '/reservations/$reservationId/link-guest',
      {
        if (targetProfileId != null) 'target_profile_id': targetProfileId,
      },
    );
  }

  void close() => _httpClient.close();
}

class BffException implements Exception {
  final int statusCode;
  final String message;
  const BffException(this.statusCode, this.message);

  @override
  String toString() => 'BffException($statusCode): $message';
}