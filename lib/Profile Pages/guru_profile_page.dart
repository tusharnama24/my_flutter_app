// guru_profile_page.dart  (Guru Profile – advanced features)

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

// local pages
import '../../editprofilepage.dart';
import '../../main.dart'; // LoginPage
import 'package:classic_1/Bottom Pages/PrivacySettingsPage.dart';
import 'package:classic_1/Bottom Pages/SettingsPage.dart';

// GURU SECTIONS
import '../Sections/Guru Section/guru_booking_section.dart';
import '../Sections/Guru Section/guru_classes_section.dart';
import '../Sections/Guru Section/guru_earnings_section.dart';
import '../Sections/Guru Section/guru_students_section.dart';
import '../Sections/Guru Section/guru_analytics_section.dart';

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
//  GURU PROFILE PAGE
// ===================================================================

class GuruProfilePage extends StatelessWidget {
  final String profileUserId;

  const GuruProfilePage({Key? key, required this.profileUserId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _GuruProfilePageStateful(profileUserId: profileUserId);
  }
}

class _GuruProfilePageStateful extends StatefulWidget {
  final String profileUserId;

  const _GuruProfilePageStateful({Key? key, required this.profileUserId})
      : super(key: key);

  @override
  State<_GuruProfilePageStateful> createState() =>
      _GuruProfilePageState();
}

class _GuruProfilePageState extends State<_GuruProfilePageStateful>
    with TickerProviderStateMixin {
  // -------------------- FIREBASE --------------------
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  bool _isOwnProfile = false;

  // -------------------- USER DATA --------------------
  String _fullName = '';
  String _username = '';
  String _primaryCategory = ''; // yoga / cricket / dance
  String _city = '';
  int? _experienceYears;
  String _bio = '';
  String? _profilePhotoUrl;
  String? _coverPhotoUrl;

  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  double _rating = 4.8;
  int _reviewCount = 0;
  bool _isPrivate = false;

  // extra profile info
  List<String> _languages = [];
  String _trainingStyle = ''; // soft / hard / hybrid
  List<String> _badges = [];
  List<String> _specialties = [];
  List<Map<String, dynamic>> _certifications = [];
  List<Map<String, dynamic>> _achievements = [];

  // -------------------- GURU SECTIONS DATA --------------------
  // booking
  Map<String, dynamic> _bookingSettings = {};
  List<Map<String, dynamic>> _upcomingSessions = [];
  List<Map<String, dynamic>> _pastSessions = [];

  // earnings
  Map<String, dynamic> _earningsSummary = {};
  List<Map<String, dynamic>> _recentEarnings = [];

  // classes
  List<Map<String, dynamic>> _classes = [];

  // students
  List<Map<String, dynamic>> _students = [];

  // analytics
  Map<String, dynamic> _analytics = {};

  // -------------------- SOCIAL & MEDIA --------------------
  Map<String, String> _socialLinks = {};
  List<String> _galleryImages = [];

  // -------------------- FIRST TAB DATA --------------------
  List<Map<String, dynamic>> _recentPosts = [];
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _lastWorkouts = [];

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
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _followAnimController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _followAnimController.dispose();
    _tabController.dispose();
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

        // --------- DEBUG: account type (with fallbacks) ----------
        final rawAccountType =
        (data['accountType'] ?? data['category'] ?? data['profileType'] ?? 'guru')
            .toString();
        final accountType = rawAccountType.toLowerCase();
        debugPrint('🔍 Guru Profile Page - Account Type: $accountType');
        debugPrint('🔍 Guru Profile Page - Is Own Profile: $_isOwnProfile');
        // ---------------------------------------------------------

        _fullName = (data['name'] ?? '') as String;
        _username = (data['username'] ?? '') as String;
        _primaryCategory = (data['primaryCategory'] ?? '') as String;
        _city = (data['city'] ?? '') as String;
        _experienceYears =
        data['experienceYears'] is int ? data['experienceYears'] as int : null;

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

        _languages = List<String>.from(data['languages'] ?? []);
        _trainingStyle = (data['trainingStyle'] ?? '') as String;
        _badges = List<String>.from(data['badges'] ?? []);
        _specialties = List<String>.from(data['specialties'] ?? []);

        final certRaw = data['certifications'];
        if (certRaw is List) {
          _certifications = certRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else {
          _certifications = [];
        }

        final achRaw = data['achievements'];
        if (achRaw is List) {
          _achievements =
              achRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else {
          _achievements = [];
        }

        // booking - load from user doc or subcollection
        final bs = data['bookingSettings'];
        _bookingSettings =
        bs is Map ? Map<String, dynamic>.from(bs) : <String, dynamic>{};

        // ================== SESSIONS (UPDATED – NO COMPOSITE INDEX NEEDED) ==================
        try {
          final sessionsRef = _firestore
              .collection('users')
              .doc(widget.profileUserId)
              .collection('sessions');

          // Upcoming: only where, NO orderBy -> composite index nahi lagega
          final upcomingSnapshot = await sessionsRef
              .where('status', isEqualTo: 'upcoming')
              .limit(10)
              .get();

          if (upcomingSnapshot.docs.isNotEmpty) {
            _upcomingSessions = upcomingSnapshot.docs.map((doc) {
              final d = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                'title': d['title'] ?? 'Session',
                'time': d['sessionDate'] != null
                    ? _formatDateTime(d['sessionDate'])
                    : d['time']?.toString() ?? '',
                'studentName': d['studentName'] ?? '',
                'type': d['type'] ?? 'offline',
              };
            }).toList();
          } else {
            final upcomingRaw = data['upcomingSessions'];
            _upcomingSessions = upcomingRaw is List
                ? upcomingRaw
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
                : [];
          }

          // Past: only where, NO orderBy -> composite index nahi lagega
          final pastSnapshot = await sessionsRef
              .where('status', isEqualTo: 'completed')
              .limit(10)
              .get();

          if (pastSnapshot.docs.isNotEmpty) {
            _pastSessions = pastSnapshot.docs.map((doc) {
              final d = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                'title': d['title'] ?? 'Session',
                'time': d['sessionDate'] != null
                    ? _formatDateTime(d['sessionDate'])
                    : d['time']?.toString() ?? '',
                'studentName': d['studentName'] ?? '',
                'type': d['type'] ?? 'offline',
              };
            }).toList();
          } else {
            final pastRaw = data['pastSessions'];
            _pastSessions = pastRaw is List
                ? pastRaw
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
                : [];
          }
        } catch (e) {
          debugPrint('Error loading sessions: $e');
          final upcomingRaw = data['upcomingSessions'];
          _upcomingSessions = upcomingRaw is List
              ? upcomingRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
              : [];

          final pastRaw = data['pastSessions'];
          _pastSessions = pastRaw is List
              ? pastRaw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
              : [];
        }
        // ===========================================================================

        // earnings - load from subcollection or calculate
        try {
          if (_isOwnProfile) {
            final earningsSnapshot = await _firestore
                .collection('users')
                .doc(widget.profileUserId)
                .collection('earnings')
                .orderBy('date', descending: true)
                .limit(10)
                .get();

            _recentEarnings = earningsSnapshot.docs.map((doc) {
              final d = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                'label': d['label'] ?? 'Session',
                'amount': d['amount'] ?? 0,
                'date': d['date'] != null
                    ? _formatDateTime(d['date'])
                    : d['date']?.toString() ?? '',
              };
            }).toList();

            double total = 0;
            double thisMonth = 0;
            double pending = 0;
            final now = DateTime.now();

            for (var doc in earningsSnapshot.docs) {
              final d = doc.data();
              final amount = (d['amount'] ?? 0).toDouble();
              total += amount;

              if (d['date'] != null) {
                final date = (d['date'] as Timestamp).toDate();
                if (date.year == now.year && date.month == now.month) {
                  thisMonth += amount;
                }
              }

              if (d['status'] == 'pending') {
                pending += amount;
              }
            }

            _earningsSummary = {
              'total': total,
              'thisMonth': thisMonth,
              'pending': pending,
            };
          } else {
            final es = data['earningsSummary'];
            _earningsSummary =
            es is Map ? Map<String, dynamic>.from(es) : <String, dynamic>{};

            final er = data['recentEarnings'];
            _recentEarnings = er is List
                ? er.map((e) => Map<String, dynamic>.from(e as Map)).toList()
                : [];
          }
        } catch (e) {
          debugPrint('Error loading earnings: $e');
          final es = data['earningsSummary'];
          _earningsSummary =
          es is Map ? Map<String, dynamic>.from(es) : <String, dynamic>{};

          final er = data['recentEarnings'];
          _recentEarnings = er is List
              ? er.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : [];
        }

