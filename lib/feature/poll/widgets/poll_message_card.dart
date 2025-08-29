import 'package:connecto/feature/discover/screens/select_location_discover.dart';
import 'package:connecto/feature/poll/widgets/poll_option_card.dart';
import 'package:connecto/feature/poll/widgets/time_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:connecto/feature/poll/controllers/poll_controller.dart';
import 'package:connecto/feature/poll/models/poll_model.dart';

class PollMessageCard extends ConsumerWidget {
  final String circleId;
  final String pollId;
  final bool isMine; // aligns timestamp like your other cards
  final String? headerText; // message.text (optional title)

  const PollMessageCard({
    super.key,
    required this.circleId,
    required this.pollId,
    required this.isMine,
    this.headerText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final pollAsync =
        ref.watch(pollProvider((circleId: circleId, pollId: pollId)));
    final myVoteAsync = ref
        .watch(myVoteProvider((circleId: circleId, pollId: pollId, uid: uid)));

    return pollAsync.when(
      loading: () => _Skeleton(isMine: isMine),
      error: (_, __) => _ErrorTile(isMine: isMine),
      data: (poll) {
        final isClosed = !poll.isOpen;
        final myVote = myVoteAsync.asData?.value;

        final maxTimeVotes = poll.countTime.values.isEmpty
            ? 0.0
            : poll.countTime.values
                .map((v) => v.toDouble())
                .reduce((a, b) => a > b ? a : b);

        final maxTime = poll.countTime.values.isEmpty
            ? 0
            : poll.countTime.values.reduce((a, b) => a > b ? a : b);

        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 10,
                ),
                Container(
                  width: MediaQuery.sizeOf(context).width,
                  padding: const EdgeInsets.all(12).copyWith(right: 0),
                  decoration: BoxDecoration(
                    color: isMine
                        ? const Color(0xff0F4A48)
                        : const Color(0xff0F4A48),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (headerText != null && headerText!.isNotEmpty) ...[
                        Text(headerText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            )),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        children: [
                          const Icon(Icons.poll,
                              size: 18, color: Colors.white70),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              poll.activity.isNotEmpty ? poll.activity : 'Poll',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _StatusPill(isClosed: isClosed),
                          const SizedBox(width: 12),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (!isClosed) ...[
                        _SectionTitle('Location'),
                        const SizedBox(height: 6),
                        // _LocationOptions(
                        //   poll: poll,
                        //   selectedId: myVote?.locationId,
                        //   onSelect: (id) {
                        //     final chosenTime =
                        //         myVote?.timeSlotId ?? poll.timeSlots.first.id;
                        //     ref.read(pollControllerProvider.notifier).vote(
                        //           circleId: circleId,
                        //           pollId: poll.id,
                        //           locationId: id,
                        //           timeSlotId: chosenTime,
                        //         );
                        //   },
                        // ),
                        // horizontally scrollable cards like the Figma
                        SizedBox(
                          height: 350,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: poll.locations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) {
                              final loc = poll.locations[i];
                              final votes = poll.countLocation[loc.id] ?? 0;
                              final selected = (myVote?.locationId == loc.id);
                              final imgUrl = loc.img.isNotEmpty
                                  ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${loc.img}&key=$googleApiKey'
                                  : '';

                              return PollOptionCard(
                                title: loc.name,
                                subtitle: loc.address,
                                imageUrl: imgUrl,
                                rating:
                                    null, // plug your rating source if you have it
                                voteCount: votes,
                                selected: selected,
                                onDetails: () {
                                  /* open place details bottom sheet */
                                },
                                onVote: () {
                                  final chosenTime = myVote?.timeSlotId ??
                                      poll.timeSlots.first.id;
                                  ref
                                      .read(pollControllerProvider.notifier)
                                      .vote(
                                        circleId: circleId,
                                        pollId: poll.id,
                                        locationId: loc.id,
                                        timeSlotId: chosenTime,
                                      );
                                },
                              );
                            },
                          ),
                        ),

                        // const SizedBox(height: 10),
                        // _SectionTitle('Time'),
                        // const SizedBox(height: 6),
                        // _TimeOptions(
                        //   poll: poll,
                        //   selectedId: myVote?.timeSlotId,
                        //   onSelect: (id) {
                        //     final chosenLoc =
                        //         myVote?.locationId ?? poll.locations.first.id;
                        //     ref.read(pollControllerProvider.notifier).vote(
                        //           circleId: circleId,
                        //           pollId: poll.id,
                        //           locationId: chosenLoc,
                        //           timeSlotId: id,
                        //         );
                        //   },
                        // ),

                        const SizedBox(height: 10),
                        _SectionTitle('When?'),
                        const SizedBox(height: 6),

                        SizedBox(
                          height: 170,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: poll.timeSlots.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) {
                              final t = poll.timeSlots[i];
                              final votes =
                                  (poll.countTime[t.id] ?? 0).toDouble();
                              final selected = myVote?.timeSlotId == t.id;
                              final ratio = (maxTimeVotes == 0.0)
                                  ? 0.0
                                  : votes / maxTimeVotes;

                              return TimeOptionCard(
                                start: t.start,
                                end: t.end,
                                selected: selected,
                                voteCount:
                                    votes.toInt(), // 👈 keep the label as int
                                ratio: ratio, // 👈 now always double
                                disabled: !poll.isOpen,
                                onVote: () {
                                  final chosenLoc = myVote?.locationId ??
                                      poll.locations.first.id;
                                  ref
                                      .read(pollControllerProvider.notifier)
                                      .vote(
                                        circleId: circleId,
                                        pollId: poll.id,
                                        locationId: chosenLoc,
                                        timeSlotId: t.id,
                                      );
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: MiniBarsWhatsApp(
                            counts: poll.countLocation,
                            labels: {
                              for (final l in poll.locations) l.id: l.name
                            },
                            showPercent: false, // toggle as you like
                            sortByCountDesc: true,
                          ),
                        ),
                        // NEW: time bars
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: MiniBarsWhatsApp(
                            counts: poll.countTime,
                            labels: {
                              for (final t in poll.timeSlots)
                                t.id: "${DateFormat('EEE, MMM d').format(t.start)} • "
                                    "${DateFormat('h:mm a').format(t.start)} – ${DateFormat('h:mm a').format(t.end)}"
                            },
                            showPercent: false, // toggle as you like
                            sortByCountDesc: true,
                          ),
                        ),
                        // PollResultCard(
                        //   locations: poll.locations.map((l) {
                        //     final votes = poll.countLocation[l.id] ?? 0;
                        //     // optional images: convert place photoRef -> full URL if you have it
                        //     final logoUrl = (l.img.isNotEmpty)
                        //         ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=200&photoreference=${l.img}&key=$googleApiKey'
                        //         : null;

                        //     // optional avatars list per location if you track who voted-where
                        //     return ResultBarItem(
                        //       label: l.name,
                        //       count: votes,
                        //       logoUrl: logoUrl,
                        //        // supply if you have
                        //     );
                        //   }).toList(),
                        //   times: poll.timeSlots.map((t) {
                        //     final c = poll.countTime[t.id] ?? 0;
                        //     return ResultTimeItem(
                        //       start: t.start,
                        //       end: t.end,
                        //       count: c,
                        //       maxCount: maxTime,
                        //     );
                        //   }).toList(),
                        //   onCreateFromWinner: true
                        //       ? () {/* navigate to create event with winner */}
                        //       : null,
                        // ),
                        const SizedBox(height: 6),
                        Text(
                          myVote == null ? 'Tap options to vote' : 'You voted',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                      if (true) ...[
                        _SectionTitle('Results'),
                        const SizedBox(height: 8),
                        _Winners(
                          poll: poll,
                        ),
                        const SizedBox(height: 10),
                        if (poll.createdBy == uid)
                          _PrimaryButton(
                            text: 'Create event from winner',
                            onTap: () {
                              // Navigate to your create-event screen with prefill extras
                              // Replace with your route + prefill object
                              context.push('/gathering/create-gathering-circle',
                                  extra: {
                                    'circleId': circleId,
                                    'prefillFromPoll': {
                                      'pollId': poll.id,
                                      'title': poll.title,
                                      'activity': poll.activity,
                                      'locationId': poll.winnerLocationId,
                                      'timeSlotId': poll.winnerTimeSlotId,
                                    },
                                  });
                            },
                          ),
                      ],
                    ],
                  ),
                ),
                // timestamp is shown by parent; keep consistent if you show here
              ],
            ),
          ),
        );
      },
    );
  }
}

