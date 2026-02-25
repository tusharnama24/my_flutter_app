import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:halo/services/reel_service.dart';

/// Full-screen vertical reels feed ranked by virality score.
class ReelsFeed extends StatefulWidget {
  const ReelsFeed({super.key});

  @override
  State<ReelsFeed> createState() => _ReelsFeedState();
}

class _ReelsFeedState extends State<ReelsFeed> {
  final ReelService _reelService = ReelService();
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _reelService.getRankedReelsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final reels = snapshot.data ?? [];
          if (reels.isEmpty) {
            return const Center(
              child: Text(
                'No reels yet',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            itemBuilder: (context, index) {
              final doc = reels[index];
              final data = doc.data();
              final videoUrl = (data['videoUrl'] ?? data['url'] ?? data['mediaUrl'] ?? '')
                  .toString()
                  .trim();
              final caption = (data['caption'] ?? '').toString();
              final userId = (data['userId'] ?? '').toString();

              return _ReelPage(
                reelId: doc.id,
                videoUrl: videoUrl,
                caption: caption,
                userId: userId,
                data: data,
              );
            },
          );
        },
      ),
    );
  }
}

class _ReelPage extends StatefulWidget {
  final String reelId;
  final String videoUrl;
  final String caption;
  final String userId;
  final Map<String, dynamic> data;

  const _ReelPage({
    required this.reelId,
    required this.videoUrl,
    required this.caption,
    required this.userId,
    required this.data,
  });

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.videoUrl.isNotEmpty)
          _ReelVideoPlayer(url: widget.videoUrl)
        else
          const Center(
            child: Icon(Icons.videocam_off, color: Colors.white38, size: 64),
          ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.userId.isNotEmpty)
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.userId)
                      .get(),
                  builder: (context, snap) {
                    final name = snap.hasData && snap.data!.exists
                        ? (snap.data!.data()?['username'] ??
                            snap.data!.data()?['name'] ??
                            snap.data!.data()?['full_name'] ??
                            'User')
                        : 'User';
                    return Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
              if (widget.caption.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReelVideoPlayer extends StatefulWidget {
  final String url;

  const _ReelVideoPlayer({required this.url});

  @override
  State<_ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<_ReelVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    if (widget.url.isEmpty) {
      setState(() => _error = true);
      return;
    }
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        _controller!..setLooping(true)..play();
        setState(() => _initialized = true);
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _error = true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Center(
        child: Icon(Icons.videocam_off, color: Colors.white38, size: 64),
      );
    }
    if (!_initialized || _controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white54));
    }
    final c = _controller!;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: c.value.size.width,
        height: c.value.size.height,
        child: VideoPlayer(c),
      ),
    );
  }
}
