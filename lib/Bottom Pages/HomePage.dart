import 'package:classic_1/Bottom%20Pages/AddPostPage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classic_1/chat/chat_list_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:classic_1/Profile%20Pages/wellness_profile_page.dart'
as wellness_profile;
import 'package:classic_1/interest_selection_page.dart';

// ✅ NEW profile imports (aliased)
import 'package:classic_1/Profile%20Pages/aspirant_profile_page.dart'
as aspirant_profile;
import 'package:classic_1/Profile%20Pages/guru_profile_page.dart'
as guru_profile;

import 'NotificationPage.dart';
import 'SearchPage.dart';

// ---- THEME COLORS (matching LoginPage palette) ----
const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep purple
const Color kBackgroundColor = Color(0xFFF4F1FB); // Light lavender-gray

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {


  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
                    const SnackBar(
                        content: Text('Location permission granted')),
                  );
                  await prefs.setBool('location_prompt_shown', true);
                } else if (result.isPermanentlyDenied) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'Location permission permanently denied. Open settings to enable.'),
                      action: SnackBarAction(
                        label: 'Settings',
                        onPressed: openAppSettings,
                      ),
                    ),
                  );
                  await prefs.setBool('location_prompt_shown', true);
                }
              },
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );

    await prefs.setBool('location_prompt_shown', true);
  }

  void _onMenuAction(_HaloMenuAction action) {
    switch (action) {
      case _HaloMenuAction.home:
        return;
      case _HaloMenuAction.feed:
        _showFeaturePlaceholder('Feed');
        return;
      case _HaloMenuAction.premium:
        _showFeaturePlaceholder('Premium Content & Features');
        return;
      case _HaloMenuAction.wellness:
        _showFeaturePlaceholder('Wellness');
        return;
      case _HaloMenuAction.challenges:
        _showFeaturePlaceholder('Challenges');
        return;
      case _HaloMenuAction.profileSettings:
        _showFeaturePlaceholder('Profile Settings');
        return;
      case _HaloMenuAction.events:
        _showFeaturePlaceholder('Events');
        return;
      case _HaloMenuAction.analytics:
        _showFeaturePlaceholder('Analytics & Insight');
        return;
      case _HaloMenuAction.gurus:
        _showFeaturePlaceholder('Gurus');
        return;
      case _HaloMenuAction.logout:
        _showFeaturePlaceholder('Log Out');
        return;
      case _HaloMenuAction.email:
        _showFeaturePlaceholder('Email');
        return;
      case _HaloMenuAction.share:
        _showFeaturePlaceholder('Share');
        return;
      case _HaloMenuAction.customerCare:
        _showFeaturePlaceholder('Customer Care');
        return;
    }
  }

  void _showFeaturePlaceholder(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.velocity.pixelsPerSecond.dx < 0) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please sign in to use chat')),
              );
              return;
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => ChatListPage(currentUserId: uid)),
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
                  color: kSecondaryColor,
                ),
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
                          builder: (_) =>
                          const InterestSelectionPage(isFromSettings: true)),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please sign in to use chat')),
                      );
                      return;
                    }
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ChatListPage(currentUserId: uid),
                      ),
                    );
                  },
                ),
              ],
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF5EDFF),
                      Color(0xFFE8E4FF),
                    ],
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
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Column(
                  children: [
                    // Stories section
                    _StoriesStrip(),
                    const SizedBox(height: 4),

                    // Posts feed
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                                'Error loading posts: ${snapshot.error}'),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>
                        filtered = docs;

                        if (_interests.isNotEmpty) {
                          filtered = docs.where((d) {
                            final tags = (d.data()['tags'] as List?)
                                ?.map((e) => e.toString())
                                .toList() ??
                                const [];
                            if (tags.isEmpty) return true;
                            return tags.any((t) => _interests.contains(t));
                          }).toList();
                        }

                        if (filtered.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 40, color: Colors.grey.shade500),
                                const SizedBox(height: 8),
                                Text(
                                  'No posts yet',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Follow more people or add your first post.',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final data = filtered[index].data();
                            final media =
                                (data['media'] as List?)?.cast<dynamic>() ??
                                    const [];
                            final images = List<String>.from(
                                data['images'] ?? const []);
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

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4.0, vertical: 6.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 24,
                                      spreadRadius: -12,
                                      offset: const Offset(0, 16),
                                      color: Colors.black.withOpacity(0.08),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      // Header
                                      ListTile(
                                        contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 4),
                                        leading: CircleAvatar(
                                          backgroundImage:
                                          const AssetImage(
                                              'assets/images/Profile.png'),
                                          radius: 20,
                                        ),
                                        title: Text(
                                          location.isNotEmpty
                                              ? location
                                              : 'Post',
                                          style: textTheme.labelLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          createdText,
                                          style: textTheme.bodySmall
                                              ?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                              Icons.more_horiz_rounded),
                                          onPressed: () {},
                                        ),
                                      ),

                                      // Media
                                      if (media.isNotEmpty)
                                        _PostMedia(media: media)
                                      else if (images.isNotEmpty)
                                        ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(18),
                                          child: Image.network(
                                            images.first,
                                            height: 300,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, _, __) =>
                                                Container(
                                                  height: 300,
                                                  color: Colors.grey[300],
                                                  child: const Center(
                                                      child: Icon(
                                                          Icons.broken_image)),
                                                ),
                                          ),
                                        ),

                                      // Actions
                                      _PostActions(
                                        postId: filtered[index].id,
                                        postData: data,
                                      ),

                                      // Caption
                                      if (caption.isNotEmpty)
                                        Padding(
                                          padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                              vertical: 8.0),
                                          child: Text(
                                            caption,
                                            style:
                                            textTheme.bodyMedium?.copyWith(
                                              color: Colors.grey.shade900,
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
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Navigation Bar
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 12,
            selectedItemColor: kSecondaryColor,
            unselectedItemColor: Colors.grey.shade500,
            showUnselectedLabels: true,
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
                  MaterialPageRoute(
                      builder: (context) => NotificationPage()),
                );
              }
              if (index == 4) {
                () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                          Text('Please sign in to view profile')),
                    );
                    return;
                  }
                  try {
                    final doc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .get();
                    final accountType = doc
                        .data()?['accountType']
                        ?.toString()
                        .toLowerCase() ??
                        'aspirant';

                    if (accountType == 'wellness') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              wellness_profile.WellnessProfilePage(
                                  profileUserId: uid),
                        ),
                      );
                    } else if (accountType == 'guru') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              guru_profile.GuruProfilePage(
                                profileUserId: uid,
                              ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              aspirant_profile.ProfilePage(
                                profileUserId: uid,
                              ),
                        ),
                      );
                    }
                  } catch (e) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => aspirant_profile.ProfilePage(
                          profileUserId: uid,
                        ),
                      ),
                    );
                  }
                }();
              }
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_box_outlined),
                label: 'Add Post',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_outline_rounded),
                label: 'Notifications',
              ),
              BottomNavigationBarItem(
                icon: CircleAvatar(
                  radius: 12,
                  backgroundImage:
                  AssetImage('assets/images/Profile.png'),
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------- Stories Strip ----------------------

class _StoriesStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              Text(
                'Stories',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const Spacer(),
              Text(
                'See all',
                style: textTheme.bodySmall?.copyWith(
                  color: kSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 10,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (context, index) {
              return Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            kPrimaryColor,
                            kSecondaryColor,
                          ],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 26,
                          backgroundImage:
                          const AssetImage('assets/Profile.png'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'User $index',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Colors.grey.shade800,
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
}

// ---------------------- Drawer -----------------------------

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

  const _DrawerItemData({
    required this.icon,
    required this.label,
    required this.action,
  });
}

class _HaloDrawer extends StatelessWidget {
  final ValueChanged<_HaloMenuAction> onSelect;

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
          icon: Icons.public, label: 'Events', action: _HaloMenuAction.events),
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

    final headerTextStyle = GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: kSecondaryColor,
    );

    return Drawer(
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF3EDFF),
                Color(0xFFE5E0FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Row(
                  children: [
                    Text('MENU', style: headerTextStyle),
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24.0),
                  children: [
                    ...primaryItems.map(
                          (item) => _HaloDrawerTile(
                        data: item,
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelect(item.action);
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Divider(thickness: 1.0),
                    ),
                    ...secondaryItems.map(
                          (item) => _HaloDrawerTile(
                        data: item,
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelect(item.action);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                child: Text(
                  'Version 1.013',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
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

  const _HaloDrawerTile({
    Key? key,
    required this.data,
    required this.onTap,
  }) : super(key: key);

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
              child: Icon(
                data.icon,
                color: kSecondaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                data.label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------- Old PostWidget (still available) -------------------

class PostWidget extends StatelessWidget {
  final int index;

  const PostWidget({Key? key, required this.index}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const CircleAvatar(
            backgroundImage: AssetImage('assets/images/Profile.png'),
          ),
          title: Text('User $index'),
          subtitle: Text('Location $index'),
          trailing: const Icon(Icons.more_vert),
        ),
        Image.asset(
          'assets/images/Halo.png',
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.message_outlined),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {},
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              onPressed: () {},
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Liked by 99 others',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'User: This is a caption for the post.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'View all comments',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ---------------------- Post Media --------------------------

class _PostMedia extends StatefulWidget {
  final List<dynamic> media; // [{type: image|video, url: ...}, ...]

  const _PostMedia({Key? key, required this.media}) : super(key: key);

  @override
  State<_PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<_PostMedia> {
  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) return const SizedBox.shrink();

    final first =
    Map<String, dynamic>.from(widget.media.first as Map);
    final type = (first['type'] ?? 'image').toString();
    final url = (first['url'] ?? '').toString();

    if (type == 'video') {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: _NetworkVideo(url: url),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url,
        height: 300,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) => Container(
          height: 300,
          color: Colors.grey[300],
          child: const Center(child: Icon(Icons.broken_image)),
        ),
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
              icon: Icon(
                _controller.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------- Post Actions ------------------------

class _PostActions extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const _PostActions({
    Key? key,
    required this.postId,
    required this.postData,
  }) : super(key: key);

  @override
  State<_PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<_PostActions> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _toggleLike() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like posts')),
      );
      return;
    }

    try {
      final likeRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('likes')
          .doc(_currentUserId!);

      final likeDoc = await likeRef.get();
      if (likeDoc.exists) {
        await likeRef.delete();
      } else {
        await likeRef.set({
          'userId': _currentUserId,
          'likedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating like: $e')),
      );
    }
  }

  void _showComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CommentsPage(
          postId: widget.postId,
          postData: widget.postData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _currentUserId != null
                  ? FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('likes')
                  .doc(_currentUserId!)
                  .snapshots()
                  : const Stream.empty(),
              builder: (context, likeSnapshot) {
                final isLiked =
                    likeSnapshot.hasData && likeSnapshot.data!.exists;
                return IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.black,
                  ),
                  onPressed: _toggleLike,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.message_outlined),
              onPressed: _showComments,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Share functionality coming soon!')),
                );
              },
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Save functionality coming soon!')),
                );
              },
            ),
          ],
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .collection('likes')
              .snapshots(),
          builder: (context, likeCountSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .snapshots(),
              builder: (context, commentCountSnapshot) {
                final likeCount =
                    likeCountSnapshot.data?.docs.length ?? 0;
                final commentCount =
                    commentCountSnapshot.data?.docs.length ?? 0;

                if (likeCount == 0 && commentCount == 0) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4),
                  child: Row(
                    children: [
                      if (likeCount > 0)
                        Text(
                          '$likeCount ${likeCount == 1 ? 'like' : 'likes'}',
                          style:
                          const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      if (likeCount > 0 && commentCount > 0)
                        const SizedBox(width: 16),
                      if (commentCount > 0)
                        Text(
                          '$commentCount ${commentCount == 1 ? 'comment' : 'comments'}',
                          style:
                          const TextStyle(fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ---------------------- Comments Page -----------------------

class _CommentsPage extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const _CommentsPage({
    Key? key,
    required this.postId,
    required this.postData,
  }) : super(key: key);

  @override
  State<_CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<_CommentsPage> {
  final TextEditingController _commentController =
  TextEditingController();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _addComment() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'userId': _currentUserId,
        'text': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comments'),
          backgroundColor: kSecondaryColor,
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy('createdAt', descending: true)
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
                      child: Text(
                        'No comments yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index].data();
                      return ListTile(
                        title: Text(comment['text'] ?? ''),
                        subtitle: Text(
                          comment['createdAt'] != null
                              ? (comment['createdAt'] as Timestamp)
                              .toDate()
                              .toString()
                              .substring(0, 16)
                              : '',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _addComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
