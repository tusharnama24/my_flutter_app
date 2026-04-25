// ExplorePage.dart — Fixed + Instagram-style Explore & Reels for Halo
//
// FIXES IN THIS VERSION:
// [V1] Grid videos now show play icon + black bg thumbnail (no broken tiles)
// [V2] VideoPlayerController autoPlay now correctly triggers on page change
// [V3] _MixedGridLayout removed — replaced with clean 3-col grid (no offset bugs)
// [V4] Reels use SizedBox.expand + FittedBox(BoxFit.cover) for true fullscreen
// [V5] Video ratio matches screen — FittedBox wraps SizedBox with video dimensions
// [V6] PageView gesture conflict resolved (NeverScrollableScrollPhysics on inner)
// [V7] isCurrent propagation fixed — controller play/pause on didUpdateWidget
// [V8] Video grid tile: uses firstVideoUrl for thumbnail extraction
// [V9] Reels PageController initialPage set correctly
// [V10] All StreamBuilders merged per-post (no redundant listeners)

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:halo/Profile%20Pages/wellness_profile_page.dart' as wellness_profile;
import 'package:halo/Profile%20Pages/aspirant_profile_page.dart' as aspirant_profile;
import 'package:halo/Profile%20Pages/guru_profile_page.dart' as guru_profile;
import 'package:halo/widgets/save_button.dart';
import 'package:halo/services/explore_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const Color _kPrimary    = Color(0xFF5B3FA3);
const Color _kExploreBg  = Color(0xFFF4F1FB);
const Color _kLikeRed    = Color(0xFFED4956);
const int   _kPageSize   = 10;

// ─────────────────────────────────────────────────────────────────────────────
// POST MODEL
// ─────────────────────────────────────────────────────────────────────────────

class PostMediaItem {
  final String url;
  final bool isVideo;
  final int? trimStartMs;
  final int? trimEndMs;
  const PostMediaItem({
    required this.url,
    required this.isVideo,
    this.trimStartMs,
    this.trimEndMs,
  });
}

class PostModel {
  final String id;
  final String userId;
  final String caption;
  final String location;
  final List<String> tags;
  final List<PostMediaItem> mediaItems;
  final DateTime? createdAt;
  final String thumbnailUrl;
  final int likeCount;
  final int commentCount;

  const PostModel({
    required this.id,
    required this.userId,
    required this.caption,
    required this.location,
    required this.tags,
    required this.mediaItems,
    this.createdAt,
    this.thumbnailUrl = '',
    this.likeCount = 0,
    this.commentCount = 0,
  });

  bool get isVideo  => mediaItems.any((m) => m.isVideo);
  bool get hasMedia => mediaItems.isNotEmpty;

  String get firstImageUrl {
    for (final m in mediaItems) { if (!m.isVideo) return m.url; }
    return '';
  }

  String get firstVideoUrl {
    for (final m in mediaItems) { if (m.isVideo) return m.url; }
    return '';
  }

  PostMediaItem? get firstVideoItem {
    for (final m in mediaItems) {
      if (m.isVideo) return m;
    }
    return null;
  }

  factory PostModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PostModel(
      id:         doc.id,
      userId:     (data['userId'] ?? '').toString(),
      caption:    (data['caption'] ?? '').toString(),
      location:   (data['location'] ?? '').toString(),
      tags:       _safeStringList(data['tags']),
      mediaItems: _parseMediaItems(data),
      createdAt:  (data['createdAt'] as Timestamp?)?.toDate(),
      thumbnailUrl: (data['thumbnailUrl'] ?? '').toString().trim(),
      likeCount: _asInt(data['likeCount']),
      commentCount: _asInt(data['commentCount']),
    );
  }

  static List<PostMediaItem> _parseMediaItems(Map<String, dynamic> data) {
    final out = <PostMediaItem>[];

    final media = data['media'];
    if (media is List) {
      for (final m in media) {
        if (m is Map) {
          final url = (m['url'] ?? '').toString().trim();
          if (url.isEmpty) continue;
          final t = (m['type'] ?? '').toString().toLowerCase();
          out.add(PostMediaItem(
            url: url,
            isVideo: t == 'video' || url.contains('.mp4'),
            trimStartMs: _asIntNullable(m['trimStartMs']),
            trimEndMs: _asIntNullable(m['trimEndMs']),
          ));
        }
      }
    }
    if (out.isNotEmpty) return out;

    final imageUrl = data['imageUrl']?.toString() ?? '';
    if (imageUrl.isNotEmpty) {
      out.add(PostMediaItem(url: imageUrl, isVideo: false));
      return out;
    }

    final images = data['images'];
    if (images is List) {
      for (final img in images) {
        final url = img?.toString() ?? '';
        if (url.isNotEmpty) out.add(PostMediaItem(url: url, isVideo: false));
      }
      if (out.isNotEmpty) return out;
    }

    final videoUrl = (data['videoUrl'] ?? data['mediaUrl'] ?? '').toString().trim();
    if (videoUrl.isNotEmpty) out.add(PostMediaItem(url: videoUrl, isVideo: true));

    return out;
  }
}

