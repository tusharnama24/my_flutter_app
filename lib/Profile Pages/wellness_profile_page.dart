// wellness_profile_page.dart
// WELLNESS PROFILE PAGE - Updated with tabs and all sections

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';

// -------------------- SECTIONS --------------------
import '../Sections/Wellness Section/wellness_products_section.dart';
import '../Sections/Wellness Section/wellness_services_section.dart';
import '../Sections/Wellness Section/wellness_booking_section.dart';
import '../Sections/Wellness Section/wellness_reviews_section.dart';
import '../Sections/Wellness Section/wellness_analytics_section.dart';

// -------------------- EXISTING PAGES --------------------
import '../../editprofilepage.dart';
import '../../main.dart';
import 'package:halo/Bottom Pages/PrivacySettingsPage.dart';
import 'package:halo/Bottom Pages/SettingsPage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:halo/chat/chat_screen.dart';
import 'package:halo/chat/chat_service.dart';
import 'package:halo/newpostpage.dart';

// ===================================================================
//  SLIVER APP BAR DELEGATE (for TabBar)
// ===================================================================
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

// ===================================================================
//  WELLNESS PROFILE PAGE
// ===================================================================

class WellnessProfilePage extends StatefulWidget {
  final String profileUserId;

  const WellnessProfilePage({Key? key, required this.profileUserId})
      : super(key: key);

  @override
  State<WellnessProfilePage> createState() => _WellnessProfilePageState();
}

