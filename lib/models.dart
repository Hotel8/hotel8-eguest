// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EGuest
// SPDX-License-Identifier: Apache-2.0

/// eGuest data models.
///
/// Simple Dart classes mirroring the PMS / Upsell / POS / Loyalty contract
/// shapes (see `eguest/DESIGN.md` §3)
/// and the BFF proxy surface for eGuest. eGuest is the in-stay
/// companion for hotel guests — mobile check-in/out, service requests,
/// messaging, digital key, upsell offers, and loyalty.

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Stay Info (reservation / current stay)
// ═══════════════════════════════════════════════════════════════════════════

enum StayStatus {
  pending,
  confirmed,
  preCheckedIn,
  checkedIn,
  checkedOut,
  cancelled,
  noShow;

  static StayStatus fromString(String s) => StayStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == s.toLowerCase().replaceAll('_', ''),
        orElse: () => StayStatus.confirmed,
      );

  String get label {
    switch (this) {
      case StayStatus.pending:
        return 'Pending';
      case StayStatus.confirmed:
        return 'Confirmed';
      case StayStatus.preCheckedIn:
        return 'Pre-Checked-In';
      case StayStatus.checkedIn:
        return 'Checked In';
      case StayStatus.checkedOut:
        return 'Checked Out';
      case StayStatus.cancelled:
        return 'Cancelled';
      case StayStatus.noShow:
        return 'No Show';
    }
  }

  bool get isUpcoming =>
      this == StayStatus.pending ||
      this == StayStatus.confirmed ||
      this == StayStatus.preCheckedIn;
  bool get isInStay => this == StayStatus.checkedIn;
}

class StayInfo {
  final String id;
  final String confirmationNumber;
  final String propertyCode;
  final String propertyName;
  final String? propertyAddress;
  final String? propertyPhone;
  final DateTime arrivalDate;
  final DateTime departureDate;
  final int numberOfNights;
  final int numberOfGuests;
  final int numberOfRooms;
  final String roomTypeCode;
  final String roomTypeName;
  final String? roomNumber;
  final String? floorNumber;
  final String ratePlanName;
  final double rateAmount;
  final String currencyCode;
  final StayStatus status;
  final String? guestId;
  final String guestName;
  final String? specialRequests;
  final bool digitalKeyEligible;

  const StayInfo({
    required this.id,
    required this.confirmationNumber,
    required this.propertyCode,
    required this.propertyName,
    this.propertyAddress,
    this.propertyPhone,
    required this.arrivalDate,
    required this.departureDate,
    this.numberOfNights = 1,
    this.numberOfGuests = 1,
    this.numberOfRooms = 1,
    required this.roomTypeCode,
    required this.roomTypeName,
    this.roomNumber,
    this.floorNumber,
    this.ratePlanName = '',
    this.rateAmount = 0.0,
    this.currencyCode = 'USD',
    this.status = StayStatus.confirmed,
    this.guestId,
    required this.guestName,
    this.specialRequests,
    this.digitalKeyEligible = false,
  });

