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
                  _buildProfileHeaderSection(),

                  // ---------- GURU SECTIONS ----------
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
        ),
      ),
    );
  }
}
