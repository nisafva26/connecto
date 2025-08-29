import 'dart:developer';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/feature/gatherings/data/acitivity_data.dart';
import 'package:connecto/feature/poll/controllers/poll_controller.dart';
import 'package:connecto/feature/poll/models/poll_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:connecto/helper/date_helper.dart' as date;

// ⬇️ bring your activity list, date helper, models, and provider
// import 'activity_list.dart';

// ^ contains pollControllerProvider with createPoll(...)

import 'package:intl/intl.dart';

String formatTime12(DateTime dt) =>
    DateFormat('h:mm a').format(dt); // e.g. 7:30 PM
String formatDateShort(DateTime dt) =>
    DateFormat('EEE, MMM d').format(dt); // e.g. Mon, Aug 26

final googleApiKey = dotenv.env['GOOGLE_API_KEY'];

class CreatePollCircleScreen extends ConsumerStatefulWidget {
  final String? circleId;
  final PlacesSearchResult? place; // optional prefilled location
  final String? initialActivity;

  const CreatePollCircleScreen({
    super.key,
    this.circleId,
    this.place,
    this.initialActivity,
  });

  @override
  ConsumerState<CreatePollCircleScreen> createState() =>
      _CreatePollCircleScreenState();
}

class _CreatePollCircleScreenState
    extends ConsumerState<CreatePollCircleScreen> {
  final _titleCtrl = TextEditingController(); // poll title (eg. "Padel Pro")
  final _activityCtrl = TextEditingController(); // if "Other"
  String? selectedActivity;

  // ── Poll close time (default +24h)
  DateTime closesAt = DateTime.now().add(const Duration(hours: 24));

  // ── Multi locations
  final List<_PollLocationVM> locations = []; // local VM for UI
  // ── Multi time slots
  final List<_PollTimeSlotVM> timeSlots = [];

  // figma activity grid
  final List<Map<String, dynamic>> activities =
      activityList; // you already have this

  @override
  void initState() {
    super.initState();
    selectedActivity = widget.initialActivity;
    if (widget.place != null) {
      _addLocationFromPlace(widget.place!);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _activityCtrl.dispose();
    super.dispose();
  }

  // ===== UI VMs =====

  String _id() => const Uuid().v4();

  void _addLocationFromPlace(PlacesSearchResult place) {
    final photoRef =
        place.photos.isNotEmpty ? place.photos.first.photoReference : '';
    final g = place.geometry;
    if (g == null) return;
    locations.add(_PollLocationVM(
      id: _id(),
      name: place.name,
      address: place.formattedAddress ?? '',
      lat: g.location.lat,
      lng: g.location.lng,
      photoRef: photoRef,
      placeId: place.placeId,
    ));
    setState(() {});
  }

  Future<void> _openLocationSelector() async {
    final result = await context.push<PlacesSearchResult>(
      '/gathering/select-location',
      extra: selectedActivity ?? '',
    );
    if (result != null) _addLocationFromPlace(result);
  }

  Future<void> _addTimeSlot() async {
    final now = DateTime.now().add(const Duration(minutes: 5));
    DateTime start = now;
    int durationMinutes = 60;

    await showCupertinoModalPopup(
      context: context,
      builder: (_) => _CupertinoTimeSlotPicker(
        initialStart: now,
        initialDurationMinutes: durationMinutes,
        onDone: (s, dur) {
          start = s;
          durationMinutes = dur;
        },
      ),
    );

    final end = start.add(Duration(minutes: durationMinutes));
    timeSlots.add(_PollTimeSlotVM(
      id: _id(),
      start: start,
      end: end,
      label:
          "${formatDateShort(start)} • ${formatTime12(start)} – ${formatTime12(end)}",
    ));
    setState(() {});
  }

  bool _isValid() {
    if ((_titleCtrl.text.trim()).isEmpty) return false;
    if (selectedActivity == null) return false;
    if (selectedActivity == "Other" && _activityCtrl.text.trim().isEmpty)
      return false;
    if (locations.isEmpty) return false;
    if (timeSlots.isEmpty) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_isValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all required fields")),
      );
      return;
    }

    final act = selectedActivity == "Other"
        ? _activityCtrl.text.trim()
        : selectedActivity!;
    final title = _titleCtrl.text.trim();
    final currentUser = ref.read(currentUserProvider).value;

    try {
      await ref.read(pollControllerProvider.notifier).createPoll(
          circleId: widget.circleId!,
          title: title,
          activity: act,
          locations: locations.map((e) => e.toPollLocation()).toList(),
          timeSlots: timeSlots.map((e) => e.toPollTimeSlot()).toList(),
          closesAt: closesAt,
          senderName: currentUser!.fullName);

      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      log("createPoll error: $e\n$st");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong creating poll")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pollState = ref.watch(pollControllerProvider);

    // react to one-off transitions (snackbars, navigation, etc.)
    ref.listen<AsyncValue<void>>(pollControllerProvider, (prev, next) {
      // error
      next.whenOrNull(
        error: (err, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err.toString())),
          );
          HapticFeedback.heavyImpact();
        },
      );

      // success (only when coming from loading)
      if (prev is AsyncLoading && next is AsyncData) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Poll created')),
        );
        HapticFeedback.lightImpact();
        // if (mounted) Navigator.pop(context); // go back to chat
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xff001311),
      appBar: AppBar(
        backgroundColor: const Color(0xff08201e),
        surfaceTintColor: const Color(0xff08201e),
        title: const Text("Create poll"),
        titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: "Inter",
            color: Color(0xffE6E7E9)),
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 20),

          // ===== Activity =====
          const Text("Activity",
              style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            itemCount: activities.length,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 182 / 104),
            itemBuilder: (context, index) {
              String activity = activities[index]['name'];
              bool isSelected = selectedActivity == activity;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedActivity = activity;
                    if (activity != "Other") _activityCtrl.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xff091F1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isSelected
                            ? const Color(0xFF03FFE2)
                            : Colors.transparent,
                        width: 2),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(activities[index]['icon'],
                            color: const Color(0xFF03FFE2)),
                        const SizedBox(height: 8),
                        Text(activity,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'SFPRO')),
                      ]),
                )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .scaleXY(begin: .95, end: 1)
                    .then(delay: Duration(milliseconds: index * 100)),
              );
            },
          ),
          if (selectedActivity == "Other")
            _LabeledField(
                header: "Activity type",
                hint: "Enter activity type",
                controller: _activityCtrl),

          const SizedBox(height: 12),
          _LabeledField(
              header: "Poll title",
              hint: "Eg. Padel Pro",
              controller: _titleCtrl),

          const SizedBox(height: 24),

          // ===== Locations (multi) =====
          const Text(
            'Select Locations',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              height: 1.43,
            ),
          ),
          const SizedBox(height: 10),
          _AddTile(
              label: "Add location",
              icon: Icons.add_location_alt,
              onTap: _openLocationSelector),
          const SizedBox(height: 12),
          if (locations.isNotEmpty) const SizedBox(height: 12),
          if (locations.isNotEmpty)
            Container(
                height: 300,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final loc = locations[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _LocationCard(
                        vm: loc,
                        onRemove: () {
                          setState(() {
                            locations.removeWhere((x) => x.id == loc.id);
                          });
                        },
                      ),
                    );
                  },
                )),

          const SizedBox(height: 24),

          // ===== Time Slots (multi) =====
          const Text(
            'Time options',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              height: 1.43,
            ),
          ),
          const SizedBox(height: 10),
          _AddTile(
              label: "Add time slots",
              icon: Icons.schedule,
              onTap: _addTimeSlot),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: timeSlots
                .map((t) => InputChip(
                      label: Text(t.label,
                          style: const TextStyle(color: Colors.white)),
                      backgroundColor: const Color(0xff0E3735),
                      onDeleted: () => setState(
                          () => timeSlots.removeWhere((x) => x.id == t.id)),
                      deleteIcon: const Icon(Icons.close,
                          size: 16, color: Colors.white70),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),

          const SizedBox(height: 24),

          // ===== Voting ends =====
          const Text('Voting ends',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xffF2F2F2),
                  fontFamily: "Inter")),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              await showCupertinoModalPopup(
                context: context,
                builder: (_) => _CupertinoDatePickerSheet(
                  initial: closesAt,
                  onDone: (dt) => setState(() => closesAt = dt),
                ),
              );
            },
            child: AbsorbPointer(
              child: TextField(
                controller: TextEditingController(
                    text:
                        "${formatDateShort(closesAt)}  -  ${formatTime12(closesAt)}"),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(const Icon(Icons.timer_outlined)),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ===== Submit =====
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF03FFE2),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: pollState.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Create poll  →"),
            ),
          ),

          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  InputDecoration _inputDecoration(Widget? suffix) {
    return InputDecoration(
      hintText: "",
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xff091F1E),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xff0E3735), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF03FFE2), width: 2),
      ),
      suffixIcon: suffix,
    );
  }
}

