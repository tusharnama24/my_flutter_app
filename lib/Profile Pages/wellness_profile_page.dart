
// wellness_profile_page.dart  (Wellness / Coach Profile)

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

// Local pages (paths tumhare project ke hisaab se change ho sakte hain)
import '../../editprofilepage.dart';
import '../../main.dart'; // LoginPage
import 'package:classic_1/Bottom Pages/PrivacySettingsPage.dart';
import 'package:classic_1/Bottom Pages/SettingsPage.dart';
import 'edit_profile_sections.dart'; // Edit pages for profile sections

// ===================================================================
//  WELLNESS PROFILE PAGE (COACH / TRAINER / SHOPS)
// ===================================================================

class WellnessProfilePage extends StatelessWidget {
  final String profileUserId; // Jis wellness user ki profile dekhni hai

  const WellnessProfilePage({Key? key, required this.profileUserId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _WellnessProfilePageStateful(profileUserId: profileUserId);
  }
}

class _WellnessProfilePageStateful extends StatefulWidget {
  final String profileUserId;

  const _WellnessProfilePageStateful({Key? key, required this.profileUserId})
      : super(key: key);

  @override
  State<_WellnessProfilePageStateful> createState() =>
      _WellnessProfilePageState();
}

class _WellnessProfilePageState extends State<_WellnessProfilePageStateful>
    with TickerProviderStateMixin {
  // -------------------- FIREBASE --------------------
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  bool _isOwnProfile = false;

  // -------------------- USER DATA --------------------
  String _fullName = '';
  String _username = '';
  String _tagline = 'Fitness & Wellness Coach'; // profession line
  String _city = '';
  int? _experienceYears; // eg. 5 yrs exp

  String _bio = '';
  String? _profilePhotoUrl;
  String? _coverPhotoUrl;

  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  double _rating = 4.8;
  int _reviewCount = 0;
  bool _isPrivate = false;

  // Products / Services / Events / Reviews / Social etc.
  List<Map<String, dynamic>> _popularProducts = [];
  List<String> _popularServices = [];
  List<Map<String, dynamic>> _fitnessEvents = [];
  String _studioLocation = '';
  List<Map<String, dynamic>> _serviceSlots = [];
  List<Map<String, dynamic>> _reviews = [];
  Map<String, String> _socialLinks = {};
  List<String> _interests = [];
  List<String> _galleryImages = [];

  // -------------------- UI CONSTANTS --------------------
  static const double _coverHeight = 220.0;
  static const double _avatarSize = 90.0;
  static const double _avatarOverlap = 30.0;
  static const Color _lavender = Color(0xFFA58CE3);
  static const Color _deepLavender = Color(0xFF6D4DB3);
  static const Color _bg = Color(0xFFF4F1FB);

  // -------------------- STATE --------------------
  bool _isFollowing = false;
  bool _isLoading = true;

  final ImagePicker _picker = ImagePicker();
  File? _profilePhotoFile;
  File? _coverPhotoFile;

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  late final AnimationController _followAnimController;

  @override
  void initState() {
    super.initState();
    _followAnimController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _loadProfileData();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
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

      // Main document (users collection)
      final doc =
      await _firestore.collection('users').doc(widget.profileUserId).get();

      if (doc.exists) {
        final data = doc.data()!;

        _fullName = (data['business_name'] ?? data['name'] ?? '') as String;
        _username = (data['username'] ?? '') as String;
        _tagline =
        (data['professionTag'] ?? data['fitnessTag'] ?? 'Wellness Coach')
        as String;
        _city = (data['city'] ?? '') as String;
        _experienceYears = data['experienceYears'] is int
            ? data['experienceYears'] as int
            : null;

        _bio = (data['bio'] ?? '') as String;
        _profilePhotoUrl = data['profilePhoto'] as String?;
        _coverPhotoUrl = data['coverPhoto'] as String?;

        _followersCount = (data['followersCount'] ?? 0) as int;
        _followingCount = (data['followingCount'] ?? 0) as int;
        _postsCount = (data['postsCount'] ?? 0) as int;
        _isPrivate = (data['isPrivate'] ?? false) as bool;

        _rating = (data['rating'] is num)
            ? (data['rating'] as num).toDouble()
            : 4.8;
        _reviewCount = (data['reviewCount'] ?? 0) as int;

        // Popular products - Load from Firebase
        final productsRaw = data['popularProducts'] as List<dynamic>?;
        if (productsRaw != null && productsRaw.isNotEmpty) {
          _popularProducts = productsRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else {
          _popularProducts = [];
        }

        // Popular services - Load from Firebase
        final servicesRaw = data['popularServices'] as List<dynamic>?;
        _popularServices = servicesRaw != null
            ? servicesRaw.map((e) => e.toString()).toList()
            : [];

        // Events - Load from Firebase
        final eventsRaw = data['fitnessEvents'] as List<dynamic>?;
        if (eventsRaw != null && eventsRaw.isNotEmpty) {
          _fitnessEvents =
              eventsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else {
          _fitnessEvents = [];
        }

        _studioLocation = (data['studioLocation'] ?? '') as String;

        // Service time slots - Load from Firebase
        final slotsRaw = data['serviceSlots'] as List<dynamic>?;
        if (slotsRaw != null && slotsRaw.isNotEmpty) {
          _serviceSlots =
              slotsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else {
          _serviceSlots = [];
        }

        // Reviews - Load from Firebase
        final reviewsRaw = data['reviews'] as List<dynamic>?;
        if (reviewsRaw != null && reviewsRaw.isNotEmpty) {
          _reviews =
              reviewsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else {
          _reviews = [];
        }

        // Social links
        final sl = data['socialLinks'] as Map<String, dynamic>?;
        _socialLinks = sl != null
            ? sl.map((key, value) => MapEntry(key, value.toString()))
            : {
          'youtube': 'YouTube',
          'instagram': 'Instagram',
          'telegram': 'Telegram',
        };

        // Interests
        final interestsRaw = data['interests'] as List<dynamic>?;
        _interests = interestsRaw != null
            ? interestsRaw.map((e) => e.toString()).toList()
            : ['Yoga', 'Strength Training', 'Mindfulness'];

        // Gallery
        final galleryRaw = data['galleryImages'] as List<dynamic>?;
        _galleryImages =
        galleryRaw != null ? galleryRaw.map((e) => e.toString()).toList() : [];
      }

      // Follow status
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
      debugPrint('wellness profile load error: $e');
      Fluttertoast.showToast(msg: 'Failed to load profile');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ===================================================================
  //  CAMERA / IMAGES
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
    if (!_isOwnProfile || _currentUser == null) return;
    final XFile? picked =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _profilePhotoFile = File(picked.path));
    await _uploadAndSavePhoto(_profilePhotoFile!, isCover: false);
  }

  Future<void> _pickCoverImage() async {
    if (!_isOwnProfile || _currentUser == null) return;
    final XFile? picked =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _coverPhotoFile = File(picked.path));
    await _uploadAndSavePhoto(_coverPhotoFile!, isCover: true);
  }

  Future<void> _uploadAndSavePhoto(File file, {required bool isCover}) async {
    if (_currentUser == null) return;
    try {
      final fileName =
          '${isCover ? 'cover' : 'profile'}_${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(_currentUser!.uid)
          .child(fileName);
      final snap = await ref.putFile(file);
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
  //  FOLLOW / MESSAGE
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
      setState(() {
        _isFollowing = wasFollowing;
        _followersCount += wasFollowing ? 1 : -1;
        if (_followersCount < 0) _followersCount = 0;
      });
      Fluttertoast.showToast(
          msg: 'Something went wrong. Please try again later.');
    }
  }

  Future<void> _openMessage() async {
    if (_isOwnProfile) return;
    Fluttertoast.showToast(msg: 'Open chat (not implemented yet)');
  }

  // ===================================================================
  //  POST CREATION (same as aspirant)
  // ===================================================================
  Future<void> _openGalleryForPost() async {
    if (!_isOwnProfile) return;
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
  //  EDIT PROFILE / SETTINGS / LOGOUT
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
          initialprofessiontype: _tagline,
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
        ? 'Tell people about your studio, style and coaching approach.'
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
                          Text(
                            _fullName.isNotEmpty ? _fullName : 'No name',
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
                                final data = snapshot.data?.data()
                                as Map<String, dynamic>?;
                                bool isOnline = false;

                                if (data?['isOnline'] == true) {
                                  isOnline = true;
                                } else if (data?['lastSeen'] != null) {
                                  final lastSeen =
                                  (data!['lastSeen'] as Timestamp?)
                                      ?.toDate();
                                  if (lastSeen != null) {
                                    isOnline = DateTime.now()
                                        .difference(lastSeen)
                                        .inMinutes <
                                        2;
                                  }
                                }

                                return Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color:
                                    isOnline ? Colors.green : Colors.grey,
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
                        _username.isNotEmpty ? '@$_username' : '',
                        style: GoogleFonts.poppins(),
                      ),
                      const SizedBox(height: 6),
                      // Display interests/categories instead of tagline
                      if (_interests.isNotEmpty) ...[
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            ..._interests.take(3).map((interest) {
                              return Text(
                                interest,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                ),
                              );
                            }).toList(),
                            if (_interests.length > 3)
                              Text(
                                '+${_interests.length - 3}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                ),
                              ),
                          ],
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
                              style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                          if (_experienceYears != null) ...[
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
                              '${_experienceYears}+ yrs exp',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.star,
                              color: Colors.amber[700], size: 18),
                          const SizedBox(width: 4),
                          Text(
                            _rating.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($_reviewCount reviews)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
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
        const SizedBox(height: 14),
        _buildStatsCard(),
        const SizedBox(height: 12),
        _buildActionButtons(),
        _buildBioCard(),
      ],
    );
  }

  // ===================================================================
  //  WELLNESS-SPECIFIC SECTIONS
  // ===================================================================

  Widget _buildPopularProductsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popular Products',
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
                        builder: (ctx) => EditProductsPage(
                          initialProducts: _popularProducts,
                          userType: 'wellness',
                        ),
                      ),
                    );
                    if (updated != null) {
                      setState(() {
                        _popularProducts =
                        List<Map<String, dynamic>>.from(updated);
                      });
                      await _loadProfileData();
                    }
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_popularProducts.isEmpty && _isOwnProfile)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'No products yet. Add your first product!',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
            )
          else if (_popularProducts.isEmpty)
            const SizedBox.shrink()
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _popularProducts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final p = _popularProducts[index];
                  return Container(
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.grey[200],
                            ),
                            child: const Center(child: Text('image')),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p['name']?.toString() ?? 'Product',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              p['price']?.toString() ?? '₹0',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: const Text('View'),
                            )
                          ],
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

  Widget _buildPopularServicesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popular Services',
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
                        builder: (ctx) => EditServicesPage(
                          initialServices: _popularServices,
                        ),
                      ),
                    );
                    if (updated != null) {
                      setState(() {
                        _popularServices = List<String>.from(updated);
                      });
                      await _loadProfileData();
                    }
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_popularServices.isEmpty && _isOwnProfile)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'No services yet. Add your first service!',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
            )
          else if (_popularServices.isEmpty)
            const SizedBox.shrink()
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _popularServices.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.grey[200],
                          child: const Icon(Icons.fitness_center),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 80,
                          child: Text(
                            s,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------- Recommended by Gurus --------------------
  Widget _buildRecommendedByGurusSection() {
    // Gurus who added this wellness profile in their 'recommendedWellness' array
    final query = _firestore
        .collection('users')
        .where('profileType', isEqualTo: 'guru')
        .where('recommendedWellness', arrayContains: widget.profileUserId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended by Gurus',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
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
                    'When gurus recommend you, they will appear here.',
                    style: GoogleFonts.poppins(fontSize: 12),
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
                          width: 80,
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 10),
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

  Widget _buildRecentPostsSection() {
    final userId = widget.profileUserId;

    if (_isPrivate && !_isOwnProfile && !_isFollowing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
        child: Text(
          'This account is private.\nFollow to see posts and events.',
          style: GoogleFonts.poppins(),
        ),
      );
    }

    final postsQuery = _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(6);

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
                return Text(
                  'No posts yet',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 4 / 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data()! as Map<String, dynamic>;
                  final imageUrl = data['imageUrl'] as String?;
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey[200],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.cover)
                        : const SizedBox.shrink(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFitnessEventsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fitness Events',
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
                        builder: (ctx) => EditFitnessEventsPage(
                          initialEvents: _fitnessEvents,
                        ),
                      ),
                    );
                    if (updated != null) {
                      setState(() {
                        _fitnessEvents =
                        List<Map<String, dynamic>>.from(updated);
                      });
                      await _loadProfileData();
                    }
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_fitnessEvents.isEmpty && _isOwnProfile)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'No events yet. Add your first event!',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
            )
          else if (_fitnessEvents.isEmpty)
            const SizedBox.shrink()
          else
            ..._fitnessEvents.map((e) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: e['imageUrl'] != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(e['imageUrl'],
                            fit: BoxFit.cover),
                      )
                          : const Center(child: Text('Poster')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e['title']?.toString() ?? 'Event',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            e['date']?.toString() ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e['place']?.toString() ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
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

  Widget _buildLocationSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Studio Location',
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
                        builder: (ctx) => EditLocationAvailabilityPage(
                          initialLocation: _studioLocation,
                          initialSlots: _serviceSlots,
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
          const SizedBox(height: 12),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('Map preview')),
          ),
          const SizedBox(height: 8),
          Text(
            _studioLocation,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesAvailabilitySection() {
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
                  'Services & Availability',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
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
                          builder: (ctx) => EditLocationAvailabilityPage(
                            initialLocation: _studioLocation,
                            initialSlots: _serviceSlots,
                          ),
                        ),
                      );
                      await _loadProfileData();
                    },
                    icon: const Icon(Icons.edit,
                        size: 18, color: Colors.white),
                    label: const Text('Edit',
                        style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_serviceSlots.isEmpty && _isOwnProfile)
              Center(
                child: Text(
                  'No service slots yet. Add your availability!',
                  style: GoogleFonts.poppins(color: Colors.white70),
                ),
              )
            else if (_serviceSlots.isEmpty)
              const SizedBox.shrink()
            else
              ..._serviceSlots.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['title']?.toString() ?? '',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s['time']?.toString() ?? '',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      if (s['status'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          s['status']!.toString(),
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ]
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    if (_reviews.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reviews & Ratings',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          ..._reviews.take(3).map((r) {
            final rating = (r['rating'] ?? 5) as int;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r['name']?.toString() ?? 'User',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(
                      5,
                          (i) => Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        size: 16,
                        color: Colors.amber[700],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r['text']?.toString() ?? '',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ],
              ),
            );
          }),
        ],
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
                      await _loadProfileData();
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
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
            )
          else if (_socialLinks.isEmpty)
            const SizedBox.shrink()
          else
            Row(
              children: [
                if (_socialLinks['youtube'] != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('YouTube'),
                    ),
                  ),
                if (_socialLinks['youtube'] != null) const SizedBox(width: 8),
                if (_socialLinks['instagram'] != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Instagram'),
                    ),
                  ),
                if (_socialLinks['instagram'] != null) const SizedBox(width: 8),
                if (_socialLinks['telegram'] != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Telegram'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInterestsAndGallerySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_interests.isNotEmpty) ...[
            Text(
              'Interests',
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
            const SizedBox(height: 16),
          ],
          Text(
            'Gallery',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          if (_galleryImages.isEmpty)
            Text(
              _isOwnProfile
                  ? 'Add your session photos and studio shots.'
                  : 'No gallery photos yet.',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _galleryImages.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemBuilder: (context, index) {
                final url = _galleryImages[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(url, fit: BoxFit.cover),
                );
              },
            ),
        ],
      ),
    );
  }

  // -------------------- Suggested Aspirants --------------------
  Widget _buildSuggestedAspirantsSection() {
    if (_interests.isEmpty) return const SizedBox.shrink();

    final List<String> topInterests =
    _interests.length > 5 ? _interests.sublist(0, 5) : _interests;

    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('profileType', isEqualTo: 'aspirant')
        .where('interests', arrayContainsAny: topInterests);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aspirants Interested in You',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.limit(12).snapshots(),
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
                docs = docs.where((d) => d.id != widget.profileUserId).toList();

                if (docs.isEmpty) {
                  return Text(
                    'We will show relevant aspirants here.',
                    style: GoogleFonts.poppins(fontSize: 12),
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
                            style: GoogleFonts.poppins(fontSize: 10),
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
                              style: GoogleFonts.poppins(fontSize: 9),
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

  // ===================================================================
  //  BUILD
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
                  _buildProfileHeaderSection(), // ✅ common header
                  _buildPopularProductsSection(),
                  _buildPopularServicesSection(),
                  _buildRecommendedByGurusSection(),
                  _buildRecentPostsSection(),
                  _buildFitnessEventsSection(),
                  _buildLocationSection(),
                  _buildServicesAvailabilitySection(),
                  _buildReviewsSection(),
                  _buildSuggestedAspirantsSection(),
                  _buildSocialLinksSection(),
                  _buildInterestsAndGallerySection(),
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
