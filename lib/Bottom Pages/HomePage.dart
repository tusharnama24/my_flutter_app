import 'package:classic_1/Bottom%20Pages/AddPostPage.dart';
import 'package:classic_1/Bottom%20Pages/ProfilePage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classic_1/chat/chat_list_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:classic_1/Wellness Bottom Pages/WellnessProfilePage.dart';
import 'package:classic_1/interest_selection_page.dart';
import 'ProfilePage.dart';
import 'MessagePage.dart';
import 'NotificationPage.dart';
import 'SearchPage.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _promptedLocation = false;
  List<String> _interests = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptForLocation();
    });
    _loadInterests();
  }

  Future<void> _loadInterests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final interests = prefs.getStringList('user_interests') ?? const [];
      if (!mounted) return;
      setState(() {
        _interests = interests;
      });
    } catch (_) {}
  }

  Future<void> _maybePromptForLocation() async {
    if (_promptedLocation) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested = prefs.getBool('location_prompt_shown') ?? false;
    if (alreadyRequested) return;

    // If already granted or restricted, skip prompt
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) {
      await prefs.setBool('location_prompt_shown', true);
      return;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Allow Location Access'),
          content: Text('Halo uses your location to enhance discovery and local features.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Not now'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final result = await Permission.locationWhenInUse.request();
                if (!mounted) return;
                if (result.isGranted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Location permission granted')),
                  );
                  await prefs.setBool('location_prompt_shown', true);
                } else if (result.isPermanentlyDenied) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Location permission permanently denied. Open settings to enable.'),
                      action: SnackBarAction(
                        label: 'Settings',
                        onPressed: openAppSettings,
                      ),
                    ),
                  );
                  await prefs.setBool('location_prompt_shown', true);
                }
              },
              child: Text('Allow'),
            ),
          ],
        );
      },
    );

    // Mark as shown even if dismissed, to avoid repeated prompts
    await prefs.setBool('location_prompt_shown', true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
    onHorizontalDragEnd: (details) {
      // Check the swipe direction
      if (details.velocity.pixelsPerSecond.dx < 0) {
        // Navigate to the next page when swiping right
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please sign in to use chat')),
          );
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ChatListPage(currentUserId: uid)),
        );
      }
    },
      child: Scaffold(
      appBar:PreferredSize(
        preferredSize: Size.fromHeight(45.0),
    child: AppBar(
      // backgroundColor: Colors.white,
          title: Text(
            'Halo',
            style: GoogleFonts.pacifico(
              fontSize: 23,
              fontWeight: FontWeight.w700,
             // color: Colors.black, // Changed text color to black for visibility
            ),
          ),
          //Image.asset('assets/Halo.png'), // Add Instagram-like logo here
        actions: [
          IconButton(
            tooltip: 'Edit interests',
            icon: const Icon(Icons.tune),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InterestSelectionPage(isFromSettings: true)),
              );
              if (!mounted) return;
              await _loadInterests();
            },
          ),
          IconButton(
            icon: Icon(Icons.forum,
              //  color: Colors.black
            ),
            onPressed: () {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please sign in to use chat')),
                );
                return;
              }
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatListPage(currentUserId: uid),
                ),
              );
            },
          ),
        ],
      ),
      ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Stories Section
              Container(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 10, // Number of stories
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: AssetImage('assets/Profile.png'), // Replace with story images
                          ),
                          SizedBox(height: 4),
                          Text(
                            'User $index',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Divider for separation
              //  Divider(thickness: 1, color: Colors.grey.shade300),

              // Posts Feed (Realtime)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error loading posts: ${snapshot.error}'),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  // Optional client-side filtering by interests if post has 'tags' array
                  // This keeps behavior unchanged when tags are absent
                  List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered = docs;
                  if (_interests.isNotEmpty) {
                    filtered = docs.where((d) {
                      final tags = (d.data()['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [];
                      if (tags.isEmpty) return true; // don't hide untagged content
                      return tags.any((t) => _interests.contains(t));
                    }).toList();
                  }
                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('No posts yet'),
                    );
                  }

                  return ListView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final data = filtered[index].data();
                      final media = (data['media'] as List?)?.cast<dynamic>() ?? const [];
                      final images = List<String>.from(data['images'] ?? const []);
                      final caption = (data['caption'] ?? '').toString();
                      final location = (data['location'] ?? '').toString();
                      final createdAt = data['createdAt'] as Timestamp?;
                      final createdText = createdAt != null
                          ? createdAt.toDate().toLocal().toString().substring(0,16)
                          : '';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header (placeholder user)
                          ListTile(
                            leading: CircleAvatar(
                              backgroundImage: AssetImage('assets/images/Profile.png'),
                            ),
                            title: Text(location.isNotEmpty ? location : 'Post'),
                            subtitle: Text(createdText),
                            trailing: Icon(Icons.more_vert),
                          ),

                          // Media rendering (image/video), fallback to images[] for legacy posts
                          if (media.isNotEmpty)
                            _PostMedia(media: media)
                          else if (images.isNotEmpty)
                            Image.network(
                              images.first,
                              height: 300,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, __) => Container(
                                height: 300,
                                color: Colors.grey[300],
                                child: Center(child: Icon(Icons.broken_image)),
                              ),
                            ),

                          // Actions (static)
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.favorite_border),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: Icon(Icons.message_outlined),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: Icon(Icons.share),
                                onPressed: () {},
                              ),
                              Spacer(),
                              IconButton(
                                icon: Icon(Icons.bookmark_border),
                                onPressed: () {},
                              ),
                            ],
                          ),

                          // Caption
                          if (caption.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text(caption, style: TextStyle(fontSize: 14)),
                            ),

                          SizedBox(height: 16),
                        ],
                      );
                    },
                  );
                },
              ),

              /*  // Posts Feed
            Expanded(
              child: ListView.builder(
                itemCount: 10, // Number of posts
                itemBuilder: (context, index) {
                  return PostWidget(index: index);
                },
              ),
            ),*/
            ],
          ),
        ),

        // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SearchPage()),
            );
          }
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddPostPage()),
            );
          }
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NotificationPage()),
            );
          }
          if (index == 4) {
            () async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please sign in to view profile')),
                );
                return;
              }
              try {
                final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                final accountType = doc.data()?['accountType']?.toString().toLowerCase() ?? 'aspirant';
                if (accountType == 'wellness') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WellnessProfilePage()),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfilePage()),
                  );
                }
              } catch (e) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfilePage()),
                );
              }
            }();
          }
        },

        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            label: 'Add Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              radius: 12,
              backgroundImage: AssetImage('assets/images/Profile.png'), // Replace with profile picture
            ),
            label: 'Profile',
          ),
        ],
      ),
      ),
    );
  }
}