        // classes - load from subcollection
        try {
          final classesSnapshot = await _firestore
              .collection('users')
              .doc(widget.profileUserId)
              .collection('classes')
              .where('isActive', isEqualTo: true)
              .limit(10)
              .get();

          if (classesSnapshot.docs.isNotEmpty) {
            _classes = classesSnapshot.docs.map((doc) {
              final d = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                'name': d['name'] ?? 'Batch',
                'schedule': d['schedule'] ?? '',
                'enrolled': d['enrolled'] ?? 0,
                'capacity': d['capacity'] ?? 0,
                'price': d['price'] ?? 0,
              };
            }).toList();
          } else {
            final cls = data['classes'];
            _classes = cls is List
                ? cls.map((e) => Map<String, dynamic>.from(e as Map)).toList()
                : [];
          }
        } catch (e) {
          debugPrint('Error loading classes: $e');
          final cls = data['classes'];
          _classes = cls is List
              ? cls.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : [];
        }

        // students - load from subcollection
        try {
          final studentsSnapshot = await _firestore
              .collection('users')
              .doc(widget.profileUserId)
              .collection('students')
              .limit(10)
              .get();

          if (studentsSnapshot.docs.isNotEmpty) {
            final studentsFutures = studentsSnapshot.docs.map((doc) async {
              final d = doc.data();
              final studentId = d['studentId'] ?? doc.id;

              try {
                final studentDoc =
                await _firestore.collection('users').doc(studentId).get();
                final studentData = studentDoc.data() ?? {};

                return {
                  'id': doc.id,
                  'studentId': studentId,
                  'name': studentData['name'] ?? d['name'] ?? 'Student',
                  'level': d['level'] ?? 'Beginner',
                  'progress': d['progress'] ?? 0,
                  'goal': d['goal'] ?? '',
                };
              } catch (_) {
                return {
                  'id': doc.id,
                  'studentId': studentId,
                  'name': d['name'] ?? 'Student',
                  'level': d['level'] ?? 'Beginner',
                  'progress': d['progress'] ?? 0,
                  'goal': d['goal'] ?? '',
                };
              }
            }).toList();

            _students = await Future.wait(studentsFutures);
          } else {
            final stu = data['students'];
            _students = stu is List
                ? stu.map((e) => Map<String, dynamic>.from(e as Map)).toList()
                : [];
          }
        } catch (e) {
          debugPrint('Error loading students: $e');
          final stu = data['students'];
          _students = stu is List
              ? stu.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : [];
        }

        // analytics - load from user doc
        final an = data['analytics'];
        _analytics =
        an is Map ? Map<String, dynamic>.from(an) : <String, dynamic>{};

        // social + gallery
        final sl = data['socialLinks'] as Map<String, dynamic>?;
        _socialLinks = sl != null
            ? sl.map((k, v) => MapEntry(k, v.toString()))
            : {
          'instagram': 'Instagram',
          'telegram': 'Telegram',
        };

        final gal = data['galleryImages'];
        _galleryImages = gal is List
            ? gal.map((e) => e.toString()).toList()
            : <String>[];

        // Load posts for first tab
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
            // Try with createdAt if timestamp doesn't work
            try {
              postsSnapshot = await _firestore
                  .collection('posts')
                  .where('userId', isEqualTo: widget.profileUserId)
                  .orderBy('createdAt', descending: true)
                  .limit(9)
                  .get();
            } catch (_) {
              // If both fail, get without orderBy
              postsSnapshot = await _firestore
                  .collection('posts')
                  .where('userId', isEqualTo: widget.profileUserId)
                  .limit(9)
                  .get();
            }
          }

          _recentPosts = postsSnapshot.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return <String, dynamic>{
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

        // Load reviews for first tab
        try {
          // Try reviews collection first
          QuerySnapshot<Map<String, dynamic>>? reviewsSnapshot;
          try {
            reviewsSnapshot = await _firestore
                .collection('reviews')
                .where('guruId', isEqualTo: widget.profileUserId)
                .orderBy('createdAt', descending: true)
                .limit(2)
                .get();
          } catch (_) {
            // If query fails (no index), try without orderBy
            try {
              reviewsSnapshot = await _firestore
                  .collection('reviews')
                  .where('guruId', isEqualTo: widget.profileUserId)
                  .limit(2)
                  .get();
            } catch (_) {
              reviewsSnapshot = null;
            }
          }

          if (reviewsSnapshot != null && reviewsSnapshot.docs.isNotEmpty) {
            _reviews = reviewsSnapshot.docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return <String, dynamic>{
                'id': doc.id,
                'name': d['userName'] ?? d['name'] ?? 'User',
                'rating': d['rating'] ?? 5,
                'text': d['text'] ?? '',
                'createdAt': d['createdAt'],
                'profilePhoto': d['profilePhoto'],
              };
            }).toList();
          } else {
            // Fallback to user document reviews array
            final reviewsRaw = data['reviews'];
            if (reviewsRaw is List && reviewsRaw.isNotEmpty) {
              _reviews = reviewsRaw
                  .take(2)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
            } else {
              _reviews = [];
            }
          }
        } catch (e) {
          debugPrint('Error loading reviews: $e');
          final reviewsRaw = data['reviews'];
          _reviews = reviewsRaw is List && reviewsRaw.isNotEmpty
              ? reviewsRaw
                  .take(2)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList()
              : [];
        }

        // Load programs/services (from classes or popularProducts)
        try {
          if (_classes.isNotEmpty) {
            _programs = _classes.take(5).map((cls) {
              return <String, dynamic>{
                'id': cls['id'] ?? '',
                'name': cls['name'] ?? 'Program',
                'duration': cls['schedule'] ?? 'Ongoing',
                'imageUrl': cls['imageUrl'],
                'price': cls['price'] ?? 0,
              };
            }).toList();
          } else {
            final productsRaw = data['popularProducts'];
            if (productsRaw is List && productsRaw.isNotEmpty) {
              _programs = productsRaw.take(5).map((p) {
                return Map<String, dynamic>.from(p as Map);
              }).toList();
            } else {
              _programs = [];
            }
          }
        } catch (e) {
          debugPrint('Error loading programs: $e');
          _programs = [];
        }

        // Load last workouts
        try {
          final workoutsRaw = data['lastWorkouts'];
          if (workoutsRaw is List && workoutsRaw.isNotEmpty) {
            _lastWorkouts = workoutsRaw.take(3).map((w) {
              return Map<String, dynamic>.from(w as Map);
            }).toList();
          } else {
            _lastWorkouts = [];
          }
        } catch (e) {
          debugPrint('Error loading workouts: $e');
          _lastWorkouts = [];
        }
      }

      // follow status
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
      debugPrint('guru profile load error: $e');
      Fluttertoast.showToast(msg: 'Failed to load profile');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '';
    try {
      if (dateTime is Timestamp) {
        final date = dateTime.toDate();
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (dateTime is String) {
        return dateTime;
      }
      return dateTime.toString();
    } catch (e) {
      return dateTime.toString();
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
  //  POSTS
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
  //  GURU SECTION HANDLERS
  // ===================================================================
  Future<void> _handleManageSlots() async {
    if (!_isOwnProfile || _currentUser == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Manage Booking Slots',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Settings:',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('Base Price: ₹${_bookingSettings['basePrice'] ?? 'Not set'}'),
              Text('Duration: ${_bookingSettings['duration'] ?? 60} min'),
              Text('Online: ${_bookingSettings['online'] == true ? 'Yes' : 'No'}'),
              Text('Offline: ${_bookingSettings['offline'] == true ? 'Yes' : 'No'}'),
              const SizedBox(height: 16),
              const Text(
                'Full booking management feature coming soon! You will be able to set your availability, pricing, and manage all your slots here.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Navigate to booking management page
            },
            child: const Text('Edit Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBookNow() async {
    if (_isOwnProfile) return;

    if (_currentUser == null) {
      Fluttertoast.showToast(msg: 'Please login to book a session');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Book a Session',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Guru: $_fullName'),
            const SizedBox(height: 8),
            Text(
                'Starting from: ₹${_bookingSettings['basePrice'] ?? 'Contact for pricing'}'),
            Text('Duration: ${_bookingSettings['duration'] ?? 60} min'),
            const SizedBox(height: 16),
            const Text(
              'Booking feature coming soon! You will be able to select a time slot and book a session.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Navigate to booking page
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManageClasses() async {
    if (!_isOwnProfile || _currentUser == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Manage Classes & Batches',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active Classes: ${_classes.length}'),
            const SizedBox(height: 16),
            const Text(
              'Class management feature coming soon! You will be able to create, edit, and manage your batches here.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Navigate to classes management page
            },
            child: const Text('Create New Class'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleViewPayoutDetails() async {
    if (!_isOwnProfile || _currentUser == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Payout Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPayoutRow('Total Earnings', '₹${_earningsSummary['total'] ?? 0}'),
              _buildPayoutRow('This Month', '₹${_earningsSummary['thisMonth'] ?? 0}'),
              _buildPayoutRow('Pending', '₹${_earningsSummary['pending'] ?? 0}'),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Recent Transactions:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_recentEarnings.isEmpty)
                const Text(
                  'No transactions yet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                )
              else
                ..._recentEarnings.take(5).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e['label']?.toString() ?? 'Session',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        '₹${e['amount'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
              const SizedBox(height: 16),
              const Text(
                'Withdrawal options and bank details management coming soon!',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Navigate to full earnings page
            },
            child: const Text('View All'),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  //  EDIT PROFILE / SETTINGS / LOGOUT
  // ===================================================================)
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
          initialprofessiontype: _primaryCategory,
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
      tag: 'guru-avatar-${widget.profileUserId}',
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
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black87,
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
          child: const Text(
            'Edit Profile',
            style: TextStyle(color: Colors.black87),
          ),
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
              icon: const Icon(Icons.message_outlined,
                  color: Colors.black87),
              label: const Text(
                'Message',
                style: TextStyle(color: Colors.black87),
              ),
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

  Widget _buildBadgesRow() {
    if (_badges.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: _badges
            .map(
              (b) => Chip(
            label: Text(
              b,
              style: GoogleFonts.poppins(color: Colors.black87),
            ),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildBioCard() {
    final displayBio = _bio.isNotEmpty
        ? _bio
        : (_isOwnProfile
        ? 'Tell aspirants how you train, your style and experience.'
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
          style: GoogleFonts.poppins(
            fontSize: 14,
            height: 1.4,
            color: Colors.black87,
          ),
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
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_primaryCategory.isNotEmpty)
                        Text(
                          _primaryCategory,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (_city.isNotEmpty) ...[
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: Colors.black87),
                            const SizedBox(width: 4),
                            Text(
                              _city,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                          if (_experienceYears != null) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.school_outlined,
                                size: 14, color: Colors.black87),
                            const SizedBox(width: 4),
                            Text(
                              '${_experienceYears}+ yrs exp',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (_languages.isNotEmpty)
                        Text(
                          'Languages: ${_languages.join(', ')}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      if (_trainingStyle.isNotEmpty)
                        Text(
                          'Training style: $_trainingStyle',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
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
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($_reviewCount reviews)',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.black54,
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
        const SizedBox(height: 6),
        _buildBadgesRow(),
        const SizedBox(height: 10),
        _buildStatsCard(),
        const SizedBox(height: 12),
        _buildActionButtons(),
        _buildBioCard(),
      ],
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
              // First Tab - Posts/Content (placeholder for future features)
              _buildFirstTab(),
              // Second Tab - Existing Guru Sections
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
              // CTA Buttons
              _buildCTAButtons(),
              const SizedBox(height: 24),
              // Popular Products Section (Figma Design)
              _buildPopularProductsSection(),
              const SizedBox(height: 24),
              // Last Workouts Section (Figma Design)
              _buildLastWorkoutsSection(),
              const SizedBox(height: 24),
              // Recent Posts (Figma Design - Full Cards)
              _buildRecentPostsSection(),
              const SizedBox(height: 24),
              // Specializations (Figma Design - Red Background)
              _buildSpecializationsSection(),
              const SizedBox(height: 24),
              // Reviews & Ratings (Figma Design - Grey Background)
              _buildReviewsSection(),
              const SizedBox(height: 24),
              // Social Links (Figma Design - YouTube, Apple Music, Instagram)
              _buildSocialLinksSection(),
              const SizedBox(height: 24),
              // Footer
              _buildFooter(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  // ===================================================================
  //  FIRST TAB SECTION BUILDERS
  // ===================================================================
  Widget _buildCTAButtons() {
    if (_isOwnProfile) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _lavender,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
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
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _openMessage,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Text(
                'DM',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _handleBookNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _deepLavender,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
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

  Widget _buildBioSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                'About',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: _editBio,
                  color: _lavender,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_bio.isNotEmpty)
            Text(
              _bio,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            )
          else if (_isOwnProfile)
            TextButton.icon(
              onPressed: _editBio,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add bio'),
              style: TextButton.styleFrom(foregroundColor: _lavender),
            )
          else
            Text(
              'No bio available',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (_bio.isNotEmpty) const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (_experienceYears != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_outlined,
                        size: 16, color: Colors.black87),
                    const SizedBox(width: 4),
                    Text(
                      'Experience: $_experienceYears years',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              if (_languages.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language_outlined,
                        size: 16, color: Colors.black87),
                    const SizedBox(width: 4),
                    Text(
                      'Languages: ${_languages.join(', ')}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              if (_city.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.black87),
                    const SizedBox(width: 4),
                    Text(
                      'Location: $_city',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

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
            hintText: 'Tell people about yourself...',
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

  Widget _buildSpecializationsSection() {
    // Mock ratings for specialties (can be stored in Firestore)
    final specialtyRatings = [3.5, 4.0, 3.0, 2.0];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Specialties (with certification)',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_specialties.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _isOwnProfile
                ? TextButton.icon(
                    onPressed: _editSpecializations,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add specializations'),
                    style: TextButton.styleFrom(foregroundColor: _lavender),
                  )
                : Text(
                    'No specializations yet',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
          )
        else
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20.0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _specialties.asMap().entries.map((entry) {
                final index = entry.key;
                final specialty = entry.value;
                final rating = index < specialtyRatings.length
                    ? specialtyRatings[index]
                    : 4.0;
                
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _specialties.length - 1 ? 12 : 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        specialty,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (i) {
                          return Icon(
                            i < rating.floor()
                                ? Icons.star
                                : (i < rating
                                    ? Icons.star_half
                                    : Icons.star_border),
                            size: 16,
                            color: Colors.amber[700],
                          );
                        }),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _editSpecializations() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final controller = TextEditingController(
        text: _specialties.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Specializations',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter specializations separated by commas',
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
      final specialties = result
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      try {
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'specialties': specialties});
        setState(() => _specialties = specialties);
        Fluttertoast.showToast(msg: 'Specializations updated');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to update specializations');
      }
    }
  }

  Widget _buildGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gallery',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                  onPressed: _addGalleryImage,
                  color: _lavender,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_galleryImages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _isOwnProfile
                ? TextButton.icon(
                    onPressed: _addGalleryImage,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add gallery images'),
                    style: TextButton.styleFrom(foregroundColor: _lavender),
                  )
                : Text(
                    'No gallery images',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: _galleryImages.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[200],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _galleryImages[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _addGalleryImage() async {
    if (!_isOwnProfile || _currentUser == null) return;
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    try {
      final fileName =
          'gallery_${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(_currentUser!.uid)
          .child('gallery')
          .child(fileName);
      final snap = await ref.putFile(File(picked.path));
      final url = await snap.ref.getDownloadURL();

      final updated = List<String>.from(_galleryImages)..add(url);
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'galleryImages': updated});
      setState(() => _galleryImages = updated);
      Fluttertoast.showToast(msg: 'Image added to gallery');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to add image');
    }
  }

  Widget _buildPopularProductsSection() {
    // Load products from user data
    final products = _programs.isNotEmpty 
        ? _programs 
        : (widget.profileUserId == _currentUser?.uid 
            ? [] 
            : []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Popular Products',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Check out my recommended fitness gear',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _isOwnProfile
                ? TextButton.icon(
                    onPressed: _addProgram,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add products'),
                    style: TextButton.styleFrom(foregroundColor: _lavender),
                  )
                : Text(
                    'No products available',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildProductCard(
                    products[0],
                    tag: products[0]['tag']?.toString() ?? 'Best Seller',
                  ),
                ),
                const SizedBox(width: 12),
                if (products.length > 1)
                  Expanded(
                    child: _buildProductCard(
                      products[1],
                      tag: products[1]['tag']?.toString() ?? 'New Arrival',
                    ),
                  )
                else
                  Expanded(child: Container()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, {required String tag}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 140,
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
                            child: Icon(Icons.image, size: 40, color: Colors.grey),
                          ),
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Image-url',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tag == 'Best Seller' ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
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
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Price: ${product['price']?.toString() ?? 'Rs 0.00'}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastWorkoutsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Last workouts',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_lastWorkouts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'No workouts yet',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: _lastWorkouts.map((workout) {
                final title = workout['title']?.toString() ?? 'Workout';
                final duration = workout['duration']?.toString() ?? '0 mins';
                final intensity = workout['intensity']?.toString() ?? '';
                final calories = workout['calories']?.toString() ?? '';
                
                // Determine icon based on workout title
                IconData workoutIcon = Icons.fitness_center;
                Color iconColor = Colors.grey;
                if (title.toLowerCase().contains('cardio') || 
                    title.toLowerCase().contains('run')) {
                  workoutIcon = Icons.directions_run;
                  iconColor = Colors.orange;
                } else if (title.toLowerCase().contains('zumba') || 
                           title.toLowerCase().contains('dance')) {
                  workoutIcon = Icons.music_note;
                  iconColor = Colors.orange;
                } else if (title.toLowerCase().contains('leg')) {
                  workoutIcon = Icons.accessibility_new;
                  iconColor = Colors.grey;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(workoutIcon, color: iconColor, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Duration: $duration',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (intensity.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: intensity.toLowerCase() == 'high'
                                ? Colors.red[50]
                                : Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Intensity: $intensity',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: intensity.toLowerCase() == 'high'
                                  ? Colors.red[700]
                                  : Colors.blue[700],
                            ),
                          ),
                        )
                      else if (calories.isNotEmpty)
                        Text(
                          'Calories Burned: $calories',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _addProgram() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final nameController = TextEditingController();
    final durationController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Add Program',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Program Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationController,
              decoration: InputDecoration(
                labelText: 'Duration (e.g., 4 weeks)',
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
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _lavender),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final newProgram = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': nameController.text,
          'duration': durationController.text.isNotEmpty
              ? durationController.text
              : 'Ongoing',
          'createdAt': FieldValue.serverTimestamp(),
        };

        final updated = List<Map<String, dynamic>>.from(_programs)..add(newProgram);
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'popularProducts': updated});
        setState(() => _programs = updated);
        Fluttertoast.showToast(msg: 'Program added');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to add program');
      }
    }
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
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.add_box_outlined, size: 20),
                  onPressed: _openGalleryForPost,
                  color: _lavender,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('posts')
              .where('userId', isEqualTo: widget.profileUserId)
              .snapshots()
              .handleError((error) {
            debugPrint('Error in posts stream: $error');
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              debugPrint('Posts stream error: ${snapshot.error}');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Error loading posts',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }

            final allDocs = snapshot.data?.docs ?? [];
            final sortedDocs = List.from(allDocs)
              ..sort((a, b) {
                try {
                  final aTime = a.data();
                  final bTime = b.data();
                  if (aTime is! Map<String, dynamic> || bTime is! Map<String, dynamic>) {
                    return 0;
                  }
                  final aTimestamp = aTime['timestamp'] ?? aTime['createdAt'];
                  final bTimestamp = bTime['timestamp'] ?? bTime['createdAt'];
                  if (aTimestamp == null) return 1;
                  if (bTimestamp == null) return -1;
                  if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
                    return bTimestamp.compareTo(aTimestamp);
                  }
                  return 0;
                } catch (e) {
                  debugPrint('Error sorting posts: $e');
                  return 0;
                }
              });
            final docs = sortedDocs.take(9).toList();
            
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _isOwnProfile
                    ? TextButton.icon(
                        onPressed: _openGalleryForPost,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Create your first post'),
                        style: TextButton.styleFrom(foregroundColor: _lavender),
                      )
                    : Column(
                        children: [
                          Icon(Icons.camera_alt_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No posts yet',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: docs.take(2).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final imageUrl = data['imageUrl']?.toString() ?? '';
                  final caption = data['caption']?.toString() ?? '';
                  final timestamp = data['timestamp'] ?? data['createdAt'];
                  
                  // Extract tags from caption (hashtags)
                  final tags = RegExp(r'#\w+').allMatches(caption).map((m) => m.group(0)!).toList();
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Header
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: _lavender.withOpacity(0.2),
                                backgroundImage: _profilePhotoUrl != null
                                    ? NetworkImage(_profilePhotoUrl!)
                                    : null,
                                child: _profilePhotoUrl == null
                                    ? Text(
                                        _username.isNotEmpty
                                            ? _username[0].toUpperCase()
                                            : 'U',
                                        style: GoogleFonts.poppins(
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
                                    Text(
                                      _username.isNotEmpty ? '@$_username' : '@user',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${_formatPostTime(timestamp)} - ${_city.isNotEmpty ? _city : "Gym"}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onPressed: () {},
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                        // Post Image
                        if (imageUrl.isNotEmpty)
                          Container(
                            width: double.infinity,
                            height: 300,
                            color: Colors.grey[200],
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Text('Image-url', style: TextStyle(color: Colors.grey)),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            height: 300,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Text('Image-url', style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                        // Caption and Tags
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (caption.isNotEmpty)
                                Text(
                                  caption,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              if (tags.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: tags.map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        tag,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
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
                'Reviews & Ratings',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (!_isOwnProfile)
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to write review
                  },
                  child: Text(
                    'Write a Review',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _lavender,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore
              .collection('reviews')
              .where('guruId', isEqualTo: widget.profileUserId)
              .snapshots()
              .handleError((error) {
            debugPrint('Error in reviews stream: $error');
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              debugPrint('Reviews stream error: ${snapshot.error}');
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Error loading reviews',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }

            final allDocs = snapshot.data?.docs ?? [];
            final sortedDocs = List.from(allDocs)
              ..sort((a, b) {
                try {
                  final aTime = a.data();
                  final bTime = b.data();
                  if (aTime is! Map<String, dynamic> || bTime is! Map<String, dynamic>) {
                    return 0;
                  }
                  final aTimestamp = aTime['createdAt'];
                  final bTimestamp = bTime['createdAt'];
                  if (aTimestamp == null) return 1;
                  if (bTimestamp == null) return -1;
                  if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
                    return bTimestamp.compareTo(aTimestamp);
                  }
                  return 0;
                } catch (e) {
                  debugPrint('Error sorting reviews: $e');
                  return 0;
                }
              });
            final docs = sortedDocs.take(2).toList();
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Icon(Icons.rate_review_outlined,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No reviews yet',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: docs.map((doc) {
                  final review = doc.data() as Map<String, dynamic>;
                  final name = review['userName']?.toString() ??
                      review['name']?.toString() ??
                      'User';
                  final rating = (review['rating'] ?? 4).toDouble();
                  final text = review['text']?.toString() ?? '';
                  
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: docs.indexOf(doc) < docs.length - 1 ? 16 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < rating.floor()
                                      ? Icons.star
                                      : (i < rating
                                          ? Icons.star_half
                                          : Icons.star_border),
                                  size: 16,
                                  color: Colors.amber[700],
                                );
                              }),
                            ),
                          ],
                        ),
                        if (text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            text,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAchievementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Achievements',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: _addAchievement,
                  color: _lavender,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_achievements.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _isOwnProfile
                ? TextButton.icon(
                    onPressed: _addAchievement,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add achievements'),
                    style: TextButton.styleFrom(foregroundColor: _lavender),
                  )
                : Text(
                    'No achievements yet',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: _achievements.length,
              itemBuilder: (context, index) {
                final achievement = _achievements[index];
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events,
                          size: 32, color: Colors.amber[700]),
                      const SizedBox(height: 8),
                      Text(
                        achievement['title']?.toString() ?? 'Achievement',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

  Future<void> _addAchievement() async {
    if (!_isOwnProfile || _currentUser == null) return;

    final titleController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Add Achievement',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: 'Achievement Title',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _lavender),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && titleController.text.isNotEmpty) {
      try {
        final newAchievement = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': titleController.text,
          'createdAt': FieldValue.serverTimestamp(),
        };

        final updated =
            List<Map<String, dynamic>>.from(_achievements)..add(newAchievement);
        await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'achievements': updated});
        setState(() => _achievements = updated);
        Fluttertoast.showToast(msg: 'Achievement added');
      } catch (e) {
        Fluttertoast.showToast(msg: 'Failed to add achievement');
      }
    }
  }

  Widget _buildSocialLinksSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Social Links',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          // YouTube Section
          if (_socialLinks.containsKey('youtube') ||
              _socialLinks.containsKey('YouTube'))
            _buildYouTubeSection(),
          // Apple Music Section
          if (_socialLinks.containsKey('appleMusic') ||
              _socialLinks.containsKey('Apple Music') ||
              _socialLinks.containsKey('spotify'))
            _buildAppleMusicSection(),
          // Instagram Section
          if (_socialLinks.containsKey('instagram') ||
              _socialLinks.containsKey('Instagram'))
            _buildInstagramSection(),
        ],
      ),
    );
  }

  Widget _buildYouTubeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.play_circle_filled, color: Colors.red[700], size: 24),
            const SizedBox(width: 8),
            Text(
              'Youtube',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(3, (index) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'Youtube Thumbnail',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAppleMusicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.music_note, color: Colors.pink[300], size: 24),
            const SizedBox(width: 8),
            Text(
              'Apple music',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Playlist names
        Text(
          'Playlist names',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            _buildRadioOption('Beast workout', false),
            _buildRadioOption('Anna\'s playlist', false),
          ],
        ),
        const SizedBox(height: 16),
        // Top artist names
        Text(
          'Top artist names',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            _buildRadioOption('Drake', false),
            _buildRadioOption('Travis Scott', false),
            _buildRadioOption('Diljit Dosanjh', false),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRadioOption(String label, bool selected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey, width: 2),
            color: selected ? _lavender : Colors.transparent,
          ),
          child: selected
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInstagramSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple, Colors.pink, Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'Instagram',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Recent posts',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(3, (index) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image, color: Colors.grey, size: 32),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            _bg,
            _lavender.withOpacity(0.1),
          ],
        ),
      ),
    );
  }

  String _formatReviewDate(dynamic date) {
    if (date == null) return '';
    try {
      if (date is Timestamp) {
        final reviewDate = date.toDate();
        final now = DateTime.now();
        final difference = now.difference(reviewDate);

        if (difference.inDays == 0) {
          return 'Today';
        } else if (difference.inDays == 1) {
          return 'Yesterday';
        } else if (difference.inDays < 7) {
          return '${difference.inDays} days ago';
        } else if (difference.inDays < 30) {
          return '${(difference.inDays / 7).floor()} weeks ago';
        } else {
          return '${reviewDate.day}/${reviewDate.month}/${reviewDate.year}';
        }
      }
      return date.toString();
    } catch (e) {
      return '';
    }
  }

  String _formatPostTime(dynamic date) {
    if (date == null) return 'Just now';
    try {
      if (date is Timestamp) {
        final postDate = date.toDate();
        final now = DateTime.now();
        final difference = now.difference(postDate);

        if (difference.inMinutes < 1) {
          return 'Just now';
        } else if (difference.inMinutes < 60) {
          return '${difference.inMinutes} minutes ago';
        } else if (difference.inHours < 24) {
          return '${difference.inHours} hours ago';
        } else if (difference.inDays < 7) {
          return '${difference.inDays} days ago';
        } else {
          return '${postDate.day}/${postDate.month}/${postDate.year}';
        }
      }
      return date.toString();
    } catch (e) {
      return 'Just now';
    }
  }

  Widget _buildSecondTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              GuruBookingSection(
                guruid: widget.profileUserId,
                isOwnProfile: _isOwnProfile,
                bookingSettings: _bookingSettings,
                upcomingSessions: _upcomingSessions,
                pastSessions: _pastSessions,
                onManageSlots:
                _isOwnProfile ? _handleManageSlots : null,
                onBookNow: !_isOwnProfile ? _handleBookNow : null,
              ),
              GuruClassesSection(
                guruid: widget.profileUserId,
                isOwnProfile: _isOwnProfile,
                classes: _classes,
                specialties: _specialties,
                onManage:
                _isOwnProfile ? _handleManageClasses : null,
              ),
              GuruEarningsSection(
                guruid: widget.profileUserId,
                isOwnProfile: _isOwnProfile,
                earningsSummary: _earningsSummary,
                recentEarnings: _recentEarnings,
                onViewPayoutDetails: _isOwnProfile
                    ? _handleViewPayoutDetails
                    : null,
              ),
              GuruStudentsSection(
                guruid: widget.profileUserId,
                isOwnProfile: _isOwnProfile,
                students: _students,
              ),
              GuruAnalyticsSection(
                guruid: widget.profileUserId,
                isOwnProfile: _isOwnProfile,
                analytics: _analytics,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }
}