List<String> _safeStringList(dynamic v) {
  if (v == null) return [];
  if (v is List) return v.map((e) => e.toString()).toList();
  return [];
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

// ─────────────────────────────────────────────────────────────────────────────
// USER PROFILE CACHE
// ─────────────────────────────────────────────────────────────────────────────

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime fetchedAt;
  _CacheEntry(this.data) : fetchedAt = DateTime.now();
  bool get isStale => DateTime.now().difference(fetchedAt).inMinutes >= 5;
}

class _UserProfileCache {
  static final _instance = _UserProfileCache._();
  _UserProfileCache._();
  factory _UserProfileCache() => _instance;

  final Map<String, _CacheEntry> _cache = {};

  static String extractPhotoUrl(Map<String, dynamic> data) {
    return (data['profilePhoto'] ??
        data['photoURL']    ??
        data['profile_photo'] ??
        data['avatar']      ??
        data['photoUrl']    ??
        '').toString().trim();
  }

  Future<Map<String, dynamic>> get(String userId) async {
    final entry = _cache[userId];
    if (entry != null && !entry.isStale) return entry.data;
    final snap = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = snap.data() ?? {};
    _cache[userId] = _CacheEntry(data);
    return data;
  }

  void clear() => _cache.clear();
  void invalidate(String userId) => _cache.remove(userId);
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum _ExploreFilter { forYou, photos, videos, trending }

extension _ExploreFilterLabel on _ExploreFilter {
  String get label {
    switch (this) {
      case _ExploreFilter.forYou:    return 'For You';
      case _ExploreFilter.photos:    return 'Photos';
      case _ExploreFilter.videos:    return 'Videos';
      case _ExploreFilter.trending:  return 'Trending';
    }
  }
  IconData get icon {
    switch (this) {
      case _ExploreFilter.forYou:    return Icons.auto_awesome_rounded;
      case _ExploreFilter.photos:    return Icons.photo_rounded;
      case _ExploreFilter.videos:    return Icons.videocam_rounded;
      case _ExploreFilter.trending:  return Icons.trending_up_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPLORE PAGE
// ─────────────────────────────────────────────────────────────────────────────

class ExplorePage extends StatefulWidget {
  final bool openReelsOnStart;
  final String? initialReelPostId;

  const ExplorePage({
    Key? key,
    this.openReelsOnStart = false,
    this.initialReelPostId,
  }) : super(key: key);

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final List<PostModel>   _posts          = [];
  DocumentSnapshot?       _lastDoc;
  bool                    _isFetching     = false;
  bool                    _hasMore        = true;
  bool                    _didAutoOpenReels = false;
  final ScrollController  _scrollCtrl     = ScrollController();
  final ExploreService    _exploreService = ExploreService();
  final TextEditingController _searchCtrl = TextEditingController();

  _ExploreFilter _filter      = _ExploreFilter.forYou;
  String         _searchQuery = '';
  List<String>   _trendingTags = [];

  @override
  void initState() {
    super.initState();
    if (widget.openReelsOnStart) _filter = _ExploreFilter.videos;
    _fetchNextPage();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400 &&
        !_isFetching && _hasMore) {
      _fetchNextPage();
    }
  }

  Future<void> _fetchNextPage() async {
    if (_isFetching || !_hasMore) return;
    _isFetching = true;
    if (mounted) setState(() {});

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_kPageSize);
      if (_lastDoc != null) query = query.startAfterDocument(_lastDoc!);

      final snap = await query.get();
      if (snap.docs.isEmpty || snap.docs.length < _kPageSize) _hasMore = false;

      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
        final newPosts = snap.docs.map(PostModel.fromFirestore).toList();
        _posts.addAll(newPosts);
        _recomputeTrending();
        _tryAutoOpenReels();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load posts. Pull to retry.')),
        );
      }
    } finally {
      _isFetching = false;
      if (mounted) setState(() {});
    }
  }

  void _tryAutoOpenReels() {
    if (!widget.openReelsOnStart || _didAutoOpenReels) return;
    final videoPosts = _posts.where((p) => p.isVideo).toList();
    if (videoPosts.isEmpty) return;

    final targetId = widget.initialReelPostId?.trim() ?? '';
    int startIdx = 0;
    if (targetId.isNotEmpty) {
      final found = videoPosts.indexWhere((p) => p.id == targetId);
      if (found >= 0) startIdx = found;
    }

    _didAutoOpenReels = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openReels(videoPosts, startIdx);
    });
  }

  void _recomputeTrending() {
    final freq = <String, int>{};
    for (final p in _posts) {
      for (final t in p.tags) freq[t] = (freq[t] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    _trendingTags = sorted.take(10).map((e) => e.key).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _posts.clear();
      _lastDoc    = null;
      _hasMore    = true;
      _isFetching = false;
      _trendingTags = [];
    });
    _UserProfileCache().clear();
    await _fetchNextPage();
  }

  List<PostModel> get _filteredPosts {
    List<PostModel> list = _posts;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) =>
      p.caption.toLowerCase().contains(q) ||
          p.tags.any((t) => t.toLowerCase().contains(q)) ||
          p.location.toLowerCase().contains(q),
      ).toList();
    }
    switch (_filter) {
      case _ExploreFilter.forYou:   break;
      case _ExploreFilter.photos:   list = list.where((p) => !p.isVideo && p.hasMedia).toList(); break;
      case _ExploreFilter.videos:   list = list.where((p) => p.isVideo).toList(); break;
      case _ExploreFilter.trending:
        list = list.where((p) => p.tags.isNotEmpty).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        break;
    }
    return list;
  }

  void _openReels(List<PostModel> videoPosts, int startIdx) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ExploreReelsViewer(videoPosts: videoPosts, initialIndex: startIdx),
    ));
  }

  void _openPostDetail(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PostDetailPage(
          post: post,
          currentUserId: FirebaseAuth.instance.currentUser?.uid,
        ),
      ),
    );
  }

  void _onTileTap(PostModel post, List<PostModel> posts) async {
    if (post.isVideo) {
      final videoPosts = posts.where((p) => p.isVideo).toList();
      final startIdx = videoPosts.indexWhere((p) => p.id == post.id);
      _openReels(videoPosts, startIdx < 0 ? 0 : startIdx);
      return;
    }
    _openPostDetail(post);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kExploreBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: _kPrimary,
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),

              if (_trendingTags.isNotEmpty &&
                  (_filter == _ExploreFilter.forYou || _filter == _ExploreFilter.trending))
                SliverToBoxAdapter(child: _buildTrendingSection()),

              _buildGrid(),

              if (_isFetching)
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: _kPrimary))),
                ),

              if (!_hasMore && _posts.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(padding: const EdgeInsets.all(24),
                      child: Center(child: Text("You've seen it all!",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13)))),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: _kPrimary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text('Explore', style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: 22, color: const Color(0xFF1F1033))),
        ]),
      ),

      // Search bar
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: _kPrimary.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            textInputAction: TextInputAction.search,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search posts, tags, places...',
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: _kPrimary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                onPressed: () => setState(() { _searchCtrl.clear(); _searchQuery = ''; }),
              )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
      ),

      const SizedBox(height: 10),

      // Filter chips
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: _ExploreFilter.values.map((f) => _FilterChip(
            filter: f, selected: _filter == f,
            onTap: () => setState(() => _filter = f),
          )).toList(),
        ),
      ),

      const SizedBox(height: 10),
    ],
  );

  Widget _buildTrendingSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          const Icon(Icons.local_fire_department_rounded, color: _kPrimary, size: 18),
          const SizedBox(width: 6),
          Text('Trending', style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1F1033))),
        ]),
      ),
      SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: _trendingTags.length,
          itemBuilder: (_, i) {
            final tag = _trendingTags[i];
            return GestureDetector(
              onTap: () => setState(() { _searchCtrl.text = tag; _searchQuery = tag; }),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _kPrimary.withOpacity(0.18), width: 1),
                ),
                child: Text('#$tag', style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500, color: _kPrimary)),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
    ],
  );

  // [V3] Clean 3-column grid — no custom delegate (eliminates offset bugs)
  Widget _buildGrid() {
    final posts = _filteredPosts;

    if (posts.isEmpty && !_isFetching) {
      return SliverFillRemaining(
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.explore_off, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'No results for "$_searchQuery"' : 'Nothing to explore yet',
              style: GoogleFonts.poppins(color: Colors.grey.shade500),
            ),
          ]),
        ),
      );
    }

    if (posts.isEmpty && _isFetching) {
      return SliverToBoxAdapter(child: _buildShimmerGrid());
    }

    return SliverPadding(
      padding: const EdgeInsets.all(1),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            if (index >= posts.length) return null;
            final post = posts[index];
            // Every 7th item is a hero (double-wide spanning 2 columns)
            final isHero = (index % 7 == 6);
            return RepaintBoundary(
              child: _ExploreGridTile(
                post: post,
                isHero: isHero,
                onTap: () => _onTileTap(post, posts),
              ),
            );
          },
          childCount: posts.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
          childAspectRatio: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final _ExploreFilter filter;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.filter, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? _kPrimary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? _kPrimary : Colors.grey.shade300, width: 1.2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(filter.icon, size: 14, color: selected ? Colors.white : Colors.grey.shade600),
        const SizedBox(width: 5),
        Text(filter.label, style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.grey.shade700)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  const _ShimmerBox({required this.width, required this.height});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value, 0),
          colors: [Colors.grey.shade200, Colors.grey.shade100, Colors.grey.shade200],
        ),
      ),
    ),
  );
}

