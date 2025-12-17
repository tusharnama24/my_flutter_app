import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WellnessServicesSection extends StatelessWidget {
  final bool isOwnProfile;
  final List<Map<String, dynamic>> services;
  final VoidCallback? onEdit;

  const WellnessServicesSection({
    Key? key,
    required this.isOwnProfile,
    required this.services,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty && !isOwnProfile) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Services',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (services.isEmpty)
            Text(
              'Add your services to attract users',
              style: GoogleFonts.poppins(color: Colors.grey),
            )
          else
            ...services.map((s) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['title'] ?? 'Service',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s['duration'] ?? '',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      s['price'] ?? '',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                      ),
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
