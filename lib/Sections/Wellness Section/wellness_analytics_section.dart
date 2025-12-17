import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WellnessAnalyticsSection extends StatelessWidget {
  final bool isOwnProfile;
  final int views;
  final int bookings;

  const WellnessAnalyticsSection({
    Key? key,
    required this.isOwnProfile,
    required this.views,
    required this.bookings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isOwnProfile) return const SizedBox.shrink();

    Widget tile(String label, String value) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            tile('Profile Views', views.toString()),
            tile('Bookings', bookings.toString()),
          ],
        ),
      ),
    );
  }
}
