import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PollOptionCard extends StatelessWidget {
  final String title; // e.g., "Butchershop.ae"
  final String subtitle; // address/area
  final String imageUrl; // photoRef -> full URL
  final double? rating; // optional, show if present
  final int voteCount; // current votes for this option
  final bool selected; // show selected state
  final VoidCallback onDetails; // "Details" tap
  final VoidCallback onVote; // "Vote" tap

  const PollOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.rating,
    this.voteCount = 0,
    this.selected = false,
    required this.onDetails,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF091F1E); // card bg
    final border = const Color(0xff0E3735); // subtle border
    final accent = const Color(0xFF03FFE2);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        // border: Border.all(color: border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           ClipRRect(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12),topRight:Radius.circular(12)),
             child: Container(
              height: 160,
              width: double.infinity,
               child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.black12),
                ),
             ),
           ),
          // Container(
          //   decoration: BoxDecoration(
          //     image: DecorationImage(image: CachedNetworkImageProvider())
          //   ),
            
            
          // ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFC4C4C4), fontSize: 12, height: 1.25)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (rating != null) ...[
                      const Icon(Icons.star, size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        rating!.toStringAsFixed(1),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Icon(Icons.how_to_vote,
                        size: 16, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text("$voteCount Votes",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDetails,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: accent),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          "Details",
                          style: TextStyle(color: accent),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onVote,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selected ? Colors.white : accent,
                          foregroundColor:
                              selected ? Colors.black : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(selected ? "Voted" : "Vote"),
                      ),
                    ),
                  ],
                ),
                // const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