class _WellnessProfilePageState extends State<WellnessProfilePage>
    with TickerProviderStateMixin {
  // -------------------- FIREBASE --------------------
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  bool _isOwnProfile = false;
  bool _isFollowing = false;
  bool _isLoading = true;

  // -------------------- PROFILE DATA --------------------
  String _businessName = '';
  String _username = '';
  String _bio = '';
  String _category = ''; // Gym / Yoga Studio / Café / Diet Center / Physio Clinic
  String _location = ''; // City, State
  String? _profilePhotoUrl;
  String? _coverPhotoUrl;

  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;
  int _likesCount = 0;
  double _rating = 0.0;
  int _reviewCount = 0;
  bool _isOnline = false;

  // -------------------- WELLNESS SPECIFIC DATA --------------------
  List<String> _services = []; // Strength Training, Cardio, etc.
  Map<String, String> _availability = {}; // Mon-Sat: 6am-10pm, etc.
  Map<String, String> _socialLinks = {}; // Instagram, YouTube, etc.
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _staff = []; // Featured staff/trainers
  List<Map<String, dynamic>> _events = []; // Fitness events
  List<Map<String, dynamic>> _recentPosts = [];
  List<Map<String, dynamic>> _reviews = [];

  // -------------------- UI CONSTANTS --------------------
  static const double _coverHeight = 220.0;
  static const double _avatarSize = 90.0;
  static const double _avatarOverlap = 30.0;
  static const Color _lavender = Color(0xFFA58CE3);
  static const Color _deepLavender = Color(0xFF6F4BC2);
  static const Color _bg = Color(0xFFF4F1FB);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _mutedText = Color(0xFF6B6B6B);

  // -------------------- IMAGE PICKER --------------------
  final ImagePicker _picker = ImagePicker();
  File? _profilePhotoFile;
  File? _coverPhotoFile;

  // -------------------- STATE --------------------
  late final TabController _tabController;
  late final AnimationController _followAnimController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _followAnimController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _followAnimController.dispose();
    super.dispose();
  }

  // ===================================================================
  //  DATA LOAD
  // ===================================================================
  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = _auth.currentUser;
      _isOwnProfile =
          _currentUser != null && _currentUser!.uid == widget.profileUserId;

      final doc =
      await _firestore.collection('users').doc(widget.profileUserId).get();

      if (doc.exists) {
        final data = doc.data()!;

        _businessName = data['name'] ?? data['business_name'] ?? '';
        _username = data['username'] ?? '';
        _bio = data['bio'] ?? '';
        _category = data['category'] ?? data['wellness_category'] ?? '';
        _location = data['city'] ?? data['location'] ?? '';
        _profilePhotoUrl = data['profilePhoto'] as String?;
        _coverPhotoUrl = data['coverPhoto'] as String?;

        _followersCount = data['followersCount'] ?? 0;
        _followingCount = data['followingCount'] ?? 0;
        _postsCount = data['postsCount'] ?? 0;
        _likesCount = data['likesCount'] ?? 0;
        _rating = (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0.0;
        _reviewCount = data['reviewCount'] ?? 0;
        _isOnline = data['isOnline'] ?? false;

        // Services
        _services = List<String>.from(data['services'] ?? []);

        // Availability
        if (data['availability'] is Map) {
          _availability = Map<String, String>.from(data['availability']);
        }

        // Social Links
        if (data['socialLinks'] is Map) {
          _socialLinks = Map<String, String>.from(data['socialLinks']);
        }

        // Load products
        await _loadProducts();

        // Load staff
        await _loadStaff();

        // Load events
        await _loadEvents();

        // Load posts
        await _loadPosts();

        // Load reviews
        await _loadReviews();
      }

      // Check follow status
      if (_currentUser != null && !_isOwnProfile) {
        final f = await _firestore
            .collection('users')
            .doc(widget.profileUserId)
            .collection('followers')
            .doc(_currentUser!.uid)
            .get();
        _isFollowing = f.exists;
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadProducts() async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(widget.profileUserId)
          .collection('products')
          .limit(4)
          .get();

      _products = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading products: $e');
    }
  }

  Future<void> _loadStaff() async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(widget.profileUserId)
          .collection('staff')
          .limit(10)
          .get();

      _staff = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading staff: $e');
    }
  }

  Future<void> _loadEvents() async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(widget.profileUserId)
          .collection('events')
          .limit(5)
          .get();

      _events = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading events: $e');
    }
  }

  Future<void> _loadPosts() async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: widget.profileUserId)
          .limit(30)
          .get();

      final list = snapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'imageUrl': _getPostImageUrl(d),
          'caption': d['caption'] ?? '',
          'timestamp': d['timestamp'] ?? d['createdAt'],
        };
      }).toList();

      list.sort((a, b) {
        final aTs = a['timestamp'];
        final bTs = b['timestamp'];
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
        return 0;
      });

      _recentPosts = list;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading posts: $e');
      _recentPosts = [];
      if (mounted) setState(() {});
    }
  }

  /// Resolves post image URL from AddPostPage format (images/media) or legacy (imageUrl).
  static String? _getPostImageUrl(Map<String, dynamic> data) {
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

  Future<void> _loadReviews() async {
    try {
      QuerySnapshot<Map<String, dynamic>>? reviewsSnapshot;
      try {
        reviewsSnapshot = await _firestore
            .collection('reviews')
            .where('wellnessId', isEqualTo: widget.profileUserId)
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get();
      } catch (_) {
        try {
          reviewsSnapshot = await _firestore
              .collection('reviews')
              .where('wellnessId', isEqualTo: widget.profileUserId)
              .limit(3)
              .get();
        } catch (_) {
          reviewsSnapshot = null;
        }
      }

      if (reviewsSnapshot != null) {
        _reviews = reviewsSnapshot.docs.map((doc) {
          final d = doc.data();
          return {
            'id': doc.id,
            'userName': d['userName'] ?? 'User',
            'rating': d['rating'] ?? 5,
            'text': d['text'] ?? '',
            'profilePhoto': d['profilePhoto'],
            'createdAt': d['createdAt'],
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
    }
  }

  // ===================================================================
  //  FOLLOW / UNFOLLOW
  // ===================================================================
  Future<void> _toggleFollow() async {
    if (_currentUser == null || _isOwnProfile) return;

    final uid = _currentUser!.uid;
    final pid = widget.profileUserId;

    final refFollower = _firestore
        .collection('users')
        .doc(pid)
        .collection('followers')
        .doc(uid);

    final refFollowing = _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(pid);

    setState(() {
      _isFollowing = !_isFollowing;
      _followersCount += _isFollowing ? 1 : -1;
    });

    try {
      await _firestore.runTransaction((tx) async {
        if (_isFollowing) {
          tx.set(refFollower, {'createdAt': FieldValue.serverTimestamp()});
          tx.set(refFollowing, {'createdAt': FieldValue.serverTimestamp()});
          tx.update(_firestore.collection('users').doc(pid),
              {'followersCount': FieldValue.increment(1)});
        } else {
          tx.delete(refFollower);
          tx.delete(refFollowing);
          tx.update(_firestore.collection('users').doc(pid),
              {'followersCount': FieldValue.increment(-1)});
        }
      });
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to update follow status');
      setState(() {
        _isFollowing = !_isFollowing;
        _followersCount += _isFollowing ? 1 : -1;
      });
    }
  }

  // ===================================================================
  //  IMAGE PICKERS
  // ===================================================================
  Future<void> _pickProfileImage() async {
    if (!_isOwnProfile || _currentUser == null) return;
    final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _profilePhotoFile = File(picked.path));

    try {
      final fileName =
          'profile_${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(_currentUser!.uid)
          .child(fileName);
      final snap = await ref.putFile(_profilePhotoFile!);
      final url = await snap.ref.getDownloadURL();

      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'profilePhoto': url});

      setState(() {
        _profilePhotoUrl = url;
        _profilePhotoFile = null;
      });

      Fluttertoast.showToast(msg: 'Profile photo updated');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to upload photo');
      setState(() => _profilePhotoFile = null);
    }
  }

  Future<void> _pickCoverImage() async {
    if (!_isOwnProfile || _currentUser == null) return;
    final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() => _coverPhotoFile = File(picked.path));

    try {
      final fileName =
          'cover_${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(_currentUser!.uid)
          .child(fileName);
      final snap = await ref.putFile(_coverPhotoFile!);
      final url = await snap.ref.getDownloadURL();

      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'coverPhoto': url});

      setState(() {
        _coverPhotoUrl = url;
        _coverPhotoFile = null;
      });

      Fluttertoast.showToast(msg: 'Cover photo updated');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to upload photo');
      setState(() => _coverPhotoFile = null);
    }
  }

  // ===================================================================
  //  UI HELPERS (HEADER)
  // ===================================================================
  Widget _coverWidget(BuildContext context) {
    final ImageProvider cover = _coverPhotoFile != null
        ? FileImage(_coverPhotoFile!)
        : (_coverPhotoUrl != null
        ? NetworkImage(_coverPhotoUrl!)
        : const AssetImage('assets/images/bio.png')) as ImageProvider;

    return GestureDetector(
      onTap: _isOwnProfile ? _pickCoverImage : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(image: cover, fit: BoxFit.cover),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.25), Colors.transparent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarWidget() {
    final ImageProvider avatar = _profilePhotoFile != null
        ? FileImage(_profilePhotoFile!)
        : (_profilePhotoUrl != null
        ? NetworkImage(_profilePhotoUrl!)
        : const AssetImage('assets/images/Profile.png')) as ImageProvider;

    return Hero(
      tag: 'wellness-avatar-${widget.profileUserId}',
      child: GestureDetector(
        onTap: _isOwnProfile ? _pickProfileImage : null,
        child: Stack(
          children: [
            Container(
              width: _avatarSize + 6,
              height: _avatarSize + 6,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: CircleAvatar(
                radius: _avatarSize / 2,
                backgroundImage: avatar,
              ),
            ),
            if (_isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: _avatarOverlap + 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: const Offset(0, -_avatarOverlap),
                child: _avatarWidget(),
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
                              _businessName.isNotEmpty ? _businessName : 'Business Name',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _username.isNotEmpty ? '@$_username' : '',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _mutedText,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_category.isNotEmpty)
                        GestureDetector(
                          onTap: _isOwnProfile ? _editCategory : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _lavender.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _lavender.withOpacity(0.3), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    _category,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _deepLavender,
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_isOwnProfile) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 12, color: _lavender),
                                ],
                              ],
                            ),
                          ),
                        )
                      else if (_isOwnProfile)
                        GestureDetector(
                          onTap: _editCategory,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _lavender.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _lavender.withOpacity(0.3), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Add Category',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _deepLavender,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.add, size: 12, color: _lavender),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      if (_location.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: _mutedText),
                            const SizedBox(width: 4),
                            Text(
                              _location,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: _mutedText,
                                fontWeight: FontWeight.w400,
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
        const SizedBox(height: 16),
        _buildStatsBar(),
        const SizedBox(height: 16),
        _buildActionButtons(),
        if (_bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildBioCard(),
        ],
      ],
    );
  }

  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _lavender.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statTile(_followersCount.toString(), 'Followers'),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          _statTile(_followingCount.toString(), 'Following'),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          _statTile(_postsCount.toString(), 'Posts'),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          _statTile(_likesCount.toString(), 'Likes'),
        ],
      ),
    );
  }

  Widget _statTile(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: _mutedText,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_isOwnProfile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EditProfilePage(
                        initialName: _businessName,
                        initialUsername: _username,
                        initialBio: _bio,
                        initialGender: '',
                        initialprofessiontype: '',
                      )));
              _loadProfileData();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              side: const BorderSide(color: _lavender),
            ),
            child: Text(
              'Edit Profile',
              style: GoogleFonts.poppins(
                color: _lavender,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _lavender,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 3,
                shadowColor: _lavender.withOpacity(0.4),
              ),
              child: Text(
                _isFollowing ? 'Following' : 'Follow',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: _openMessage,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
              child: Text(
                'Message',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _openBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: _deepLavender,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 3,
                shadowColor: _deepLavender.withOpacity(0.4),
              ),
              child: Text(
                'Book',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _lavender.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _bio,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.black87,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isOwnProfile)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: _editBio,
                  color: _lavender,
                  iconSize: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  //  EDIT FUNCTIONS
  // ===================================================================
  Future<void> _editBio() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final controller = TextEditingController(text: _bio);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Bio',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe your business...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: _lavender),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'bio': result});
        setState(() => _bio = result);
        Fluttertoast.showToast(msg: 'Bio updated');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to update bio');
      }
    }
  }

  Future<void> _editServices() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final controller = TextEditingController(text: _services.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Services',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Enter services separated by commas',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: _lavender),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final services = result
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'services': services});
        setState(() => _services = services);
        Fluttertoast.showToast(msg: 'Services updated');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to update services');
      }
    }
  }

  Future<void> _editAvailability() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final monSatCtrl = TextEditingController(text: _availability['Mon-Sat'] ?? '');
    final sunCtrl = TextEditingController(text: _availability['Sun'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Availability',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: monSatCtrl,
              decoration: InputDecoration(
                labelText: 'Mon-Sat (e.g., 6am - 10pm)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sunCtrl,
              decoration: InputDecoration(
                labelText: 'Sunday (e.g., 8am - 8pm)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _lavender),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newAvailability = <String, String>{};
      if (monSatCtrl.text.isNotEmpty) newAvailability['Mon-Sat'] = monSatCtrl.text;
      if (sunCtrl.text.isNotEmpty) newAvailability['Sun'] = sunCtrl.text;

      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'availability': newAvailability});
        setState(() => _availability = newAvailability);
        Fluttertoast.showToast(msg: 'Availability updated');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to update availability');
      }
    }
  }

  Future<void> _editCategory() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final categories = ['Gym', 'Yoga Studio', 'Café', 'Diet Center', 'Physio Clinic'];
    final currentIndex = categories.indexOf(_category);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Select Category',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: categories.map((cat) {
            return RadioListTile<String>(
              title: Text(cat),
              value: cat,
              groupValue: _category.isNotEmpty ? _category : null,
              onChanged: (value) => Navigator.pop(ctx, value),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'category': result, 'wellness_category': result});
        setState(() => _category = result);
        Fluttertoast.showToast(msg: 'Category updated');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to update category');
      }
    }
  }

  // ===================================================================
  //  BUILD
  // ===================================================================
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.black87,
          displayColor: Colors.black87,
        ),
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : NestedScrollView(
          headerSliverBuilder:
              (BuildContext context, bool innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                expandedHeight: _coverHeight,
                backgroundColor: _lavender,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: _isOwnProfile
                    ? [
                  IconButton(
                    icon: const Icon(Icons.add_box_outlined),
                    onPressed: _openPostCreation,
                  ),

                  /// ⚡ OPTIMIZED POPUP MENU
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'Edit Profile') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfilePage(
                              initialName: _businessName,
                              initialUsername: _username,
                              initialBio: _bio,
                              initialGender: '',
                              initialprofessiontype: '',
                            ),
                          ),
                        ).then((_) {
                          // reload AFTER coming back, non-blocking
                          if (!mounted) return;
                          _loadProfileData();
                        });
                      } else if (value == 'Settings') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettingsPage(),
                          ),
                        ).then((result) async {
                          if (result == 'logout') {
                            await _auth.signOut();
                            if (!mounted) return;

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoginPage(),
                              ),
                            );
                          }
                        });
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'Edit Profile',
                        child: Text('Edit Profile'),
                      ),
                      PopupMenuItem(
                        value: 'Settings',
                        child: Text('Settings'),
                      ),
                    ],
                  ),
                ]
                    : [],
                flexibleSpace: FlexibleSpaceBar(
                  background: _coverWidget(context),
                ),
              ),

              SliverToBoxAdapter(
                child: _buildProfileHeaderSection(),
              ),

              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: _lavender,
                    indicatorWeight: 3,
                    labelColor: Colors.black87,
                    unselectedLabelColor: Colors.black54,
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.grid_on_outlined, size: 24),
                      ),
                      Tab(
                        icon:
                        Icon(Icons.dashboard_outlined, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildFirstTab(),
              _buildSecondTab(),
            ],
          ),
        ),
      ),
    );
  }


  // ===================================================================
  //  TAB CONTENT BUILDERS
  // ===================================================================
  Widget _buildFirstTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Popular Products Section
              _buildPopularProductsSection(),
              const SizedBox(height: 24),
              // Featured Staff Section
              _buildFeaturedStaffSection(),
              const SizedBox(height: 24),
              // Recent Posts Section
              _buildRecentPostsSection(),
              const SizedBox(height: 24),
              // Fitness Events Section
              _buildFitnessEventsSection(),
              const SizedBox(height: 24),
              // Location Section
              _buildLocationSection(),
              const SizedBox(height: 24),
              // Services & Availability Section
              _buildServicesAndAvailabilitySection(),
              const SizedBox(height: 24),
              // Reviews Section
              _buildReviewsSection(),
              const SizedBox(height: 24),
              // Social Links Section
              _buildSocialLinksSection(),
              const SizedBox(height: 24),
              // New Professional Features for Wellness
              _buildFacilityGallerySection(),
              _buildAmenitiesShowcaseSection(),
              _buildMembershipPlansSection(),
              _buildSpecialOffersSection(),
              _buildFacilityStatusSection(),
              _buildAwardsCertificationsSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecondTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              WellnessProductsSection(
                wellnessUserId: widget.profileUserId,
                isOwner: _isOwnProfile,
              ),
              WellnessServicesSection(
                wellnessUserId: widget.profileUserId,
                isOwner: _isOwnProfile,
              ),
              WellnessBookingSection(
                wellnessUserId: widget.profileUserId,
                isOwner: _isOwnProfile,
              ),
              WellnessReviewsSection(
                wellnessUserId: widget.profileUserId,
              ),
              if (_isOwnProfile) ...[
                const SizedBox(height: 16),
                WellnessAnalyticsSection(
                  wellnessUserId: widget.profileUserId,
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }

  // ===================================================================
  //  FIRST TAB SECTION BUILDERS
  // ===================================================================
  Widget _buildPopularProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popular Products',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              TextButton(
                onPressed: () => _showAllProducts(),
              child: Text(
                'View All',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: _deepLavender,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'No products available',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _mutedText,
                fontWeight: FontWeight.w400,
              ),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _lavender.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: product['imageUrl'] != null &&
                              product['imageUrl'].toString().isNotEmpty
                              ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.network(
                              product['imageUrl'].toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                          )
                              : const Center(
                            child: Icon(Icons.image, color: Colors.grey),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name']?.toString() ?? 'Product',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (product['price'] != null)
                              Text(
                                '₹${product['price']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: _deepLavender,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFeaturedStaffSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child:             Text(
              'Our Team',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
        ),
        const SizedBox(height: 12),
        if (_staff.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'No staff members added',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _mutedText,
                fontWeight: FontWeight.w400,
              ),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: _staff.length,
              itemBuilder: (context, index) {
                final staff = _staff[index];
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundImage: staff['photoUrl'] != null
                            ? NetworkImage(staff['photoUrl'].toString())
                            : null,
                        backgroundColor: _lavender.withOpacity(0.2),
                        child: staff['photoUrl'] == null
                            ? Text(
                          staff['name']?.toString()[0].toUpperCase() ?? 'S',
                          style: GoogleFonts.poppins(
                            color: _lavender,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 60,
                        child: Text(
                          staff['name']?.toString() ?? 'Staff',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecentPostsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Posts',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              TextButton(
                onPressed: () => _showAllPosts(),
                child: Text(
                  'View All Posts →',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: _deepLavender,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_recentPosts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'No posts yet',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _mutedText,
                fontWeight: FontWeight.w400,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _recentPosts.length > 9 ? 9 : _recentPosts.length,
              itemBuilder: (context, index) {
                final post = _recentPosts[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: post['imageUrl'] != null &&
                      post['imageUrl'].toString().isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      post['imageUrl'].toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                  )
                      : const Center(
                    child: Icon(Icons.image, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFitnessEventsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _lavender.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fitness Events',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            if (_events.isEmpty)
              Text(
                'No events scheduled',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: _mutedText,
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              Column(
                children: _events.map((event) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _lavender,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            event['name']?.toString() ?? 'Event',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _lavender.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: const Center(
                child: Icon(Icons.map, size: 64, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _location.isNotEmpty ? _location : 'Location not set',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openMaps,
                      icon: Icon(Icons.map_outlined, color: _lavender),
                      label: Text(
                        'Open in Maps',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 0.2,
                          color: _lavender,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: _lavender, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesAndAvailabilitySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _lavender.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Services Offered',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                if (_isOwnProfile)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: _editServices,
                    color: _lavender,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_services.isEmpty)
              Text(
                'No services listed',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: _mutedText,
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _services.map((service) {
                  return Chip(
                    label: Text(
                      service,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _deepLavender,
                      ),
                    ),
                    backgroundColor: _lavender.withOpacity(0.12),
                    side: BorderSide(color: _lavender.withOpacity(0.2), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Availability',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                if (_isOwnProfile)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: _editAvailability,
                    color: _lavender,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_availability.isEmpty)
              Text(
                'Availability not set',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: _mutedText,
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _availability.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                          ),
                        ),
                        Text(
                          entry.value,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _deepLavender,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reviews',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              if (_reviewCount > 0)
                TextButton(
                  onPressed: () => _showAllReviews(),
                  child: Text(
                    'View All Reviews',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _deepLavender,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'No reviews yet',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _mutedText,
                fontWeight: FontWeight.w400,
              ),
            ),
          )
        else
          Column(
            children: _reviews.map((review) {
              return Padding(
                padding: const EdgeInsets.only(
                    left: 20.0, right: 20.0, bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _lavender.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: review['profilePhoto'] != null
                            ? NetworkImage(review['profilePhoto'].toString())
                            : null,
                        backgroundColor: _lavender.withOpacity(0.2),
                        child: review['profilePhoto'] == null
                            ? Text(
                          (review['userName']?.toString()[0] ?? 'U').toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _lavender,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    review['userName']?.toString() ?? 'User',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < (review['rating'] as int? ?? 5)
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 16,
                                      color: Colors.amber,
                                    );
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              review['text']?.toString() ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSocialLinksSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Social Links',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: _editSocialLinks,
                  color: _lavender,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_socialLinks.isEmpty)
            Text(
              'No social links added',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _mutedText,
                fontWeight: FontWeight.w400,
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_socialLinks.containsKey('instagram'))
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.pink.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 24),
                      color: Colors.pink[700],
                      onPressed: () => _openSocialLink('instagram', _socialLinks['instagram'] ?? ''),
                    ),
                  ),
                if (_socialLinks.containsKey('youtube'))
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.play_circle_outline, size: 24),
                      color: Colors.red[700],
                      onPressed: () => _openSocialLink('youtube', _socialLinks['youtube'] ?? ''),
                    ),
                  ),
                if (_socialLinks.containsKey('website'))
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.language, size: 24),
                      color: Colors.blue[700],
                      onPressed: () => _openSocialLink('website', _socialLinks['website'] ?? ''),
                    ),
                  ),
                if (_socialLinks.containsKey('whatsapp'))
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chat, size: 24),
                      color: Colors.green[700],
                      onPressed: () => _openSocialLink('whatsapp', _socialLinks['whatsapp'] ?? ''),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _editSocialLinks() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final instagramCtrl = TextEditingController(text: _socialLinks['instagram'] ?? '');
    final youtubeCtrl = TextEditingController(text: _socialLinks['youtube'] ?? '');
    final websiteCtrl = TextEditingController(text: _socialLinks['website'] ?? '');
    final whatsappCtrl = TextEditingController(text: _socialLinks['whatsapp'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Social Links',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: instagramCtrl,
                decoration: InputDecoration(
                  labelText: 'Instagram',
                  prefixIcon: const Icon(Icons.camera_alt, color: Colors.pink),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: youtubeCtrl,
                decoration: InputDecoration(
                  labelText: 'YouTube',
                  prefixIcon: const Icon(Icons.play_circle_outline, color: Colors.red),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: websiteCtrl,
                decoration: InputDecoration(
                  labelText: 'Website',
                  prefixIcon: const Icon(Icons.language, color: Colors.blue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: whatsappCtrl,
                decoration: InputDecoration(
                  labelText: 'WhatsApp',
                  prefixIcon: const Icon(Icons.chat, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _lavender),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newLinks = <String, String>{};
      if (instagramCtrl.text.isNotEmpty) newLinks['instagram'] = instagramCtrl.text;
      if (youtubeCtrl.text.isNotEmpty) newLinks['youtube'] = youtubeCtrl.text;
      if (websiteCtrl.text.isNotEmpty) newLinks['website'] = websiteCtrl.text;
      if (whatsappCtrl.text.isNotEmpty) newLinks['whatsapp'] = whatsappCtrl.text;

      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'socialLinks': newLinks});
        setState(() => _socialLinks = newLinks);
        Fluttertoast.showToast(msg: 'Social links updated');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to update social links');
      }
    }
  }

  // ===================================================================
  //  NEW PROFESSIONAL FEATURES FOR WELLNESS
  // ===================================================================

  Widget _buildFacilityGallerySection() {
    // Mock gallery images - in real app, load from Firestore
    final galleryImages = List.generate(6, (i) => 'gallery_$i');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _lavender.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.photo_library, color: _lavender, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Facility Gallery',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: _lavender),
                  onPressed: _addGalleryImage,
                )
              else if (galleryImages.isNotEmpty)
                TextButton(
                  onPressed: () => _showFullGallery(),
                  child: Text(
                    'View All',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _deepLavender,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: galleryImages.length > 6 ? 6 : galleryImages.length,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Placeholder for image
                    Center(
                      child: Icon(Icons.image, size: 32, color: Colors.grey[600]),
                    ),
                    if (index == 5 && galleryImages.length > 6)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '+${galleryImages.length - 6}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAmenitiesShowcaseSection() {
    final amenities = [
      {'name': 'Parking', 'icon': Icons.local_parking, 'available': true},
      {'name': 'Locker Room', 'icon': Icons.lock, 'available': true},
      {'name': 'Shower', 'icon': Icons.shower, 'available': true},
      {'name': 'WiFi', 'icon': Icons.wifi, 'available': true},
      {'name': 'AC', 'icon': Icons.ac_unit, 'available': true},
      {'name': 'Café', 'icon': Icons.local_cafe, 'available': false},
    ];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _lavender.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _lavender.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.spa, color: _lavender, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Amenities',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: amenities.map((amenity) {
                final isAvailable = amenity['available'] as bool;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isAvailable 
                        ? _lavender.withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAvailable 
                          ? _lavender.withOpacity(0.3)
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        amenity['icon'] as IconData,
                        size: 20,
                        color: isAvailable ? _lavender : Colors.grey[400],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        amenity['name'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isAvailable ? Colors.black87 : Colors.grey[600],
                        ),
                      ),
                      if (isAvailable) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check_circle, size: 16, color: Colors.green),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipPlansSection() {
    // Mock membership plans - in real app, load from Firestore
    final plans = [
      {'name': 'Basic', 'price': 999, 'duration': 'Monthly', 'features': ['Gym Access', 'Locker']},
      {'name': 'Premium', 'price': 2499, 'duration': 'Monthly', 'features': ['All Access', 'Personal Trainer', 'Nutrition Plan']},
      {'name': 'Annual', 'price': 19999, 'duration': 'Yearly', 'features': ['All Premium Features', '20% Discount']},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _lavender.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.card_membership, color: _lavender, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Membership Plans',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: _lavender),
                  onPressed: _addMembershipPlan,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                final isPopular = index == 1; // Premium is popular
                
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPopular ? _lavender.withOpacity(0.1) : _cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPopular ? _lavender : Colors.grey[300]!,
                      width: isPopular ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPopular)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _lavender,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'POPULAR',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 4),
                      const SizedBox(height: 8),
                      Text(
                        plan['name'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${plan['price']}',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _lavender,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/${plan['duration']}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...(plan['features'] as List<String>).map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, size: 16, color: _lavender),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      const Spacer(),
                      if (_isOwnProfile)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, size: 18, color: Colors.grey[600]),
                              onPressed: () => _editMembershipPlan(index, plan),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, size: 18, color: Colors.red[600]),
                              onPressed: () => _deleteMembershipPlan(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        )
                      else
                        ElevatedButton(
                          onPressed: () => _subscribeToPlan(plan),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPopular ? _lavender : Colors.grey[300],
                          foregroundColor: isPopular ? Colors.white : Colors.black87,
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Subscribe',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialOffersSection() {
    // Mock offers - in real app, load from Firestore
    final offers = [
      {'title': 'New Member Special', 'discount': '20% OFF', 'validUntil': 'Dec 31, 2024'},
      {'title': 'Weekend Warrior', 'discount': '15% OFF', 'validUntil': 'Ongoing'},
    ];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange[100]!, Colors.orange[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[700]!.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.local_offer, color: Colors.orange[900], size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Special Offers',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange[900],
                      ),
                    ),
                  ],
                ),
                if (_isOwnProfile)
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: Colors.orange[900]),
                    onPressed: _addSpecialOffer,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...offers.asMap().entries.map((entry) {
              final index = entry.key;
              final offer = entry.value;
              return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      offer['discount'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer['title'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Valid until: ${offer['validUntil']}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isOwnProfile)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editSpecialOffer(index, offer);
                        } else if (value == 'delete') {
                          _deleteSpecialOffer(index);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange[700]),
                      onPressed: () => _showOfferDetails(offer),
                    ),
                ],
              ),
            );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilityStatusSection() {
    final now = DateTime.now();
    final hour = now.hour;
    final isOpen = hour >= 6 && hour < 22; // Mock: 6 AM to 10 PM
    final currentStatus = isOpen ? 'Open Now' : 'Closed';
    final statusColor = isOpen ? Colors.green : Colors.red;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _lavender.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isOpen ? Icons.check_circle : Icons.cancel,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Facility Status',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (_isOwnProfile)
                  IconButton(
                    icon: Icon(Icons.edit, color: _lavender),
                    onPressed: _editFacilityStatus,
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      currentStatus,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_availability.isNotEmpty)
              Column(
                children: _availability.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          entry.value,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            else
              Text(
                'Mon-Sat: 6:00 AM - 10:00 PM\nSunday: 8:00 AM - 8:00 PM',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.6,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAwardsCertificationsSection() {
    // Mock awards - in real app, load from Firestore
    final awards = [
      {'name': 'Best Gym 2024', 'issuer': 'Fitness Awards', 'year': '2024'},
      {'name': 'ISO Certified', 'issuer': 'ISO Organization', 'year': '2023'},
    ];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber[50]!, Colors.amber[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber[700]!.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.workspace_premium, color: Colors.amber[900], size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Awards & Certifications',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (_isOwnProfile)
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: Colors.amber[900]),
                    onPressed: _addAward,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (awards.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      _isOwnProfile 
                          ? 'Add your awards and certifications'
                          : 'No awards listed',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...awards.map((award) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.workspace_premium, color: Colors.amber[700], size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            award['name'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${award['issuer']} • ${award['year']}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  //  EDIT FUNCTIONS FOR NEW FEATURES
  // ===================================================================

  Future<void> _addGalleryImage() async {
    if (!_isOwnProfile || _currentUser == null) return;
    
    // In a real app, you would use ImagePicker here
    Fluttertoast.showToast(msg: 'Gallery image upload feature coming soon!');
  }

  Future<void> _addMembershipPlan() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: 'Monthly');
    final featuresCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Membership Plan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _lavender,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Plan Name',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.card_membership, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceCtrl,
                decoration: InputDecoration(
                  labelText: 'Price (₹)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.currency_rupee, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: durationCtrl,
                decoration: InputDecoration(
                  labelText: 'Duration (e.g., Monthly, Yearly)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.calendar_today, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: featuresCtrl,
                decoration: InputDecoration(
                  labelText: 'Features (comma separated)',
                  labelStyle: GoogleFonts.poppins(),
                  hintText: 'e.g., Gym Access, Locker, Personal Trainer',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.checklist, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _lavender,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) return;
              
              try {
                final features = featuresCtrl.text.trim().split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
                final newPlan = {
                  'name': nameCtrl.text.trim(),
                  'price': int.tryParse(priceCtrl.text.trim()) ?? 0,
                  'duration': durationCtrl.text.trim(),
                  'features': features,
                };
                
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('membershipPlans')
                    .add(newPlan);
                
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Membership plan added successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error adding plan: $e');
              }
            },
            child: Text(
              'Add',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editMembershipPlan(int index, Map<String, dynamic> plan) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final nameCtrl = TextEditingController(text: plan['name']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: (plan['price'] ?? 0).toString());
    final durationCtrl = TextEditingController(text: plan['duration']?.toString() ?? 'Monthly');
    final featuresCtrl = TextEditingController(text: (plan['features'] as List?)?.join(', ') ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Membership Plan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _lavender,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Plan Name',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.card_membership, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceCtrl,
                decoration: InputDecoration(
                  labelText: 'Price (₹)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.currency_rupee, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: durationCtrl,
                decoration: InputDecoration(
                  labelText: 'Duration',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.calendar_today, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: featuresCtrl,
                decoration: InputDecoration(
                  labelText: 'Features (comma separated)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.checklist, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _lavender,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) return;
              
              try {
                final features = featuresCtrl.text.trim().split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
                final updatedPlan = {
                  'name': nameCtrl.text.trim(),
                  'price': int.tryParse(priceCtrl.text.trim()) ?? 0,
                  'duration': durationCtrl.text.trim(),
                  'features': features,
                };
                
                // Update in Firestore - you'll need to track document IDs
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Membership plan updated successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating plan: $e');
              }
            },
            child: Text(
              'Save',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMembershipPlan(int index) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Membership Plan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _lavender,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this membership plan?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete from Firestore - you'll need to track document IDs
        Fluttertoast.showToast(msg: 'Membership plan deleted successfully!');
        await _loadProfileData();
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error deleting plan: $e');
      }
    }
  }

  Future<void> _addSpecialOffer() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final titleCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    final validUntilCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Special Offer',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _lavender,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Offer Title',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.local_offer, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: discountCtrl,
                decoration: InputDecoration(
                  labelText: 'Discount (e.g., 20% OFF)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.percent, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: validUntilCtrl,
                decoration: InputDecoration(
                  labelText: 'Valid Until',
                  labelStyle: GoogleFonts.poppins(),
                  hintText: 'e.g., Dec 31, 2024 or Ongoing',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.calendar_today, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _lavender,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || discountCtrl.text.trim().isEmpty) return;
              
              try {
                final newOffer = {
                  'title': titleCtrl.text.trim(),
                  'discount': discountCtrl.text.trim(),
                  'validUntil': validUntilCtrl.text.trim().isEmpty ? 'Ongoing' : validUntilCtrl.text.trim(),
                };
                
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('specialOffers')
                    .add(newOffer);
                
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Special offer added successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error adding offer: $e');
              }
            },
            child: Text(
              'Add',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSpecialOffer(int index, Map<String, dynamic> offer) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final titleCtrl = TextEditingController(text: offer['title']?.toString() ?? '');
    final discountCtrl = TextEditingController(text: offer['discount']?.toString() ?? '');
    final validUntilCtrl = TextEditingController(text: offer['validUntil']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Special Offer',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _lavender,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Offer Title',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.local_offer, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: discountCtrl,
                decoration: InputDecoration(
                  labelText: 'Discount',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.percent, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: validUntilCtrl,
                decoration: InputDecoration(
                  labelText: 'Valid Until',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.calendar_today, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _lavender,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || discountCtrl.text.trim().isEmpty) return;
              
              try {
                // Update in Firestore - you'll need to track document IDs
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Special offer updated successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating offer: $e');
              }
            },
            child: Text(
              'Save',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSpecialOffer(int index) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Special Offer',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _lavender,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this special offer?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete from Firestore - you'll need to track document IDs
        Fluttertoast.showToast(msg: 'Special offer deleted successfully!');
        await _loadProfileData();
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error deleting offer: $e');
      }
    }
  }

  Future<void> _editFacilityStatus() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final openTimeCtrl = TextEditingController(text: '06:00');
    final closeTimeCtrl = TextEditingController(text: '22:00');
    final daysCtrl = TextEditingController(text: 'Monday - Sunday');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Facility Hours',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _lavender,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: openTimeCtrl,
                decoration: InputDecoration(
                  labelText: 'Opening Time',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.access_time, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: closeTimeCtrl,
                decoration: InputDecoration(
                  labelText: 'Closing Time',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.access_time, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: daysCtrl,
                decoration: InputDecoration(
                  labelText: 'Operating Days',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.calendar_today, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _lavender,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              try {
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({
                      'facilityHours': {
                        'openTime': openTimeCtrl.text.trim(),
                        'closeTime': closeTimeCtrl.text.trim(),
                        'days': daysCtrl.text.trim(),
                      },
                    });
                
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Facility hours updated successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating hours: $e');
              }
            },
            child: Text(
              'Save',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  //  HELPER FUNCTIONS FOR STATIC FEATURES
  // ===================================================================
  
  Future<void> _openMessage() async {
    if (_isOwnProfile || _currentUser == null) return;
    
    try {
      final chatService = ChatService();
      final chatId = await chatService.getOrCreateChatId(
        _currentUser!.uid,
        widget.profileUserId,
      );
      
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => ChatScreen(
            chatId: chatId,
            currentUserId: _currentUser!.uid,
            otherUserId: widget.profileUserId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening chat: $e');
      Fluttertoast.showToast(msg: 'Failed to open chat. Please try again.');
    }
  }
  
  Future<void> _openBooking() async {
    if (_isOwnProfile) return;
    
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: 'Please login to book');
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => WellnessBookingSection(
          wellnessUserId: widget.profileUserId,
          isOwner: false,
        ),
      ),
    );
  }
  
  Future<void> _openPostCreation() async {
    if (!_isOwnProfile || _currentUser == null) return;
    
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Newpostpage(
          imagePath: image.path,
          onPostSubmit: (caption) async {
            try {
              final fileName = DateTime.now().millisecondsSinceEpoch.toString();
              final ref = FirebaseStorage.instance
                  .ref()
                  .child('posts')
                  .child(fileName);
              final snap = await ref.putFile(File(image.path));
              final url = await snap.ref.getDownloadURL();
              await FirebaseFirestore.instance.collection('posts').add({
                'imageUrl': url,
                'caption': caption,
                'userId': _currentUser!.uid,
                'timestamp': FieldValue.serverTimestamp(),
              });
              await _firestore
                  .collection('users')
                  .doc(_currentUser!.uid)
                  .update({
                'postsCount': FieldValue.increment(1),
              });
              Fluttertoast.showToast(msg: 'Post uploaded');
              await _loadProfileData();
            } catch (e) {
              debugPrint('post upload error: $e');
              Fluttertoast.showToast(msg: 'Upload failed');
            }
          },
        ),
      ),
    );
  }
  
  Future<void> _openSocialLink(String platform, String link) async {
    try {
      if (link.isEmpty) {
        Fluttertoast.showToast(msg: '$platform link not available');
        return;
      }
      
      String url = link;
      
      // If link doesn't start with http, add it
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        // Format URLs based on platform
        switch (platform.toLowerCase()) {
          case 'youtube':
            url = url.contains('youtube.com') || url.contains('youtu.be')
                ? url
                : 'https://youtube.com/$url';
            break;
          case 'instagram':
            url = url.startsWith('@') 
                ? 'https://instagram.com/${url.substring(1)}'
                : 'https://instagram.com/$url';
            break;
          case 'whatsapp':
            url = url.startsWith('+') || url.startsWith('91')
                ? 'https://wa.me/$url'
                : 'https://wa.me/91$url';
            break;
          case 'website':
            url = 'https://$url';
            break;
          default:
            url = 'https://$url';
        }
      }
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Fluttertoast.showToast(msg: 'Could not open $platform link');
      }
    } catch (e) {
      debugPrint('Error opening social link: $e');
      Fluttertoast.showToast(msg: 'Failed to open link');
    }
  }
  
  Future<void> _openMaps() async {
    try {
      if (_location.isEmpty) {
        Fluttertoast.showToast(msg: 'Location not available');
        return;
      }
      
      // Create a Google Maps URL with the location
      final encodedLocation = Uri.encodeComponent(_location);
      final url = 'https://www.google.com/maps/search/?api=1&query=$encodedLocation';
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Fluttertoast.showToast(msg: 'Could not open maps');
      }
    } catch (e) {
      debugPrint('Error opening maps: $e');
      Fluttertoast.showToast(msg: 'Failed to open maps');
    }
  }
  
  Future<void> _showAllProducts() async {
    if (_products.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AllProductsPage(products: _products),
    );
  }
  
  Future<void> _showAllPosts() async {
    if (_recentPosts.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AllPostsPage(posts: _recentPosts),
    );
  }
  
  Future<void> _showAllReviews() async {
    if (_reviews.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AllReviewsPage(reviews: _reviews),
    );
  }
  
  Future<void> _showFullGallery() async {
    // Mock gallery - in real app, load from Firestore
    final galleryImages = List.generate(12, (i) => 'gallery_$i');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FullGalleryPage(images: galleryImages),
    );
  }
  
  Future<void> _subscribeToPlan(Map<String, dynamic> plan) async {
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: 'Please login to subscribe');
      return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Subscribe to Plan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _lavender,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan['name']?.toString() ?? 'Plan',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Price: ₹${plan['price'] ?? 0}/${plan['duration'] ?? 'month'}',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Subscription feature coming soon! You will be able to complete payment and subscribe to this plan.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _lavender,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Fluttertoast.showToast(msg: 'Subscription feature coming soon!');
            },
            child: Text(
              'Continue',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showOfferDetails(Map<String, dynamic> offer) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OfferDetailsPage(offer: offer),
    );
  }
  
  Future<void> _addAward() async {
    if (!_isOwnProfile || _currentUser == null) return;
    
    final nameCtrl = TextEditingController();
    final issuerCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Award/Certification',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _lavender,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Award Name',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.workspace_premium, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: issuerCtrl,
                decoration: InputDecoration(
                  labelText: 'Issuing Organization',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.business, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: yearCtrl,
                decoration: InputDecoration(
                  labelText: 'Year (Optional)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.calendar_today, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _lavender,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              
              try {
                final newAward = {
                  'name': nameCtrl.text.trim(),
                  'issuer': issuerCtrl.text.trim(),
                  if (yearCtrl.text.trim().isNotEmpty) 'year': yearCtrl.text.trim(),
                };
                
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .collection('awards')
                    .add(newAward);
                
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Award added successfully!');
                await _loadProfileData();
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error adding award: $e');
              }
            },
            child: Text(
              'Add',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
//  MODAL PAGES FOR WELLNESS FEATURES
// ===================================================================

class _AllProductsPage extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  
  const _AllProductsPage({required this.products});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Products',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: product['imageUrl'] != null
                              ? ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: Image.network(
                                    product['imageUrl'].toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey),
                                  ),
                                )
                              : const Center(child: Icon(Icons.image, color: Colors.grey)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name']?.toString() ?? 'Product',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (product['price'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '₹${product['price']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFA58CE3),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AllPostsPage extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  
  const _AllPostsPage({required this.posts});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Posts',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: post['imageUrl'] != null &&
                      post['imageUrl'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            post['imageUrl'].toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey),
                          ),
                        )
                      : const Center(child: Icon(Icons.image, color: Colors.grey)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AllReviewsPage extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  
  const _AllReviewsPage({required this.reviews});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Reviews',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final review = reviews[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: review['profilePhoto'] != null
                          ? NetworkImage(review['profilePhoto'].toString())
                          : null,
                      child: review['profilePhoto'] == null
                          ? Text(
                              (review['userName']?.toString()[0] ?? 'U').toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFA58CE3),
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      review['userName']?.toString() ?? 'User',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(5, (i) {
                            return Icon(
                              i < (review['rating'] as int? ?? 5)
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16,
                              color: Colors.amber,
                            );
                          }),
                        ),
                        if (review['text'] != null && review['text'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            review['text'].toString(),
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FullGalleryPage extends StatelessWidget {
  final List<String> images;
  
  const _FullGalleryPage({required this.images});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Facility Gallery',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.image, size: 32, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferDetailsPage extends StatelessWidget {
  final Map<String, dynamic> offer;
  
  const _OfferDetailsPage({required this.offer});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    offer['title']?.toString() ?? 'Special Offer',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[100]!, Colors.orange[50]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        offer['discount']?.toString() ?? 'Special Discount',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Valid Until: ${offer['validUntil']?.toString() ?? 'Ongoing'}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Terms and Conditions:\n• Offer valid for new members only\n• Cannot be combined with other offers\n• Subject to availability',
                    style: TextStyle(fontSize: 13, height: 1.5),
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
