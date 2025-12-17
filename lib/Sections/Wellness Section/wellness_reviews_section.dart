import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WellnessReviewsSection extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;

  const WellnessReviewsSection({
    Key? key,
    required this.reviews,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reviews',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...reviews.take(3).map((r) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r['name'] ?? 'User',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(
                      5,
                          (i) => Icon(
                        i < (r['rating'] ?? 5)
                            ? Icons.star
                            : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r['text'] ?? '',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
