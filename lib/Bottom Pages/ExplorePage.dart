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

  // ── Instagram-style mixed layout pattern ──
  // Pattern repeats every 5 posts:
  // [0]=small, [1]=small, [2]=small, [3]=LARGE(spans 2), [4]=small
  // Row 1: [0][1][2]
  // Row 2: [3 large][4]
  Widget _buildMixedGrid(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(2),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final imageUrl = _postImageUrl(data);
                final likes = (data['likesCount'] ?? data['likes']?.length ?? 0) as int;
                final views = (data['viewsCount'] ?? data['views'] ?? 0) as int;

                // Every group of 5: index 3 is the large tile
                final posInGroup = index % 5;
                final isLarge = posInGroup == 3;

                return _PostTile(
                  doc: doc,
                  imageUrl: imageUrl,
                  likes: likes,
                  views: views,
                  isLarge: isLarge,
                );
              },
              childCount: docs.length,
            ),
            gridDelegate: _MixedGridDelegate(),
          ),
        ),
      ],
    );
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
          // ── Shimmer loading ──
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _ShimmerGrid();
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

          return _buildMixedGrid(docs);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 1️⃣  MIXED GRID DELEGATE
// ─────────────────────────────────────────────
class _MixedGridDelegate extends SliverGridDelegate {
  static const double _gap = 2.0;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = constraints.crossAxisExtent;
    final cellSize = (width - _gap * 2) / 3; // 3 columns

    return _MixedGridLayout(
      cellSize: cellSize,
      gap: _gap,
      totalWidth: width,
    );
  }

  @override
  bool shouldRelayout(_MixedGridDelegate oldDelegate) => false;
}

class _MixedGridLayout extends SliverGridLayout {
  final double cellSize;
  final double gap;
  final double totalWidth;

  const _MixedGridLayout({
    required this.cellSize,
    required this.gap,
    required this.totalWidth,
  });

  // Group of 5 items occupies 2 rows
  double get _groupHeight => (cellSize + gap) * 2;

  @override
  double computeMaxScrollOffset(int childCount) {
    final groups = (childCount / 5).ceil();
    return groups * _groupHeight;
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final group = index ~/ 5;
    final pos = index % 5;
    final groupTop = group * _groupHeight;

    // Row 1 of group: positions 0,1,2 → 3 small tiles
    if (pos < 3) {
      return SliverGridGeometry(
        scrollOffset: groupTop,
        crossAxisOffset: pos * (cellSize + gap),
        mainAxisExtent: cellSize,
        crossAxisExtent: cellSize,
      );
    }

    // Row 2 of group:
    // pos 3 → large tile (2 cols wide)
    if (pos == 3) {
      return SliverGridGeometry(
        scrollOffset: groupTop + cellSize + gap,
        crossAxisOffset: 0,
        mainAxisExtent: cellSize,
        crossAxisExtent: cellSize * 2 + gap,
      );
    }

    // pos 4 → small tile on the right
    return SliverGridGeometry(
      scrollOffset: groupTop + cellSize + gap,
      crossAxisOffset: cellSize * 2 + gap * 2,
      mainAxisExtent: cellSize,
      crossAxisExtent: cellSize,
    );
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    final group = (scrollOffset / _groupHeight).floor();
    return group * 5;
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    final group = (scrollOffset / _groupHeight).ceil();
    return (group * 5 + 4).clamp(0, double.maxFinite.toInt());
  }
}

// ─────────────────────────────────────────────
// 2️⃣  POST TILE — with long-press overlay
// ─────────────────────────────────────────────
class _PostTile extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String? imageUrl;
  final int likes;
  final int views;
  final bool isLarge;

  const _PostTile({
    required this.doc,
    required this.imageUrl,
    required this.likes,
    required this.views,
    required this.isLarge,
  });

  @override
  State<_PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<_PostTile>
    with SingleTickerProviderStateMixin {
  bool _showOverlay = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onLongPress() {
    setState(() => _showOverlay = true);
    _animController.forward();
  }

  void _onLongPressEnd(_) {
    _animController.reverse().then((_) {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              aspirant_profile.PostDetailsPage(postId: widget.doc.id),
        ),
      ),
      onLongPress: _onLongPress,
      onLongPressEnd: _onLongPressEnd,
      child: Container(
        color: Colors.grey.shade300,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Image ──
            widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const SizedBox(),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.image_not_supported,
                      color: Colors.grey,
                    ),
                  )
                : const Icon(Icons.image, color: Colors.grey),

            // ── Large tile badge ──
            if (widget.isLarge)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.collections,
                      color: Colors.white, size: 14),
                ),
              ),

            // ── Long-press overlay ──
            if (_showOverlay)
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  color: Colors.black54,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            _formatCount(widget.likes),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.remove_red_eye,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            _formatCount(widget.views),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

// ─────────────────────────────────────────────
// 3️⃣  SHIMMER LOADING GRID
// ─────────────────────────────────────────────
class _ShimmerGrid extends StatefulWidget {
  @override
  State<_ShimmerGrid> createState() => _ShimmerGridState();
}

class _ShimmerGridState extends State<_ShimmerGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            return _ShimmerTile(progress: _shimmerController.value);
          },
        );
      },
    );
  }
}

class _ShimmerTile extends StatelessWidget {
  final double progress;
  const _ShimmerTile({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0xFFE0E0E0),
            Color(0xFFF5F5F5),
            Color(0xFFE0E0E0),
          ],
          stops: [
            (progress - 0.3).clamp(0.0, 1.0),
            progress.clamp(0.0, 1.0),
            (progress + 0.3).clamp(0.0, 1.0),
          ],
        ).createShader(bounds);
      },
      child: Container(color: Colors.white),
    );
  }
}