  factory StayInfo.fromJson(Map<String, dynamic> json) => StayInfo(
        id: json['id'] as String,
        confirmationNumber: json['confirmation_number'] as String? ?? '',
        propertyCode: json['property_code'] as String,
        propertyName: json['property_name'] as String? ?? '',
        propertyAddress: json['property_address'] as String?,
        propertyPhone: json['property_phone'] as String?,
        arrivalDate:
            DateTime.tryParse(json['arrival_date'] as String? ?? '') ??
                DateTime.now(),
        departureDate:
            DateTime.tryParse(json['departure_date'] as String? ?? '') ??
                DateTime.now(),
        numberOfNights: (json['number_of_nights'] as num?)?.toInt() ?? 1,
        numberOfGuests: (json['number_of_guests'] as num?)?.toInt() ?? 1,
        numberOfRooms: (json['number_of_rooms'] as num?)?.toInt() ?? 1,
        roomTypeCode: json['room_type_code'] as String? ?? '',
        roomTypeName: json['room_type_name'] as String? ?? '',
        roomNumber: json['room_number'] as String?,
        floorNumber: json['floor_number'] as String?,
        ratePlanName: json['rate_plan_name'] as String? ?? '',
        rateAmount: (json['rate_amount'] as num?)?.toDouble() ?? 0.0,
        currencyCode: json['currency_code'] as String? ?? 'USD',
        status: StayStatus.fromString(json['status'] as String? ?? 'confirmed'),
        guestId: json['guest_id'] as String?,
        guestName: json['guest_name'] as String? ?? '',
        specialRequests: json['special_requests'] as String?,
        digitalKeyEligible: json['digital_key_eligible'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'confirmation_number': confirmationNumber,
        'property_code': propertyCode,
        'property_name': propertyName,
        'property_address': propertyAddress,
        'property_phone': propertyPhone,
        'arrival_date': _dateStr(arrivalDate),
        'departure_date': _dateStr(departureDate),
        'number_of_nights': numberOfNights,
        'number_of_guests': numberOfGuests,
        'number_of_rooms': numberOfRooms,
        'room_type_code': roomTypeCode,
        'room_type_name': roomTypeName,
        'room_number': roomNumber,
        'floor_number': floorNumber,
        'rate_plan_name': ratePlanName,
        'rate_amount': rateAmount,
        'currency_code': currencyCode,
        'status': status.name,
        'guest_id': guestId,
        'guest_name': guestName,
        'special_requests': specialRequests,
        'digital_key_eligible': digitalKeyEligible,
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// Room Info
// ═══════════════════════════════════════════════════════════════════════════

class RoomInfo {
  final String roomNumber;
  final String floorNumber;
  final String roomTypeCode;
  final String roomTypeName;
  final bool smoking;
  final List<Amenity> amenities;
  final String? wifiNetwork;
  final String? wifiPassword;

  const RoomInfo({
    required this.roomNumber,
    required this.floorNumber,
    required this.roomTypeCode,
    required this.roomTypeName,
    this.smoking = false,
    this.amenities = const [],
    this.wifiNetwork,
    this.wifiPassword,
  });

  factory RoomInfo.fromJson(Map<String, dynamic> json) => RoomInfo(
        roomNumber: json['room_number'] as String? ?? '',
        floorNumber: json['floor_number'] as String? ?? '',
        roomTypeCode: json['room_type_code'] as String? ?? '',
        roomTypeName: json['room_type_name'] as String? ?? '',
        smoking: json['smoking'] as bool? ?? false,
        amenities: (json['amenities'] as List<dynamic>?)
                ?.map((e) => Amenity.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        wifiNetwork: json['wifi_network'] as String?,
        wifiPassword: json['wifi_password'] as String?,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Amenity
// ═══════════════════════════════════════════════════════════════════════════

class Amenity {
  final String code;
  final String name;
  final String? description;
  final String? icon;

  const Amenity({
    required this.code,
    required this.name,
    this.description,
    this.icon,
  });

  factory Amenity.fromJson(Map<String, dynamic> json) => Amenity(
        code: json['code'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        icon: json['icon'] as String?,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Service Request
// ═══════════════════════════════════════════════════════════════════════════

enum ServiceRequestType {
  housekeeping,
  maintenance,
  roomService,
  concierge,
  wakeUpCall,
  extraAmenities;

  static ServiceRequestType fromString(String s) =>
      ServiceRequestType.values.firstWhere(
        (e) => e.name.toLowerCase() == s.toLowerCase().replaceAll('_', ''),
        orElse: () => ServiceRequestType.housekeeping,
      );

  String get label {
    switch (this) {
      case ServiceRequestType.housekeeping:
        return 'Housekeeping';
      case ServiceRequestType.maintenance:
        return 'Maintenance';
      case ServiceRequestType.roomService:
        return 'Room Service';
      case ServiceRequestType.concierge:
        return 'Concierge';
      case ServiceRequestType.wakeUpCall:
        return 'Wake-Up Call';
      case ServiceRequestType.extraAmenities:
        return 'Extra Amenities';
    }
  }

  IconData get icon {
    // ignore: avoid_returning_null_for_void
    return switch (this) {
      ServiceRequestType.housekeeping => Icons.cleaning_services,
      ServiceRequestType.maintenance => Icons.build,
      ServiceRequestType.roomService => Icons.restaurant,
      ServiceRequestType.concierge => Icons.support_agent,
      ServiceRequestType.wakeUpCall => Icons.alarm,
      ServiceRequestType.extraAmenities => Icons.local_laundry_service,
    };
  }
}

enum ServiceRequestStatus {
  submitted,
  acknowledged,
  inProgress,
  completed,
  cancelled;

  static ServiceRequestStatus fromString(String s) =>
      ServiceRequestStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == s.toLowerCase().replaceAll('_', ''),
        orElse: () => ServiceRequestStatus.submitted,
      );

  String get label => switch (this) {
        ServiceRequestStatus.submitted => 'Submitted',
        ServiceRequestStatus.acknowledged => 'Acknowledged',
        ServiceRequestStatus.inProgress => 'In Progress',
        ServiceRequestStatus.completed => 'Completed',
        ServiceRequestStatus.cancelled => 'Cancelled',
      };
}

class ServiceRequest {
  final String id;
  final String stayId;
  final String? reservationId;
  final String? roomNumber;
  final ServiceRequestType type;
  final String subject;
  final String description;
  final ServiceRequestStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? scheduledFor;
  final String? assignedTo;
  final String? staffNote;

  const ServiceRequest({
    required this.id,
    required this.stayId,
    this.reservationId,
    this.roomNumber,
    required this.type,
    required this.subject,
    required this.description,
    this.status = ServiceRequestStatus.submitted,
    required this.createdAt,
    this.updatedAt,
    this.scheduledFor,
    this.assignedTo,
    this.staffNote,
  });

  factory ServiceRequest.fromJson(Map<String, dynamic> json) => ServiceRequest(
        id: json['id'] as String,
        stayId: json['stay_id'] as String? ?? '',
        reservationId: json['reservation_id'] as String?,
        roomNumber: json['room_number'] as String?,
        type: ServiceRequestType.fromString(
            json['type'] as String? ?? 'housekeeping'),
        subject: json['subject'] as String? ?? '',
        description: json['description'] as String? ?? '',
        status: ServiceRequestStatus.fromString(
            json['status'] as String? ?? 'submitted'),
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
        scheduledFor: json['scheduled_for'] != null
            ? DateTime.tryParse(json['scheduled_for'] as String)
            : null,
        assignedTo: json['assigned_to'] as String?,
        staffNote: json['staff_note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'stay_id': stayId,
        'reservation_id': reservationId,
        'room_number': roomNumber,
        'type': type.name,
        'subject': subject,
        'description': description,
        if (scheduledFor != null) 'scheduled_for': _dateStr(scheduledFor!),
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// Message (guest ↔ front desk chat)
// ═══════════════════════════════════════════════════════════════════════════

enum MessageDirection { incoming, outgoing }

class Message {
  final String id;
  final String stayId;
  final String senderName;
  final String senderRole; // "guest" or "front_desk"
  final String body;
  final DateTime sentAt;
  final bool read;
  final MessageDirection direction;

  const Message({
    required this.id,
    required this.stayId,
    required this.senderName,
    required this.senderRole,
    required this.body,
    required this.sentAt,
    this.read = false,
    this.direction = MessageDirection.incoming,
  });

  factory Message.fromJson(Map<String, dynamic> json, {
    String? currentGuestId,
  }) {
    final role = json['sender_role'] as String? ?? 'front_desk';
    return Message(
      id: json['id'] as String,
      stayId: json['stay_id'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? '',
      senderRole: role,
      body: json['body'] as String? ?? '',
      sentAt:
          DateTime.tryParse(json['sent_at'] as String? ?? '') ?? DateTime.now(),
      read: json['read'] as bool? ?? false,
      direction: role == 'guest'
          ? MessageDirection.outgoing
          : MessageDirection.incoming,
    );
  }

  Map<String, dynamic> toJson() => {
        'stay_id': stayId,
        'sender_role': senderRole,
        'body': body,
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// Digital Key
// ═══════════════════════════════════════════════════════════════════════════

enum DigitalKeyStatus { inactive, active, expired, revoked }

extension DigitalKeyStatusX on DigitalKeyStatus {
  static DigitalKeyStatus fromString(String s) =>
      DigitalKeyStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == s.toLowerCase(),
        orElse: () => DigitalKeyStatus.inactive,
      );

  String get label => switch (this) {
        DigitalKeyStatus.inactive => 'Inactive',
        DigitalKeyStatus.active => 'Active',
        DigitalKeyStatus.expired => 'Expired',
        DigitalKeyStatus.revoked => 'Revoked',
      };
}

class DigitalKey {
  final String id;
  final String stayId;
  final String roomNumber;
  final String? floorNumber;
  final String keyType; // "ble" or "nfc"
  final DigitalKeyStatus status;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final String? lockSystem;

  const DigitalKey({
    required this.id,
    required this.stayId,
    required this.roomNumber,
    this.floorNumber,
    this.keyType = 'ble',
    this.status = DigitalKeyStatus.inactive,
    this.activatedAt,
    this.expiresAt,
    this.lockSystem,
  });

  factory DigitalKey.fromJson(Map<String, dynamic> json) => DigitalKey(
        id: json['id'] as String,
        stayId: json['stay_id'] as String? ?? '',
        roomNumber: json['room_number'] as String? ?? '',
        floorNumber: json['floor_number'] as String?,
        keyType: json['key_type'] as String? ?? 'ble',
        status: DigitalKeyStatusX.fromString(
            json['status'] as String? ?? 'inactive'),
        activatedAt: json['activated_at'] != null
            ? DateTime.tryParse(json['activated_at'] as String)
            : null,
        expiresAt: json['expires_at'] != null
            ? DateTime.tryParse(json['expires_at'] as String)
            : null,
        lockSystem: json['lock_system'] as String?,
      );

  bool get isActive => status == DigitalKeyStatus.active;
}

// ═══════════════════════════════════════════════════════════════════════════
// Upsell Offer
// ═══════════════════════════════════════════════════════════════════════════

enum UpsellCategory {
  roomUpgrade,
  spa,
  dining,
  experience,
  lateCheckout,
  earlyCheckIn,
  parking,
  breakfast;

  static UpsellCategory fromString(String s) =>
      UpsellCategory.values.firstWhere(
        (e) => e.name.toLowerCase() == s.toLowerCase().replaceAll('_', ''),
        orElse: () => UpsellCategory.roomUpgrade,
      );

  String get label => switch (this) {
        UpsellCategory.roomUpgrade => 'Room Upgrade',
        UpsellCategory.spa => 'Spa',
        UpsellCategory.dining => 'Dining',
        UpsellCategory.experience => 'Experience',
        UpsellCategory.lateCheckout => 'Late Check-Out',
        UpsellCategory.earlyCheckIn => 'Early Check-In',
        UpsellCategory.parking => 'Parking',
        UpsellCategory.breakfast => 'Breakfast',
      };

  IconData get icon => switch (this) {
        UpsellCategory.roomUpgrade => Icons.upgrade,
        UpsellCategory.spa => Icons.spa,
        UpsellCategory.dining => Icons.restaurant,
        UpsellCategory.experience => Icons.celebration,
        UpsellCategory.lateCheckout => Icons.schedule,
        UpsellCategory.earlyCheckIn => Icons.login,
        UpsellCategory.parking => Icons.local_parking,
        UpsellCategory.breakfast => Icons.free_breakfast,
      };
}

enum OfferStatus { available, accepted, declined, expired }

extension OfferStatusX on OfferStatus {
  static OfferStatus fromString(String s) =>
      OfferStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == s.toLowerCase(),
        orElse: () => OfferStatus.available,
      );
}

class UpsellOffer {
  final String id;
  final String stayId;
  final String title;
  final String description;
  final UpsellCategory category;
  final double price;
  final String currencyCode;
  final String? imageUrl;
  final String? roomTypeFrom;
  final String? roomTypeTo;
  final OfferStatus status;
  final DateTime? validUntil;

  const UpsellOffer({
    required this.id,
    required this.stayId,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.currencyCode = 'USD',
    this.imageUrl,
    this.roomTypeFrom,
    this.roomTypeTo,
    this.status = OfferStatus.available,
    this.validUntil,
  });

  factory UpsellOffer.fromJson(Map<String, dynamic> json) => UpsellOffer(
        id: json['id'] as String,
        stayId: json['stay_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        category: UpsellCategory.fromString(
            json['category'] as String? ?? 'room_upgrade'),
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        currencyCode: json['currency_code'] as String? ?? 'USD',
        imageUrl: json['image_url'] as String?,
        roomTypeFrom: json['room_type_from'] as String?,
        roomTypeTo: json['room_type_to'] as String?,
        status: OfferStatusX.fromString(
            json['status'] as String? ?? 'available'),
        validUntil: json['valid_until'] != null
            ? DateTime.tryParse(json['valid_until'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'stay_id': stayId,
        'offer_id': id,
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// Folio (charges / payments)
// ═══════════════════════════════════════════════════════════════════════════

class FolioItem {
  final String id;
  final DateTime date;
  final String description;
  final double amount;
  final String currencyCode;
  final String category; // room, tax, fnb, minibar, spa, other

  const FolioItem({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    this.currencyCode = 'USD',
    this.category = 'other',
  });

  factory FolioItem.fromJson(Map<String, dynamic> json) => FolioItem(
        id: json['id'] as String,
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.now(),
        description: json['description'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        currencyCode: json['currency_code'] as String? ?? 'USD',
        category: json['category'] as String? ?? 'other',
      );
}

class Folio {
  final String id;
  final String stayId;
  final List<FolioItem> charges;
  final List<FolioItem> payments;
  final double balance;
  final String currencyCode;

  const Folio({
    required this.id,
    required this.stayId,
    this.charges = const [],
    this.payments = const [],
    this.balance = 0.0,
    this.currencyCode = 'USD',
  });

  factory Folio.fromJson(Map<String, dynamic> json) => Folio(
        id: json['id'] as String,
        stayId: json['stay_id'] as String? ?? '',
        charges: (json['charges'] as List<dynamic>?)
                ?.map((e) => FolioItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        payments: (json['payments'] as List<dynamic>?)
                ?.map((e) => FolioItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
        currencyCode: json['currency_code'] as String? ?? 'USD',
      );

  double get totalCharges =>
      charges.fold(0.0, (sum, item) => sum + item.amount);
  double get totalPayments =>
      payments.fold(0.0, (sum, item) => sum + item.amount);
}

// ═══════════════════════════════════════════════════════════════════════════
// Guest Profile
// ═══════════════════════════════════════════════════════════════════════════

class GuestProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? countryCode;
  final String? loyaltyNumber;
  final String? loyaltyTier;
  final List<String> preferences;
  final String? idType;
  final String? idNumber;
  final DateTime? dateOfBirth;
  final String? preferredLanguage;
  final bool marketingOptIn;

  const GuestProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.countryCode,
    this.loyaltyNumber,
    this.loyaltyTier,
    this.preferences = const [],
    this.idType,
    this.idNumber,
    this.dateOfBirth,
    this.preferredLanguage,
    this.marketingOptIn = false,
  });

  factory GuestProfile.fromJson(Map<String, dynamic> json) => GuestProfile(
        id: json['id'] as String,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        countryCode: json['country_code'] as String?,
        loyaltyNumber: json['loyalty_number'] as String?,
        loyaltyTier: json['loyalty_tier'] as String?,
        preferences:
            (json['preferences'] as List<dynamic>?)?.cast<String>() ?? const [],
        idType: json['id_type'] as String?,
        idNumber: json['id_number'] as String?,
        dateOfBirth: json['date_of_birth'] != null
            ? DateTime.tryParse(json['date_of_birth'] as String)
            : null,
        preferredLanguage: json['preferred_language'] as String?,
        marketingOptIn: json['marketing_opt_in'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'country_code': countryCode,
        'loyalty_number': loyaltyNumber,
        'preferences': preferences,
        'id_type': idType,
        'id_number': idNumber,
        'preferred_language': preferredLanguage,
        'marketing_opt_in': marketingOptIn,
      };

  String get fullName => '$firstName $lastName';
}

// ═══════════════════════════════════════════════════════════════════════════
// Loyalty Info
// ═══════════════════════════════════════════════════════════════════════════

class LoyaltyInfo {
  final String memberId;
  final String tier;
  final int currentPoints;
  final int lifetimePoints;
  final int pointsToNextTier;
  final String? nextTier;
  final String currencyCode;

  const LoyaltyInfo({
    required this.memberId,
    required this.tier,
    this.currentPoints = 0,
    this.lifetimePoints = 0,
    this.pointsToNextTier = 0,
    this.nextTier,
    this.currencyCode = 'USD',
  });

  factory LoyaltyInfo.fromJson(Map<String, dynamic> json) => LoyaltyInfo(
        memberId: json['member_id'] as String? ?? json['id'] as String? ?? '',
        tier: json['tier'] as String? ?? 'Member',
        currentPoints: (json['current_points'] as num?)?.toInt() ?? 0,
        lifetimePoints: (json['lifetime_points'] as num?)?.toInt() ?? 0,
        pointsToNextTier: (json['points_to_next_tier'] as num?)?.toInt() ?? 0,
        nextTier: json['next_tier'] as String?,
        currencyCode: json['currency_code'] as String? ?? 'USD',
      );
}

class LoyaltyTransaction {
  final String id;
  final DateTime date;
  final String description;
  final int points; // positive = earned, negative = redeemed
  final String type; // earn, redeem

  const LoyaltyTransaction({
    required this.id,
    required this.date,
    required this.description,
    required this.points,
    this.type = 'earn',
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) =>
      LoyaltyTransaction(
        id: json['id'] as String,
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.now(),
        description: json['description'] as String? ?? '',
        points: (json['points'] as num?)?.toInt() ?? 0,
        type: json['type'] as String? ?? 'earn',
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Check-in / Check-out payloads
// ═══════════════════════════════════════════════════════════════════════════

class PreCheckInRequest {
  final String reservationId;
  final String? idType;
  final String? idNumber;
  final String? idImageUrl;
  final DateTime? estimatedArrivalTime;
  final String? specialRequests;
  final bool optInDigitalKey;

  const PreCheckInRequest({
    required this.reservationId,
    this.idType,
    this.idNumber,
    this.idImageUrl,
    this.estimatedArrivalTime,
    this.specialRequests,
    this.optInDigitalKey = false,
  });

  Map<String, dynamic> toJson() => {
        'reservation_id': reservationId,
        'id_type': idType,
        'id_number': idNumber,
        'id_image_url': idImageUrl,
        'estimated_arrival_time': estimatedArrivalTime?.toIso8601String(),
        'special_requests': specialRequests,
        'opt_in_digital_key': optInDigitalKey,
      };
}

class CheckInRequest {
  final String reservationId;
  final String? roomNumber;
  final bool activateDigitalKey;

  const CheckInRequest({
    required this.reservationId,
    this.roomNumber,
    this.activateDigitalKey = false,
  });

  Map<String, dynamic> toJson() => {
        'reservation_id': reservationId,
        'room_number': roomNumber,
        'activate_digital_key': activateDigitalKey,
      };
}

class CheckOutRequest {
  final String stayId;
  final String? paymentMethodToken;
  final bool emailReceipt;
  final String? email;

  const CheckOutRequest({
    required this.stayId,
    this.paymentMethodToken,
    this.emailReceipt = false,
    this.email,
  });

  Map<String, dynamic> toJson() => {
        'stay_id': stayId,
        'payment_method_token': paymentMethodToken,
        'email_receipt': emailReceipt,
        'email': email,
      };
}

class StayRating {
  final String stayId;
  final int overallScore; // 1–5
  final int? cleanlinessScore;
  final int? serviceScore;
  final int? locationScore;
  final String? comment;

  const StayRating({
    required this.stayId,
    required this.overallScore,
    this.cleanlinessScore,
    this.serviceScore,
    this.locationScore,
    this.comment,
  });

  Map<String, dynamic> toJson() => {
        'stay_id': stayId,
        'overall_score': overallScore,
        'cleanliness_score': cleanlinessScore,
        'service_score': serviceScore,
        'location_score': locationScore,
        'comment': comment,
      };
}

// ═══════════════════════════════════════════════════════════════════════════

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
// ═══════════════════════════════════════════════════════════════════════════
// Rewards catalog + redemption (Hotel8:Loyalty), room-service ordering
// (Hotel8:POS guest surface), saved payment methods (Hotel8:PMS).
// ═══════════════════════════════════════════════════════════════════════════

/// A redemption-catalog reward (loyalty rewards catalog screen).
class Reward {
  final String id;
  final String itemCode;
  final String name;
  final String? description;
  final int pointsCost;
  final String category;
  final String rewardType;
  final bool redeemable;

  const Reward({
    required this.id,
    required this.itemCode,
    required this.name,
    this.description,
    required this.pointsCost,
    required this.category,
    required this.rewardType,
    this.redeemable = false,
  });

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
        id: json['id'] as String,
        itemCode: json['item_code'] as String? ?? '',
        name: json['item_name'] as String? ?? json['name'] as String? ?? '',
        description: json['description'] as String?,
        pointsCost: (json['points_cost'] as num?)?.toInt() ?? 0,
        category: json['category'] as String? ?? 'GENERAL',
        rewardType: json['reward_type'] as String? ?? 'VOUCHER',
        redeemable: json['redeemable'] as bool? ?? false,
      );
}

/// A redemption outcome — a voucher code the guest can present at the desk.
class RewardRedemption {
  final String redemptionId;
  final String voucherCode;
  final String itemName;
  final int pointsSpent;
  final int remainingBalance;
  final DateTime? expiresAt;

  const RewardRedemption({
    required this.redemptionId,
    required this.voucherCode,
    required this.itemName,
    required this.pointsSpent,
    required this.remainingBalance,
    this.expiresAt,
  });

  factory RewardRedemption.fromJson(Map<String, dynamic> json) =>
      RewardRedemption(
        redemptionId: json['redemption_id'] as String? ?? '',
        voucherCode: json['voucher_code'] as String? ?? '',
        itemName: json['item_name'] as String? ?? '',
        pointsSpent: (json['points_spent'] as num?)?.toInt() ?? 0,
        remainingBalance: (json['remaining_balance'] as num?)?.toInt() ?? 0,
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      );
}

/// A saved payment method (bill8 token reference held by the guest profile).
class PaymentMethodInfo {
  final String id;
  final String label;
  final String paymentMethodId;
  final bool isDefault;

  const PaymentMethodInfo({
    required this.id,
    required this.label,
    required this.paymentMethodId,
    this.isDefault = false,
  });

  factory PaymentMethodInfo.fromJson(Map<String, dynamic> json) =>
      PaymentMethodInfo(
        id: json['id'] as String,
        label: json['label'] as String? ?? '',
        paymentMethodId: json['payment_method_id'] as String? ?? '',
        isDefault: json['is_default'] as bool? ?? false,
      );
}

/// Room-service menu line (Hotel8:POS guest menu).
class RoomServiceMenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;

  const RoomServiceMenuItem({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.category = '',
  });

  factory RoomServiceMenuItem.fromJson(Map<String, dynamic> json) =>
      RoomServiceMenuItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ??
            double.tryParse(json['price'] as String? ?? '') ??
            0.0,
        category: json['category'] as String? ?? '',
      );
}

/// A placed room-service order (check read-back with prep states).
class RoomServiceOrder {
  final String checkId;
  final String checkNumber;
  final String status;
  final String total;
  final List<RoomServiceOrderLine> lines;

  const RoomServiceOrder({
    required this.checkId,
    required this.checkNumber,
    required this.status,
    required this.total,
    required this.lines,
  });

  factory RoomServiceOrder.fromJson(Map<String, dynamic> json) =>
      RoomServiceOrder(
        checkId: json['check_id'] as String,
        checkNumber: json['check_number'] as String? ?? '',
        status: json['status'] as String? ?? 'OPEN',
        total: json['total'] as String? ?? '0',
        lines: ((json['items'] as List<dynamic>?) ?? const [])
            .map((e) =>
                RoomServiceOrderLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class RoomServiceOrderLine {
  final String name;
  final int quantity;
  final String lineTotal;
  final String status;

  const RoomServiceOrderLine({
    required this.name,
    required this.quantity,
    required this.lineTotal,
    required this.status,
  });

  factory RoomServiceOrderLine.fromJson(Map<String, dynamic> json) =>
      RoomServiceOrderLine(
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        lineTotal: json['line_total'] as String? ?? '0',
        status: json['status'] as String? ?? 'SENT',
      );
}