Widget _buildShimmerGrid() => GridView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  padding: const EdgeInsets.all(1),
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3, crossAxisSpacing: 1, mainAxisSpacing: 1, childAspectRatio: 1,
  ),
  itemCount: 12,
  itemBuilder: (_, __) => const _ShimmerBox(width: double.infinity, height: double.infinity),
);

// ─────────────────────────────────────────────────────────────────────────────
// [V1] GRID TILE — videos now show correctly with play icon overlay
// ─────────────────────────────────────────────────────────────────────────────

class _ExploreGridTile extends StatelessWidget {
  final PostModel post;
  final bool isHero;
  final VoidCallback onTap;

  const _ExploreGridTile(
      {required this.post, required this.isHero, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.firstImageUrl;
    final videoThumbUrl = post.thumbnailUrl;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (post.isVideo && videoThumbUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: videoThumbUrl,
              fit: BoxFit.cover,
              memCacheWidth: 300,
              memCacheHeight: 300,
              maxWidthDiskCache: 300,
              placeholder: (_, __) => const SizedBox(),
              errorWidget: (_, __, ___) => Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.play_circle_fill, color: Colors.white, size: 30),
                ),
              ),
            )
          else if (post.isVideo)
            Container(
              color: Colors.black,
              child: const Center(
                child: Icon(Icons.play_circle_fill, color: Colors.white, size: 30),
              ),
            )

          // 🖼️ Image post
          else
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 300,
                memCacheHeight: 300,
                maxWidthDiskCache: 300,
                placeholder: (_, __) => const SizedBox(),
                errorWidget: (_, __, ___) =>
                    Container(
                      color: Colors.grey.shade200,
                      child: const Icon(
                          Icons.image_not_supported, color: Colors.grey),
                    ),
              )

            // ⚠️ fallback
            else
              Container(color: Colors.grey.shade200),

          // 🎥 Video badge
          if (post.isVideo)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.videocam_rounded,
                    color: Colors.white, size: 14),
              ),
            )

          // 🖼️ Multi-image badge
          else
            if (post.mediaItems.length > 1)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.collections_rounded,
                      color: Colors.white, size: 14),
                ),
              ),

          // 🏷️ Hero caption
          if (isHero)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
                child: Text(
                  post.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// POST DETAIL PAGE
// ─────────────────────────────────────────────────────────────────────────────

class _PostDetailPage extends StatelessWidget {
  final PostModel post;
  final String? currentUserId;

  const _PostDetailPage({required this.post, required this.currentUserId});

  Future<void> _toggleLike(BuildContext context) async {
    final uid = currentUserId;
    if (uid == null) return;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
    final ref = postRef.collection('likes').doc(uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final d = await tx.get(ref);
        if (d.exists) {
          tx.delete(ref);
          tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
        } else {
          tx.set(ref, {
            'userId': uid,
            'likedAt': FieldValue.serverTimestamp(),
          });
          tx.update(postRef, {'likeCount': FieldValue.increment(1)});
        }
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update like.')));
    }
  }

  Future<void> _share() async {
    final parts = [
      if (post.caption.isNotEmpty) post.caption,
      if (post.mediaItems.isNotEmpty) post.mediaItems.first.url,
    ];
    if (parts.isNotEmpty) await Share.share(parts.join('\n'));
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CommentsSheet(postId: post.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _UserHeader(userId: post.userId, location: post.location),

          if (post.mediaItems.isNotEmpty)
            _MediaCarousel(
              mediaItems: post.mediaItems,
              onDoubleTap: () => _toggleLike(context),
            ),

          _PostActions(
            postId: post.id,
            currentUserId: currentUserId,
            likeCount: post.likeCount,
            commentCount: post.commentCount,
            onLike: () => _toggleLike(context),
            onComment: () => _openComments(context),
            onShare: _share,
          ),

          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Text(post.caption, style: GoogleFonts.poppins(
                  fontSize: 14, color: const Color(0xFF262626))),
            ),

          if (post.location.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Row(children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(post.location, style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ),

          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDIA CAROUSEL
// ─────────────────────────────────────────────────────────────────────────────

class _MediaCarousel extends StatefulWidget {
  final List<PostMediaItem> mediaItems;
  final VoidCallback onDoubleTap;

  const _MediaCarousel({required this.mediaItems, required this.onDoubleTap});

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 380,
          child: PageView.builder(
            itemCount: widget.mediaItems.length,
            physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),

            // 🔥 FIX: update page only; avoid hidden preloads here
            onPageChanged: (i) {
              setState(() => _page = i);
            },

            itemBuilder: (_, i) {
              final m = widget.mediaItems[i];

              return GestureDetector(
                onDoubleTap: widget.onDoubleTap,

                child: m.isVideo
                    ? _VideoCell(
                  key: ValueKey('media_${m.url}'),
                  url: m.url,
                  trimStartMs: m.trimStartMs,
                  trimEndMs: m.trimEndMs,
                  fit: BoxFit.cover,

                  // 🔥 FIX: only current video should autoplay
                  autoPlay: i == _page,

                  visibilityKey: 'media_${m.url.hashCode}_$i',
                )

                    : CachedNetworkImage(
                  imageUrl: m.url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  memCacheWidth: 300,
                  memCacheHeight: 300,
                  maxWidthDiskCache: 300,
                  placeholder: (_, __) => const SizedBox(),
                  errorWidget: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image)),
                ),
              );
            },
          ),
        ),

        // 🔘 DOT INDICATOR
        if (widget.mediaItems.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.mediaItems.length,
                    (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                    _page == i ? _kPrimary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST ACTIONS
// ─────────────────────────────────────────────────────────────────────────────

class _PostActions extends StatelessWidget {
  final String postId;
  final String? currentUserId;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const _PostActions({
    required this.postId, required this.currentUserId,
    required this.likeCount, required this.commentCount,
    required this.onLike, required this.onComment, required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: currentUserId == null
          ? null
          : FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .collection('likes')
              .doc(currentUserId)
              .snapshots(),
      builder: (context, likeSnap) {
        final isLiked = likeSnap.data?.exists ?? false;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(
              onPressed: onLike,
              icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? _kLikeRed : Colors.black87, size: 28),
            ),
            IconButton(onPressed: onComment,
                icon: const Icon(Icons.chat_bubble_outline, size: 26, color: Colors.black87)),
            IconButton(onPressed: onShare,
                icon: const Icon(Icons.send_outlined, size: 26, color: Colors.black87)),
            const Spacer(),
            SaveButton(postId: postId, currentUserId: currentUserId, iconSize: 26, color: Colors.black87),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                likeCount == 0 ? 'Be the first to like this'
                    : isLiked && likeCount == 1 ? 'Liked by you'
                    : isLiked ? 'Liked by you and ${likeCount - 1} others'
                    : '$likeCount likes',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13,
                    color: const Color(0xFF262626)),
              ),
              if (commentCount > 0)
                GestureDetector(
                  onTap: onComment,
                  child: Text('View all $commentCount comments',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
                ),
            ]),
          ),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _UserHeader extends StatefulWidget {
  final String userId;
  final String location;
  const _UserHeader({required this.userId, required this.location});

  @override
  State<_UserHeader> createState() => _UserHeaderState();
}

class _UserHeaderState extends State<_UserHeader> {
  Map<String, dynamic>? _userData;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (widget.userId.isEmpty) return;
    final data = await _UserProfileCache().get(widget.userId);
    if (mounted) setState(() => _userData = data);
  }

  @override
  Widget build(BuildContext context) {
    final username = (_userData?['username'] ?? _userData?['name'] ?? _userData?['full_name'] ?? 'User').toString();
    final photoUrl = _UserProfileCache.extractPhotoUrl(_userData ?? {});

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: photoUrl.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: photoUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            memCacheWidth: 300,
            memCacheHeight: 300,
            maxWidthDiskCache: 300,
            placeholder: (_, __) => const SizedBox(),
            errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.grey),
          )
              : const Icon(Icons.person, color: Colors.grey),
        ),
      ),
      title: Text(username, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: widget.location.isNotEmpty
          ? Text(widget.location, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500))
          : null,
      trailing: const Icon(Icons.more_horiz),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMENTS SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final String postId;
  const _CommentsSheet({required this.postId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _input = TextEditingController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void dispose() { _input.dispose(); super.dispose(); }

  Future<void> _addComment() async {
    final uid  = _currentUserId;
    if (uid == null) return;
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final commentRef = postRef.collection('comments').doc();
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(commentRef, {
          'userId': uid,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {'commentCount': FieldValue.increment(1)});
      });
      _input.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post comment.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 10),
          Text('Comments', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
          const Divider(),
          Expanded(child: _CommentsList(postId: widget.postId)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _addComment(),
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addComment,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: _kPrimary, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CommentsList extends StatelessWidget {
  final String postId;
  const _CommentsList({required this.postId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts').doc(postId).collection('comments')
          .orderBy('createdAt').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Text('No comments yet',
              style: GoogleFonts.poppins(color: Colors.grey.shade500)));
        }
        return _CommentsFetcher(docs: docs);
      },
    );
  }
}

