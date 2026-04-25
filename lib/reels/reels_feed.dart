import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

/// ================= CONTROLLER POOL =================
class VideoControllerPool {
  final int maxSize;
  final _map = <String, VideoPlayerController>{};

  VideoControllerPool({this.maxSize = 4});

  Future<VideoPlayerController> get(String url) async {
    if (_map.containsKey(url)) return _map[url]!;

    if (_map.length >= maxSize) {
      final key = _map.keys.first;
      await _map[key]!.dispose();
      _map.remove(key);
    }

    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    await c.initialize();
    c.setLooping(true);

    _map[url] = c;
    return c;
  }

  void disposeAll() {
    for (var c in _map.values) {
      c.dispose();
    }
    _map.clear();
  }
}

/// ================= USER CACHE =================
class UserCache {
  static final _cache = <String, String>{};

  static Future<String> getName(String userId) async {
    if (_cache.containsKey(userId)) return _cache[userId]!;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final name = doc.data()?['username'] ?? "User";
    _cache[userId] = name;
    return name;
  }
}

/// ================= MAIN FEED =================
class ReelsFeed extends StatefulWidget {
  const ReelsFeed({super.key});

  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> {
  final PageController _pageController = PageController();
  final VideoControllerPool _pool = VideoControllerPool();

  List<QueryDocumentSnapshot<Map<String, dynamic>>> reels = [];
  int currentIndex = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  Future<void> _loadReels() async {
    final snap = await FirebaseFirestore.instance
        .collection('reels')
        .orderBy('createdAt', descending: true)
        .limit(10) // pagination
        .get();

    setState(() {
      reels = snap.docs;
      loading = false;
    });

    _preload(0);
  }

  void _preload(int index) {
    for (int i = index - 1; i <= index + 1; i++) {
      if (i >= 0 && i < reels.length) {
        final url = reels[i]['videoUrl'];
        _pool.get(url);
      }
    }
  }

  @override
  void dispose() {
    _pool.disposeAll();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: reels.length,
        onPageChanged: (i) {
          setState(() => currentIndex = i);
          _preload(i);
        },
        itemBuilder: (context, index) {
          final data = reels[index].data();

          return ReelItem(
            isActive: index == currentIndex,
            pool: _pool,
            videoUrl: data['videoUrl'],
            caption: data['caption'] ?? '',
            userId: data['userId'] ?? '',
          );
        },
      ),
    );
  }
}

/// ================= REEL ITEM =================
class ReelItem extends StatefulWidget {
  final bool isActive;
  final String videoUrl;
  final String caption;
  final String userId;
  final VideoControllerPool pool;

  const ReelItem({
    super.key,
    required this.isActive,
    required this.videoUrl,
    required this.caption,
    required this.userId,
    required this.pool,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  VideoPlayerController? _controller;
  bool liked = false;
  bool showHeart = false;
  bool showPlay = false;
  String username = "";

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _controller = await widget.pool.get(widget.videoUrl);
    if (widget.isActive) _controller!.play();

    username = await UserCache.getName(widget.userId);

    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    /// URL guard
    if (oldWidget.videoUrl != widget.videoUrl) {
      _init();
      return;
    }

    if (widget.isActive) {
      _controller?.play();
    } else {
      _controller?.pause();
    }
  }

  void _togglePlay() {
    if (_controller == null) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      showPlay = true;
    } else {
      _controller!.play();
      showPlay = false;
    }
    setState(() {});
  }

  void _doubleTap() {
    liked = true;
    showHeart = true;

    setState(() {});

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        showHeart = false;
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    final isBuffering = _controller!.value.isBuffering;

    return GestureDetector(
      onTap: _togglePlay,
      onDoubleTap: _doubleTap,
      child: Stack(
        children: [
          /// VIDEO
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),

          /// BUFFERING
          if (isBuffering)
            const Center(
                child: CircularProgressIndicator(color: Colors.white)),

          /// PLAY ICON
          if (showPlay)
            const Center(
              child: Icon(Icons.play_arrow,
                  size: 80, color: Colors.white),
            ),

          /// HEART
          if (showHeart)
            const Center(
              child:
              Icon(Icons.favorite, size: 100, color: Colors.white),
            ),

          /// GRADIENT
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          /// RIGHT SIDE BUTTONS
          Positioned(
            right: 10,
            bottom: 100,
            child: Column(
              children: [
                IconButton(
                  icon: Icon(Icons.favorite,
                      color: liked ? Colors.red : Colors.white,
                      size: 30),
                  onPressed: () {
                    setState(() => liked = !liked);
                  },
                ),
                const SizedBox(height: 16),
                const Icon(Icons.comment,
                    color: Colors.white, size: 28),
                const SizedBox(height: 16),
                const Icon(Icons.share,
                    color: Colors.white, size: 28),
              ],
            ),
          ),

          /// USER + CAPTION
          Positioned(
            left: 12,
            bottom: 40,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("@$username",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),

                const SizedBox(height: 6),

                Text(widget.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                    const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}