// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EGuest
// SPDX-License-Identifier: Apache-2.0

/// Mobile Check-In.
///
/// Multi-step check-in: verify identity → upload ID document → select room
/// → activate digital key. Shows reservation summary and estimated arrival
/// time.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';
import 'digital_key_page.dart';

class MobileCheckInPage extends StatefulWidget {
  const MobileCheckInPage({
    super.key,
    required this.client,
    required this.stay,
  });

  final BffClient client;
  final StayInfo stay;

  @override
  State<MobileCheckInPage> createState() => _MobileCheckInPageState();
}

class _MobileCheckInPageState extends State<MobileCheckInPage> {
  late final List<_CheckInStep> _steps;
  int _currentStep = 0;
  bool _loading = false;

  final _idTypeController = TextEditingController();
  final _idNumberController = TextEditingController();
  String? _idImageUrl;
  DateTime? _estimatedArrival;
  String? _selectedRoom;
  bool _optInDigitalKey = false;

  @override
  void initState() {
    super.initState();
    _steps = _buildSteps();
  }

  List<_CheckInStep> _buildSteps() => [
        _CheckInStep(
          title: 'Verify Identity',
          icon: Icons.badge,
        ),
        _CheckInStep(
          title: 'Upload ID',
          icon: Icons.document_scanner,
        ),
        _CheckInStep(
          title: 'Select Room',
          icon: Icons.meeting_room,
        ),
        _CheckInStep(
          title: 'Digital Key',
          icon: Icons.key,
        ),
      ];