// ====== Small UI pieces ======

class _LabeledField extends StatelessWidget {
  final String header, hint;
  final TextEditingController controller;
  const _LabeledField(
      {required this.header, required this.hint, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        header,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          height: 1.43,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: const Color(0xff091F1E),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xff0E3735), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF03FFE2), width: 2),
          ),
        ),
      ),
    ]);
  }
}

class _AddTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _AddTile(
      {required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.sizeOf(context).width,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
            color: const Color(0xff091F1E),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Icon(icon, color: const Color(0xFF03FFE2)),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'SFPRO',
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final _PollLocationVM vm;
  final VoidCallback onRemove;
  const _LocationCard({required this.vm, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 320,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: const Color(0xff091F1E),
          borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          Column(children: [
            if (vm.photoRef.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12)),
                child: CachedNetworkImage(
                  height: 160,
                  width: MediaQuery.sizeOf(context).width,
                  fit: BoxFit.cover,
                  imageUrl:
                      'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${vm.photoRef}&key=$googleApiKey',
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // const Icon(Icons.location_on, color: Colors.white),
                // const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vm.name,
                          maxLines: 2,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'SFPRO',
                            fontWeight: FontWeight.w700,
                            height: 1.38,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(vm.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFFC4C4C4),
                                fontSize: 13,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.32)),
                      ]),
                ),
              ]),
            ),
          ]),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: onRemove),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final _PollTimeSlotVM vm;
  final VoidCallback onRemove;
  const _TimeChip({required this.vm, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(vm.label, style: const TextStyle(color: Colors.black)),
      backgroundColor: const Color(0xFF03FFE2),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ====== Pickers ======

class _CupertinoDatePickerSheet extends StatelessWidget {
  final DateTime initial;
  final ValueChanged<DateTime> onDone;
  const _CupertinoDatePickerSheet(
      {required this.initial, required this.onDone});

  @override
  Widget build(BuildContext context) {
    DateTime temp = initial;
    return Container(
      height: 400,
      decoration: const BoxDecoration(
        color: Color(0xFF091F1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(children: [
        SizedBox(
          height: 300,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.dateAndTime,
            initialDateTime: initial,
            minimumDate: DateTime.now(),
            maximumDate: DateTime(2100),
            use24hFormat: false,
            onDateTimeChanged: (d) => temp = d,
          ),
        ),
        CupertinoButton(
          child: const Text("Done", style: TextStyle(color: Color(0xFF03FFE2))),
          onPressed: () {
            Navigator.pop(context);
            onDone(temp);
          },
        )
      ]),
    );
  }
}

/* ---------- Pickers ---------- */

class _CupertinoTimeSlotPicker extends StatelessWidget {
  final DateTime initialStart;
  final int initialDurationMinutes;
  final void Function(DateTime start, int durationMins) onDone;
  final String title;
  final bool showDuration; // set false for "Voting ends"

  const _CupertinoTimeSlotPicker({
    required this.initialStart,
    required this.initialDurationMinutes,
    required this.onDone,
    this.title = "Pick start & duration",
    this.showDuration = true,
  });

  static const _durations = <int>[60, 75, 90, 105, 120];

  @override
  Widget build(BuildContext context) {
    DateTime start = initialStart.isAfter(DateTime.now())
        ? initialStart
        : DateTime.now().add(const Duration(minutes: 5));

    int duration = _durations.contains(initialDurationMinutes)
        ? initialDurationMinutes
        : 60;

    final initialIdx = _durations.indexOf(duration);

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF091F1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SizedBox(
          height: 380,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // const SizedBox(height: 12),
              // Text(
              //   title,
              //   style: const TextStyle(
              //     color: Colors.white,
              //     fontSize: 16,
              //     fontFamily: 'Inter',
              //     fontWeight: FontWeight.w600,
              //   ),
              // ),
              const SizedBox(height: 8),

              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: CupertinoDatePicker(
                        backgroundColor: const Color(0xFF091F1E),
                        mode: CupertinoDatePickerMode.dateAndTime,
                        initialDateTime: start,
                        minimumDate: DateTime.now(),
                        maximumDate: DateTime(2100),
                        use24hFormat: false,
                        onDateTimeChanged: (d) => start = d,
                      ),
                    ),
                    if (showDuration)
                      Expanded(
                        child: CupertinoPicker(
                          backgroundColor: const Color(0xFF091F1E),
                          itemExtent: 40,
                          scrollController: FixedExtentScrollController(
                            initialItem:
                                initialIdx.clamp(0, _durations.length - 1),
                          ),
                          onSelectedItemChanged: (i) =>
                              duration = _durations[i],
                          children: _durations
                              .map((m) => Text(
                                    '$m min',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 16),
                                  ))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              CupertinoButton(
                child: const Text("Done",
                    style: TextStyle(color: Color(0xFF03FFE2))),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                  onDone(start, showDuration ? duration : 0);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ====== Local VMs + mapping to your Poll models ======

class _PollLocationVM {
  final String id, name, address, photoRef, placeId;
  final double lat, lng;
  _PollLocationVM({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.photoRef,
    required this.placeId,
  });

  // adapt to your PollLocation model from previous message
  PollLocation toPollLocation() => PollLocation(
        id: id,
        name: name,
        address: address,
        img: photoRef,
        lat: lat,
        lng: lng,
      );
}

class _PollTimeSlotVM {
  final String id, label;
  final DateTime start, end;
  _PollTimeSlotVM(
      {required this.id,
      required this.start,
      required this.end,
      required this.label});

  PollTimeSlot toPollTimeSlot() =>
      PollTimeSlot(id: id, label: label, start: start, end: end);
}