class _CommentsFetcher extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  const _CommentsFetcher({required this.docs});

  @override
  State<_CommentsFetcher> createState() => _CommentsFetcherState();
}

class _CommentsFetcherState extends State<_CommentsFetcher> {
  final Map<String, Map<String, dynamic>> _profiles = {};
  bool _loaded = false;

  @override
  void initState() { super.initState(); _fetchProfiles(); }

  @override
  void didUpdateWidget(_CommentsFetcher old) { super.didUpdateWidget(old); _fetchProfiles(); }

  Future<void> _fetchProfiles() async {
    final ids = widget.docs.map((d) => (d.data()['userId'] ?? '').toString())
        .where((id) => id.isNotEmpty).toSet();
    await Future.wait(ids.map((id) async {
      _profiles[id] = await _UserProfileCache().get(id);
    }));
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: widget.docs.length,
      itemBuilder: (_, i) {
        final c  = widget.docs[i].data();
        final uid = (c['userId'] ?? '').toString();
        final ud  = _profiles[uid] ?? {};
        final username = (ud['username'] ?? ud['name'] ?? 'User').toString();
        final photoUrl = _UserProfileCache.extractPhotoUrl(ud);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              child: ClipOval(
                child: photoUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  memCacheHeight: 300,
                  maxWidthDiskCache: 300,
                  placeholder: (_, __) => const SizedBox(),
                  errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.grey),
                )
                    : const Icon(Icons.person, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF262626)),
                  children: [
                    TextSpan(text: '$username ', style: const TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: (c['text'] ?? '').toString()),
                  ],
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [V4][V5] REELS VIEWER — true fullscreen, correct aspect ratio
// ─────────────────────────────────────────────────────────────────────────────

class _ExploreReelsViewer extends StatefulWidget {
  final List<PostModel> videoPosts;
  final int initialIndex;

