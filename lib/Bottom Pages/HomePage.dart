// HomePage.dart — Instagram-style feed for Halo
// All bugs fixed — see fix comments tagged [FIX-n]

import 'package:halo/Bottom%20Pages/AddPostPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:halo/chat/chat_list_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:halo/Profile%20Pages/wellness_profile_page.dart'
as wellness_profile;
import 'package:halo/interest_selection_page.dart';
import 'package:halo/services/story_service.dart';
import 'package:halo/models/story_model.dart';
import 'package:halo/story/story_viewer_page.dart';
import 'package:halo/story/story_upload_sheet.dart';

import 'package:halo/Profile%20Pages/aspirant_profile_page.dart'
as aspirant_profile;
import 'package:halo/Profile%20Pages/guru_profile_page.dart'
as guru_profile;

import 'package:halo/services/feed_service.dart';
import 'package:halo/widgets/save_button.dart';
import 'package:halo/services/save_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'NotificationPage.dart';
import 'SearchPage.dart';
import 'ExplorePage.dart';
import 'SettingsPage.dart';
import 'saved_posts_page.dart';

// ---- THEME COLORS ----
const Color kPrimaryColor = Color(0xFFA58CE3);
const Color kSecondaryColor = Color(0xFF5B3FA3);
const Color kBackgroundColor = Color(0xFFF4F1FB);

const Color kIgPrimaryText = Color(0xFF262626);
const Color kIgSecondaryText = Color(0xFF8E8E8E);
const Color kIgLikeRed = Color(0xFFED4956);
const Color kIgPostBackground = Colors.white;

