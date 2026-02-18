// profile_page_improved.dart  (Aspirant Profile)

// -------------------- IMPORTS --------------------
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:halo/newpostpage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:halo/Profile Pages/guru_profile_page.dart' as guru_profile;
import 'package:halo/Profile Pages/wellness_profile_page.dart' as wellness_profile;
import 'package:url_launcher/url_launcher.dart';
import 'package:halo/chat/chat_screen.dart';
import 'package:halo/chat/chat_service.dart';


// Local pages (paths adjust kar lena agar different ho)
import '../editprofilepage.dart';
import '../main.dart'; // LoginPage
import 'package:halo/Bottom Pages/PrivacySettingsPage.dart';
import 'package:halo/Bottom Pages/SettingsPage.dart';
import 'package:halo/utils/search_utils.dart';
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
  List<Map<String, dynamic>> _personalRecords = [];     // Personal fitness records
  List<Map<String, dynamic>> _weeklyProgressData = [];  // Weekly progress data

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

        _fullName = (data['full_name'] ?? '') as String;
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
            'currentWeight': data['currentWeight'] ?? 70,
            'targetWeight': data['targetWeight'] ?? 65,
            'bodyFat': data['bodyFat'] ?? 18,
            'targetBodyFat': data['targetBodyFat'] ?? 15,
            'currentStreak': data['currentStreak'] ?? 0,
            'longestStreak': data['longestStreak'] ?? 0,
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
              final uid = FirebaseAuth.instance.currentUser!.uid;

// 🔹 get accountType from users collection
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get();

              final accountType =
                  userDoc.data()?['accountType']?.toString().toLowerCase() ?? 'aspirant';

