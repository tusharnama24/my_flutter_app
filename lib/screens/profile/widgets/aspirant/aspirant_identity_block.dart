import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AspirantIdentityBlock extends StatelessWidget {
  final Widget avatar;
  final String profileUserId;
  final String fullName;
  final String username;
  final List<String> interests;
  final String fitnessTag;
  final String city;
  final int? age;

  const AspirantIdentityBlock({
    super.key,
    required this.avatar,
    required this.profileUserId,
    required this.fullName,
    required this.username,
    required this.interests,
    required this.fitnessTag,
    required this.city,
    required this.age,
  });

  @override
  Widget build(BuildContext context) {
    final title = fullName.isNotEmpty
        ? fullName
        : username.isNotEmpty
            ? '@$username'
            : 'No name';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(0, -40),
            child: avatar,
          ),
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
                    style: GoogleFonts.poppins(),
                  ),
                  const SizedBox(height: 6),
                  if (interests.isNotEmpty) ...[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        ...interests.take(3).map((interest) {
                          return Text(
                            interest,
                            style: GoogleFonts.poppins(fontSize: 12),
                          );
                        }),
                        if (interests.length > 3)
                          Text(
                            '+${interests.length - 3}',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ] else if (fitnessTag.isNotEmpty) ...[
                    Text(fitnessTag, style: GoogleFonts.poppins()),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      if (city.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(city, style: GoogleFonts.poppins()),
                      ],
                      if (age != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${age} yrs', style: GoogleFonts.poppins()),
                      ],
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
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(profileUserId)
          .snapshots(),
      builder: (context, snapshot) {
        var isOnline = false;
        if (snapshot.hasData) {
          final data = snapshot.data?.data();
          if (data?['isOnline'] == true) {
            isOnline = true;
          } else if (data?['lastSeen'] != null) {
            final lastSeen = (data?['lastSeen'] as Timestamp?)?.toDate();
            if (lastSeen != null) {
              isOnline = DateTime.now().difference(lastSeen).inMinutes < 2;
            }
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