String _profilePhotoUrlFromUser(Map<String, dynamic>? data) {
  if (data == null) return '';
  final v = data['profilePhoto'] ??
      data['photoURL'] ??
      data['profile_photo'] ??
      data['avatar'];
  if (v == null) return '';
  final s = v.toString().trim();
  return s.isEmpty ? '' : s;
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

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
  GlobalKey<RefreshIndicatorState>();
  final FeedService _feedService = FeedService();

  bool _promptedLocation = false;
  List<String> _interests = const [];
  int _feedTabIndex = 0;
  String _contentPreference = '';

  int _feedRefreshKey = 0;
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _feedStream;

  // [FIX-7] Store SaveService stream and BottomNav user stream in state —
  // never create streams inside build() because each call creates a new
  // subscription and defeats StreamBuilder's internal caching.
  late final Stream<Map<String, dynamic>> _savedPostsStream;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream;

  // [FIX-4] Cache accountType so the BottomNav profile tap doesn't need
  // a Firestore read on every press.
  String _accountType = 'aspirant';
  String _userProfileUrl = '';

  @override
  void initState() {
    super.initState();
    _initFeedStream();
    _initSideStreams();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptForLocation();
    });
    _loadInterests();
  }

  // [FIX-7] Streams are created once here, not in build().
  void _initSideStreams() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _savedPostsStream = uid.isNotEmpty
        ? SaveService().savedPostsStream(uid)
        : const Stream.empty();

    if (uid.isNotEmpty) {
      _userDocStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
      // [FIX-4] Listen once to cache accountType for profile navigation.
      _userDocStream.listen((snap) {
        if (!mounted) return;
        final data = snap.data();
        setState(() {
          _accountType =
              (data?['accountType'] as String?)?.toLowerCase() ?? 'aspirant';
          _userProfileUrl = _profilePhotoUrlFromUser(data);
        });
      });
    } else {
      _userDocStream = const Stream.empty();
    }
  }

  void _initFeedStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _feedStream = _feedService.getRankedFeedStream(
      currentUserId: uid,
      // [FIX-11] _contentPreference is wired; extend FeedService to filter
      // by following when _feedTabIndex == 1.
      userPreference: _contentPreference,
      followingOnly: _feedTabIndex == 1,
    );
  }

  Future<void> _loadInterests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final interests = prefs.getStringList('user_interests') ?? const [];
      if (!mounted) return;
      setState(() => _interests = interests);
    } catch (_) {}
  }

  Future<void> _maybePromptForLocation() async {
    if (_promptedLocation) return;
    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested = prefs.getBool('location_prompt_shown') ?? false;
    if (alreadyRequested) return;

    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) {
      await prefs.setBool('location_prompt_shown', true);
      return;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow Location Access'),
        content: const Text(
            'Halo uses your location to enhance discovery and local features.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final result = await Permission.locationWhenInUse.request();
              if (!mounted) return;
              if (result.isGranted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location permission granted')),
                );
              } else if (result.isPermanentlyDenied) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Location permission permanently denied. Open settings to enable.'),
                    action: SnackBarAction(
                        label: 'Settings', onPressed: openAppSettings),
                  ),
                );
              }
              await prefs.setBool('location_prompt_shown', true);
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    await prefs.setBool('location_prompt_shown', true);
  }

  // [FIX-13] Logout is now handled explicitly instead of falling through
  // to _showFeaturePlaceholder.
  Future<void> _onMenuAction(_HaloMenuAction action) async {
    switch (action) {
      case _HaloMenuAction.home:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already on Home')),
        );
        return;
      case _HaloMenuAction.feed:
        if (!mounted) return;
        setState(() {
          _feedTabIndex = 0;
          _feedRefreshKey++;
          _initFeedStream();
        });
        return;
      case _HaloMenuAction.premium:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SavedPostsPage()),
        );
        return;
      case _HaloMenuAction.wellness:
        if (!mounted) return;
        _openMyProfile();
        return;
      case _HaloMenuAction.challenges:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const InterestSelectionPage(isFromSettings: true),
          ),
        );
        if (!mounted) return;
        await _loadInterests();
        return;
      case _HaloMenuAction.profileSettings:
        if (!mounted) return;
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SettingsPage()),
        );
        if (!mounted) return;
        if (result == 'logout') {
          await _onMenuAction(_HaloMenuAction.logout);
        } else if (result == 'edit_profile') {
          _openMyProfile();
        }
        return;
      case _HaloMenuAction.events:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NotificationPage()),
        );
        return;
      case _HaloMenuAction.analytics:
        if (!mounted) return;
        _openMyProfile();
        return;
      case _HaloMenuAction.gurus:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SearchPage()),
        );
        return;
      case _HaloMenuAction.logout:
        try {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          // AuthGate listens to authStateChanges and will render LoginPage.
          Navigator.of(context).popUntil((route) => route.isFirst);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Sign-out failed: $e')));
        }
        return;
      case _HaloMenuAction.email:
        await _openSupportEmail();
        return;
      case _HaloMenuAction.share:
        await _shareAppLink();
        return;
      case _HaloMenuAction.customerCare:
        await _openCustomerCare();
        return;
      default:
        _showFeaturePlaceholder(action.name);
    }
  }

  void _showFeaturePlaceholder(String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature coming soon!')));
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri.parse(
      'mailto:support@haloapp.in?subject=${Uri.encodeComponent('Halo Support')}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app')),
      );
    }
  }

  Future<void> _shareAppLink() async {
    const appLink = 'https://haloapp.in';
    const message = 'Check out Halo: https://haloapp.in';
    await Clipboard.setData(const ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App link copied to clipboard')),
    );
    final uri = Uri.parse(
      'sms:?body=${Uri.encodeComponent('Check out Halo: $appLink')}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openCustomerCare() async {
    final phoneUri = Uri.parse('tel:+919999999999');
    final openedDialer = await launchUrl(
      phoneUri,
      mode: LaunchMode.externalApplication,
    );
    if (openedDialer || !mounted) return;
    await _openSupportEmail();
  }

  Widget _buildFeedSegmentedControl() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _buildFeedTab(0, 'For you'),
          _buildFeedTab(1, 'Following'),
        ],
      ),
    );
  }

  Widget _buildFeedTab(int index, String label) {
    final selected = _feedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        // [FIX-6] Switching tabs now re-creates the feed stream so the
        // "Following" tab actually shows different content.
        onTap: () {
          if (_feedTabIndex == index) return;
          setState(() {
            _feedTabIndex = index;
            _feedRefreshKey++;
            _initFeedStream();
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? kIgPrimaryText : kIgSecondaryText,
            ),
          ),
        ),
      ),
    );
  }

  // [FIX-3] Navigate to profile using cached _accountType — no Firestore
  // read at tap time.
  void _openMyProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to view profile')));
      return;
    }
    if (_accountType == 'wellness') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              wellness_profile.WellnessProfilePage(profileUserId: uid),
        ),
      );
    } else if (_accountType == 'guru') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => guru_profile.GuruProfilePage(profileUserId: uid),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              aspirant_profile.ProfilePage(profileUserId: uid),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: GestureDetector(
        // [FIX-14] Use push instead of pushReplacement so the back-stack
        // is preserved when opening chat via swipe or icon.
        onHorizontalDragEnd: (details) {
          if (details.velocity.pixelsPerSecond.dx < 0) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please sign in to use chat')));
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ChatListPage(currentUserId: uid)),
            );
          }
        },
        child: Scaffold(
          key: _scaffoldKey,
          drawer: _HaloDrawer(onSelect: _onMenuAction),
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(52.0),
            child: AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.black87),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: Text(
                'Halo',
                style: GoogleFonts.pacifico(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: kSecondaryColor),
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  tooltip: 'Edit interests',
                  icon: const Icon(Icons.tune, color: Colors.black87),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const InterestSelectionPage(
                              isFromSettings: true)),
                    );
                    if (!mounted) return;
                    await _loadInterests();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.forum, color: Colors.black87),
                  onPressed: () {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Please sign in to use chat')));
                      return;
                    }
                    // [FIX-14] push, not pushReplacement
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChatListPage(currentUserId: uid)),
                    );
                  },
                ),
              ],
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF5EDFF), Color(0xFFE8E4FF)],
                  ),
                ),
              ),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF5EDFF),
                  Color(0xFFE8E4FF),
                  kBackgroundColor,
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                key: _refreshKey,
                onRefresh: () async {
                  setState(() {
                    _feedRefreshKey++;
                    _initFeedStream();
                  });
                  await Future.delayed(const Duration(milliseconds: 400));
                },
                // [FIX-1] The SaveService stream is now stable (created in
                // initState). The outer StreamBuilder no longer wraps the
                // entire feed — savedPostsMap is passed directly to
                // _PostActions, preventing full-list rebuilds on save events.
                child: StreamBuilder<Map<String, dynamic>>(
                  stream: _savedPostsStream,
                  builder: (context, savedSnap) {
                    final savedPostsMap =
                        savedSnap.data ?? const <String, dynamic>{};
                    return StreamBuilder<
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                      key: ValueKey(_feedRefreshKey),
                      stream: _feedStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 8.0),
                            children: const [
                              _StoriesStrip(),
                              SizedBox(height: 12),
                              Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: CircularProgressIndicator(),
                                  )),
                            ],
                          );
                        }
                        if (snapshot.hasError) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 8.0),
                            children: [
                              const _StoriesStrip(),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                    'Error loading posts: ${snapshot.error}'),
                              ),
                            ],
                          );
                        }

                        final rankedDocs = snapshot.data ?? [];
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>
                        filtered = rankedDocs;

                        if (_interests.isNotEmpty) {
                          filtered = rankedDocs.where((d) {
                            final data = d.data();
                            final accountType =
                            (data['accountType'] ?? '').toString().toLowerCase();

                            if (accountType == 'guru') return true;

                            final tags = (data['tags'] as List?)
                                ?.map((e) => e.toString())
                                .toList() ?? [];

                            // ✅ allow posts without tags
                            if (tags.isEmpty) return true;

                            return tags.any((t) => _interests.contains(t));
                          }).toList();
                        }

                        final hasPosts = filtered.isNotEmpty;
                        const headerCount = 2;
                        final emptyStateCount = hasPosts ? 0 : 1;
                        final totalCount =
                            headerCount + filtered.length + emptyStateCount;

                        return ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 8.0),
                          itemCount: totalCount,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return const Column(
                                children: [
                                  _StoriesStrip(),
                                  SizedBox(height: 12),
                                ],
                              );
                            }
                            if (index == 1) {
                              return Column(
                                children: [
                                  _buildFeedSegmentedControl(),
                                  const SizedBox(height: 8),
                                ],
                              );
                            }
                            if (!hasPosts) {
                              return Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.inbox_outlined,
                                        size: 40,
                                        color: Colors.grey.shade500),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No posts yet',
                                      style: textTheme.titleMedium?.copyWith(
                                          color: Colors.grey.shade700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Follow more people or add your first post.',
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodySmall?.copyWith(
                                          color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final feedIndex = index - headerCount;
                            final data = filtered[feedIndex].data();
                            final media =
                                (data['media'] as List?)?.cast<dynamic>() ??
                                    const [];
                            final images = List<String>.from(
                                data['images'] ?? const []);
                            final imageUrl =
                                (data['imageUrl'] as String?)?.trim() ?? '';
                            final caption =
                            (data['caption'] ?? '').toString();
                            final location =
                            (data['location'] ?? '').toString();
                            final createdAt =
                            data['createdAt'] as Timestamp?;
                            final createdText = createdAt != null
                                ? createdAt
                                .toDate()
                                .toLocal()
                                .toString()
                                .substring(0, 16)
                                : '';
                            final userId =
                            (data['userId'] ?? '').toString();

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0, vertical: 6.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: kIgPostBackground,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                      Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      userId.isNotEmpty
                                          ? _PostUserHeader(
                                        userId: userId,
                                        subtitle: location.isNotEmpty
                                            ? location
                                            : createdText,
                                      )
                                          : _PostHeader(
                                        username: 'User',
                                        profilePhotoUrl: '',
                                        subtitle: location.isNotEmpty
                                            ? location
                                            : createdText,
                                        onTap: null,
                                      ),
                                      _DoubleTapHeartOverlay(
                                        postId: filtered[feedIndex].id,
                                        child: media.isNotEmpty
                                            ? _PostMedia(
                                          media: media,
                                          onVideoTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ExplorePage(
                                                      openReelsOnStart:
                                                      true,
                                                      initialReelPostId:
                                                      filtered[feedIndex]
                                                          .id,
                                                    ),
                                              ),
                                            );
                                          },
                                        )
                                            : (images.isNotEmpty &&
                                            images.first
                                                .trim()
                                                .isNotEmpty
                                            ? _PostImage(
                                            url: images.first)
                                            : imageUrl
                                            .trim()
                                            .isNotEmpty
                                            ? _PostImage(
                                            url: imageUrl)
                                            : const SizedBox
                                            .shrink()),
                                      ),
                                      _PostActions(
                                        postId: filtered[feedIndex].id,
                                        savedPostsMap: savedPostsMap,
                                      ),
                                      if (caption.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 16.0,
                                              vertical: 10.0),
                                          child: Text(
                                            caption,
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                              color: kIgPrimaryText,
                                              fontSize: 15,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          // [FIX-8] BottomNav no longer has a StreamBuilder — user data is
          // already cached in _userProfileUrl and _accountType via the
          // listener set up in _initSideStreams().
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: 0,
            backgroundColor: Colors.white,
            elevation: 12,
            selectedItemColor: kSecondaryColor,
            unselectedItemColor: Colors.grey.shade500,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            onTap: (index) {
              if (index == 0) return;
              if (index == 1) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => SearchPage()));
              } else if (index == 2) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ExplorePage()));
              } else if (index == 3) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AddPostPage()));
              } else if (index == 4) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => NotificationPage()));
              } else if (index == 5) {
                // [FIX-4] No Firestore call — use cached _accountType
                _openMyProfile();
              }
            },
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded), label: ''),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.search_rounded), label: ''),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.explore_rounded), label: ''),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.add_box_outlined), label: ''),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_outline_rounded), label: ''),
              BottomNavigationBarItem(
                icon: CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.grey.shade200,
                  child: ClipOval(
                    child: _userProfileUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: _userProfileUrl,
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.grey),
                    )
                        : const Icon(Icons.person,
                        size: 16, color: Colors.grey),
                  ),
                ),
                label: '',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------- Post Header ----------------------

