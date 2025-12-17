// profile_page_improved.dart  (Aspirant Profile)

// -------------------- IMPORTS --------------------
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:classic_1/newpostpage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:classic_1/Profile Pages/guru_profile_page.dart' as guru_profile;
import 'package:classic_1/Profile Pages/wellness_profile_page.dart' as wellness_profile;


// Local pages (paths adjust kar lena agar different ho)
import '../editprofilepage.dart';
import '../main.dart'; // LoginPage
import 'package:classic_1/Bottom Pages/PrivacySettingsPage.dart';
import 'package:classic_1/Bottom Pages/SettingsPage.dart';
import '../spotify_player_widget.dart'; // optional, tum use kar sakte ho
import 'edit_profile_sections.dart'; // Edit pages for profile sections

// ===================================================================
//  ASPIRANT PROFILE PAGE (HALO – HOBBY BASED ASPIRANT)
// ===================================================================

/// Wrapper class
class ProfilePage extends StatelessWidget {
  final String profileUserId; // Jis aspirant ki profile dekhni hai

  const ProfilePage({Key? key, required this.profileUserId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProfilePageImproved(profileUserId: profileUserId);
  }
}

class ProfilePageImproved extends StatefulWidget {
  final String profileUserId;

  const ProfilePageImproved({Key? key, required this.profileUserId})
      : super(key: key);

  @override
  _ProfilePageImprovedState createState() => _ProfilePageImprovedState();
}

class _ProfilePageImprovedState extends State<ProfilePageImproved>
    with TickerProviderStateMixin {
  // -------------------- FIREBASE --------------------
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser; // logged in user
  bool _isOwnProfile = false; // current user == profile user ?

  // -------------------- USER DATA (ASPIRANT) --------------------
  String _fullName = '';
  String _username = '';
  String _fitnessTag = ''; // legacy field, use as "tagline" if needed
  String _city = '';
  int? _age;
  String _bio = '';
  String? _profilePhotoUrl;
  String? _coverPhotoUrl;
  List<String> _fitnessGoals = [];
  String? _fitnessLevel;
  List<String> _interests = []; // Hobbies / categories (cricket, dance, yoga...)
  List<String> _healthNotes = [];

  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  // ---- Aspirant extra UI data ----
  List<Map<String, dynamic>> _lastWorkouts = [];        // now "Recent Activities"
  List<Map<String, dynamic>> _eventsChallenges = [];
  List<Map<String, dynamic>> _fitnessArticles = [];     // now "Learning Resources"
  Map<String, dynamic> _fitnessStats = {};              // now "Activity Stats"
  Map<String, String> _socialLinks = {};
  List<String> _badges = [];                            // Achievements / badges
  String? _primaryCategory;                             // main hobby (e.g. Cricket)

  // -------------------- UI CONSTANTS --------------------
  static const double _coverHeight = 220.0;
  static const double _avatarSize = 90.0;
  static const double _avatarOverlap = 30.0;
  static const Color _lavender = Color(0xFFA58CE3);
  static const Color _deepLavender = Color(0xFF6D4DB3);
  static const Color _bg = Color(0xFFF4F1FB);
  static const Color _chipBg = Color(0xFFEDE7F6);

  // -------------------- INTERACTION STATE --------------------
  bool _isFollowing = false;
  bool _isPrivate = false;
  bool _isLoading = true;

  // Image picker
  final ImagePicker _picker = ImagePicker();
  File? _profilePhotoFile;
  File? _coverPhotoFile;

  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // Animations
  late final AnimationController _followAnimController;

  @override
  void initState() {
    super.initState();
    _followAnimController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _loadProfileData(); // aspirant data load
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _followAnimController.dispose();
    super.dispose();
  }

  // ===================================================================
  //  DATA LOAD (ASPIRANT + FOLLOW STATUS)
  // ===================================================================
  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = _auth.currentUser;
      _isOwnProfile =
          _currentUser != null && _currentUser!.uid == widget.profileUserId;

      // Aspirant user document
      final doc =
      await _firestore.collection('users').doc(widget.profileUserId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final accountType = data['category']?.toString().toLowerCase() ?? 'aspirant';

// agar guru found → guru page open
        if (accountType == 'guru') {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => guru_profile.GuruProfilePage(
                  profileUserId: widget.profileUserId,
                ),
              ),
            );
          });
          return;
        }

