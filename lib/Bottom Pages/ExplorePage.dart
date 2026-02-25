import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/services/explore_service.dart';
import 'package:halo/Profile Pages/aspirant_profile_page.dart' as aspirant_profile;

const Color _kExplorePrimary = Color(0xFF5B3FA3);
const Color _kExploreBg = Color(0xFFF4F1FB);

class ExplorePage extends StatefulWidget {
  const ExplorePage({Key? key}) : super(key: key);

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final ExploreService _exploreService = ExploreService();

  static String? _postImageUrl(Map<String, dynamic> data) {
    final imageUrl = data['imageUrl']?.toString();
    if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;
    final images = data['images'];
    if (images is List && images.isNotEmpty) return images.first?.toString();
    final media = data['media'];
    if (media is List && media.isNotEmpty) {
      final first = media.first;
      if (first is Map && first['url'] != null) return first['url']?.toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _kExploreBg,
      appBar: AppBar(
        title: Text(
          'Explore',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _exploreService.getExplorePostsStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _kExplorePrimary));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Something went wrong',
                style: GoogleFonts.poppins(color: Colors.grey.shade700),
              ),
            );
          }

          final docs = snapshot.data ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.explore_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No posts to explore yet',
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final imageUrl = _postImageUrl(data);

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => aspirant_profile.PostDetailsPage(postId: doc.id),
                    ),
                  );
                },
                child: Container(
                  color: Colors.grey.shade300,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(Icons.image, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