// 🔹 now save post (image URL from upload above)
              await FirebaseFirestore.instance.collection('posts').add({
                'userId': uid,
                'accountType': accountType,
                'caption': caption,
                'tags': [],
                'imageUrl': url,
                'timestamp': FieldValue.serverTimestamp(),
                'createdAt': FieldValue.serverTimestamp(),
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
        final username = updatedData['username']?.toString().trim() ?? '';
        final name = updatedData['name']?.toString().trim() ?? '';
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'username': username,
          'name': name,
          'bio': updatedData['bio'],
          'searchTerms': buildSearchTerms(name: name, username: username),
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
              Expanded(
                child: Text(
                  'Suggested Gurus (Coaches)',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_primaryCategory != null && _primaryCategory!.isNotEmpty)
                Flexible(
                  child: Text(
                    _primaryCategory!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
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
              Expanded(
                child: Text(
                  'Achievements & Badges',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isOwnProfile)
                Flexible(
                  child: Text(
                    'Auto-unlocks as you use Halo',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
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
                      onPressed: () => _openSocialLink('instagram', _socialLinks['instagram']!),
                      child: const Text('Instagram'),
                    ),
                  ),
                if (_socialLinks['instagram'] != null)
                  const SizedBox(width: 8),
                if (_socialLinks['spotify'] != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openSocialLink('spotify', _socialLinks['spotify']!),
                      child: const Text('Spotify'),
                    ),
                  ),
                if (_socialLinks['spotify'] != null)
                  const SizedBox(width: 8),
                if (_socialLinks['telegram'] != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openSocialLink('telegram', _socialLinks['telegram']!),
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
              onTap: () => _openArticle(a),
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
  //  NEW PROFESSIONAL FEATURES FOR ASPIRANTS
  // ===================================================================

  Widget _buildProgressTrackingSection() {
    if (!_isOwnProfile) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _lavender.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.trending_up, color: _lavender, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Progress Tracking',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _navigateToFullProgressPage(),
                  child: Text(
                    'View',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _lavender,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _isOwnProfile ? () => _editProgress('weight') : null,
                    child: _buildProgressCard(
                      'Weight',
                      '${(_fitnessStats['currentWeight'] ?? 70).toString()} kg',
                      'Goal: ${(_fitnessStats['targetWeight'] ?? 65).toString()} kg',
                      Icons.monitor_weight,
                      Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _isOwnProfile ? () => _editProgress('bodyFat') : null,
                    child: _buildProgressCard(
                      'Body Fat',
                      '${(_fitnessStats['bodyFat'] ?? 18).toString()}%',
                      'Target: ${(_fitnessStats['targetBodyFat'] ?? 15).toString()}%',
                      Icons.analytics,
                      Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_fitnessGoals.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Goals',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._fitnessGoals.take(3).map((goal) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 18, color: _lavender),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            goal,
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        ),
                        if (_isOwnProfile)
                          IconButton(
                            icon: Icon(Icons.edit, size: 16, color: Colors.grey[600]),
                            onPressed: () => _editGoal(goal),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  )),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCalendarSection() {
    if (!_isOwnProfile) return const SizedBox.shrink();
    
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
    final workoutDays = List.generate(7, (i) => (i * 4) + 1); // Mock workout days
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _lavender.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.calendar_today, color: _lavender, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Workout Calendar',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    '${_getMonthName(currentMonth)} $currentYear',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) => 
                Text(
                  day,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: List.generate(daysInMonth, (index) {
                final day = index + 1;
                final isWorkoutDay = workoutDays.contains(day);
                final isToday = day == now.day;
                
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isToday 
                        ? _lavender 
                        : isWorkoutDay 
                            ? _lavender.withOpacity(0.2)
                            : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: isToday 
                        ? Border.all(color: _lavender, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday 
                            ? Colors.white 
                            : isWorkoutDay 
                                ? _lavender 
                                : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildLegendItem(_lavender, 'Workout'),
                const SizedBox(width: 16),
                _buildLegendItem(_lavender.withOpacity(0.3), 'Today'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildFitnessGoalsSection() {
    if (!_isOwnProfile) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_lavender.withOpacity(0.1), _deepLavender.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _lavender.withOpacity(0.3)),
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
                        color: _lavender,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.flag, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Fitness Goals',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: _lavender),
                  onPressed: _addNewGoal,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_fitnessGoals.isEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No goals set yet',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _addNewGoal,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Set Your First Goal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _lavender,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._fitnessGoals.map((goal) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _lavender.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.fitness_center, color: _lavender, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              goal,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: 0.6, // Mock progress
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(_lavender),
                            ),
                          ],
                        ),
                      ),
                      if (_isOwnProfile)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editGoal(goal);
                            } else if (value == 'delete') {
                              _deleteGoal(goal);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                    ],
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutStreakSection() {
    final currentStreak = _fitnessStats['currentStreak'] ?? 5;
    final longestStreak = _fitnessStats['longestStreak'] ?? 12;
    
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
            )
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange[700], size: 32),
                const SizedBox(width: 12),
                Text(
                  '$currentStreak',
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Day Streak!',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Keep it up! Your longest streak is $longestStreak days',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.orange[800],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalRecordsSection() {
    // Use Firebase data if available, otherwise use defaults
    final defaultRecords = [
      {'name': 'Fastest 5K', 'value': '28:45', 'icon': Icons.directions_run, 'color': Colors.blue},
      {'name': 'Max Bench Press', 'value': '85 kg', 'icon': Icons.fitness_center, 'color': Colors.red},
      {'name': 'Longest Plank', 'value': '3:15', 'icon': Icons.timer, 'color': Colors.green},
    ];
    
    final records = _personalRecords.isNotEmpty ? _personalRecords : defaultRecords;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
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
                child: Icon(Icons.emoji_events, color: _lavender, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Personal Records',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                return GestureDetector(
                  onTap: _isOwnProfile ? () => _editPersonalRecord(index, record) : null,
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(
                              record['icon'] is IconData 
                                  ? record['icon'] as IconData
                                  : _getIconFromString(record['icon']?.toString() ?? 'fitness_center'),
                              color: record['color'] is Color
                                  ? record['color'] as Color
                                  : _getColorFromString(record['color']?.toString() ?? 'blue'),
                              size: 24,
                            ),
                            if (_isOwnProfile)
                              Icon(Icons.edit, size: 14, color: Colors.grey[400]),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            record['name']?.toString() ?? 'Record',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record['value']?.toString() ?? '0',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: record['color'] is Color
                                ? record['color'] as Color
                                : _getColorFromString(record['color']?.toString() ?? 'blue'),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

  Widget _buildWeeklyProgressSection() {
    if (!_isOwnProfile) return const SizedBox.shrink();
    
    // Use Firebase data if available, otherwise use defaults
    final weeklyData = _weeklyProgressData.isNotEmpty
        ? _weeklyProgressData
        : [
            {'day': 'Mon', 'workouts': 2, 'calories': 450},
            {'day': 'Tue', 'workouts': 1, 'calories': 320},
            {'day': 'Wed', 'workouts': 3, 'calories': 680},
            {'day': 'Thu', 'workouts': 2, 'calories': 520},
            {'day': 'Fri', 'workouts': 1, 'calories': 380},
            {'day': 'Sat', 'workouts': 2, 'calories': 490},
            {'day': 'Sun', 'workouts': 0, 'calories': 0},
          ];
    
    final maxCalories = weeklyData.isNotEmpty
        ? weeklyData.map((d) => (d['calories'] as num?)?.toInt() ?? 0).reduce((a, b) => a > b ? a : b)
        : 680;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _lavender.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.bar_chart, color: _lavender, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Weekly Progress',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    'This Week',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weeklyData.map((data) {
                final calories = (data['calories'] as num?)?.toInt() ?? 0;
                final height = maxCalories > 0 
                    ? (calories / maxCalories * 100).clamp(0.0, 100.0)
                    : 0.0;
                return Column(
                  children: [
                    Container(
                      width: 32,
                      height: height,
                      decoration: BoxDecoration(
                        color: calories > 0 
                            ? _lavender 
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['day']?.toString() ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$calories',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeeklyStat('Total Workouts', '${weeklyData.map((d) => (d['workouts'] as num?)?.toInt() ?? 0).reduce((a, b) => a + b)}'),
                Container(width: 1, height: 30, color: Colors.grey[300]),
                _buildWeeklyStat('Calories Burned', '${weeklyData.map((d) => (d['calories'] as num?)?.toInt() ?? 0).reduce((a, b) => a + b)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _lavender,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // ===================================================================
  //  POSTS GRID
  // ===================================================================
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
        .limit(30);

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
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
              final allDocs = snap.data?.docs ?? [];
              final sortedDocs = List.from(allDocs)..sort((a, b) {
                final aData = a.data() as Map<String, dynamic>?;
                final bData = b.data() as Map<String, dynamic>?;
                final aTs = aData?['timestamp'] ?? aData?['createdAt'];
                final bTs = bData?['timestamp'] ?? bData?['createdAt'];
                if (aTs == null) return 1;
                if (bTs == null) return -1;
                if (aTs is Timestamp && bTs is Timestamp) return bTs.compareTo(aTs);
                return 0;
              });
              final docs = sortedDocs.take(12).toList();
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
                  final imageUrl = _getPostImageUrl(data);
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
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image, color: Colors.grey)),
                        )
                            : const Center(child: Icon(Icons.image, color: Colors.grey)),
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
                                    Expanded(
                                      child: Text(
                                        _fullName.isNotEmpty
                                            ? _fullName
                                            : _username.isNotEmpty
                                            ? '@$_username'
                                            : 'No name',
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Online status green dot
                                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
                  
                  // New Professional Features for Aspirants
                  _buildProgressTrackingSection(),
                  _buildWorkoutCalendarSection(),
                  _buildFitnessGoalsSection(),
                  _buildWorkoutStreakSection(),
                  _buildPersonalRecordsSection(),
                  _buildWeeklyProgressSection(),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  //  EDIT FUNCTIONS FOR NEW FEATURES
  // ===================================================================

  Future<void> _editProgress(String type) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final currentWeightCtrl = TextEditingController(
      text: (_fitnessStats['currentWeight'] ?? 70).toString(),
    );
    final targetWeightCtrl = TextEditingController(
      text: (_fitnessStats['targetWeight'] ?? 65).toString(),
    );
    final bodyFatCtrl = TextEditingController(
      text: (_fitnessStats['bodyFat'] ?? 18).toString(),
    );
    final targetBodyFatCtrl = TextEditingController(
      text: (_fitnessStats['targetBodyFat'] ?? 15).toString(),
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Progress',
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
                controller: currentWeightCtrl,
                decoration: InputDecoration(
                  labelText: 'Current Weight (kg)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.monitor_weight, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetWeightCtrl,
                decoration: InputDecoration(
                  labelText: 'Target Weight (kg)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.flag, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bodyFatCtrl,
                decoration: InputDecoration(
                  labelText: 'Current Body Fat (%)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.analytics, color: _lavender),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _lavender, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetBodyFatCtrl,
                decoration: InputDecoration(
                  labelText: 'Target Body Fat (%)',
                  labelStyle: GoogleFonts.poppins(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.track_changes, color: _lavender),
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
              try {
                final updatedStats = {
                  ..._fitnessStats,
                  'currentWeight': double.tryParse(currentWeightCtrl.text) ?? _fitnessStats['currentWeight'] ?? 70,
                  'targetWeight': double.tryParse(targetWeightCtrl.text) ?? _fitnessStats['targetWeight'] ?? 65,
                  'bodyFat': double.tryParse(bodyFatCtrl.text) ?? _fitnessStats['bodyFat'] ?? 18,
                  'targetBodyFat': double.tryParse(targetBodyFatCtrl.text) ?? _fitnessStats['targetBodyFat'] ?? 15,
                };
                
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({'fitnessStats': updatedStats});
                
                setState(() => _fitnessStats = updatedStats);
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Progress updated successfully!');
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating progress: $e');
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

  Future<void> _addNewGoal() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final goalCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Fitness Goal',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _lavender,
          ),
        ),
        content: TextField(
          controller: goalCtrl,
          decoration: InputDecoration(
            labelText: 'Goal Description',
            labelStyle: GoogleFonts.poppins(),
            hintText: 'e.g., Lose 10kg, Run a marathon',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: Icon(Icons.flag, color: _lavender),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _lavender, width: 2),
            ),
          ),
          maxLines: 2,
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
              if (goalCtrl.text.trim().isEmpty) return;
              
              try {
                final updatedGoals = List<String>.from(_fitnessGoals)..add(goalCtrl.text.trim());
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({'fitnessGoals': updatedGoals});
                
                setState(() => _fitnessGoals = updatedGoals);
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Goal added successfully!');
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error adding goal: $e');
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

  Future<void> _editGoal(String oldGoal) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final goalCtrl = TextEditingController(text: oldGoal);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Goal',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _lavender,
          ),
        ),
        content: TextField(
          controller: goalCtrl,
          decoration: InputDecoration(
            labelText: 'Goal Description',
            labelStyle: GoogleFonts.poppins(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: Icon(Icons.flag, color: _lavender),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _lavender, width: 2),
            ),
          ),
          maxLines: 2,
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
              if (goalCtrl.text.trim().isEmpty) return;
              
              try {
                final updatedGoals = List<String>.from(_fitnessGoals);
                final index = updatedGoals.indexOf(oldGoal);
                if (index != -1) {
                  updatedGoals[index] = goalCtrl.text.trim();
                  await _firestore
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .update({'fitnessGoals': updatedGoals});
                  
                  setState(() => _fitnessGoals = updatedGoals);
                  Navigator.pop(ctx);
                  Fluttertoast.showToast(msg: 'Goal updated successfully!');
                }
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating goal: $e');
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

  Future<void> _deleteGoal(String goal) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Goal',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _lavender,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$goal"?',
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
        final updatedGoals = List<String>.from(_fitnessGoals)..remove(goal);
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'fitnessGoals': updatedGoals});
        
        setState(() => _fitnessGoals = updatedGoals);
        Fluttertoast.showToast(msg: 'Goal deleted successfully!');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error deleting goal: $e');
      }
    }
  }

  // ===================================================================
  //  HELPER FUNCTIONS FOR STATIC FEATURES
  // ===================================================================
  
  Future<void> _openSocialLink(String platform, String link) async {
    try {
      String url = link;
      
      // If link doesn't start with http, add it
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        // Format URLs based on platform
        switch (platform.toLowerCase()) {
          case 'instagram':
            url = url.startsWith('@') 
                ? 'https://instagram.com/${url.substring(1)}'
                : 'https://instagram.com/$url';
            break;
          case 'spotify':
            url = 'https://open.spotify.com/user/$url';
            break;
          case 'telegram':
            url = url.startsWith('@')
                ? 'https://t.me/${url.substring(1)}'
                : 'https://t.me/$url';
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
  
  Future<void> _openArticle(Map<String, dynamic> article) async {
    try {
      final url = article['url']?.toString() ?? article['link']?.toString();
      if (url == null || url.isEmpty) {
        Fluttertoast.showToast(msg: 'Article link not available');
        return;
      }
      
      String articleUrl = url;
      if (!articleUrl.startsWith('http://') && !articleUrl.startsWith('https://')) {
        articleUrl = 'https://$articleUrl';
      }
      
      final uri = Uri.parse(articleUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Fluttertoast.showToast(msg: 'Could not open article');
      }
    } catch (e) {
      debugPrint('Error opening article: $e');
      Fluttertoast.showToast(msg: 'Failed to open article');
    }
  }
  
  Future<void> _navigateToFullProgressPage() async {
    if (!_isOwnProfile) return;
    
    // Show a detailed progress page with charts and history
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FullProgressPage(
        fitnessStats: _fitnessStats,
        fitnessGoals: _fitnessGoals,
        onUpdate: () async {
          await _loadProfileData();
        },
      ),
    );
  }

  Future<void> _editPersonalRecord(int index, Map<String, dynamic> record) async {
    if (!_isOwnProfile || _currentUser == null) return;

    final nameCtrl = TextEditingController(text: record['name'] as String);
    final valueCtrl = TextEditingController(text: record['value'] as String);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Personal Record',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: _lavender,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Record Name',
                labelStyle: GoogleFonts.poppins(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(record['icon'] as IconData, color: record['color'] as Color),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _lavender, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueCtrl,
              decoration: InputDecoration(
                labelText: 'Record Value',
                labelStyle: GoogleFonts.poppins(),
                hintText: 'e.g., 28:45, 85 kg, 3:15',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.edit, color: _lavender),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _lavender, width: 2),
                ),
              ),
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
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || valueCtrl.text.trim().isEmpty) return;
              
              try {
                // Update in main user document
                final updatedRecords = List<Map<String, dynamic>>.from(_personalRecords);
                if (index < updatedRecords.length) {
                  updatedRecords[index] = {
                    'name': nameCtrl.text.trim(),
                    'value': valueCtrl.text.trim(),
                    'icon': record['icon']?.toString() ?? 'fitness_center',
                    'color': record['color']?.toString() ?? 'blue',
                  };
                } else {
                  updatedRecords.add({
                    'name': nameCtrl.text.trim(),
                    'value': valueCtrl.text.trim(),
                    'icon': record['icon']?.toString() ?? 'fitness_center',
                    'color': record['color']?.toString() ?? 'blue',
                  });
                }
                
                await _firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({
                      'personalRecords': updatedRecords,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                
                setState(() => _personalRecords = updatedRecords);
                Navigator.pop(ctx);
                Fluttertoast.showToast(msg: 'Record updated successfully!');
              } catch (e) {
                Fluttertoast.showToast(msg: 'Error updating record: $e');
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
  
  // Helper functions for Personal Records
  IconData _getIconFromString(String iconStr) {
    switch (iconStr.toLowerCase()) {
      case 'directions_run':
      case 'directionsrun':
        return Icons.directions_run;
      case 'fitness_center':
      case 'fitnesscenter':
        return Icons.fitness_center;
      case 'timer':
        return Icons.timer;
      default:
        return Icons.fitness_center;
    }
  }
  
  Color _getColorFromString(String colorStr) {
    switch (colorStr.toLowerCase()) {
      case 'blue':
        return Colors.blue;
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}

// ===================================================================
//  FULL PROGRESS PAGE (Modal Bottom Sheet)
// ===================================================================

class _FullProgressPage extends StatelessWidget {
  final Map<String, dynamic> fitnessStats;
  final List<String> fitnessGoals;
  final VoidCallback onUpdate;
  
  const _FullProgressPage({
    required this.fitnessStats,
    required this.fitnessGoals,
    required this.onUpdate,
  });
  
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
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Full Progress',
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
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weight Progress
                  _buildProgressCard(
                    'Weight Progress',
                    'Current: ${fitnessStats['currentWeight'] ?? 70} kg',
                    'Target: ${fitnessStats['targetWeight'] ?? 65} kg',
                    Icons.monitor_weight,
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  // Body Fat Progress
                  _buildProgressCard(
                    'Body Fat Progress',
                    'Current: ${fitnessStats['bodyFat'] ?? 18}%',
                    'Target: ${fitnessStats['targetBodyFat'] ?? 15}%',
                    Icons.analytics,
                    Colors.orange,
                  ),
                  const SizedBox(height: 24),
                  // Goals Section
                  if (fitnessGoals.isNotEmpty) ...[
                    Text(
                      'Active Goals',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...fitnessGoals.map((goal) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: const Color(0xFFA58CE3), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              goal,
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressCard(String title, String current, String target, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            current,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            target,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