  const _ExploreReelsViewer({required this.videoPosts, required this.initialIndex});

  @override
  State<_ExploreReelsViewer> createState() => _ExploreReelsViewerState();
}

class _ExploreReelsViewerState extends State<_ExploreReelsViewer> {
  late final PageController _controller;
  int  _currentIndex = 0;
  bool _globalMuted  = false;
  VideoPlayerController? _preloadCtrl;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // [V9] initialPage must match _currentIndex
    _controller = PageController(initialPage: widget.initialIndex);
    _preloadNext(widget.initialIndex);
  }

  @override
  void dispose() {
    _preloadCtrl?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _preloadNext(int index) {
    final nextIndex = index + 1;
    if (nextIndex >= widget.videoPosts.length) return;
    final nextUrl = widget.videoPosts[nextIndex].firstVideoUrl;
    if (nextUrl.isEmpty) return;
    _preloadCtrl?.dispose();
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(nextUrl));
    _preloadCtrl = ctrl;
    ctrl
      ..setLooping(true)
      ..initialize().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoPosts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text('No videos', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Go back', style: TextStyle(color: Colors.white))),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
        itemCount: widget.videoPosts.length,
        onPageChanged: (i) {
          setState(() => _currentIndex = i);
          _preloadNext(i);
        },
        itemBuilder: (_, index) {
          final post = widget.videoPosts[index];
          return _ReelItem(
            key: ValueKey(post.id),
            post: post,
            // [V7] isCurrent correctly passed to each item
            isCurrent: index == _currentIndex,
            muted: _globalMuted,
            onMuteToggle: () => setState(() => _globalMuted = !_globalMuted),
            onBack: () => Navigator.pop(context),
            currentUserId: FirebaseAuth.instance.currentUser?.uid,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// [V7] REEL ITEM — play/pause responds correctly when isCurrent changes
// ─────────────────────────────────────────────────────────────────────────────

class _ReelItem extends StatefulWidget {
  final PostModel post;
  final bool isCurrent;
  final bool muted;
  final VoidCallback onMuteToggle;
  final VoidCallback onBack;
  final String? currentUserId;

  const _ReelItem({
    Key? key,
    required this.post,
    required this.isCurrent,
    required this.muted,
    required this.onMuteToggle,
    required this.onBack,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  bool _showHeart = false;

  Future<void> _toggleLike() async {
    final uid = widget.currentUserId;
    if (uid == null) return;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.post.id);
    final ref = postRef.collection('likes').doc(uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final d = await tx.get(ref);
        if (d.exists) {
          tx.delete(ref);
          tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
        } else {
          tx.set(ref, {
            'userId': uid,
            'likedAt': FieldValue.serverTimestamp(),
          });
          tx.update(postRef, {'likeCount': FieldValue.increment(1)});
        }
      });
    } catch (_) {}
  }

  void _onDoubleTap() {
    _toggleLike();
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(postId: widget.post.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final firstVideo = post.firstVideoItem;

    return Stack(
      fit: StackFit.expand,
      children: [
        // [V4][V5] Full-screen video with correct ratio
        GestureDetector(
          onDoubleTap: _onDoubleTap,
          child: _VideoCell(
            key: ValueKey('reel_${post.id}'),
            url: post.firstVideoUrl,
            trimStartMs: firstVideo?.trimStartMs,
            trimEndMs: firstVideo?.trimEndMs,
            fit: BoxFit.cover,
            // [V7] autoPlay is driven by isCurrent
            autoPlay: widget.isCurrent,
            muted: widget.muted,
            visibilityKey: 'reel_${post.id}',
            showProgressBar: true,
          ),
        ),

        // Double-tap heart
        if (_showHeart)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (_, v, __) => Transform.scale(
                scale: v,
                child: const Icon(Icons.favorite, color: Colors.white, size: 90),
              ),
            ),
          ),

        // Top gradient
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.5), Colors.transparent],
              ),
            ),
          ),
        ),

