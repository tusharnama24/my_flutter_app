import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GuruIdentityBlock extends StatelessWidget {
  final Widget avatar;
  final String profileUserId;
  final String fullName;
  final String username;
  final String primaryCategory;
  final String city;
  final int? experienceYears;
  final List<String> languages;
  final String trainingStyle;
  final double rating;
  final int reviewCount;

  const GuruIdentityBlock({
    super.key,
    required this.avatar,
    required this.profileUserId,
    required this.fullName,
    required this.username,
    required this.primaryCategory,
    required this.city,
    required this.experienceYears,
    required this.languages,
    required this.trainingStyle,
    required this.rating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    final title = fullName.isNotEmpty ? fullName : (username.isNotEmpty ? '@$username' : 'Guru');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(offset: const Offset(0, -40), child: avatar),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _OnlineDot(profileUserId: profileUserId),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    username.isNotEmpty ? '@$username' : '',
                    style: GoogleFonts.poppins(color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  if (primaryCategory.isNotEmpty)
                    Text(
                      primaryCategory,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (city.isNotEmpty) ...[
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.black87),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            city,
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (experienceYears != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.school_outlined, size: 14, color: Colors.black87),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${experienceYears}+ yrs exp',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (languages.isNotEmpty)
                    Text(
                      'Languages: ${languages.join(', ')}',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (trainingStyle.isNotEmpty)
                    Text(
                      'Training style: $trainingStyle',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber[700], size: 18),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($reviewCount reviews)',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  final String profileUserId;
  const _OnlineDot({required this.profileUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(profileUserId).snapshots(),
      builder: (context, snapshot) {
        var isOnline = false;
        final data = snapshot.data?.data();
        if (data?['isOnline'] == true) {
          isOnline = true;
        } else if (data?['lastSeen'] != null) {
          final lastSeen = (data?['lastSeen'] as Timestamp?)?.toDate();
          if (lastSeen != null) {
            isOnline = DateTime.now().difference(lastSeen).inMinutes < 2;
          }
        }
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isOnline ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      },
    );
  }
}