class _PostHeader extends StatelessWidget {
  final String username;
  final String profilePhotoUrl;
  final String subtitle;
  final VoidCallback? onTap;

  const _PostHeader({
    Key? key,
    required this.username,
    required this.profilePhotoUrl,
    required this.subtitle,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: GestureDetector(
        onTap: onTap,
        child: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade200,
          child: ClipOval(
            child: profilePhotoUrl.isNotEmpty
                ? CachedNetworkImage(
              imageUrl: profilePhotoUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Icon(Icons.person,
                  color: Colors.grey, size: 24),
              errorWidget: (_, __, ___) => Image.asset(
                  'assets/images/Profile.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover),
            )
                : Image.asset('assets/images/Profile.png',
                width: 40, height: 40, fit: BoxFit.cover),
          ),
        ),
      ),
      title: GestureDetector(
        onTap: onTap,
        child: Text(
          username,
          style: (textTheme.labelLarge ?? textTheme.bodyLarge)?.copyWith(
              fontWeight: FontWeight.w600,
              color: kIgPrimaryText,
              fontSize: 15),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall
            ?.copyWith(color: kIgSecondaryText, fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz_rounded),
        iconSize: 26,
        onPressed: () {},
      ),
      onTap: onTap,
    );
  }
}

// ---------------------- Post Image ----------------------

class _PostImage extends StatelessWidget {
  final String url;
  const _PostImage({Key? key, required this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      height: 300,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        height: 300,
        color: Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (_, __, ___) => Container(
        height: 300,
        color: Colors.grey[300],
        child: const Center(child: Icon(Icons.broken_image)),
      ),
    );
  }
}

// ---------------------- Stories Strip ----------------------

class _StoriesStrip extends StatefulWidget {
  const _StoriesStrip({Key? key}) : super(key: key);

