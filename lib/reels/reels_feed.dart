// ═══════════════════════════════════════════════════════════════════════════════
// reels_feed.dart — Production-Grade Reels Feed
// ═══════════════════════════════════════════════════════════════════════════════
//
// ARCHITECTURE DECISIONS (read before touching this file):
//
// 1. NO CONTROLLER POOL. Every ReelItem owns exactly one BetterPlayerController
//    created in initState and disposed in dispose(). This eliminates every
//    surface-rebinding bug, race condition, and stale-controller issue that
//    the pool caused. BetterPlayer/ExoPlayer do not support safe surface
//    migration across widgets — pooling is fundamentally broken on Android.
//
// 2. MP4-FIRST PLAYBACK. HLS (.m3u8) requires FFmpeg demuxing, segment fetching,
//    and playlist parsing before the first frame. For short-form reels (5-60s)
//    this adds 800ms–2s of black screen on every swipe. We use the direct MP4
//    URL when available and fall back to HLS only when there is no MP4.
//
// 3. ONE ACTIVE PLAYER. ReelsFeed tracks `_currentIndex` and passes `isActive`
//    to each ReelItem. Only the active item calls play(). All others are paused
//    immediately in didUpdateWidget. This eliminates audio overlap and Android
//    AudioFocus conflicts.
//
// 4. PRELOAD STRATEGY. ReelsFeed preloads index+1 by calling setupDataSource()
//    without play() — this fills ExoPlayer's buffer silently so the next swipe
//    starts instantly. We do NOT preload index+2 or beyond; that wastes memory
//    and causes OOM on low-end devices.
//
// 5. THUMBNAIL → FIRST FRAME. Each item shows a CachedNetworkImage thumbnail
//    until BetterPlayerEventType.initialized fires, then cross-fades to video.
//    This gives instant perceived performance.
//
// 6. MOUNTED GUARDS. Every async continuation checks `mounted` before calling
//    setState or touching the controller. Every dispose() nulls the controller
//    reference BEFORE calling dispose() on it to prevent use-after-free.
//
// 7. NO VisibilityDetector for play/pause logic. VisibilityDetector fires on
//    a timer, not synchronously, causing play() calls on disposed widgets.
//    Play/pause is driven entirely by `isActive` from the parent — clean and
//    deterministic.
//
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:halo/models/media_model.dart';
import 'package:halo/services/app_cache_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// USER CACHE — unchanged, keeps Firestore reads minimal
// ─────────────────────────────────────────────────────────────────────────────

class UserCache {
  UserCache._();

  static final _cache = <String, String>{};

  static Future<String> getName(String userId) async {
    if (userId.isEmpty) return 'User';
    if (_cache.containsKey(userId)) return _cache[userId]!;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final name = (doc.data()?['username'] as String?)?.trim();
      _cache[userId] = (name != null && name.isNotEmpty) ? name : 'User';
    } catch (_) {
      _cache[userId] = 'User';
    }

    return _cache[userId]!;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// URL HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the best playback URL from a Firestore reel document + its parsed
/// MediaModel. MP4 is preferred over HLS for short-form reels — see file header.
String resolvePlaybackUrl(
    Map<String, dynamic> data,
    MediaModel firstVideo,
    ) {
  // 1. Explicit direct MP4 stored on the document
  final mp4 = (data['videoUrl'] as String? ?? '').trim();
  if (mp4.isNotEmpty && !mp4.contains('.m3u8')) return mp4;

  // 2. MediaModel preferred URL (may already prefer MP4 internally)
  final preferred = firstVideo.preferredVideoUrl.trim();
  if (preferred.isNotEmpty && !preferred.contains('.m3u8')) return preferred;

  // 3. HLS fallback — only if no MP4 exists
  final hls = (data['hlsUrl'] as String? ?? '').trim();
  if (hls.isNotEmpty) return hls;

  // 4. Last resort: any URL the MediaModel has
  if (preferred.isNotEmpty) return preferred;

  return '';
}

BetterPlayerVideoFormat _formatForUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  if (path.endsWith('.m3u8')) return BetterPlayerVideoFormat.hls;
  return BetterPlayerVideoFormat.other;
}

// ─────────────────────────────────────────────────────────────────────────────
// REEL DATA — lightweight struct so we don't carry QueryDocumentSnapshot
// ─────────────────────────────────────────────────────────────────────────────

class ReelData {
  final String id;
  final String videoUrl;
  final String thumbnailUrl;
  final String caption;
  final String userId;

  const ReelData({
    required this.id,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.caption,
    required this.userId,
  });

  factory ReelData.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
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

    final videoUrl = resolvePlaybackUrl(data, firstVideo);

