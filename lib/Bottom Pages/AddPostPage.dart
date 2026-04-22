import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';

// ── Theme ──────────────────────────────────────────────────────────────────
const Color kPrimaryColor   = Color(0xFFA58CE3);
const Color kSecondaryColor = Color(0xFF5B3FA3);
const Color kBgColor        = Color(0xFFF4F1FB);

// ══════════════════════════════════════════════════════════════════════════
//  MediaItem – wraps an XFile + optional VideoPlayerController
// ══════════════════════════════════════════════════════════════════════════
enum MediaType { image, video }

class MediaItem {
  final XFile file;
  final MediaType type;
  VideoPlayerController? videoController;

  MediaItem({required this.file, required this.type, this.videoController});

  bool get isVideo => type == MediaType.video;
}

// ══════════════════════════════════════════════════════════════════════════
//  AddPostPage
// ══════════════════════════════════════════════════════════════════════════
class AddPostPage extends StatefulWidget {
  const AddPostPage({super.key});
  @override
  State<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> with SingleTickerProviderStateMixin {
  static const int _maxMediaItems = 12;

  // Controllers
  final _captionCtrl  = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _picker       = ImagePicker();

  // Media
  final List<MediaItem> _media = [];

  // Upload state
  bool   _isUploading      = false;
  double _uploadProgress   = 0;
  String _uploadStatusMsg  = '';
  int    _currentUploadIdx = 0;

  // Camera
  CameraController?      _camCtrl;
  List<CameraDescription>? _cameras;
  bool _isCamReady = false;

  // Tags
  static const List<String> _allTags = [
    'Career','Wellness','Fitness','Spirituality',
    'Study','Finance','Mindset','Relationships','Productivity','Lifestyle',
  ];
  final Set<String> _selectedTags = {};

  // @mention
  List<Map<String,dynamic>> _mentionSuggestions = [];
  bool   _showMentions      = false;
  int    _mentionReqId      = 0;

  // Tab animation
  late final AnimationController _tabAnim;
  bool _isFetchingLiveLocation = false;

  @override
  void initState() {
    super.initState();
    _tabAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _initCamera();
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
    _captionCtrl.dispose();
    _locationCtrl.dispose();
    _tabAnim.dispose();
    for (final m in _media) {
      m.videoController?.dispose();
    }
    super.dispose();
  }

  // ── Camera init ──────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) return;
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _camCtrl = CameraController(_cameras!.first, ResolutionPreset.high, enableAudio: true);
        await _camCtrl!.initialize();
        if (mounted) setState(() => _isCamReady = true);
      }
    } catch (_) {}
  }

  // ── Pick from gallery ────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (files.isEmpty || !mounted) return;

      final availableSlots = _maxMediaItems - _media.length;
      if (availableSlots <= 0) {
        _showSnack('Maximum $_maxMediaItems media items allowed.');
        return;
      }

      final selected = files.take(availableSlots).toList();
      setState(() {
        for (final f in selected) {
          _media.add(MediaItem(file: f, type: MediaType.image));
        }
      });

      if (files.length > selected.length) {
        _showSnack('Only $_maxMediaItems items are allowed per post.');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Unable to pick images: $e');
    }
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
    if (file == null) return;
    final ctrl = VideoPlayerController.file(File(file.path));
    await ctrl.initialize();
    setState(() => _media.add(MediaItem(file: file, type: MediaType.video, videoController: ctrl)));
  }

  // ── Open full-screen camera ───────────────────────────────────────────────
  Future<void> _openCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;
    final result = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenCamera(cameras: _cameras!),
      ),
    );
    if (result == null) return;
    final isVideo = result.path.endsWith('.mp4');
    if (isVideo) {
      final ctrl = VideoPlayerController.file(File(result.path));
      await ctrl.initialize();
      setState(() => _media.add(MediaItem(file: result, type: MediaType.video, videoController: ctrl)));
    } else {
      setState(() => _media.add(MediaItem(file: result, type: MediaType.image)));
    }
  }

  Future<void> _pickLiveLocationCity() async {
    if (_isFetchingLiveLocation) return;
    setState(() => _isFetchingLiveLocation = true);
    try {
      final location = loc.Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
      }
      if (!serviceEnabled) {
        _showSnack('Please enable location service.');
        return;
      }

      var permission = await location.hasPermission();
      if (permission == loc.PermissionStatus.denied) {
        permission = await location.requestPermission();
      }
      if (permission != loc.PermissionStatus.granted &&
          permission != loc.PermissionStatus.grantedLimited) {
        _showSnack('Location permission is required.');
        return;
      }

      final data = await location.getLocation();
      final lat = data.latitude;
      final lng = data.longitude;
      if (lat == null || lng == null) {
        _showSnack('Unable to fetch your location.');
        return;
      }

      final places = await placemarkFromCoordinates(lat, lng);
      if (places.isEmpty) {
        _showSnack('City not found from current location.');
        return;
      }

      final place = places.first;
      final city =
          (place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? '')
              .trim();
      if (city.isEmpty) {
        _showSnack('City not found from current location.');
        return;
      }

      _locationCtrl.text = city;
      _showSnack('Location updated to $city');
    } catch (e) {
      _showSnack('Could not fetch location: $e');
    } finally {
      if (mounted) setState(() => _isFetchingLiveLocation = false);
    }
  }

  // ── Remove media ─────────────────────────────────────────────────────────
  void _removeMedia(int index) {
    final item = _media[index];
    item.videoController?.dispose();
    setState(() => _media.removeAt(index));
  }

  // ── Reorder media ────────────────────────────────────────────────────────
  void _reorderMedia(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _media.removeAt(oldIndex);
      _media.insert(newIndex, item);
    });
  }

  // ── @mention logic ───────────────────────────────────────────────────────
  void _onCaptionChanged(String value) {
    setState(() {});
    final cursor = _captionCtrl.selection.baseOffset;
    if (cursor <= 0 || cursor > value.length) { _hideMentions(); return; }
    final before = value.substring(0, cursor);
    final atIdx  = before.lastIndexOf('@');
    if (atIdx == -1) { _hideMentions(); return; }
    if (atIdx > 0 && !RegExp(r'\s').hasMatch(before[atIdx - 1])) { _hideMentions(); return; }
    final query = before.substring(atIdx + 1);
    if (query.length < 2) { _hideMentions(); return; }
    _fetchMentions(query.toLowerCase());
  }

  void _hideMentions() {
    if (_showMentions || _mentionSuggestions.isNotEmpty) {
      setState(() { _showMentions = false; _mentionSuggestions = []; });
    }
  }

  Future<void> _fetchMentions(String q) async {
    final id = ++_mentionReqId;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username_lower', isGreaterThanOrEqualTo: q, isLessThanOrEqualTo: '$q\uf8ff')
          .limit(5).get();
      if (!mounted || id != _mentionReqId) return;
      final results = snap.docs.map((d) => d.data()..['id'] = d.id).toList();
      setState(() { _mentionSuggestions = results; _showMentions = results.isNotEmpty; });
    } catch (_) {
      if (!mounted || id != _mentionReqId) return;
      setState(() { _mentionSuggestions = []; _showMentions = false; });
    }
  }

  void _insertMention(String username) {
    final text   = _captionCtrl.text;
    final cursor = _captionCtrl.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) return;
    final before  = text.substring(0, cursor);
    final atIdx   = before.lastIndexOf('@');
    if (atIdx == -1) return;
    final newText = '${text.substring(0, atIdx + 1)}$username ${text.substring(cursor)}';
    final newPos  = atIdx + 1 + username.length + 1;
    _captionCtrl.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newPos));
    setState(() { _mentionSuggestions = []; _showMentions = false; });
  }

  List<String> _extractMentions(String caption) {
    final set = <String>{};
    for (final m in RegExp(r'@(\w+)').allMatches(caption)) {
      final u = m.group(1);
      if (u != null && u.isNotEmpty) set.add(u.toLowerCase());
    }
    return set.toList();
  }

  // ── Navigate to Preview ──────────────────────────────────────────────────
  void _openPreview() {
    if (_media.isEmpty) {
      _showSnack('Add at least one photo or video first.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PostPreviewPage(
          media: _media,
          caption: _captionCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          tags: _selectedTags.toList(),
          onPost: _submitPost,
        ),
      ),
    );
  }

  // ── Submit ───────────────────────────────────────────────────────────────
  Future<void> _submitPost() async {
    if (_media.isEmpty) { _showSnack('Add at least one photo or video.'); return; }
    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty) { _showSnack('Please enter a caption.'); return; }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) { _showSnack('Please sign in to post.'); return; }

    setState(() { _isUploading = true; _uploadProgress = 0; _currentUploadIdx = 0; });

    try {
      final postId  = FirebaseFirestore.instance.collection('posts').doc().id;
      final mediaList = <Map<String, dynamic>>[];

      for (int i = 0; i < _media.length; i++) {
        final item = _media[i];
        final ext  = item.isVideo ? 'mp4' : 'jpg';
        final path = 'users/$userId/posts/$postId-$i.$ext';

        setState(() {
          _currentUploadIdx = i + 1;
          _uploadStatusMsg  = 'Uploading ${item.isVideo ? "video" : "photo"} ${i + 1} of ${_media.length}…';
        });

        final ref = FirebaseStorage.instance.ref(path);
        final task = ref.putFile(File(item.file.path));

        task.snapshotEvents.listen((snap) {
          if (!mounted) return;
          final fileProgress = snap.bytesTransferred / snap.totalBytes;
          setState(() => _uploadProgress = (i + fileProgress) / _media.length);
        });

        await task;
        final url = await ref.getDownloadURL();
        mediaList.add({'type': item.isVideo ? 'video' : 'image', 'url': url});
      }

      setState(() { _uploadStatusMsg = 'Saving post…'; _uploadProgress = 1; });

      await FirebaseFirestore.instance.collection('posts').doc(postId).set({
        'userId'   : userId,
        'media'    : mediaList,
        'images'   : mediaList.where((m) => m['type'] == 'image').map<String>((m) => m['url'] as String).toList(),
        'caption'  : caption,
        'location' : _locationCtrl.text.trim(),
        'tags'     : _selectedTags.toList(),
        'mentions' : _extractMentions(caption),
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(userId)
          .update({'postsCount': FieldValue.increment(1)});

      if (!mounted) return;
      _showSnack('Post shared successfully!');
      _reset();
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _reset() {
    for (final m in _media) m.videoController?.dispose();
    setState(() {
      _media.clear();
      _captionCtrl.clear();
      _locationCtrl.clear();
      _selectedTags.clear();
      _mentionSuggestions.clear();
      _showMentions = false;
      _uploadProgress = 0;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final tt = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    return Theme(
      data: Theme.of(context).copyWith(textTheme: tt),
      child: Scaffold(
        backgroundColor: kBgColor,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            _buildBody(tt),
            if (_isUploading) _buildUploadOverlay(tt),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    elevation: 0,
    centerTitle: true,
    backgroundColor: Colors.transparent,
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [kSecondaryColor, kPrimaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
    ),
    title: Text('Create Post', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
    iconTheme: const IconThemeData(color: Colors.white),
    actions: [
      TextButton.icon(
        onPressed: _openPreview,
        icon: const Icon(Icons.visibility_rounded, color: Colors.white, size: 18),
        label: Text('Preview', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    ],
  );

  Widget _buildBody(TextTheme tt) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Media section ──────────────────────────────────────────────
        _sectionHeader(Icons.photo_library_rounded, 'Media', tt),
        const SizedBox(height: 12),
        _buildMediaRow(),
        const SizedBox(height: 12),
        _buildMediaGrid(tt),
        const SizedBox(height: 24),

        // ── Location ───────────────────────────────────────────────────
        _sectionHeader(Icons.location_on_rounded, 'Location', tt),
        const SizedBox(height: 12),
        _buildLocationField(tt),
        const SizedBox(height: 24),

        // ── Caption ────────────────────────────────────────────────────
        _sectionHeader(Icons.edit_note_rounded, 'Caption', tt),
        const SizedBox(height: 12),
        _buildCaptionField(tt),
        if (_showMentions) _buildMentionList(tt),
        const SizedBox(height: 24),

        // ── Tags ───────────────────────────────────────────────────────
        _sectionHeader(Icons.tag_rounded, 'Tags / Interests', tt),
        const SizedBox(height: 12),
        _buildTagsWrap(tt),
        const SizedBox(height: 32),

        // ── Buttons ────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _buildPreviewButton(tt)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _buildPostButton(tt)),
        ]),
        const SizedBox(height: 32),
      ],
    ),
  );

  // ── Section header ─────────────────────────────────────────────────────
  Widget _sectionHeader(IconData icon, String label, TextTheme tt) => Row(children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: kSecondaryColor, size: 18),
    ),
    const SizedBox(width: 10),
    Text(label, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.black87, letterSpacing: 0.3)),
  ]);

  // ── Media picker buttons row ───────────────────────────────────────────
  Widget _buildMediaRow() => Row(children: [
    _mediaTile(Icons.photo_library_rounded, 'Gallery', kPrimaryColor, _pickImages),
    const SizedBox(width: 12),
    _mediaTile(Icons.camera_alt_rounded, 'Camera', kSecondaryColor, _isCamReady ? _openCamera : null),
    const SizedBox(width: 12),
    _mediaTile(Icons.videocam_rounded, 'Video', const Color(0xFF2E7D32), _pickVideo),
  ]);

  Widget _mediaTile(IconData icon, String label, Color color, VoidCallback? onTap) {
    final disabled = onTap == null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 90,
          decoration: BoxDecoration(
            color: disabled ? Colors.grey.shade100 : color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: disabled ? Colors.grey.shade300 : color.withOpacity(0.4), width: 1.5),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: disabled ? Colors.grey.shade400 : color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600,
                color: disabled ? Colors.grey.shade400 : Colors.black87)),
          ]),
        ),
      ),
    );
  }

  // ── Media grid with reorder + preview + delete ─────────────────────────
  Widget _buildMediaGrid(TextTheme tt) {
    if (_media.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_photo_alternate_outlined, color: Colors.grey.shade400, size: 36),
            const SizedBox(height: 8),
            Text('No media selected', style: tt.bodySmall?.copyWith(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
          ]),
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        onReorder: _reorderMedia,
        itemCount: _media.length,
        itemBuilder: (ctx, index) {
          final item = _media[index];
          return ReorderableDragStartListener(
            key: ValueKey(item.file.path),
            index: index,
            child: _MediaThumbnail(
              item: item,
              index: index,
              isFirst: index == 0,
              onRemove: () => _removeMedia(index),
              onTap: () => _openMediaViewer(index),
            ),
          );
        },
      ),
    );
  }

  void _openMediaViewer(int index) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _MediaViewerPage(media: _media, initialIndex: index),
    ));
  }

  // ── Location field ────────────────────────────────────────────────────
  Widget _buildLocationField(TextTheme tt) => _styledField(
    controller: _locationCtrl,
    hint: 'Add a location tag…',
    icon: Icons.location_on_rounded,
    maxLines: 1,
    tt: tt,
    readOnly: false,
    suffixIcon: _isFetchingLiveLocation
        ? const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : IconButton(
            tooltip: 'Use current location',
            icon:
                const Icon(Icons.my_location_rounded, color: kSecondaryColor),
            onPressed: _pickLiveLocationCity,
          ),
  );

  // ── Caption field ─────────────────────────────────────────────────────
  Widget _buildCaptionField(TextTheme tt) => _styledField(
    controller: _captionCtrl,
    hint: 'Share your thoughts… use @username to mention',
    icon: Icons.short_text_rounded,
    maxLines: 5,
    tt: tt,
    onChanged: _onCaptionChanged,
  );

  Widget _styledField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required int maxLines,
    required TextTheme tt,
    void Function(String)? onChanged,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      style: tt.bodyMedium?.copyWith(color: Colors.black87),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: tt.bodyMedium?.copyWith(color: Colors.black38),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, color: kSecondaryColor, size: 20),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: kPrimaryColor.withOpacity(0.2), width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: kPrimaryColor.withOpacity(0.2), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: kPrimaryColor, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
  );

  // ── @mention list ──────────────────────────────────────────────────────
  Widget _buildMentionList(TextTheme tt) => Container(
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kPrimaryColor.withOpacity(0.2), width: 1),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 6))],
    ),
    child: ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _mentionSuggestions.length,
      separatorBuilder: (_, __) => Divider(height: 0, color: Colors.grey.shade100),
      itemBuilder: (_, i) {
        final u = _mentionSuggestions[i];
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundImage: u['photoUrl'] != null
                ? NetworkImage(u['photoUrl'] as String) as ImageProvider
                : const AssetImage('assets/images/Profile.png'),
          ),
          title: Text('@${u['username'] ?? ''}', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87)),
          subtitle: u['fullname'] != null ? Text(u['fullname'] as String, style: tt.bodySmall?.copyWith(color: Colors.black54)) : null,
          onTap: () => _insertMention(u['username'] as String? ?? ''),
        );
      },
    ),
  );

  // ── Tags wrap ─────────────────────────────────────────────────────────
  Widget _buildTagsWrap(TextTheme tt) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: kPrimaryColor.withOpacity(0.2), width: 1.5),
    ),
    child: Wrap(
      spacing: 8, runSpacing: 8,
      children: _allTags.map((tag) {
        final selected = _selectedTags.contains(tag);
        return GestureDetector(
          onTap: () => setState(() => selected ? _selectedTags.remove(tag) : _selectedTags.add(tag)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? kSecondaryColor : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? kSecondaryColor : Colors.grey.shade300, width: 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (selected) const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              if (selected) const SizedBox(width: 4),
              Text(tag, style: tt.bodySmall?.copyWith(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              )),
            ]),
          ),
        );
      }).toList(),
    ),
  );

  // ── Buttons ───────────────────────────────────────────────────────────
  Widget _buildPreviewButton(TextTheme tt) => OutlinedButton.icon(
    onPressed: _openPreview,
    icon: const Icon(Icons.visibility_rounded, size: 18),
    label: Text('Preview', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      side: const BorderSide(color: kPrimaryColor, width: 2),
      foregroundColor: kSecondaryColor,
    ),
  );

  Widget _buildPostButton(TextTheme tt) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [kSecondaryColor, kPrimaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(28),
      boxShadow: [BoxShadow(color: kSecondaryColor.withOpacity(0.40), blurRadius: 18, offset: const Offset(0, 8))],
    ),
    child: ElevatedButton.icon(
      onPressed: _isUploading ? null : _submitPost,
      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
      label: Text('Post to Halo', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        foregroundColor: Colors.white,
      ),
    ),
  );

  // ── Upload overlay ────────────────────────────────────────────────────
  Widget _buildUploadOverlay(TextTheme tt) => Positioned.fill(
    child: Container(
      color: Colors.black.withOpacity(0.65),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Animated progress ring
            SizedBox(
              width: 80, height: 80,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: _uploadProgress, strokeWidth: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(kPrimaryColor)),
                Text('${(_uploadProgress * 100).toInt()}%',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: kSecondaryColor)),
              ]),
            ),
            const SizedBox(height: 20),
            Text('Uploading…', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.black87)),
            const SizedBox(height: 8),
            Text(_uploadStatusMsg, style: tt.bodySmall?.copyWith(color: Colors.black54), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            // Per-file dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_media.length, (i) {
                final done = i < _currentUploadIdx;
                final active = i == _currentUploadIdx - 1 && !done;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 10, height: 10,
                  decoration: BoxDecoration(
                    color: done ? kPrimaryColor : (active ? kSecondaryColor : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(5),
                  ),
                );
              }),
            ),
          ]),
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════
//  _MediaThumbnail
// ══════════════════════════════════════════════════════════════════════════
class _MediaThumbnail extends StatelessWidget {
  final MediaItem item;
  final int index;
  final bool isFirst;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _MediaThumbnail({
    required this.item, required this.index, required this.isFirst,
    required this.onRemove, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isFirst ? 200 : 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isFirst ? Border.all(color: kPrimaryColor, width: 2.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(fit: StackFit.expand, children: [
            // thumbnail
            item.isVideo
                ? Container(
                    color: Colors.black87,
                    child: const Center(
                      child: Icon(
                        Icons.videocam_rounded,
                        color: Colors.white70,
                        size: 34,
                      ),
                    ),
                  )
                : Image.file(
                    File(item.file.path),
                    fit: BoxFit.cover,
                    cacheWidth: 600,
                    filterQuality: FilterQuality.low,
                  ),

            // video icon
            if (item.isVideo)
              const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40)),

            // Cover badge
            if (isFirst)
              Positioned(
                bottom: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: kSecondaryColor, borderRadius: BorderRadius.circular(8)),
                  child: Text('Cover', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),

            // Edit / tap hint
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 14),
              ),
            ),