  @override
  State<_StoriesStrip> createState() => _StoriesStripState();
}

class _StoriesStripState extends State<_StoriesStrip> {
  Stream<RankedStoriesResult>? _rankedStream;
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    if (_myUid != null && _myUid!.isNotEmpty) {
      _rankedStream = StoryService().fetchStoriesRanked(_myUid!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    if (_myUid == null || _myUid!.isEmpty) {
      return const SizedBox(height: 110);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text(
                'Stories',
                style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'See all',
                  style: textTheme.bodySmall?.copyWith(
                      color: kSecondaryColor,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: StreamBuilder<RankedStoriesResult>(
            stream: _rankedStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2));
              }

              final result = snapshot.data!;
              final groupedStories = result.grouped;
              final userIds = <String>[
                _myUid!,
                ...result.orderedUserIds.where((id) => id != _myUid),
              ];

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                itemCount: userIds.length,
                itemBuilder: (context, index) {
                  final userId = userIds[index];

                  if (userId == _myUid) {
                    final myStories = groupedStories[_myUid!] ?? [];
                    final hasStories = myStories.isNotEmpty;
                    final hasUnseen = myStories
                        .any((s) => !s.viewers.contains(_myUid));
                    final photoUrl =
                    hasStories ? myStories.first.userPhotoUrl : null;

                    return GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => const StoryUploadSheet(),
                        );
                      },
                      onLongPress: () {
                        if (!hasStories) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  StoryViewerPage(stories: myStories)),
                        );
                      },
                      child: Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                _StoryAvatar(
                                  imageUrl: photoUrl,
                                  hasUnseen:
                                  hasStories && hasUnseen,
                                  isSeen: hasStories && !hasUnseen,
                                ),
                                const Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.blue,
                                    child: Icon(Icons.add,
                                        size: 16,
                                        color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text('Your story',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87)),
                          ],
                        ),
                      ),
                    );
                  }

                  final stories = groupedStories[userId] ?? [];
                  if (stories.isEmpty) return const SizedBox.shrink();

                  final hasUnseen =
                  stories.any((s) => !s.viewers.contains(_myUid));
                  final first = stories.first;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                StoryViewerPage(stories: stories)),
                      );
                    },
                    child: Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StoryAvatar(
                            imageUrl: first.userPhotoUrl,
                            hasUnseen: hasUnseen,
                            isSeen: !hasUnseen,
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 70,
                            child: Text(
                              first.username.isNotEmpty
                                  ? first.username
                                  : 'User',
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  final String? imageUrl;
  final bool hasUnseen;
  final bool isSeen;

  const _StoryAvatar({
    required this.imageUrl,
    required this.hasUnseen,
    required this.isSeen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasUnseen
            ? const LinearGradient(
          colors: [
            Color(0xFFF56040),
            Color(0xFFF77737),
            Color(0xFFE1306C),
            Color(0xFFC13584),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: isSeen ? Colors.grey.shade400 : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
            shape: BoxShape.circle, color: Colors.white),
        child: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey.shade200,
          child: ClipOval(
            child: (imageUrl ?? '').isNotEmpty
                ? CachedNetworkImage(
              imageUrl: imageUrl!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const Icon(Icons.person,
                  size: 28, color: Colors.white70),
            )
                : const Icon(Icons.person,
                size: 28, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

// ---------------------- Drawer ----------------------

enum _HaloMenuAction {
  home,
  feed,
  premium,
  wellness,
  challenges,
  profileSettings,
  events,
  analytics,
  gurus,
  logout,
  email,
  share,
  customerCare,
}

class _DrawerItemData {
  final IconData icon;
  final String label;
  final _HaloMenuAction action;

  const _DrawerItemData(
      {required this.icon, required this.label, required this.action});
}

class _HaloDrawer extends StatelessWidget {
  final Future<void> Function(_HaloMenuAction) onSelect;

  const _HaloDrawer({Key? key, required this.onSelect}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const primaryItems = [
      _DrawerItemData(
          icon: Icons.home_filled,
          label: 'Home',
          action: _HaloMenuAction.home),
      _DrawerItemData(
          icon: Icons.article_outlined,
          label: 'Feed',
          action: _HaloMenuAction.feed),
      _DrawerItemData(
          icon: Icons.local_fire_department,
          label: 'Premium Content & Features',
          action: _HaloMenuAction.premium),
      _DrawerItemData(
          icon: Icons.self_improvement,
          label: 'Wellness',
          action: _HaloMenuAction.wellness),
      _DrawerItemData(
          icon: Icons.timer_outlined,
          label: 'Challenges',
          action: _HaloMenuAction.challenges),
      _DrawerItemData(
          icon: Icons.person_outline,
          label: 'Profile Settings',
          action: _HaloMenuAction.profileSettings),
      _DrawerItemData(
          icon: Icons.public,
          label: 'Events',
          action: _HaloMenuAction.events),
      _DrawerItemData(
          icon: Icons.bar_chart,
          label: 'Analytics & Insight',
          action: _HaloMenuAction.analytics),
      _DrawerItemData(
          icon: Icons.school_outlined,
          label: 'Gurus',
          action: _HaloMenuAction.gurus),
      _DrawerItemData(
          icon: Icons.logout,
          label: 'Log Out',
          action: _HaloMenuAction.logout),
    ];

    const secondaryItems = [
      _DrawerItemData(
          icon: Icons.mail_outline,
          label: 'Email',
          action: _HaloMenuAction.email),
      _DrawerItemData(
          icon: Icons.ios_share,
          label: 'Share',
          action: _HaloMenuAction.share),
      _DrawerItemData(
          icon: Icons.headset_mic,
          label: 'Customer Care',
          action: _HaloMenuAction.customerCare),
    ];

    return Drawer(
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF3EDFF), Color(0xFFE5E0FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16),
                child: Row(
                  children: [
                    Text(
                      'MENU',
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: kSecondaryColor),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black87),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  children: [
                    ...primaryItems.map((item) => _HaloDrawerTile(
                      data: item,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelect(item.action);
                      },
                    )),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(thickness: 1.0),
                    ),
                    ...secondaryItems.map((item) => _HaloDrawerTile(
                      data: item,
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelect(item.action);
                      },
                    )),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16),
                child: Text(
                  'Version 1.013',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HaloDrawerTile extends StatelessWidget {
  final _DrawerItemData data;
  final VoidCallback onTap;

  const _HaloDrawerTile(
      {Key? key, required this.data, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
              Icon(data.icon, color: kSecondaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                data.label,
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------- Double-tap heart overlay ----------------------

class _DoubleTapHeartOverlay extends StatefulWidget {
  final String postId;
  final Widget child;

  const _DoubleTapHeartOverlay(
      {Key? key, required this.postId, required this.child})
      : super(key: key);

  @override
  State<_DoubleTapHeartOverlay> createState() =>
      _DoubleTapHeartOverlayState();
}

class _DoubleTapHeartOverlayState extends State<_DoubleTapHeartOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scale = Tween<double>(begin: 0.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _opacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDoubleTap() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final postRef =
        FirebaseFirestore.instance.collection('posts').doc(widget.postId);
        final likeRef = postRef.collection('likes').doc(uid);
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final likeSnap = await tx.get(likeRef);
          if (likeSnap.exists) return;
          tx.set(likeRef, {
            'userId': uid,
            'likedAt': FieldValue.serverTimestamp(),
          });
          tx.update(postRef, {'likeCount': FieldValue.increment(1)});
        });
      } catch (_) {}
    }
    if (!mounted) return;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.value == 0) return const SizedBox.shrink();
              return IgnorePointer(
                child: Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: const Icon(Icons.favorite,
                        size: 100, color: kIgLikeRed),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------- Post Media ----------------------

class _PostMedia extends StatelessWidget {
  final List<dynamic> media;
  final VoidCallback? onVideoTap;

  const _PostMedia({Key? key, required this.media, this.onVideoTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final first = Map<String, dynamic>.from(media.first as Map);
    final type = (first['type'] ?? 'image').toString();
    final url = (first['url'] ?? '').toString().trim();
    final trimStartMs = _asIntNullable(first['trimStartMs']);
    final trimEndMs = _asIntNullable(first['trimEndMs']);

    if (type == 'video') {
      return GestureDetector(
        onTap: onVideoTap,
        child: SizedBox(
            height: 300,
            width: double.infinity,
            child: _NetworkVideo(
              url: url,
              trimStartMs: trimStartMs,
              trimEndMs: trimEndMs,
            )),
      );
    }

    if (url.isEmpty) {
      return Container(
          height: 300,
          color: Colors.grey.shade200,
          child: const Center(
              child:
              Icon(Icons.image_not_supported, color: Colors.grey)));
    }

    return _PostImage(url: url);
  }
}

// ---------------------- Network Video ----------------------

class _NetworkVideo extends StatefulWidget {
  final String url;
  final int? trimStartMs;
  final int? trimEndMs;
  const _NetworkVideo({
    Key? key,
    required this.url,
    this.trimStartMs,
    this.trimEndMs,
  }) : super(key: key);

  @override
  State<_NetworkVideo> createState() => _NetworkVideoState();
}

class _NetworkVideoState extends State<_NetworkVideo> {
  VideoPlayerController? _controller;
  bool _initStarted = false;
  bool _initialized = false;
  bool _error = false;
  bool _isVisible = false;
  Duration _effectiveTrimStart = Duration.zero;
  Duration? _effectiveTrimEnd;

  @override
  void initState() {
    super.initState();
    if (widget.url.trim().isEmpty) {
      setState(() => _error = true);
    }
  }

  @override
  void didUpdateWidget(covariant _NetworkVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trimStartMs != widget.trimStartMs ||
        oldWidget.trimEndMs != widget.trimEndMs) {
      _updateTrimBounds();
      _syncPlayback();
    }
  }

  void _initIfNeeded() {
    if (_initStarted || widget.url.trim().isEmpty) return;
    _initStarted = true;
    try {
      final controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = controller;
      controller.initialize().then((_) {
        if (!mounted) {
          // [FIX-9] Dispose controller if widget was already removed
          // from the tree before initialization completed.
          controller.dispose();
          return;
        }
        _updateTrimBounds();
        controller
          ..setLooping(false)
          ..addListener(_enforceTrimWindow);
        if (_effectiveTrimStart > Duration.zero) {
          controller.seekTo(_effectiveTrimStart);
        }
        setState(() => _initialized = true);
        _syncPlayback();
      }).catchError((Object _) {
        // [FIX-9] Dispose on error path too.
        controller.dispose();
        _controller = null;
        if (!mounted) return;
        setState(() => _error = true);
      });
    } catch (_) {
      _controller?.dispose();
      _controller = null;
      if (mounted) setState(() => _error = true);
    }
  }

  void _syncPlayback() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (_isVisible) {
      if (c.value.position < _effectiveTrimStart) {
        c.seekTo(_effectiveTrimStart);
      }
      c.play();
    } else {
      c.pause();
    }
  }

  void _updateTrimBounds() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final maxMs = c.value.duration.inMilliseconds;
    var start = widget.trimStartMs ?? 0;
    if (start < 0) start = 0;
    if (start > maxMs) start = maxMs;
    int? end = widget.trimEndMs;
    if (end != null) {
      if (end <= start) {
        end = maxMs;
      } else if (end > maxMs) {
        end = maxMs;
      }
    }
    _effectiveTrimStart = Duration(milliseconds: start);
    _effectiveTrimEnd =
    end != null ? Duration(milliseconds: end) : null;
  }

  void _enforceTrimWindow() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (_effectiveTrimEnd == null) return;
    if (c.value.position >= _effectiveTrimEnd!) {
      c.seekTo(_effectiveTrimStart);
      if (_isVisible) c.play();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_enforceTrimWindow);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('home_video_${widget.url.hashCode}'),
      onVisibilityChanged: (info) {
        final visibleNow = info.visibleFraction > 0.6;
        if (visibleNow && !_initStarted) {
          _initIfNeeded();
        }
        if (_isVisible != visibleNow) {
          _isVisible = visibleNow;
          _syncPlayback();
        }
      },
      child: Builder(
        builder: (context) {
          if (_error) {
            return Container(
                height: 300,
                color: Colors.black26,
                child: const Center(
                    child: Icon(Icons.videocam_off,
                        color: Colors.white54, size: 48)));
          }
          if (!_initialized ||
              _controller == null ||
              !_controller!.value.isInitialized) {
            return Container(
                height: 300,
                color: Colors.black12,
                child:
                const Center(child: CircularProgressIndicator()));
          }

          final c = _controller!;
          return SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------- Post user header (with in-memory cache) ----------------------

class _UserLite {
  final String username;
  final String profilePhotoUrl;
  final String accountType;
  // [FIX-5] Timestamp for TTL-based cache invalidation (5 min).
  final DateTime fetchedAt;

  const _UserLite({
    required this.username,
    required this.profilePhotoUrl,
    required this.accountType,
    required this.fetchedAt,
  });

  bool get isStale =>
      DateTime.now().difference(fetchedAt).inMinutes >= 5;
}

class _PostUserHeader extends StatefulWidget {
  final String userId;
  final String subtitle;

  const _PostUserHeader({
    Key? key,
    required this.userId,
    required this.subtitle,
  }) : super(key: key);

  @override
  State<_PostUserHeader> createState() => _PostUserHeaderState();
}

class _PostUserHeaderState extends State<_PostUserHeader> {
  // [FIX-5] Cache now has a 5-minute TTL. Stale entries are re-fetched
  // so profile photo / username updates eventually propagate.
  static final Map<String, _UserLite> _cache = {};
  _UserLite? _user;

  @override
  void initState() {
    super.initState();
    final cached = _cache[widget.userId];
    if (cached != null && !cached.isStale) {
      _user = cached;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final data = doc.data();
      final user = _UserLite(
        username: (data?['username'] ??
            data?['name'] ??
            data?['full_name'] ??
            'User')
            .toString(),
        profilePhotoUrl: _profilePhotoUrlFromUser(data),
        accountType:
        (data?['accountType'] as String?)?.toLowerCase() ?? 'aspirant',
        fetchedAt: DateTime.now(),
      );
      _cache[widget.userId] = user;
      if (mounted) setState(() => _user = user);
    } catch (_) {}
  }

  void _openProfile() {
    final user = _user;
    if (user == null || widget.userId.isEmpty) return;
    if (user.accountType == 'wellness') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => wellness_profile.WellnessProfilePage(
              profileUserId: widget.userId),
        ),
      );
    } else if (user.accountType == 'guru') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              guru_profile.GuruProfilePage(profileUserId: widget.userId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              aspirant_profile.ProfilePage(profileUserId: widget.userId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return _PostHeader(
      username: user?.username ?? 'User',
      profilePhotoUrl: user?.profilePhotoUrl ?? '',
      subtitle: widget.subtitle,
      onTap: user == null ? null : _openProfile,
    );
  }
}

// ---------------------- Post Actions ----------------------
// [FIX-2] postData prop removed. likeCount and commentCount are now fetched
// from a live stream on the post document so counts never go stale.

class _PostActions extends StatefulWidget {
  final String postId;
  final Map<String, dynamic>? savedPostsMap;

  const _PostActions(
      {Key? key, required this.postId, this.savedPostsMap})
      : super(key: key);

  @override
  State<_PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<_PostActions> {
  final String? _currentUserId =
      FirebaseAuth.instance.currentUser?.uid;

  Future<void> _toggleLike() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to like posts')));
      return;
    }
    try {
      final postRef =
      FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      final likeRef = postRef.collection('likes').doc(currentUserId);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final likeDoc = await tx.get(likeRef);
        if (likeDoc.exists) {
          tx.delete(likeRef);
          tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
        } else {
          tx.set(likeRef, {
            'userId': currentUserId,
            'likedAt': FieldValue.serverTimestamp(),
          });
          tx.update(postRef, {'likeCount': FieldValue.increment(1)});
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error updating like: $e')));
    }
  }

  void _showComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CommentsPage(postId: widget.postId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    // [FIX-2] Single StreamBuilder on the post document gives live
    // likeCount, commentCount, AND the current user's like status —
    // no stale snapshot from the feed.
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .snapshots(),
      builder: (context, postSnap) {
        final postData = postSnap.data?.data() ?? const <String, dynamic>{};
        final likeCount = _asInt(postData['likeCount']);
        final commentCount = _asInt(postData['commentCount']);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _currentUserId == null
              ? null
              : FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .collection('likes')
              .doc(_currentUserId)
              .snapshots(),
          builder: (context, likeSnap) {
            final isLiked = likeSnap.data?.exists ?? false;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? kIgLikeRed : kIgPrimaryText,
                        size: 28,
                      ),
                      onPressed: _toggleLike,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    IconButton(
                      icon: Icon(Icons.chat_bubble_outline,
                          size: 26, color: kIgPrimaryText),
                      onPressed: _showComments,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                    IconButton(
                      icon: Icon(Icons.send_outlined,
                          size: 26, color: kIgPrimaryText),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                Text('Share functionality coming soon!')));
                      },
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                    const Spacer(),
                    SaveButton(
                      postId: widget.postId,
                      currentUserId: _currentUserId,
                      savedPostsMap: widget.savedPostsMap,
                      iconSize: 26,
                      color: kIgPrimaryText,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$likeCount ${likeCount == 1 ? 'like' : 'likes'}',
                        style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: kIgPrimaryText,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _showComments,
                        child: Text(
                          'View all $commentCount ${commentCount == 1 ? 'comment' : 'comments'}',
                          style: textTheme.bodyMedium
                              ?.copyWith(color: kIgSecondaryText, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------- Comments Page ----------------------
// [FIX-3] All comment user docs are fetched in a single whereIn query
// instead of one FutureBuilder per row.

class _CommentsPage extends StatefulWidget {
  final String postId;

  const _CommentsPage({Key? key, required this.postId}) : super(key: key);

  @override
  State<_CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<_CommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // [FIX-3] In-memory user data cache keyed by uid, populated in batch.
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to comment')));
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a comment')));
      return;
    }
    try {
      final postRef =
      FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      final commentRef = postRef.collection('comments').doc();
      await FirebaseFirestore.instance.runTransaction((tx) async {
        tx.set(commentRef, {
          'userId': _currentUserId,
          'text': _commentController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(postRef, {'commentCount': FieldValue.increment(1)});
      });
      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')));
    }
  }

  // [FIX-3] Batch-fetch all user docs for a list of comment documents.
  Future<void> _prefetchUsers(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> comments) async {
    final uids = comments
        .map((c) => (c.data()['userId'] ?? '').toString())
        .where((id) => id.isNotEmpty && !_userCache.containsKey(id))
        .toSet()
        .toList();

    if (uids.isEmpty) return;

    // Firestore whereIn supports up to 30 values per call.
    const chunkSize = 30;
    for (var i = 0; i < uids.length; i += chunkSize) {
      final chunk = uids.sublist(
          i, i + chunkSize > uids.length ? uids.length : i + chunkSize);
      final result = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in result.docs) {
        _userCache[doc.id] = doc.data();
      }
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comments'),
          backgroundColor: kSecondaryColor,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error loading comments'));
                  }

                  final comments = snapshot.data?.docs ?? [];

                  if (comments.isEmpty) {
                    return Center(
                      child: Text('No comments yet',
                          style: TextStyle(
                              color: Colors.grey.shade600)),
                    );
                  }

                  // [FIX-3] Trigger a batch user fetch whenever the
                  // comment list changes. Uses addPostFrameCallback so
                  // we don't call setState during build.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _prefetchUsers(comments);
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index].data();
                      final commentUserId =
                      (comment['userId'] ?? '').toString();
                      final commentText =
                      (comment['text'] ?? '').toString();
                      final ts = comment['createdAt'] as Timestamp?;
                      final timeStr = ts != null
                          ? ts
                          .toDate()
                          .toLocal()
                          .toString()
                          .substring(0, 16)
                          : '';

                      // [FIX-3] Read from local cache — no FutureBuilder.
                      final uData = _userCache[commentUserId];
                      final username = (uData?['username'] ??
                          uData?['name'] ??
                          'User')
                          .toString();
                      final photoUrl =
                      _profilePhotoUrlFromUser(uData);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
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
                                  errorWidget: (_, __, ___) =>
                                      Image.asset(
                                        'assets/images/Profile.png',
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                      ),
                                )
                                    : Image.asset(
                                  'assets/images/Profile.png',
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: textTheme.bodyMedium
                                          ?.copyWith(
                                          color: kIgPrimaryText,
                                          fontSize: 14),
                                      children: [
                                        TextSpan(
                                          text: '$username ',
                                          style: const TextStyle(
                                              fontWeight:
                                              FontWeight.w600),
                                        ),
                                        TextSpan(text: commentText),
                                      ],
                                    ),
                                  ),
                                  if (timeStr.isNotEmpty)
                                    Padding(
                                      padding:
                                      const EdgeInsets.only(top: 4),
                                      child: Text(
                                        timeStr,
                                        style: textTheme.bodySmall
                                            ?.copyWith(
                                            color: kIgSecondaryText,
                                            fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border:
                Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey.shade200,
                      child: const Icon(Icons.person,
                          size: 18, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: textTheme.bodyMedium
                              ?.copyWith(color: kIgSecondaryText),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: Colors.grey.shade300),
                          ),
                          contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    TextButton(
                      onPressed: _addComment,
                      child: Text(
                        'Post',
                        style: textTheme.bodyMedium?.copyWith(
                            color: kSecondaryColor,
                            fontWeight: FontWeight.w600),
                      ),
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
}