  @override
  void dispose() {
    _idTypeController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  bool get _isLast => _currentStep == _steps.length - 1;

  void _next() {
    if (_isLast) return;
    setState(() => _currentStep++);
  }

  void _prev() {
    if (_currentStep == 0) return;
    setState(() => _currentStep--);
  }

  Future<void> _completeCheckIn() async {
    setState(() => _loading = true);
    try {
      // Pre-check-in with identity data
      await widget.client.preCheckIn(PreCheckInRequest(
        reservationId: widget.stay.id,
        idType: _idTypeController.text.trim().isEmpty
            ? null
            : _idTypeController.text.trim(),
        idNumber: _idNumberController.text.trim().isEmpty
            ? null
            : _idNumberController.text.trim(),
        idImageUrl: _idImageUrl,
        estimatedArrivalTime: _estimatedArrival,
        optInDigitalKey: _optInDigitalKey,
      ));

      // Full check-in
      await widget.client.checkIn(CheckInRequest(
        reservationId: widget.stay.id,
        roomNumber: _selectedRoom,
        activateDigitalKey: _optInDigitalKey,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in complete! Welcome 🎉')),
        );
        if (_optInDigitalKey) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DigitalKeyPage(
                client: widget.client,
                stay: widget.stay.copyWith(roomNumber: _selectedRoom),
              ),
            ),
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } on BffException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-in failed: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mobile Check-In')),
      body: Column(
        children: [
          // Stepper indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: List.generate(_steps.length, (i) {
                final isActive = i == _currentStep;
                final isDone = i < _currentStep;
                return Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isDone
                            ? Colors.green
                            : isActive
                                ? theme.colorScheme.primary
                                : Colors.grey.shade300,
                        child: isDone
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? theme.colorScheme.onPrimary
                                      : Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      if (i < _steps.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            color: i < _currentStep
                                ? Colors.green
                                : Colors.grey.shade300,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
          // Reservation summary card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.hotel, color: Colors.blue),
                title: Text(widget.stay.propertyName),
                subtitle: Text(
                  '${widget.stay.confirmationNumber} • '
                  '${DateFormat('MMM d').format(widget.stay.arrivalDate)} – '
                  '${DateFormat('MMM d').format(widget.stay.departureDate)} • '
                  '${widget.stay.roomTypeName}',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Step content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepContent(),
            ),
          ),
          // Navigation buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _prev,
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (_isLast)
                    FilledButton.icon(
                      onPressed: _loading ? null : _completeCheckIn,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(_loading ? 'Processing...' : 'Complete Check-In'),
                    )
                  else
                    FilledButton(
                      onPressed: _next,
                      child: const Text('Continue'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _StepIdentity(
          idTypeController: _idTypeController,
          idNumberController: _idNumberController,
          estimatedArrival: _estimatedArrival,
          onPickArrival: _pickArrival,
        );
      case 1:
        return _StepUploadId(
          idImageUrl: _idImageUrl,
          onUpload: (url) => setState(() => _idImageUrl = url),
        );
      case 2:
        return _StepSelectRoom(
          stay: widget.stay,
          selectedRoom: _selectedRoom,
          onSelected: (room) => setState(() => _selectedRoom = room),
        );
      case 3:
        return _StepDigitalKey(
          optIn: _optInDigitalKey,
          onToggle: (v) => setState(() => _optInDigitalKey = v),
          roomNumber: _selectedRoom,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _pickArrival() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _estimatedArrival ?? DateTime.now().add(const Duration(hours: 2))),
    );
    if (time == null) return;
    final now = DateTime.now();
    setState(() {
      _estimatedArrival = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Step widgets
// ═══════════════════════════════════════════════════════════════════════════

class _CheckInStep {
  const _CheckInStep({required this.title, required this.icon});
  final String title;
  final IconData icon;
}

class _StepIdentity extends StatelessWidget {
  const _StepIdentity({
    required this.idTypeController,
    required this.idNumberController,
    required this.estimatedArrival,
    required this.onPickArrival,
  });

  final TextEditingController idTypeController;
  final TextEditingController idNumberController;
  final DateTime? estimatedArrival;
  final VoidCallback onPickArrival;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verify Your Identity',
            style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Enter your identification details to complete the registration card.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        DropdownMenu<String>(
          controller: idTypeController,
          expandedInsets: const EdgeInsets.all(0),
          label: const Text('ID Type'),
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: 'passport', label: 'Passport'),
            DropdownMenuEntry(value: 'drivers_license', label: 'Driver License'),
            DropdownMenuEntry(value: 'national_id', label: 'National ID'),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: idNumberController,
          decoration: const InputDecoration(
            labelText: 'ID Number',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.badge),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule, color: Colors.blue),
            title: const Text('Estimated Arrival Time'),
            subtitle: Text(
              estimatedArrival != null
                  ? DateFormat('h:mm a').format(estimatedArrival!)
                  : 'Not set',
            ),
            trailing: FilledButton.tonal(
              onPressed: onPickArrival,
              child: const Text('Set Time'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepUploadId extends StatelessWidget {
  const _StepUploadId({required this.idImageUrl, required this.onUpload});
  final String? idImageUrl;
  final ValueChanged<String?> onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload ID Document',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Take a photo of your ID document. This is required for hotel registration.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {
            // In production, this would open the camera / picker and
            // upload to Buck, returning a URL. For now we simulate.
            onUpload('mock://id-document-uploaded');
          },
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  idImageUrl != null ? Icons.check_circle : Icons.document_scanner,
                  size: 64,
                  color: idImageUrl != null ? Colors.green : Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  idImageUrl != null ? 'ID Uploaded' : 'Tap to upload',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepSelectRoom extends StatelessWidget {
  const _StepSelectRoom({
    required this.stay,
    required this.selectedRoom,
    required this.onSelected,
  });
  final StayInfo stay;
  final String? selectedRoom;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Simulated available rooms matching the booked room type.
    final rooms = <_RoomOption>[
      _RoomOption('201', '2nd Floor', 'Ocean view, King bed'),
      _RoomOption('205', '2nd Floor', 'City view, King bed'),
      _RoomOption('301', '3rd Floor', 'Ocean view, King bed, Balcony'),
      _RoomOption('402', '4th Floor', 'Quiet side, King bed'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Your Room', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Choose from available ${stay.roomTypeName} rooms. '
          'Your selection will be assigned for your stay.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        ...rooms.map((room) {
          final isSelected = selectedRoom == room.number;
          return Card(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
            child: RadioListTile<String?>(
              value: room.number,
              groupValue: selectedRoom,
              onChanged: onSelected,
              title: Text('Room ${room.number}'),
              subtitle: Text('${room.floor} • ${room.description}'),
              secondary: Icon(
                Icons.meeting_room,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
            ),
          );
        }),
        if (stay.roomNumber != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blue),
              title: const Text('Pre-Assigned Room'),
              subtitle: Text(
                  'Your room ${stay.roomNumber} has been pre-assigned. '
                  'You can keep it or choose another above.'),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepDigitalKey extends StatelessWidget {
  const _StepDigitalKey({
    required this.optIn,
    required this.onToggle,
    required this.roomNumber,
  });
  final bool optIn;
  final ValueChanged<bool> onToggle;
  final String? roomNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Digital Key', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        Card(
          child: SwitchListTile(
            value: optIn,
            onChanged: onToggle,
            secondary:
                Icon(Icons.nfc, color: optIn ? Colors.green : Colors.grey),
            title: const Text('Activate Digital Key'),
            subtitle: Text(
              optIn
                  ? 'Your phone will work as a room key via Bluetooth/NFC.'
                  : 'Skip and collect a physical key at the front desk.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (optIn && roomNumber != null)
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.key, color: Colors.green, size: 48),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Room $roomNumber',
                            style: theme.textTheme.titleMedium),
                        const Text(
                            'Digital key will be activated after check-in. '
                            'You can unlock your room with your phone.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!optIn)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No digital key selected. You can activate it later from the '
              'Digital Key screen if your property supports it.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }
}

class _RoomOption {
  const _RoomOption(this.number, this.floor, this.description);
  final String number;
  final String floor;
  final String description;
}

// ═══════════════════════════════════════════════════════════════════════════
// copyWith extension for StayInfo
// ═══════════════════════════════════════════════════════════════════════════

extension StayInfoCopy on StayInfo {
  StayInfo copyWith({
    String? roomNumber,
    String? floorNumber,
    StayStatus? status,
  }) =>
      StayInfo(
        id: id,
        confirmationNumber: confirmationNumber,
        propertyCode: propertyCode,
        propertyName: propertyName,
        propertyAddress: propertyAddress,
        propertyPhone: propertyPhone,
        arrivalDate: arrivalDate,
        departureDate: departureDate,
        numberOfNights: numberOfNights,
        numberOfGuests: numberOfGuests,
        numberOfRooms: numberOfRooms,
        roomTypeCode: roomTypeCode,
        roomTypeName: roomTypeName,
        roomNumber: roomNumber ?? this.roomNumber,
        floorNumber: floorNumber ?? this.floorNumber,
        ratePlanName: ratePlanName,
        rateAmount: rateAmount,
        currencyCode: currencyCode,
        status: status ?? this.status,
        guestId: guestId,
        guestName: guestName,
        specialRequests: specialRequests,
        digitalKeyEligible: digitalKeyEligible,
      );
}