            // Delete
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  _MediaViewerPage – full-screen preview & edit per media item
// ══════════════════════════════════════════════════════════════════════════
class _MediaViewerPage extends StatefulWidget {
  final List<MediaItem> media;
  final int initialIndex;
  const _MediaViewerPage({required this.media, required this.initialIndex});

  @override
  State<_MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<_MediaViewerPage> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _current);
    _pauseAllExcept(_current);
  }

  @override
  void dispose() {
    _pauseAllExcept(-1);
    _pageCtrl.dispose();
    super.dispose();
  }

  void _pauseAllExcept(int keepIndex) {
    for (int i = 0; i < widget.media.length; i++) {
      if (i == keepIndex) continue;
      final item = widget.media[i];
      if (item.isVideo) item.videoController?.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${_current + 1} / ${widget.media.length}',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.media.length,
        onPageChanged: (i) {
          _pauseAllExcept(i);
          setState(() => _current = i);
        },
        itemBuilder: (_, i) {
          final item = widget.media[i];
          if (item.isVideo && item.videoController != null && item.videoController!.value.isInitialized) {
            return Center(
              child: AspectRatio(
                aspectRatio: item.videoController!.value.aspectRatio,
                child: Stack(alignment: Alignment.center, children: [
                  VideoPlayer(item.videoController!),
                  GestureDetector(
                    onTap: () => setState(() =>
                    item.videoController!.value.isPlaying
                        ? item.videoController!.pause()
                        : item.videoController!.play()),
                    child: Icon(
                      item.videoController!.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      color: Colors.white.withOpacity(0.85), size: 64,
                    ),
                  ),
                ]),
              ),
            );
          }
          return InteractiveViewer(
            child: Center(
              child: Image.file(
                File(item.file.path),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.low,
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildDots(),
    );
  }

  Widget _buildDots() => Container(
    height: 40, color: Colors.black,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.media.length, (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: i == _current ? 20 : 8, height: 8,
        decoration: BoxDecoration(
          color: i == _current ? kPrimaryColor : Colors.white38,
          borderRadius: BorderRadius.circular(4),
        ),
      )),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════
//  _PostPreviewPage – full-screen Instagram-style preview with video support
// ══════════════════════════════════════════════════════════════════════════
class _PostPreviewPage extends StatefulWidget {
  final List<MediaItem> media;
  final String caption;
  final String location;
  final List<String> tags;
  final Future<void> Function() onPost;

  const _PostPreviewPage({
    required this.media,
    required this.caption,
    required this.location,
    required this.tags,
    required this.onPost,
  });

  @override
  State<_PostPreviewPage> createState() => _PostPreviewPageState();
}

class _PostPreviewPageState extends State<_PostPreviewPage> {
  int  _currentIndex = 0;
  bool _isPosting    = false;
  bool _isMuted      = false;
  bool _captionExpanded = false;

  late final PageController _pageCtrl;

  // Active video controller for the currently visible item
  VideoPlayerController? get _activeVideo {
    final item = widget.media[_currentIndex];
    return item.isVideo ? item.videoController : null;
  }

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    // Auto-play first video if present
    WidgetsBinding.instance.addPostFrameCallback((_) => _playCurrentVideo());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    // Pause all videos on exit (don't dispose — owner manages lifecycle)
    for (final m in widget.media) {
      m.videoController?.pause();
    }
    super.dispose();
  }

  void _playCurrentVideo() {
    final ctrl = _activeVideo;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    ctrl.setVolume(_isMuted ? 0 : 1);
    ctrl.play();
  }

  void _pauseVideo(int index) {
    final item = widget.media[index];
    if (item.isVideo) item.videoController?.pause();
  }

  void _onPageChanged(int i) {
    _pauseVideo(_currentIndex);
    setState(() => _currentIndex = i);
    _playCurrentVideo();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _activeVideo?.setVolume(_isMuted ? 0 : 1);
  }

  void _togglePlayPause() {
    final ctrl = _activeVideo;
    if (ctrl == null) return;
    setState(() {
      ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
    });
  }

  Future<void> _post() async {
    setState(() => _isPosting = true);
    await widget.onPost();
  }

  @override
  Widget build(BuildContext context) {
    final tt       = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);
    final size     = MediaQuery.of(context).size;
    final topPad   = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // ── Transparent app bar overlaid on media ──────────────────────
          SliverAppBar(
            expandedHeight: 0,
            pinned: true,
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Preview', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
            actions: [
              // Post now button in app bar
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _isPosting
                    ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white))),
                )
                    : TextButton(
                  onPressed: _post,
                  style: TextButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Share', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Post header (username + location) ──────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    const CircleAvatar(
                      backgroundImage: AssetImage('assets/images/Profile.png'),
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('You', style: tt.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                        if (widget.location.isNotEmpty)
                          Text(widget.location,
                              style: tt.bodySmall?.copyWith(color: Colors.white70, fontSize: 11)),
                      ]),
                    ),
                    const Icon(Icons.more_horiz_rounded, color: Colors.white),
                  ]),
                ),

                // ── Full-width media carousel ───────────────────────────
                if (widget.media.isNotEmpty)
                  SizedBox(
                    width: size.width,
                    height: size.width, // square like Instagram
                    child: Stack(
                      children: [
                        // PageView of images / videos
                        PageView.builder(
                          controller: _pageCtrl,
                          itemCount: widget.media.length,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (_, i) {
                            final item = widget.media[i];
                            if (item.isVideo) {
                              return _VideoPreviewItem(
                                item: item,
                                isCurrent: i == _currentIndex,
                                isMuted: _isMuted,
                                onTap: _togglePlayPause,
                              );
                            }
                            return Image.file(
                              File(item.file.path),
                              fit: BoxFit.cover,
                              width: size.width,
                              height: size.width,
                              cacheWidth: 1080,
                              filterQuality: FilterQuality.low,
                            );
                          },
                        ),

                        // Mute button (video only)
                        if (widget.media[_currentIndex].isVideo)
                          Positioned(
                            bottom: 12, right: 12,
                            child: GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: Icon(
                                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                  color: Colors.white, size: 20,
                                ),
                              ),
                            ),
                          ),

                        // Media index dots (top right, Instagram style)
                        if (widget.media.length > 1)
                          Positioned(
                            top: 12, right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                              child: Text('${_currentIndex + 1}/${widget.media.length}',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                      ],
                    ),
                  ),

                // ── Dots indicator ─────────────────────────────────────
                if (widget.media.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.media.length, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _currentIndex ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _currentIndex ? kPrimaryColor : Colors.white30,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )),
                    ),
                  ),

                // ── Action row ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(children: [
                    IconButton(icon: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 26), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 24), onPressed: () {}),
                    IconButton(icon: const Icon(Icons.send_outlined, color: Colors.white, size: 24), onPressed: () {}),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.bookmark_border_rounded, color: Colors.white, size: 26), onPressed: () {}),
                  ]),
                ),

                // ── Tags ───────────────────────────────────────────────
                if (widget.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Wrap(
                      spacing: 6, runSpacing: 4,
                      children: widget.tags.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kPrimaryColor.withOpacity(0.5)),
                        ),
                        child: Text(t, style: tt.bodySmall?.copyWith(color: kPrimaryColor, fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ),

                // ── Caption ────────────────────────────────────────────
                if (widget.caption.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _captionExpanded = !_captionExpanded),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: _buildRichCaption(widget.caption, tt, _captionExpanded),
                    ),
                  ),

                // ── Preview label ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Text('This is a preview — not posted yet',
                        style: tt.bodySmall?.copyWith(color: Colors.white38, fontSize: 11)),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Bottom edit / share buttons ────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: Text('Edit post', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [kSecondaryColor, kPrimaryColor],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [BoxShadow(color: kSecondaryColor.withOpacity(0.50), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isPosting ? null : _post,
                          icon: _isPosting
                              ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)))
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          label: Text(_isPosting ? 'Posting…' : 'Post to Halo',
                              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichCaption(String text, TextTheme tt, bool expanded) {
    final words = text.split(' ');
    final spans = words.map((w) => TextSpan(
      text: '$w ',
      style: (w.startsWith('@') && w.length > 1)
          ? tt.bodyMedium?.copyWith(color: kPrimaryColor, fontWeight: FontWeight.w700)
          : tt.bodyMedium?.copyWith(color: Colors.white),
    )).toList();

    if (expanded || text.length < 120) {
      return Text.rich(TextSpan(children: spans));
    }

    // Collapsed: show first ~100 chars + "more"
    final short = text.substring(0, 100);
    final shortWords = short.split(' ');
    final shortSpans = shortWords.map((w) => TextSpan(
      text: '$w ',
      style: (w.startsWith('@') && w.length > 1)
          ? tt.bodyMedium?.copyWith(color: kPrimaryColor, fontWeight: FontWeight.w700)
          : tt.bodyMedium?.copyWith(color: Colors.white),
    )).toList();

    return Text.rich(TextSpan(children: [
      ...shortSpans,
      TextSpan(
        text: '… more',
        style: tt.bodyMedium?.copyWith(color: Colors.white54, fontWeight: FontWeight.w600),
      ),
    ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  _VideoPreviewItem – handles video display + progress bar in preview
// ══════════════════════════════════════════════════════════════════════════
class _VideoPreviewItem extends StatefulWidget {
  final MediaItem item;
  final bool isCurrent;
  final bool isMuted;
  final VoidCallback onTap;

  const _VideoPreviewItem({
    required this.item,
    required this.isCurrent,
    required this.isMuted,
    required this.onTap,
  });

  @override
  State<_VideoPreviewItem> createState() => _VideoPreviewItemState();
}

class _VideoPreviewItemState extends State<_VideoPreviewItem> {
  VideoPlayerController? get _ctrl => widget.item.videoController;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _ctrl?.addListener(_onVideoUpdate);
    // Hide controls after 2s
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onVideoUpdate);
    super.dispose();
  }

  void _onVideoUpdate() {
    if (mounted) setState(() {});
  }

  void _onTap() {
    widget.onTap();
    setState(() => _showControls = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    final isReady = ctrl != null && ctrl.value.isInitialized;

    if (!isReady) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    final duration = ctrl.value.duration;
    final position = ctrl.value.position;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final isPlaying = ctrl.value.isPlaying;

    return GestureDetector(
      onTap: _onTap,
      child: Stack(fit: StackFit.expand, children: [
        // Video
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: ctrl.value.size.width,
            height: ctrl.value.size.height,
            child: VideoPlayer(ctrl),
          ),
        ),

        // Dark gradient overlay at bottom
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
          ),
        ),

        // Play / Pause overlay
        AnimatedOpacity(
          opacity: _showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white, size: 40,
              ),
            ),
          ),
        ),

        // Progress bar + time at bottom
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scrub bar
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2.5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: kPrimaryColor,
                  inactiveTrackColor: Colors.white30,
                  thumbColor: Colors.white,
                  overlayColor: kPrimaryColor.withOpacity(0.3),
                ),
                child: Slider(
                  value: progress,
                  onChanged: (v) {
                    final seekTo = Duration(milliseconds: (v * duration.inMilliseconds).toInt());
                    ctrl.seekTo(seekTo);
                  },
                ),
              ),
              // Time labels
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(children: [
                  Text(_formatDuration(position),
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                  const Spacer(),
                  Text(_formatDuration(duration),
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  _FullScreenCamera – full-screen camera modal
// ══════════════════════════════════════════════════════════════════════════
class _FullScreenCamera extends StatefulWidget {
  final List<CameraDescription> cameras;
  const _FullScreenCamera({required this.cameras});
  @override
  State<_FullScreenCamera> createState() => _FullScreenCameraState();
}

class _FullScreenCameraState extends State<_FullScreenCamera> {
  late CameraController _ctrl;
  int    _camIdx     = 0;
  bool   _ready      = false;
  bool   _recording  = false;
  bool   _isVideo    = false;

  @override
  void initState() {
    super.initState();
    _initCtrl(0);
  }

  Future<void> _initCtrl(int idx) async {
    setState(() => _ready = false);
    final ctrl = CameraController(widget.cameras[idx], ResolutionPreset.high, enableAudio: true);
    await ctrl.initialize();
    _ctrl = ctrl;
    if (mounted) setState(() { _camIdx = idx; _ready = true; });
  }

  Future<void> _flipCamera() async {
    final next = (_camIdx + 1) % widget.cameras.length;
    await _ctrl.dispose();
    _initCtrl(next);
  }

  Future<void> _capture() async {
    if (!_ready) return;
    if (_isVideo) {
      if (_recording) {
        final file = await _ctrl.stopVideoRecording();
        if (!mounted) return;
        Navigator.pop(context, file);
      } else {
        await _ctrl.startVideoRecording();
        setState(() => _recording = true);
      }
    } else {
      final photo = await _ctrl.takePicture();
      if (!mounted) return;
      Navigator.pop(context, photo);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          if (_ready) Positioned.fill(child: CameraPreview(_ctrl)),
          if (!_ready) const Center(child: CircularProgressIndicator(color: kPrimaryColor)),

          // Top bar
          Positioned(top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
              )),
              child: Row(children: [
                GestureDetector(onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white, size: 28)),
                const Spacer(),
                if (widget.cameras.length > 1)
                  GestureDetector(onTap: _flipCamera,
                      child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 28)),
              ]),
            ),
          ),

          // Bottom bar
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 32, top: 16),
              decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              )),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Photo / Video toggle
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _ModeButton(label: 'Photo', selected: !_isVideo, onTap: () => setState(() => _isVideo = false)),
                  const SizedBox(width: 24),
                  _ModeButton(label: 'Video', selected: _isVideo, onTap: () => setState(() => _isVideo = true)),
                ]),
                const SizedBox(height: 20),
                // Shutter
                GestureDetector(
                  onTap: _capture,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _recording ? Colors.red : Colors.white.withOpacity(0.9),
                    ),
                    child: _recording
                        ? const Icon(Icons.stop_rounded, color: Colors.white, size: 32)
                        : Icon(_isVideo ? Icons.videocam_rounded : Icons.camera_alt_rounded,
                        color: Colors.black87, size: 32),
                  ),
                ),
              ]),
            ),
          ),

          // Recording badge
          if (_recording)
            Positioned(top: 60, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('REC', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              )),
            ),
        ]),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Text(label, style: GoogleFonts.poppins(
        color: selected ? Colors.white : Colors.white60,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        fontSize: 14,
      )),
      const SizedBox(height: 4),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: selected ? 24 : 0, height: 2,
        decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(1)),
      ),
    ]),
  );
}