/* ───────── small pieces ───────── */

class _Skeleton extends StatelessWidget {
  final bool isMine;
  const _Skeleton({required this.isMine});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.82,
        height: 120,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xff0E1B1A),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final bool isMine;
  const _ErrorTile({required this.isMine});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        width: MediaQuery.sizeOf(context).width * 0.82,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Failed to load poll',
            style: TextStyle(color: Colors.redAccent)),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isClosed;
  const _StatusPill({required this.isClosed});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isClosed
            ? Colors.grey.withOpacity(.2)
            : const Color(0xFF03FFE2).withOpacity(.18),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
            color: isClosed ? Colors.grey : const Color(0xFF03FFE2), width: 1),
      ),
      child: Text(
        isClosed ? 'Closed' : 'Open',
        style: TextStyle(
          color: isClosed ? Colors.grey[300] : const Color(0xFF03FFE2),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ));
  }
}

class _LocationOptions extends StatelessWidget {
  final Poll poll;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  const _LocationOptions({
    required this.poll,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: poll.locations.map((l) {
        final selected = selectedId == l.id;
        return ChoiceChip(
          label: Text(l.name,
              style: TextStyle(color: selected ? Colors.black : Colors.white)),
          selected: selected,
          selectedColor: const Color(0xFF03FFE2),
          backgroundColor: const Color(0xff0E3735),
          onSelected: (_) => onSelect(l.id),
        );
      }).toList(),
    );
  }
}