class PostWidget extends StatelessWidget {
  final int index;

  const PostWidget({Key? key, required this.index}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post Header
        ListTile(
          leading: CircleAvatar(
            backgroundImage: AssetImage('assets/images/Profile.png'), // Replace with user profile image
          ),
          title: Text('User $index'),
          subtitle: Text('Location $index'),
          trailing: Icon(Icons.more_vert),
        ),

        // Post Image
        Image.asset(
          'assets/images/Halo.png', // Replace with post image
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
        ),

        // Post Actions
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.favorite_border),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.message_outlined),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.share),
              onPressed: () {},
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.bookmark_border),
              onPressed: () {},
            ),
          ],
        ),

        // Post Likes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Liked by 99 others',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        // Post Caption
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'User $index: This is a caption for post $index.',
            style: TextStyle(fontSize: 14),
          ),
        ),

        // View Comments
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'View all comments',
            style: TextStyle(color: Colors.grey),
          ),
        ),

        SizedBox(height: 16),
      ],
    );
  }
}

class _PostMedia extends StatefulWidget {
  final List<dynamic> media; // [{type: image|video, url: ...}, ...]

  const _PostMedia({Key? key, required this.media}) : super(key: key);

  @override
  State<_PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<_PostMedia> {
  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) return SizedBox.shrink();

    final first = Map<String, dynamic>.from(widget.media.first as Map);
    final type = (first['type'] ?? 'image').toString();
    final url = (first['url'] ?? '').toString();

    if (type == 'video') {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: _NetworkVideo(url: url),
      );
    }

    return Image.network(
      url,
      height: 300,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, _, __) => Container(
        height: 300,
        color: Colors.grey[300],
        child: Center(child: Icon(Icons.broken_image)),
      ),
    );
  }
}

class _NetworkVideo extends StatefulWidget {
  final String url;

  const _NetworkVideo({Key? key, required this.url}) : super(key: key);

  @override
  State<_NetworkVideo> createState() => _NetworkVideoState();
}

class _NetworkVideoState extends State<_NetworkVideo> {
  late final VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        color: Colors.black12,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        VideoPlayer(_controller),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}