// agar wellness found → wellness page open
        if (accountType == 'wellness') {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => wellness_profile.WellnessProfilePage(
                  profileUserId: widget.profileUserId,
                ),
              ),
            );
          });
          return;
        }

        _fullName = (data['name'] ?? '') as String;
        _username = (data['username'] ?? '') as String;
        _fitnessTag = (data['fitnessTag'] ?? 'Explorer on Halo') as String;
        _city = (data['city'] ?? '') as String;
        _age = data['age'] is int ? data['age'] as int : null;
        _bio = (data['bio'] ?? '') as String;
        _profilePhotoUrl = data['profilePhoto'] as String?;
        _coverPhotoUrl = data['coverPhoto'] as String?;
        _fitnessGoals = List<String>.from(data['fitnessGoals'] ?? []);
        _fitnessLevel = data['fitnessLevel'] as String?;
        _interests = List<String>.from(data['interests'] ?? []);
        _healthNotes = List<String>.from(data['healthNotes'] ?? []);
        _followersCount = (data['followersCount'] ?? 0) as int;
        _followingCount = (data['followingCount'] ?? 0) as int;
        _postsCount = (data['postsCount'] ?? 0) as int;
        _isPrivate = (data['isPrivate'] ?? false) as bool;
        _primaryCategory = data['primaryCategory'] as String?;
        _badges = List<String>.from(data['badges'] ?? []);

        // ---- Aspirant extra UI data ----

        // Last workouts / activities
        final lastWorkoutsRaw = data['lastWorkouts'] as List<dynamic>?;
        if (lastWorkoutsRaw != null && lastWorkoutsRaw.isNotEmpty) {
          _lastWorkouts = lastWorkoutsRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else {
          _lastWorkouts = [];
        }

        // Events & Challenges
        final eventsRaw = data['eventsChallenges'] as List<dynamic>?;
        if (eventsRaw != null && eventsRaw.isNotEmpty) {
          _eventsChallenges = eventsRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else {
          _eventsChallenges = [];
        }

        // Articles / learning resources
        final articlesRaw = data['fitnessArticles'] as List<dynamic>?;
        if (articlesRaw != null && articlesRaw.isNotEmpty) {
          _fitnessArticles = articlesRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else {
          _fitnessArticles = [];
        }

        // Stats
        final statsRaw = data['fitnessStats'] as Map<String, dynamic>?;
        if (statsRaw != null) {
          _fitnessStats = Map<String, dynamic>.from(statsRaw);
        } else {
          _fitnessStats = {
            'steps': 0,
            'caloriesBurned': 0,
            'workouts': 0,
          };
        }

        // Social links
        final sl = data['socialLinks'] as Map<String, dynamic>?;
        _socialLinks = sl != null
            ? sl.map((k, v) => MapEntry(k, v.toString()))
            : {
          'instagram': 'Instagram',
          'spotify': 'Spotify',
          'telegram': 'Telegram',
        };
      }

      // Follow status: kya current user is aspirant ko follow karta hai?
      if (_currentUser != null && !_isOwnProfile) {
        final followDoc = await _firestore
            .collection('users')
            .doc(widget.profileUserId)
            .collection('followers')
            .doc(_currentUser!.uid)
            .get();

        _isFollowing = followDoc.exists;
      }
    } catch (e) {
      debugPrint('profile load error: $e');
      Fluttertoast.showToast(msg: 'Failed to load profile');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ===================================================================
  //  CAMERA / IMAGE HANDLING (PROFILE + COVER)
  // ===================================================================
  Future<void> _initializeCamera() async {
    try {
      final currentStatus = await Permission.camera.status;
      if (currentStatus != PermissionStatus.granted) {
        final status = await Permission.camera.request();
        if (status != PermissionStatus.granted) return;
      }

      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController =
            CameraController(_cameras![0], ResolutionPreset.high);
        await _cameraController!.initialize();
        if (!mounted) return;
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('camera init error: $e');
    }
  }

  Future<void> _pickProfileImage() async {
    if (!_isOwnProfile || _currentUser == null) return; // sirf apni profile edit
    final XFile? picked =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _profilePhotoFile = File(picked.path));
    await _uploadAndSaveProfilePhoto(_profilePhotoFile!, isCover: false);
  }

  Future<void> _pickCoverImage() async {
    if (!_isOwnProfile || _currentUser == null) return;
    final XFile? picked =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _coverPhotoFile = File(picked.path));
    await _uploadAndSaveProfilePhoto(_coverPhotoFile!, isCover: true);
  }

  Future<void> _uploadAndSaveProfilePhoto(File file,
      {required bool isCover}) async {
    if (_currentUser == null) return;
    try {
      final fileName =
          '${isCover ? 'cover' : 'profile'}_${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(_currentUser!.uid)
          .child(fileName);
      final task = ref.putFile(file);
      final snap = await task;
      final url = await snap.ref.getDownloadURL();
      final key = isCover ? 'coverPhoto' : 'profilePhoto';

      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update({key: url});

      if (!mounted) return;
      setState(() {
        if (isCover) {
          _coverPhotoUrl = url;
        } else {
          _profilePhotoUrl = url;
        }
      });
      Fluttertoast.showToast(msg: 'Photo updated');
    } catch (e) {
      debugPrint('upload error: $e');
      Fluttertoast.showToast(msg: 'Upload failed');
    }
  }

  // ===================================================================
  //  FOLLOW / UNFOLLOW (INSTAGRAM STYLE)
  // ===================================================================
  Future<void> _toggleFollow() async {
    if (_currentUser == null || _isOwnProfile) return;

    final String currentUserId = _currentUser!.uid;
    final String profileUserId = widget.profileUserId;

    final followersDocRef = _firestore
        .collection('users')
        .doc(profileUserId)
        .collection('followers')
        .doc(currentUserId);

    final followingDocRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(profileUserId);

    final bool wasFollowing = _isFollowing;

    // Optimistic UI
    setState(() {
      _isFollowing = !wasFollowing;
      _followersCount += wasFollowing ? -1 : 1;
      if (_followersCount < 0) _followersCount = 0;
    });
    _followAnimController.forward(from: 0);

    try {
      await _firestore.runTransaction((transaction) async {
        final profileUserRef =
        _firestore.collection('users').doc(profileUserId);
        final currentUserRef =
        _firestore.collection('users').doc(currentUserId);

        if (!wasFollowing) {
          // FOLLOW
          transaction.set(followersDocRef, {
            'followerId': currentUserId,
            'createdAt': FieldValue.serverTimestamp(),
          });

          transaction.set(followingDocRef, {
            'followingId': profileUserId,
            'createdAt': FieldValue.serverTimestamp(),
          });

          transaction.update(profileUserRef, {
            'followersCount': FieldValue.increment(1),
          });

          transaction.update(currentUserRef, {
            'followingCount': FieldValue.increment(1),
          });
        } else {
          // UNFOLLOW
          transaction.delete(followersDocRef);
          transaction.delete(followingDocRef);

          transaction.update(profileUserRef, {
            'followersCount': FieldValue.increment(-1),
          });

          transaction.update(currentUserRef, {
            'followingCount': FieldValue.increment(-1),
          });
        }
      });
    } catch (e) {
      debugPrint('follow toggle error: $e');

      // Rollback UI
      setState(() {
        _isFollowing = wasFollowing;
        _followersCount += wasFollowing ? 1 : -1;
        if (_followersCount < 0) _followersCount = 0;
      });

      Fluttertoast.showToast(
        msg: 'Something went wrong. Please try again.',
      );
    }
  }

  Future<void> _openMessage() async {
    if (_isOwnProfile) return;
    Fluttertoast.showToast(msg: 'Open chat (not implemented yet)');
  }

  // ===================================================================
  //  POST CREATION (ASPIRANT FEED)
  // ===================================================================
  Future<void> _openGalleryForPost() async {
    if (!_isOwnProfile) return; // sirf apne profile se post
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (_currentUser == null) {
      Fluttertoast.showToast(msg: 'Please sign in to post');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Newpostpage(
          imagePath: image.path,
          onPostSubmit: (caption) async {
            try {
              final fileName =
              DateTime.now().millisecondsSinceEpoch.toString();
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

  // ===================================================================
  //  EDIT PROFILE / SETTINGS / LOGOUT (ONLY OWN PROFILE)
  // ===================================================================
  Future<void> _handleEditProfile() async {
    if (!_isOwnProfile || _currentUser == null) return;
    final updatedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => EditProfilePage(
          initialUsername: _username,
          initialName: _fullName,
          initialBio: _bio,
          initialGender: '',
          initialprofessiontype: '',
        ),
      ),
    );
    if (updatedData != null) {
      try {
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'username': updatedData['username'],
          'name': updatedData['name'],
          'bio': updatedData['bio'],
        });
        await _loadProfileData();
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to save profile');
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (ctx) => LoginPage()),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: 'Logout failed');
    }
  }

  // ===================================================================
  //  UI HELPERS (HEADER PARTS)
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
      tag: 'profile-avatar-${widget.profileUserId}',
      child: GestureDetector(
        onTap: _isOwnProfile ? _pickProfileImage : null,
        child: Container(
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
      ),
    );
  }

  Widget _buildStatsCard() {
    Widget tile(String count, String label) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          tile(_followersCount.toString(), 'Followers'),
          Container(width: 1, height: 36, color: Colors.grey[200]),
          tile(_followingCount.toString(), 'Following'),
          Container(width: 1, height: 36, color: Colors.grey[200]),
          tile(_postsCount.toString(), 'Posts'),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: _isOwnProfile
          ? SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _handleEditProfile,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            side: const BorderSide(color: _lavender),
          ),
          child: const Text('Edit Profile'),
        ),
      )
          : Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: ElevatedButton.icon(
                key: ValueKey(_isFollowing),
                onPressed: _toggleFollow,
                icon: Icon(
                  _isFollowing ? Icons.check : Icons.person_add,
                  color: _isFollowing ? Colors.black : Colors.white,
                ),
                label: Text(
                  _isFollowing ? 'Following' : 'Follow',
                  style: TextStyle(
                    color: _isFollowing ? Colors.black : Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  _isFollowing ? Colors.white : _lavender,
                  side: _isFollowing
                      ? const BorderSide(color: _deepLavender)
                      : null,
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openMessage,
              icon: const Icon(Icons.message_outlined),
              label: const Text('Message'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioCard() {
    final displayBio = _bio.isNotEmpty
        ? _bio
        : (_isOwnProfile
        ? 'Add a short bio — tell people what you love (cricket, dance, yoga, etc.).'
        : '');

    if (displayBio.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Text(
          displayBio,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.4),
        ),
      ),
    );
  }

  // ===================================================================
  //  NEW ASPIRANT UI SECTIONS (HOBBY FOCUSED)
  // ===================================================================

  /// Tabs – abhi sirf visual
  Widget _buildAspirantTabsRow() {
    final tabs = ['Overview', 'Coaches', 'Wellness', 'Community'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: tabs
            .map(
              (t) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: t == 'Overview'
                    ? Colors.blue
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                t,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: t == 'Overview'
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ),
          ),
        )
            .toList(),
      ),
    );
  }

  // -------------------- Suggested Gurus --------------------
  Widget _buildSuggestedGurusSection() {
    // Assume: users collection me field: profileType == 'guru'
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('profileType', isEqualTo: 'guru');

    if (_interests.isNotEmpty) {
      final List<String> topInterests = _interests.length > 5
          ? _interests.sublist(0, 5)
          : _interests;
      query = query.where('interests', arrayContainsAny: topInterests);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Suggested Gurus (Coaches)',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (_primaryCategory != null && _primaryCategory!.isNotEmpty)
                Text(
                  _primaryCategory!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.limit(10).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Text(
                    'No gurus found yet for your interests.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                    ),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();
                    final name = (data['name'] ?? 'Guru') as String;
                    final category =
                    (data['primaryCategory'] ?? '') as String;
                    final photo = data['profilePhoto'] as String?;
                    return Container(
                      width: 90,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundImage: photo != null
                                ? NetworkImage(photo)
                                : const AssetImage(
                              'assets/images/Profile.png',
                            ) as ImageProvider,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (category.isNotEmpty)
                            Text(
                              category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
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
        ],
      ),
    );
  }

  // -------------------- Suggested Wellness --------------------
  Widget _buildSuggestedWellnessSection() {
    // Assume: profileType == 'wellness'
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('profileType', isEqualTo: 'wellness');

    if (_interests.isNotEmpty) {
      final List<String> topInterests = _interests.length > 5
          ? _interests.sublist(0, 5)
          : _interests;
      query = query.where('interests', arrayContainsAny: topInterests);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore Wellness (Shops / Places)',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.limit(10).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Text(
                    'No wellness profiles yet. They will appear here.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                    ),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();
                    final name = (data['name'] ?? 'Wellness') as String;
                    final category =
                    (data['primaryCategory'] ?? '') as String;
                    final photo = data['profilePhoto'] as String?;
                    return Container(
                      width: 140,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: photo != null
                                ? NetworkImage(photo)
                                : const AssetImage(
                              'assets/images/Profile.png',
                            ) as ImageProvider,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (category.isNotEmpty)
                                  Text(
                                    category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
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
        ],
      ),
    );
  }

  // -------------------- Similar Aspirants --------------------
  Widget _buildSimilarAspirantsSection() {
    // Assume: profileType == 'aspirant'
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('profileType', isEqualTo: 'aspirant');

    if (_primaryCategory != null && _primaryCategory!.isNotEmpty) {
      query = query.where('primaryCategory', isEqualTo: _primaryCategory);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'People Like You',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.limit(15).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                var docs = snapshot.data?.docs ?? [];
                // current user ko list se hata do
                docs = docs
                    .where((d) => d.id != widget.profileUserId)
                    .toList();
                if (docs.isEmpty) {
                  return Text(
                    'We will suggest other aspirants here.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                    ),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data();
                    final name = (data['name'] ?? 'User') as String;
                    final username = (data['username'] ?? '') as String;
                    final photo = data['profilePhoto'] as String?;
                    return Column(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: photo != null
                              ? NetworkImage(photo)
                              : const AssetImage(
                            'assets/images/Profile.png',
                          ) as ImageProvider,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 70,
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if (username.isNotEmpty)
                          SizedBox(
                            width: 70,
                            child: Text(
                              '@$username',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- Achievements & Badges --------------------
  Widget _buildAchievementsSection() {
    if (_badges.isEmpty && !_isOwnProfile) {
      return const SizedBox.shrink();
    }

    final displayBadges = _badges.isNotEmpty
        ? _badges
        : ['New to Halo'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Achievements & Badges',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (_isOwnProfile)
                Text(
                  'Auto-unlocks as you use Halo',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: displayBadges
                .map(
                  (b) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _chipBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      b,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
                .toList(),
          ),
        ],
      ),
    );
  }

  // -------------------- Recent Activities --------------------
  Widget _buildLastWorkoutsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activities',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (_isOwnProfile)
                TextButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => EditWorkoutsPage(
                          initialWorkouts: _lastWorkouts,
                          userType: 'aspirant',
                        ),
                      ),
                    );
                    if (updated != null) {
                      setState(() {
                        _lastWorkouts =
                        List<Map<String, dynamic>>.from(updated);
                      });
                      // Data is already saved to Firebase by EditWorkoutsPage
                    }
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_lastWorkouts.isEmpty && _isOwnProfile)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.star_border, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No activities yet. Add your first match, session or practice!',
                      style: GoogleFonts.poppins(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else if (_lastWorkouts.isEmpty)
            const SizedBox.shrink()
          else
            ..._lastWorkouts.map((w) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sports, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w['title']?.toString() ?? 'Activity',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 12,
                            runSpacing: 2,
                            children: [
                              if (w['intensity'] != null)
                                _smallTag(w['intensity'].toString()),
                              if (w['calories'] != null)
                                _smallTag(w['calories'].toString()),
                              if (w['duration'] != null)
                                _smallTag(w['duration'].toString()),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _smallTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 11),
      ),
    );
  }

  Widget _buildEventsChallengesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red[600],
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Events & Challenges',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_isOwnProfile)
                  TextButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => EditEventsChallengesPage(
                            initialEvents: _eventsChallenges,
                          ),
                        ),
                      );
                      if (updated != null) {
                        setState(() {
                          _eventsChallenges =
                          List<Map<String, dynamic>>.from(updated);
                        });
                        // Data is already saved to Firebase by EditEventsChallengesPage
                      }
                    },
                    icon:
                    const Icon(Icons.edit, size: 18, color: Colors.white),
                    label: const Text('Edit',
                        style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_eventsChallenges.isEmpty && _isOwnProfile)
              Center(
                child: Text(
                  'No events yet. Add your first tournament, show or meetup!',
                  style: GoogleFonts.poppins(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              )
            else if (_eventsChallenges.isEmpty)
              const SizedBox.shrink()
            else
              ..._eventsChallenges.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    '${e['type'] ?? ''}: ${e['name'] ?? ''}  (${e['status'] ?? ''})',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinksSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Social Links',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (_isOwnProfile)
                TextButton.icon(
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => EditSocialLinksPage(
                          initialLinks: _socialLinks,
                        ),
                      ),
                    );
                    if (updated != null) {
                      setState(() {
                        _socialLinks = Map<String, String>.from(updated);
                      });
                      // Data is already saved to Firebase by EditSocialLinksPage
                    }
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_socialLinks.isEmpty && _isOwnProfile)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'No social links yet. Add your links!',
                  style: GoogleFonts.poppins(),
                ),
              ),
            )
          else if (_socialLinks.isEmpty)
            const SizedBox.shrink()
          else
            Row(
              children: [
                if (_socialLinks['instagram'] != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: open Instagram link using url_launcher
                      },
                      child: const Text('Instagram'),
                    ),
                  ),
                if (_socialLinks['instagram'] != null)
                  const SizedBox(width: 8),
                if (_socialLinks['spotify'] != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: open Spotify link
                      },
                      child: const Text('Spotify'),
                    ),
                  ),
                if (_socialLinks['spotify'] != null)
                  const SizedBox(width: 8),
                if (_socialLinks['telegram'] != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: open Telegram link
                      },
                      child: const Text('Telegram'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHobbiesSection() {
    if (_interests.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hobbies & Mood',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interests
                .map(
                  (i) => Chip(
                label: Text(i),
              ),
            )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFitnessArticlesSection() {
    if (_fitnessArticles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning Resources',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ..._fitnessArticles.map((a) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                a['title']?.toString() ?? '',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                a['source']?.toString() ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: open article link if available
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildFitnessStatsSection() {
    final steps = _fitnessStats['steps'] ?? 0;
    final calories = _fitnessStats['caloriesBurned'] ?? 0;
    final workouts = _fitnessStats['workouts'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity Stats',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (_isOwnProfile)
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => EditFitnessStatsPage(
                          initialStats: _fitnessStats,
                        ),
                      ),
                    );
                    await _loadProfileData();
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard('Steps', steps.toString(), 'Today'),
              _buildStatCard('Calories', calories.toString(), 'Today'),
              _buildStatCard('Sessions', workouts.toString(), 'This week'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  //  POSTS GRID
  // ===================================================================
  Widget _buildRecentPostsGrid() {
    // Private account handling (Instagram style)
    if (_isPrivate && !_isFollowing && !_isOwnProfile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
        child: Text(
          'This account is private.\nFollow to see their posts.',
          style: GoogleFonts.poppins(),
        ),
      );
    }

    final userId = widget.profileUserId;
    final postsQuery = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Posts',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: postsQuery.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(color: _lavender),
                  ),
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'No posts yet',
                    style: GoogleFonts.poppins(),
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, idx) {
                  final doc = docs[idx];
                  final data = doc.data()! as Map<String, dynamic>;
                  final imageUrl = data['imageUrl'] as String?;
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => PostDetailsPage(postId: doc.id),
                      ),
                    ),
                    child: Hero(
                      tag: 'post-${doc.id}',
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[200],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: imageUrl != null
                            ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                        )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => UserAllPostsPage(userId: userId),
                ),
              ),
              child: const Text('View All Posts →'),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  //  BUILD  (Yahin se text ka color global dark ho raha hai)
// ===================================================================
  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final textTheme = baseTheme.textTheme.apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    );

    return Theme(
      data: baseTheme.copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: _bg,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: _coverHeight,
              backgroundColor: _lavender,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (_isOwnProfile) ...[
                  IconButton(
                    icon: const Icon(Icons.add_box_outlined),
                    onPressed: _openGalleryForPost,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'Edit Profile') {
                        await _handleEditProfile();
                      } else if (value == 'Privacy') {
                        if (_currentUser == null) return;
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => PrivacySettingsPage(
                              initialPrivacy: _isPrivate,
                            ),
                          ),
                        );
                        if (updated != null) {
                          try {
                            await _firestore
                                .collection('users')
                                .doc(_currentUser!.uid)
                                .update({'isPrivate': updated});
                            setState(() => _isPrivate = updated);
                          } catch (e) {
                            Fluttertoast.showToast(
                                msg: 'Failed to update privacy');
                          }
                        }
                      } else if (value == 'Settings') {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => SettingsPage(),
                          ),
                        );
                        if (result == 'logout') {
                          await _signOut();
                        }
                      } else if (value == 'Logout') {
                        await _signOut();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'Settings',
                        child: Text('Settings'),
                      ),
                      PopupMenuItem(
                        value: 'Privacy',
                        child: Text('Privacy'),
                      ),
                      PopupMenuItem(
                        value: 'Edit Profile',
                        child: Text('Edit Profile'),
                      ),
                      PopupMenuItem(
                        value: 'Logout',
                        child: Text('Logout'),
                      ),
                    ],
                  ),
                ],
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    _coverWidget(context),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: _avatarOverlap + 18),

                  // Avatar + Name row (header)
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20.0),
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
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _fullName.isNotEmpty
                                          ? _fullName
                                          : 'No name',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Online status green dot
                                    StreamBuilder<DocumentSnapshot>(
                                      stream: _firestore
                                          .collection('users')
                                          .doc(widget.profileUserId)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          final data = snapshot.data
                                              ?.data()
                                          as Map<String, dynamic>?;
                                          bool isOnline = false;

                                          if (data?['isOnline'] ==
                                              true) {
                                            isOnline = true;
                                          } else if (data?['lastSeen'] !=
                                              null) {
                                            final lastSeen = (data![
                                            'lastSeen']
                                            as Timestamp?)
                                                ?.toDate();
                                            if (lastSeen != null) {
                                              isOnline = DateTime.now()
                                                  .difference(
                                                  lastSeen)
                                                  .inMinutes <
                                                  2;
                                            }
                                          }

                                          return Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: isOnline
                                                  ? Colors.green
                                                  : Colors.grey,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _username.isNotEmpty
                                      ? '@$_username'
                                      : '',
                                  style: GoogleFonts.poppins(),
                                ),
                                const SizedBox(height: 6),
                                if (_interests.isNotEmpty) ...[
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      ..._interests
                                          .take(3)
                                          .map((interest) {
                                        return Text(
                                          interest,
                                          style:
                                          GoogleFonts.poppins(
                                            fontSize: 12,
                                          ),
                                        );
                                      }).toList(),
                                      if (_interests.length > 3)
                                        Text(
                                          '+${_interests.length - 3}',
                                          style:
                                          GoogleFonts.poppins(
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ] else if (_fitnessTag.isNotEmpty) ...[
                                  Text(
                                    _fitnessTag,
                                    style: GoogleFonts.poppins(),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Row(
                                  children: [
                                    if (_city.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[400],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _city,
                                        style:
                                        GoogleFonts.poppins(),
                                      ),
                                    ],
                                    if (_age != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[400],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_age} yrs',
                                        style:
                                        GoogleFonts.poppins(),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  _buildStatsCard(),
                  const SizedBox(height: 12),
                  _buildActionButtons(),
                  _buildBioCard(),

                  // Halo-style sections
                  _buildAspirantTabsRow(),
                  _buildSuggestedGurusSection(),
                  _buildSuggestedWellnessSection(),
                  _buildSimilarAspirantsSection(),
                  _buildAchievementsSection(),
                  _buildLastWorkoutsSection(),
                  _buildRecentPostsGrid(),
                  _buildEventsChallengesSection(),
                  _buildSocialLinksSection(),
                  _buildHobbiesSection(),
                  _buildFitnessArticlesSection(),
                  _buildFitnessStatsSection(),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
//  PLACEHOLDER PAGES
// ===================================================================

class PostDetailsPage extends StatelessWidget {
  final String postId;
  const PostDetailsPage({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Center(child: Text('Post: $postId')),
    );
  }
}

class UserAllPostsPage extends StatelessWidget {
  final String userId;
  const UserAllPostsPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Posts')),
      body: Center(child: Text('All posts for $userId')),
    );
  }
}