class _TimeOptions extends StatelessWidget {
  final Poll poll;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  const _TimeOptions({
    required this.poll,
    required this.selectedId,
    required this.onSelect,
  });

  String _fmt(DateTime d) => DateFormat('h:mm a').format(d); // 12h
  String _short(DateTime d) => DateFormat('EEE, MMM d').format(d);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: poll.timeSlots.map((t) {
        final selected = selectedId == t.id;
        final label = "${_short(t.start)} • ${_fmt(t.start)} – ${_fmt(t.end)}";
        return ChoiceChip(
          label: Text(label,
              style: TextStyle(color: selected ? Colors.black : Colors.white),
              overflow: TextOverflow.ellipsis),
          selected: selected,
          selectedColor: const Color(0xFF03FFE2),
          backgroundColor: const Color(0xff0E3735),
          onSelected: (_) => onSelect(t.id),
        );
      }).toList(),
    );
  }
}

class MiniBarsWhatsApp extends StatelessWidget {
  final Map<String, int> counts; // id -> votes
  final Map<String, String> labels; // id -> label
  final bool sortByCountDesc; // winner first like WhatsApp
  final bool showPercent; // show "42%" next to count
  final double zeroBaseFrac; // small baseline for 0-vote bars

  const MiniBarsWhatsApp({
    super.key,
    required this.counts,
    required this.labels,
    this.sortByCountDesc = true,
    this.showPercent = false,
    this.zeroBaseFrac = 0.10, // 10% baseline for 0 votes
  });

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return const SizedBox.shrink();

    // total used for percentage-based bars (WhatsApp style)
    final int total = counts.values.fold<int>(0, (a, b) => a + b);
    // still handle all-zero gracefully
    final double denom = (total == 0) ? 1.0 : total.toDouble();

    // order
    final entries = counts.entries.toList();
    if (sortByCountDesc) {
      entries.sort((a, b) => b.value.compareTo(a.value));
    }

    const trackColor = Colors.white10;
    const fillColor = Color(0xFF03FFE2);

    return Column(
      children: entries.map((e) {
        final id = e.key;
        final votes = e.value;
        final label = labels[id] ?? '';
        final pct = (votes / denom); // 0..1
        final widthFactor = pct == 0
            ? zeroBaseFrac // tiny base for 0
            : pct.clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: label + trailing count (and optional %)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    showPercent
                        ? "$votes  (${(pct * 100).round()}%)"
                        : "$votes",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Bar row: full-width track + proportional fill
              Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: widthFactor,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MiniBars extends StatelessWidget {
  final Map<String, int> counts;
  final Map<String, String> labels;
  const _MiniBars({required this.counts, required this.labels});

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return const SizedBox.shrink();
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final maxVal = counts.values.fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: counts.entries.map((e) {
        final ratio = maxVal == 0 ? 0.0 : (e.value / maxVal);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                        height: 6,
                        decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(
                      widthFactor: ratio.clamp(0.0, 1.0),
                      child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                              color: const Color(0xFF03FFE2),
                              borderRadius: BorderRadius.circular(4))),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text("${labels[e.key] ?? ''} (${e.value})",
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Winners extends StatelessWidget {
  final Poll poll;
  const _Winners({required this.poll});

  @override
  Widget build(BuildContext context) {
    final locName = poll.locations
        .firstWhere(
          (l) => l.id == poll.winnerLocationId,
          orElse: () => poll.locations.isNotEmpty
              ? poll.locations.first
              : PollLocation(
                  id: '-', name: '-', address: '', img: '', lat: 0, lng: 0),
        )
        .name;

    final time = poll.timeSlots.firstWhere(
      (t) => t.id == poll.winnerTimeSlotId,
      orElse: () => poll.timeSlots.first,
    );
    final fmt = DateFormat('h:mm a');
    final short = DateFormat('EEE, MMM d');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WinnerRow('Location', locName),
        const SizedBox(height: 6),
        _WinnerRow('Time',
            "${short.format(time.start)} • ${fmt.format(time.start)} – ${fmt.format(time.end)}"),
      ],
    );
  }
}

class _WinnerRow extends StatelessWidget {
  final String label, value;
  const _WinnerRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.verified, color: Color(0xFF03FFE2), size: 18),
        const SizedBox(width: 6),
        Text("$label: ", style: const TextStyle(color: Colors.white70)),
        Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _PrimaryButton({required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF03FFE2),
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text),
      ),
    );
  }
}
