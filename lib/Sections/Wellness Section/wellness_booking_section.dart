import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WellnessBookingSection extends StatelessWidget {
  final bool isOwnProfile;
  final List<Map<String, dynamic>> slots;
  final VoidCallback? onEdit;
  final VoidCallback? onBook;

  const WellnessBookingSection({
    Key? key,
    required this.isOwnProfile,
    required this.slots,
    this.onEdit,
    this.onBook,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty && !isOwnProfile) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.deepPurple,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Book Appointment',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isOwnProfile)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: onEdit,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (slots.isEmpty)
              Text(
                'No slots available',
                style: GoogleFonts.poppins(color: Colors.white70),
              )
            else
              ...slots.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s['day'] ?? '',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                      Text(
                        s['time'] ?? '',
                        style: GoogleFonts.poppins(color: Colors.white70),
                      ),
                    ],
                  ),
                );
              }).toList(),
            if (!isOwnProfile) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple,
                  ),
                  child: const Text('Book Now'),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
