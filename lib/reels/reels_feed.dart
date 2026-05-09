import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/models/media_model.dart';
import 'package:halo/services/app_cache_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONTROLLER POOL — BetterPlayer + HLS (.m3u8), MP4 fallback via videoFormat
// Preload is fire-and-forget; getReady / getOrInit attach for instant playback.
// autoDispose: false so widgets can detach without killing pooled controllers.
// ─────────────────────────────────────────────────────────────────────────────

class VideoControllerPool {
  final int maxSize;
  final _map = <String, BetterPlayerController>{};

  VideoControllerPool({this.maxSize = 4});

  // 🔥 safer HLS detection
  static BetterPlayerVideoFormat _videoFormatForUrl(String url) {
    final path = Uri.parse(url).path.toLowerCase();
    if (path.endsWith('.m3u8')) return BetterPlayerVideoFormat.hls;
    return BetterPlayerVideoFormat.other;
  }

  static BetterPlayerConfiguration _reelConfiguration() {
    return BetterPlayerConfiguration(
      autoPlay: false,
      looping: true,
      fit: BoxFit.cover,
      aspectRatio: 9 / 16,
      expandToFill: true,
      autoDispose: false,
      handleLifecycle: false,
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        showControls: false,
        showControlsOnInitialize: false,
      ),
    );
  }

  BetterPlayerDataSource _dataSource(String url) {
    return BetterPlayerDataSource.network(
      url,
      videoFormat: _videoFormatForUrl(url),
      notificationConfiguration: const BetterPlayerNotificationConfiguration(
        showNotification: false,
      ),
    );
  }

  Future<void> preload(String url) async {
    if (url.trim().isEmpty) return;
    if (_map.containsKey(url)) return;

    _evictIfNeeded();

    final c = BetterPlayerController(_reelConfiguration());
    _map[url] = c;

    try {
      await c.setupDataSource(_dataSource(url));
      await c.setLooping(true);
    } catch (_) {
      c.dispose(forceDispose: true);
      _map.remove(url);
    }
  }

  BetterPlayerController? getReady(String url) {
    final c = _map[url];
    if (c != null && c.isVideoInitialized() == true) return c;
    return null;
  }

  // 🔥 FIXED: never return uninitialized controller
  Future<BetterPlayerController?> getOrInit(String url) async {
    if (url.trim().isEmpty) return null;

    var existing = _map[url];

    if (existing != null && existing.isVideoInitialized() == true) {
      return existing;
    }

    if (existing == null) {
      await preload(url);
    }

    final deadline = DateTime.now().add(const Duration(milliseconds: 300));

    while (DateTime.now().isBefore(deadline)) {
      existing = _map[url];

      if (existing != null && existing.isVideoInitialized() == true) {
        return existing;
      }

      await Future.delayed(const Duration(milliseconds: 16));
    }

    // ❌ DO NOT return unready controller
    final c = _map[url];
    if (c != null && c.isVideoInitialized() == true) {
      return c;
    }

    return null;
  }

  // 🔥 FIXED: safe eviction (don’t kill active videos)
  void _evictIfNeeded() {
    final candidates = _map.keys
        .where((k) => _map[k]?.isPlaying() != true)
        .toList(growable: false);

    var i = 0;

    // ✅ First remove non-playing controllers
    while (_map.length >= maxSize && i < candidates.length) {
      final key = candidates[i++];

      _map[key]?.pause();
      _map[key]?.dispose(forceDispose: true);
      _map.remove(key);
    }

    // 🔥 CRITICAL: fallback if still full (prevents freeze)
    while (_map.length >= maxSize) {
      final oldest = _map.keys.first;

      _map[oldest]?.pause();
      _map[oldest]?.dispose(forceDispose: true);
      _map.remove(oldest);
    }
  }

  void trimTo(Set<String> keepUrls) {
    if (_map.length <= maxSize) return;

    final removable = _map.keys
        .where((k) => !keepUrls.contains(k))
        .toList(growable: false);

    var i = 0;

    // ✅ Remove non-playing first
    while (_map.length > maxSize && i < removable.length) {
      final key = removable[i++];
      final c = _map[key];

      if (c != null && c.isPlaying() == true) continue;

      c?.pause();
      c?.dispose(forceDispose: true);
      _map.remove(key);
    }

    // 🔥 fallback (rare but safe)
    while (_map.length > maxSize) {
      final oldest = _map.keys.first;

      _map[oldest]?.pause();
      _map[oldest]?.dispose(forceDispose: true);
      _map.remove(oldest);
    }
  }

  bool isReady(String url) {
    final c = _map[url];
    return c != null && c.isVideoInitialized() == true;
  }

  void disposeAll() {
    for (final c in _map.values) {
      c.pause();
      c.dispose(forceDispose: true);
    }
    _map.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER CACHE
// ─────────────────────────────────────────────────────────────────────────────

class UserCache {
  static final _cache = <String, String>{};

  static Future<String> getName(String userId) async {
    if (_cache.containsKey(userId)) return _cache[userId]!;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final name = doc.data()?['username'] ?? 'User';
    _cache[userId] = name;
    return name;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN FEED
// ─────────────────────────────────────────────────────────────────────────────

class ReelsFeed extends StatefulWidget {
  const ReelsFeed({super.key});

  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> {
  final PageController _pageController = PageController();
  final VideoControllerPool _pool = VideoControllerPool(maxSize: 4);

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
        .limit(10)
        .get();

    setState(() {
      reels = snap.docs;
      loading = false;
    });

    _preloadAround(0);
  }

  /// HLS first (document + media), then progressive MP4 fallback.
  String _playbackUrl(Map<String, dynamic> data, MediaModel firstVideo) {
    final direct =
        (data['hlsUrl'] ?? data['videoUrl'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    if (firstVideo.preferredVideoUrl.isNotEmpty) {
      return firstVideo.preferredVideoUrl;
    }
    return '';
  }

  String _urlForIndex(int index) {
    if (index < 0 || index >= reels.length) return '';
    final data = reels[index].data();
    final media = MediaModel.parsePostMedia(data);
    final firstVideo = media.firstWhere(
      (m) => m.isVideo,
      orElse: () => const MediaModel(
        type: 'video',
        image: MediaVariant(thumb: '', medium: '', full: ''),
        videoUrl: '',
        hlsUrl: '',
        thumbnail: '',
      ),
    );
    return _playbackUrl(data, firstVideo).trim();
  }

  void _preloadAround(int index) {
    final indicesToPreload = <int>{
      index,
      index + 1,
      index + 2,
      index - 1,
    };

    final keepUrls = indicesToPreload
        .map(_urlForIndex)
        .where((u) => u.isNotEmpty)
        .toSet();
    _pool.trimTo(keepUrls);

    for (final idx in indicesToPreload) {
      final url = _urlForIndex(idx);
      if (url.isNotEmpty && !_pool.isReady(url)) {
        unawaited(_pool.preload(url));
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
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
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
          _preloadAround(i);
        },
        itemBuilder: (context, index) {
          final data = reels[index].data();
          final media = MediaModel.parsePostMedia(data);
          final firstVideo = media.firstWhere(
            (m) => m.isVideo,
            orElse: () => const MediaModel(
              type: 'video',
              image: MediaVariant(thumb: '', medium: '', full: ''),
              videoUrl: '',
              hlsUrl: '',
              thumbnail: '',
            ),
          );
          final videoUrl = _playbackUrl(data, firstVideo);
          final thumbnailUrl = firstVideo.thumbnail.isNotEmpty
              ? firstVideo.thumbnail
              : (data['thumbnailUrl'] ?? '').toString();

          return ReelItem(
            key: ValueKey(videoUrl),
            isActive: index == currentIndex,
            pool: _pool,
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl,
            caption: data['caption'] ?? '',
            userId: data['userId'] ?? '',
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REEL ITEM — BetterPlayer surface, thumbnail until first decoded progress
// ─────────────────────────────────────────────────────────────────────────────

class ReelItem extends StatefulWidget {
  final bool isActive;
  final String videoUrl;
  final String thumbnailUrl;
  final String caption;
  final String userId;
  final VideoControllerPool pool;

  const ReelItem({
    super.key,
    required this.isActive,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.caption,
    required this.userId,
    required this.pool,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  BetterPlayerController? _controller;
  bool _initializing = false;
  bool _firstFrameShown = false;
  bool liked = false;
  bool showHeart = false;
  bool showPlay = false;
  String username = '';

  void _onBetterPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
      case BetterPlayerEventType.play:
        if (!_firstFrameShown &&
            _controller?.isVideoInitialized() == true) {
          _firstFrameShown = true;
          setState(() {});
        }
        break;

      default:
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _maybeInit();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final name = await UserCache.getName(widget.userId);
    if (mounted) setState(() => username = name);
  }

  void _maybeInit() {
    if (widget.videoUrl.trim().isEmpty) return;
    if (_controller != null || _initializing) return;

    final ready = widget.pool.getReady(widget.videoUrl);
    if (ready != null) {
      _attachController(ready);
      return;
    }

    if (!widget.pool.isReady(widget.videoUrl)) {
      unawaited(widget.pool.preload(widget.videoUrl));
    }

    if (widget.isActive) {
      _initFallback();
    }
  }

  void _attachController(BetterPlayerController c) {
    if (_controller == c) return;

    _controller?.removeEventsListener(_onBetterPlayerEvent);

    _controller = c;
    c.addEventsListener(_onBetterPlayerEvent);

    if (widget.isActive && c.isPlaying() != true) {
      unawaited(c.play());
    }

    if (mounted) setState(() {});
  }

  Future<void> _initFallback() async {
    if (_initializing || _controller != null) return;

    _initializing = true;
    try {
      final c = await widget.pool.getOrInit(widget.videoUrl);
      if (!mounted || c == null) return;
      if (_controller != null) {
        if (widget.isActive && _controller!.isPlaying() != true) {
          unawaited(_controller!.play());
        }
        return;
      }
      _attachController(c);
    } finally {
      _initializing = false;
    }
  }

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.removeEventsListener(_onBetterPlayerEvent);
      _controller?.pause();
      _controller = null;
      _firstFrameShown = false;
      _initializing = false;
      _maybeInit();
      return;
    }

    if (widget.isActive && !oldWidget.isActive) {
      final ready = widget.pool.getReady(widget.videoUrl);
      if (ready != null && _controller == null) {
        _attachController(ready);
      } else if (_controller == null) {
        _initFallback();
      } else {
        unawaited(_controller!.play());
      }
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller?.pause();
    }

    if (_controller != null) {
      if (widget.isActive && _controller!.isPlaying() != true) {
        unawaited(_controller!.play());
      } else if (!widget.isActive && _controller!.isPlaying() == true) {
        _controller!.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeEventsListener(_onBetterPlayerEvent);
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.isPlaying() == true) {
        _controller!.pause();
        showPlay = true;
      } else {
        unawaited(_controller!.play());
        showPlay = false;
      }
    });
  }

  void _doubleTap() {
    setState(() {
      liked = true;
      showHeart = true;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final decodeW = (mq.size.width * mq.devicePixelRatio).round();
    final decodeH = (mq.size.height * mq.devicePixelRatio).round();

    final isReady =
        _controller != null && _controller!.isVideoInitialized() == true;
    final isBuffering = isReady && (_controller!.isBuffering() == true);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      onDoubleTap: _doubleTap,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.thumbnailUrl.trim().isNotEmpty && !_firstFrameShown)
              CachedNetworkImage(
                imageUrl: widget.thumbnailUrl.trim(),
                cacheManager: AppCacheManager.media,
                fit: BoxFit.cover,
                memCacheWidth: decodeW,
                memCacheHeight: decodeH,
                placeholder: (_, __) => const ColoredBox(color: Colors.black),
                errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
              )
            else if (!isReady)
              const ColoredBox(color: Colors.black),

            if (isReady)
              SizedBox.expand(
                child: BetterPlayer(controller: _controller!),
              ),

            if (isBuffering)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),

            if (widget.isActive && !isReady)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white70,
                  strokeWidth: 2,
                ),
              ),

            if (showPlay)
              const Center(
                child: Icon(Icons.play_arrow, size: 80, color: Colors.white70),
              ),

            if (showHeart)
              const Center(
                child: Icon(Icons.favorite, size: 100, color: Colors.white),
              ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),

            Positioned(
              right: 10,
              bottom: 100,
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.favorite,
                      color: liked ? Colors.red : Colors.white,
                      size: 30,
                    ),
                    onPressed: () => setState(() => liked = !liked),
                  ),
                  const SizedBox(height: 16),
                  const Icon(Icons.comment, color: Colors.white, size: 28),
                  const SizedBox(height: 16),
                  const Icon(Icons.share, color: Colors.white, size: 28),
                ],
              ),
            ),

            Positioned(
              left: 12,
              bottom: 40,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@$username',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