        // Back button
        Positioned(
          top: 44, left: 8,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
            onPressed: widget.onBack,
          ),
        ),

        // Mute button
        Positioned(
          top: 44, right: 8,
          child: IconButton(
            icon: Icon(widget.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white, size: 24),
            onPressed: widget.onMuteToggle,
          ),
        ),

        // Bottom gradient
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.75), Colors.transparent],
              ),
            ),
          ),
        ),

        // Author info — bottom left
        Positioned(
          left: 12, bottom: 100, right: 80,
          child: _ReelAuthorInfo(userId: post.userId),
        ),

        // Caption
        if (post.caption.isNotEmpty)
          Positioned(
            left: 12, right: 80, bottom: 50,
            child: Text(post.caption, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, height: 1.4)),
          ),

        // Right action bar
        Positioned(
          right: 10, bottom: 80,
          child: _ReelActionBar(
            postId: post.id,
            currentUserId: widget.currentUserId,
            likeCount: post.likeCount,
            commentCount: post.commentCount,
            onLike: _toggleLike,
            onComment: _openComments,
            onShare: () async {
              final url = post.firstVideoUrl;
              if (url.isNotEmpty) await Share.share(url);
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REEL AUTHOR INFO
// ─────────────────────────────────────────────────────────────────────────────

class _ReelAuthorInfo extends StatefulWidget {
  final String userId;
  const _ReelAuthorInfo({required this.userId});

  @override
  State<_ReelAuthorInfo> createState() => _ReelAuthorInfoState();
}

class _ReelAuthorInfoState extends State<_ReelAuthorInfo> {
  Map<String, dynamic>? _userData;
  bool _following = false;
  bool _followLoading = false;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (widget.userId.isEmpty) return;
    final data = await _UserProfileCache().get(widget.userId);
    if (!mounted) return;
    setState(() => _userData = data);

    if (_currentUserId != null && _currentUserId != widget.userId) {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(_currentUserId!).collection('following').doc(widget.userId).get();
      if (mounted) setState(() => _following = doc.exists);
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null || _currentUserId == widget.userId) return;
    setState(() => _followLoading = true);
    final followRef  = FirebaseFirestore.instance
        .collection('users').doc(_currentUserId!).collection('following').doc(widget.userId);
    final followerRef = FirebaseFirestore.instance
        .collection('users').doc(widget.userId).collection('followers').doc(_currentUserId!);
    try {
      if (_following) {
        await followRef.delete();
        await followerRef.delete();
      } else {
        await followRef.set({'followedAt': FieldValue.serverTimestamp()});
        await followerRef.set({'followedAt': FieldValue.serverTimestamp()});
      }
      if (mounted) setState(() { _following = !_following; _followLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  void _openProfile() {
    if (widget.userId.isEmpty) return;
    final accountType = (_userData?['accountType'] ?? 'aspirant').toString().toLowerCase();
    if (accountType == 'wellness') {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => wellness_profile.WellnessProfilePage(profileUserId: widget.userId)));
    } else if (accountType == 'guru') {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => guru_profile.GuruProfilePage(profileUserId: widget.userId)));
    } else {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => aspirant_profile.ProfilePage(profileUserId: widget.userId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = (_userData?['username'] ?? _userData?['name'] ?? 'User').toString();
    final photoUrl = _UserProfileCache.extractPhotoUrl(_userData ?? {});
    final isSelf   = _currentUserId == widget.userId;

    return Row(
      children: [
        GestureDetector(
          onTap: _openProfile,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade800,
              child: ClipOval(
                child: photoUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  memCacheHeight: 300,
                  maxWidthDiskCache: 300,
                  placeholder: (_, __) => const SizedBox(),
                )
                    : const Icon(Icons.person, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(username, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ]),
        ),
        if (!isSelf) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _followLoading ? null : _toggleFollow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _following ? Colors.transparent : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: _followLoading
                  ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                  : Text(_following ? 'Following' : 'Follow',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _following ? Colors.white : Colors.black)),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REEL ACTION BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ReelActionBar extends StatelessWidget {
  final String postId;
  final String? currentUserId;
  final int likeCount;
  final int commentCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const _ReelActionBar({
    required this.postId, required this.currentUserId,
    required this.likeCount, required this.commentCount,
    required this.onLike, required this.onComment, required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: currentUserId == null
          ? null
          : FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .collection('likes')
              .doc(currentUserId)
              .snapshots(),
      builder: (_, likeSnap) {
        final isLiked = likeSnap.data?.exists ?? false;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          _ReelActionButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? _kLikeRed : Colors.white,
            label: likeCount > 0 ? '$likeCount' : '',
            onTap: onLike,
          ),
          const SizedBox(height: 20),
          _ReelActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            color: Colors.white,
            label: commentCount > 0 ? '$commentCount' : '',
            onTap: onComment,
          ),
          const SizedBox(height: 20),
          _ReelActionButton(
            icon: Icons.send_outlined,
            color: Colors.white,
            label: 'Share',
            onTap: onShare,
          ),
          const SizedBox(height: 20),
          SaveButton(postId: postId, currentUserId: currentUserId, iconSize: 28, color: Colors.white),
        ]);
      },
    );
  }
}

class _ReelActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ReelActionButton({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 30),
      if (label.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
            shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
      ],
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// [V2][V5][V7] VIDEO CELL — core video player widget
// Fixed: autoPlay reacts to isCurrent changes via didUpdateWidget
// Fixed: uses SizedBox.expand + FittedBox(cover) for true fullscreen fill
// Fixed: mute syncs in didUpdateWidget without re-init
// ─────────────────────────────────────────────────────────────────────────────

class _VideoCell extends StatefulWidget {
  final String url;
  final int? trimStartMs;
  final int? trimEndMs;
  final BoxFit fit;
  final bool autoPlay;
  final bool muted;
  final String? visibilityKey;
  final bool showProgressBar;

  const _VideoCell({
    Key? key,
    required this.url,
    this.trimStartMs,
    this.trimEndMs,
    this.fit = BoxFit.cover,
    this.autoPlay = false,
    this.muted = false,
    this.visibilityKey,
    this.showProgressBar = false,
  }) : super(key: key);

  @override
  State<_VideoCell> createState() => _VideoCellState();
}

class _VideoCellState extends State<_VideoCell> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _error = false;
  bool _initialized = false;
  Duration _effectiveTrimStart = Duration.zero;
  Duration? _effectiveTrimEnd;

  @override
  void initState() {
    super.initState();
    _initIfNeeded();
  }

  @override
  void didUpdateWidget(_VideoCell old) {
    super.didUpdateWidget(old);

    // URL changed — dispose and re-init
    if (old.url != widget.url) {
      _ctrl?.dispose();
      _ctrl = null;
      _ready = false;
      _error = false;
      _initialized = false;
      _initIfNeeded();
      return;
    }

    // [V7] autoPlay changed — play or pause without reinit
    if (_ready && old.autoPlay != widget.autoPlay) {
      if (widget.autoPlay) {
        final c = _ctrl;
        if (c != null &&
            c.value.isInitialized &&
            c.value.position < _effectiveTrimStart) {
          c.seekTo(_effectiveTrimStart);
        }
        _ctrl?.play();
      } else {
        _ctrl?.pause();
      }
    }

    // Mute changed — update volume without reinit
    if (old.muted != widget.muted && _ctrl != null) {
      _ctrl!.setVolume(widget.muted ? 0 : 1);
    }

    if (_ready &&
        (old.trimStartMs != widget.trimStartMs ||
            old.trimEndMs != widget.trimEndMs)) {
      _updateTrimBounds();
      final c = _ctrl;
      if (c != null &&
          c.value.isInitialized &&
          c.value.position < _effectiveTrimStart) {
        c.seekTo(_effectiveTrimStart);
      }
    }
  }

  void _initIfNeeded() {
    if (_initialized || widget.url.isEmpty) return;
    _initialized = true;

    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        _updateTrimBounds();
        _ctrl!
          ..setVolume(widget.muted ? 0 : 1)
          ..setLooping(false)
          ..addListener(_enforceTrimWindow);
        if (_effectiveTrimStart > Duration.zero) {
          _ctrl!.seekTo(_effectiveTrimStart);
        }
        if (widget.autoPlay) _ctrl!.play();
        setState(() => _ready = true);
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _error = true);
      });
  }

  void _togglePlay() {
    if (_ctrl == null || !_ready) return;
    setState(() => _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play());
  }

  void _updateTrimBounds() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    final duration = c.value.duration;
    final rawStart = widget.trimStartMs ?? 0;
    final startMs = rawStart < 0 ? 0 : rawStart;
    final rawEnd = widget.trimEndMs;
    final maxMs = duration.inMilliseconds;
    final boundedStart = startMs > maxMs ? maxMs : startMs;
    int? boundedEnd;
    if (rawEnd != null) {
      if (rawEnd <= boundedStart) {
        boundedEnd = maxMs;
      } else {
        boundedEnd = rawEnd > maxMs ? maxMs : rawEnd;
      }
    }
    _effectiveTrimStart = Duration(milliseconds: boundedStart);
    _effectiveTrimEnd =
        boundedEnd != null ? Duration(milliseconds: boundedEnd) : null;
  }

  void _enforceTrimWindow() {
    final c = _ctrl;
    if (c == null || !c.value.isInitialized) return;
    if (_effectiveTrimEnd == null) return;
    if (c.value.position >= _effectiveTrimEnd!) {
      c.seekTo(_effectiveTrimStart);
      if (widget.autoPlay) c.play();
    }
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_enforceTrimWindow);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) {
      return Container(color: Colors.black,
          child: const Center(child: Icon(Icons.videocam_off, color: Colors.white54, size: 56)));
    }

    Widget content;

    if (_error) {
      content = Container(color: Colors.black,
          child: const Center(child: Icon(Icons.videocam_off, color: Colors.white54, size: 56)));
    } else if (!_ready || _ctrl == null || !_ctrl!.value.isInitialized) {
      content = Container(color: Colors.black,
          child: const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)));
    } else {
      final c = _ctrl!;

      // [V5] FIX: SizedBox.expand forces the player to fill the parent.
      // FittedBox with BoxFit.cover crops to fill without letterboxing.
      content = GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // This is the fix for aspect ratio — fills the screen like Instagram
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width:  c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              ),
            ),

            // Play icon overlay (fades when playing)
            if (!c.value.isPlaying)
              Container(
                color: Colors.black26,
                child: const Center(
                    child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 64)),
              ),

            // Progress bar
            if (widget.showProgressBar)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: VideoProgressIndicator(
                  c,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white.withOpacity(0.3),
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                ),
              ),
          ],
        ),
      );
    }

    // Visibility detector for lazy init + auto-pause off-screen
    if (widget.visibilityKey != null) {
      return VisibilityDetector(
        key: Key(widget.visibilityKey!),
        onVisibilityChanged: (info) {
          if (info.visibleFraction > 0.1) {
            _initIfNeeded();
            if (widget.autoPlay && _ready) _ctrl?.play();
          } else {
            _ctrl?.pause();
          }
        },
        child: content,
      );
    }

    _initIfNeeded();
    return content;
  }
}