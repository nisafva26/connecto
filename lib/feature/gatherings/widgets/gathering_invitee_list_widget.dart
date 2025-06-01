import 'package:connecto/feature/gatherings/models/gathering_model.dart';
import 'package:connecto/feature/gatherings/widgets/travel_status.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:flutter/material.dart';

class GatheringInviteeLsitWidget extends StatelessWidget {
  const GatheringInviteeLsitWidget(
      {super.key,
      required this.inviteeEntries,
      required this.inviteeETAs,
      required this.travelStatuses,
      required this.currentUserId,
      required this.gathering});

  final List<MapEntry<String, InviteeModel>> inviteeEntries;
  final Map<String, int> inviteeETAs;
  final Map<String, TravelStatus?> travelStatuses;
  final String currentUserId;
  final GatheringModel gathering;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(), // let parent scroll
      itemCount: inviteeEntries.length,
      separatorBuilder: (context, index) => Divider(
        color: Color(0xff2b3c3a),
        thickness: 0.5,
        height: 20,
      ),
      itemBuilder: (context, index) {
        final entry = inviteeEntries[index];
        final userId = entry.key;
        final invitee = entry.value;

        final eta = inviteeETAs[userId];

        final TravelStatus? travelStatusUser = travelStatuses[userId];

        String label = invitee.name;
        if (userId == currentUserId) {
          label += ' (You)';
        }

        return Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Text(
                getInitials(invitee.name),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                invitee.host
                    ? Text(
                        'Organiser',
                        style: TextStyle(
                          color: const Color(0xFF58616A),
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      )
                    : Text(
                        invitee.status == 'pending'
                            ? 'Request sent'
                            : 'Accepted',
                        style: TextStyle(
                          color: const Color(0xFF58616A),
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
              ],
            ),
            Spacer(),
            if (gathering.status != 'ended')
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (travelStatusUser != null)
                    Text(
                      travelStatusUser.label,
                      style: TextStyle(
                        color: travelStatusUser.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  if (eta != null) SizedBox(height: 4),
                  if (eta != null)
                    Text(
                      '$eta mins away',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontFamily: 'Inter'),
                    ),
                ],
              )
            // if (eta != null) ...[
            //   const SizedBox(width: 12),
            //   Icon(Icons.directions_walk,
            //       size: 14, color: Colors.grey),
            //   Text(
            //     "$eta min",
            //     style: TextStyle(
            //       color: Colors.grey,
            //       fontSize: 12,
            //       fontFamily: 'Inter',
            //     ),
            //   )
            // ]
          ],
        );
      },
    );
  }
}
