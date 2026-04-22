import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AspirantBioCard extends StatelessWidget {
  final String bio;
  final bool isOwnProfile;

  const AspirantBioCard({
    super.key,
    required this.bio,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    final displayBio = bio.isNotEmpty
        ? bio
        : (isOwnProfile
            ? 'Add a short bio — tell people what you love (cricket, dance, yoga, etc.).'
            : '');
    if (displayBio.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Text(
          displayBio,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.4),
        ),
      ),
    );
  }
}