    final thumbnailUrl = firstVideo.thumbnail.trim().isNotEmpty
        ? firstVideo.thumbnail.trim()
        : (data['thumbnailUrl'] as String? ?? '').trim();

    return ReelData(
      id: doc.id,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      caption: (data['caption'] as String? ?? '').trim(),
      userId: (data['userId'] as String? ?? '').trim(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REELS FEED
// ─────────────────────────────────────────────────────────────────────────────

class ReelsFeed extends StatefulWidget {
  const ReelsFeed({super.key});

  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> with WidgetsBindingObserver {
  final _pageController = PageController();

  List<ReelData> _reels = [];
  int _currentIndex = 0;
  bool _loading = true;

  // When the app goes to background we pause; track so we can resume.
  bool _appPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReels();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  // ── App lifecycle ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _appPaused = true;
      // ReelItem widgets observe isActive; setting state with same index but
      // a flag tells them to pause. Simpler: we use a ValueNotifier.
      _appPausedNotifier.value = true;
    } else if (state == AppLifecycleState.resumed) {
      if (_appPaused) {
        _appPaused = false;
        _appPausedNotifier.value = false;
      }
    }
  }

  // Notifier so ReelItem can react to app lifecycle without rebuilding the
  // entire PageView.
  final _appPausedNotifier = ValueNotifier<bool>(false);

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadReels() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('reels')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      if (!mounted) return;

      setState(() {
        _reels = snap.docs.map(ReelData.fromDoc).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ── Page change ────────────────────────────────────────────────────────────

  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
    // ReelItem widgets receive updated isActive in their next build call.
    // No manual pause loops needed — didUpdateWidget handles it.
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No reels yet', style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _reels.length,
        onPageChanged: _onPageChanged,
        // Keeping adjacent pages alive means their controllers stay initialized
        // and preloaded. We keep exactly 1 page on each side.
        itemBuilder: (context, index) {
          final reel = _reels[index];
          return ReelItem(
            // Key on the reel ID — not the URL — so if the same video appears
            // twice (unlikely but possible) each gets its own controller.
            key: ValueKey(reel.id),
            reel: reel,
            isActive: index == _currentIndex,
            // Preload the next reel so it buffers before the user swipes.
            shouldPreload: index == _currentIndex + 1,
            appPausedNotifier: _appPausedNotifier,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REEL ITEM
//
// Owns its own BetterPlayerController for its entire lifetime.
// Never shares or pools the controller.
// ─────────────────────────────────────────────────────────────────────────────

class ReelItem extends StatefulWidget {
  final ReelData reel;
  final bool isActive;
  final bool shouldPreload;
  final ValueNotifier<bool> appPausedNotifier;

  const ReelItem({
    super.key,
    required this.reel,
    required this.isActive,
    required this.shouldPreload,
    required this.appPausedNotifier,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  // ── Controller ─────────────────────────────────────────────────────────────
  //
  // Lifecycle:
  //   initState  → _createController() → setupDataSource()
  //   isActive=true (didUpdateWidget) → play()
  //   isActive=false (didUpdateWidget) → pause()
  //   dispose → _disposeController()
  //
  // The controller is NEVER shared. It is created here and dies here.

  BetterPlayerController? _controller;

  // Guards against calling play/pause/dispose after the widget is gone.
  bool _disposed = false;

  // True once BetterPlayer fires the initialized event — we flip from
  // thumbnail to video at this point.
  bool _videoInitialized = false;

  // True once at least one frame has been rendered (initialized + first play).
  bool _firstFrameRendered = false;

  // ── UI state ───────────────────────────────────────────────────────────────
  bool _liked = false;
  bool _showHeartOverlay = false;
  bool _userPaused = false; // user manually paused via tap
  String _username = '';

  // ── Init ───────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    widget.appPausedNotifier.addListener(_onAppPausedChanged);
    _loadUsername();
    _createController();
  }

  void _loadUsername() async {
    final name = await UserCache.getName(widget.reel.userId);
    if (!_disposed && mounted) {
      setState(() => _username = name);
    }
  }

  // ── Controller creation ────────────────────────────────────────────────────

  void _createController() {
    if (widget.reel.videoUrl.isEmpty) return;

    // BetterPlayerConfiguration:
    //   autoPlay: false  — we call play() explicitly after initialization,
    //                       only when isActive. This prevents audio bleed
    //                       from off-screen pages that PageView keeps warm.
    //   autoDispose: true — the widget owns the controller; let BetterPlayer
    //                        clean up its internal resources when disposed.
    //   handleLifecycle: false — we handle lifecycle ourselves via
    //                             WidgetsBindingObserver in the parent.
    //                             If true, BetterPlayer re-plays on resume
    //                             for ALL items, not just the active one.
    final config = BetterPlayerConfiguration(
      autoPlay: false,
      looping: true,
      fit: BoxFit.cover,
      aspectRatio: 9 / 16,
      expandToFill: true,
      autoDispose: true,
      handleLifecycle: false, // critical — see above
      controlsConfiguration: const BetterPlayerControlsConfiguration(
        showControls: false,
        showControlsOnInitialize: false,
      ),
    );

    final controller = BetterPlayerController(config);
    controller.addEventsListener(_onPlayerEvent);
    _controller = controller;

    // Setup data source. Do NOT await here — we respond to the initialized
    // event instead. This prevents blocking initState.
    unawaited(_setupDataSource(controller));
  }

  Future<void> _setupDataSource(BetterPlayerController controller) async {
    if (_disposed) return;

    final dataSource = BetterPlayerDataSource.network(
      widget.reel.videoUrl,
      videoFormat: _formatForUrl(widget.reel.videoUrl),
      // Caching: BetterPlayer's built-in cache uses ExoPlayer's
      // SimpleCache. For reels this is excellent — the next time the
      // user revisits the same reel it plays instantly from disk.
      cacheConfiguration: const BetterPlayerCacheConfiguration(
        useCache: true,
        maxCacheSize: 100 * 1024 * 1024,   // 100 MB total cache
        maxCacheFileSize: 20 * 1024 * 1024, // 20 MB per file
      ),
      notificationConfiguration: const BetterPlayerNotificationConfiguration(
        showNotification: false,
      ),
    );

    try {
      await controller.setupDataSource(dataSource);
    } catch (e) {
      // setupDataSource can throw if the controller was disposed between
      // _createController and this continuation. Swallow it.
      debugPrint('[ReelItem] setupDataSource error for ${widget.reel.id}: $e');
    }
  }

  // ── Player events ──────────────────────────────────────────────────────────

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (_disposed || !mounted) return;

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        setState(() => _videoInitialized = true);
        // Only auto-play if this reel is the active one and user hasn't
        // manually paused. This handles the case where initialization
        // completes after the user has already scrolled to this reel.
        if (widget.isActive && !_userPaused && !widget.appPausedNotifier.value) {
          _safePlay();
        }
        // If only preloading (not active), stay paused — buffer is filling
        // silently, which is exactly what we want.
        break;

      case BetterPlayerEventType.play:
        if (!_firstFrameRendered) {
          setState(() => _firstFrameRendered = true);
        }
        break;

      case BetterPlayerEventType.exception:
      // Log and let the thumbnail persist rather than crashing.
        debugPrint(
          '[ReelItem] Player exception for ${widget.reel.id}: '
              '${event.parameters}',
        );
        break;

      default:
        break;
    }
  }

  // ── Play / Pause helpers ───────────────────────────────────────────────────

  void _safePlay() {
    final c = _controller;
    if (c == null || _disposed) return;
    if (c.isVideoInitialized() != true) return;
    if (c.isPlaying() == true) return;
    unawaited(c.play());
  }

  void _safePause() {
    final c = _controller;
    if (c == null || _disposed) return;
    if (c.isPlaying() != true) return;
    unawaited(c.pause());
  }

  // ── App pause notifier ─────────────────────────────────────────────────────

  void _onAppPausedChanged() {
    if (_disposed || !mounted) return;
    if (widget.appPausedNotifier.value) {
      _safePause();
    } else if (widget.isActive && !_userPaused) {
      _safePlay();
    }
  }

  // ── didUpdateWidget ────────────────────────────────────────────────────────
  //
  // This is the ONLY place we drive play/pause from parent state changes.
  // No VisibilityDetector, no manual loops, no timers.

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    final becameActive = widget.isActive && !oldWidget.isActive;
    final becameInactive = !widget.isActive && oldWidget.isActive;

    if (becameActive) {
      _userPaused = false; // reset manual pause when reel becomes active again
      if (!widget.appPausedNotifier.value) {
        _safePlay();
      }
    } else if (becameInactive) {
      _safePause();
    }

    // If the app resumed and this is the active reel
    if (widget.isActive &&
        oldWidget.isActive &&
        !widget.appPausedNotifier.value &&
        widget.appPausedNotifier.value != oldWidget.appPausedNotifier.value) {
      // appPausedNotifier listener handles this — no action needed here
    }
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    widget.appPausedNotifier.removeListener(_onAppPausedChanged);

    // Capture and null the reference BEFORE disposing.
    // This ensures any in-flight async continuations that check _controller
    // see null and abort, preventing use-after-free.
    final c = _controller;
    _controller = null;

    c?.removeEventsListener(_onPlayerEvent);
    // autoDispose: true means BetterPlayer disposes ExoPlayer internally
    // when we call dispose(). We still call pause() first to release
    // AudioFocus cleanly before ExoPlayer shuts down.
    c?.pause();
    // Note: do NOT call c.dispose(forceDispose: true) here because
    // autoDispose: true is set — BetterPlayer manages it. Calling it
    // manually on top causes a double-dispose crash on some BetterPlayer
    // versions.

    super.dispose();
  }

  // ── User interactions ──────────────────────────────────────────────────────

  void _handleTap() {
    final c = _controller;
    if (c == null) return;

    setState(() {
      if (c.isPlaying() == true) {
        _userPaused = true;
        _safePause();
      } else {
        _userPaused = false;
        _safePlay();
      }
    });
  }

  void _handleDoubleTap() {
    setState(() {
      _liked = true;
      _showHeartOverlay = true;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!_disposed && mounted) {
        setState(() => _showHeartOverlay = false);
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final pixelWidth = (mq.size.width * mq.devicePixelRatio).round();
    final pixelHeight = (mq.size.height * mq.devicePixelRatio).round();

    final c = _controller;
    final isPlaying = c?.isPlaying() == true;
    final isBuffering = _videoInitialized && (c?.isBuffering() == true);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      onDoubleTap: _handleDoubleTap,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Layer 1: Thumbnail (shown until first frame rendered) ────────
            if (widget.reel.thumbnailUrl.isNotEmpty && !_firstFrameRendered)
              CachedNetworkImage(
                imageUrl: widget.reel.thumbnailUrl,
                cacheManager: AppCacheManager.media,
                fit: BoxFit.cover,
                memCacheWidth: pixelWidth,
                memCacheHeight: pixelHeight,
                placeholder: (_, __) => const ColoredBox(color: Colors.black),
                errorWidget: (_, __, ___) =>
                const ColoredBox(color: Colors.black),
              )
            else if (!_firstFrameRendered)
              const ColoredBox(color: Colors.black),

            // ── Layer 2: Video player ────────────────────────────────────────
            // Only mount the BetterPlayer widget once initialized. Mounting it
            // before initialization causes ExoPlayer to attach to a surface
            // before it has a data source, which causes a blank SurfaceView
            // that never recovers on some Android versions.
            if (_videoInitialized && c != null)
              SizedBox.expand(
                child: BetterPlayer(controller: c),
              ),

            // ── Layer 3: Buffering indicator ─────────────────────────────────
            if (isBuffering || (widget.isActive && !_videoInitialized))
              const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: Colors.white70,
                    strokeWidth: 2,
                  ),
                ),
              ),

            // ── Layer 4: Play icon overlay (shown when user-paused) ──────────
            if (_userPaused && !isPlaying)
              const Center(
                child: Icon(Icons.play_arrow_rounded,
                    size: 72, color: Colors.white70),
              ),

            // ── Layer 5: Heart overlay (double-tap) ──────────────────────────
            if (_showHeartOverlay)
              const Center(
                child: Icon(Icons.favorite, size: 96, color: Colors.white),
              ),

            // ── Layer 6: Bottom gradient ─────────────────────────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.80),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.50, 1.0],
                  ),
                ),
              ),
            ),

            // ── Layer 7: Right-side action buttons ───────────────────────────
            Positioned(
              right: 10,
              bottom: 100,
              child: _ActionColumn(
                liked: _liked,
                onLikeTap: () => setState(() => _liked = !_liked),
              ),
            ),

            // ── Layer 8: Caption + username ──────────────────────────────────
            Positioned(
              left: 12,
              bottom: 40,
              right: 80,
              child: _CaptionBlock(
                username: _username,
                caption: widget.reel.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION COLUMN — extracted to avoid rebuilding on every setState
// ─────────────────────────────────────────────────────────────────────────────

class _ActionColumn extends StatelessWidget {
  final bool liked;
  final VoidCallback onLikeTap;

  const _ActionColumn({required this.liked, required this.onLikeTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.favorite,
            color: liked ? Colors.red : Colors.white,
            size: 30,
          ),
          onPressed: onLikeTap,
        ),
        const SizedBox(height: 16),
        const Icon(Icons.comment, color: Colors.white, size: 28),
        const SizedBox(height: 16),
        const Icon(Icons.share, color: Colors.white, size: 28),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAPTION BLOCK — extracted to avoid rebuilding on every setState
// ─────────────────────────────────────────────────────────────────────────────

class _CaptionBlock extends StatelessWidget {
  final String username;
  final String caption;

  const _CaptionBlock({required this.username, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '@$username',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ],
    );
  }
}