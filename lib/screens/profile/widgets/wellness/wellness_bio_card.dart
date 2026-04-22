import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WellnessBioCard extends StatelessWidget {
  final String bio;
  final bool isOwnProfile;
  final Color cardColor;
  final Color accentColor;
  final VoidCallback onEditBio;

  const WellnessBioCard({
    super.key,
    required this.bio,
    required this.isOwnProfile,
    required this.cardColor,
    required this.accentColor,
    required this.onEditBio,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                bio,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.black87,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isOwnProfile)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEditBio,
                  color: accentColor,
                  iconSize: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
