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
import 'package:classic_1/Bottom Pages/PrivacySettingsPage.dart';
import 'package:classic_1/Bottom Pages/SettingsPage.dart';

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
      QuerySnapshot<Map<String, dynamic>> postsSnapshot;
      try {
        postsSnapshot = await _firestore
            .collection('posts')
            .where('userId', isEqualTo: widget.profileUserId)
            .orderBy('timestamp', descending: true)
            .limit(9)
            .get();
      } catch (_) {
        try {
          postsSnapshot = await _firestore
              .collection('posts')
              .where('userId', isEqualTo: widget.profileUserId)
              .orderBy('createdAt', descending: true)
              .limit(9)
              .get();
        } catch (_) {
          postsSnapshot = await _firestore
              .collection('posts')
              .where('userId', isEqualTo: widget.profileUserId)
              .limit(9)
              .get();
        }
      }

      _recentPosts = postsSnapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.id,
          'imageUrl': d['imageUrl'] ?? '',
          'caption': d['caption'] ?? '',
          'timestamp': d['timestamp'] ?? d['createdAt'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading posts: $e');
      _recentPosts = [];
    }
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
                                Text(
                                  _category,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _deepLavender,
                                    letterSpacing: 0.2,
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
              onPressed: () {
                // TODO: Open message
              },
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
              onPressed: () {
                // TODO: Open booking
              },
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
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
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
                    onPressed: () {
                      // TODO: Open post creation
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'Edit Profile') {
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
                      } else if (value == 'Settings') {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (ctx) => SettingsPage()),
                        );
                        if (result == 'logout') {
                          await _auth.signOut();
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => LoginPage()));
                        }
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
                        icon: Icon(Icons.dashboard_outlined, size: 24),
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
                onPressed: () {},
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
                onPressed: () {},
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
                      onPressed: () {
                        // TODO: Open maps
                      },
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
                  onPressed: () {},
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
                      onPressed: () {
                        // TODO: Open Instagram
                      },
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
                      onPressed: () {
                        // TODO: Open YouTube
                      },
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
                      onPressed: () {
                        // TODO: Open website
                      },
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
                      onPressed: () {
                        // TODO: Open WhatsApp
                      },
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
}
