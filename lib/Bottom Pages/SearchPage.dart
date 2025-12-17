// searchpage.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ✅ NEW profile imports (same pattern as HomePage)
import 'package:classic_1/Profile%20Pages/aspirant_profile_page.dart'
as aspirant_profile;
import 'package:classic_1/Profile%20Pages/guru_profile_page.dart'
as guru_profile;
import 'package:classic_1/Profile%20Pages/wellness_profile_page.dart'
as wellness_profile;

// ------- THEME CONSTANTS (MATCHING YOUR DESIGN SYSTEM) -------

const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep Purple
const Color kBackgroundColor = Color(0xFFF4F1FB); // Light lavender-gray

// ------- MODEL FOR UI CATEGORIES (STATIC) -------

class WellnessCategory {
  final String name;
  final String emoji;
  final String subtitle;
  final Color backgroundColor;
  final Color accentColor;
  final List<String> subcategories;
  final String? backgroundImage;

  const WellnessCategory({
    required this.name,
    required this.emoji,
    required this.subtitle,
    required this.backgroundColor,
    required this.accentColor,
    required this.subcategories,
    this.backgroundImage,
  });
}

// Updated categories
const List<WellnessCategory> _allCategories = [
  WellnessCategory(
    name: 'Physical Fitness',
    emoji: '💪',
    subtitle: '9 specializations',
    backgroundColor: Color(0xFFE9E0FA),
    accentColor: kSecondaryColor,
    backgroundImage: 'assets/categories/physical_fitness.jpg',
    subcategories: [
      'fitness',
      'strength training',
      'cardio',
      'hiit',
      'running',
      'gym',
      'mobility',
      'pilates',
      'bodyweight',
    ],
  ),
  WellnessCategory(
    name: 'Nutrition & Diet',
    emoji: '🥗',
    subtitle: '6 specializations',
    backgroundColor: Color(0xFFF1E8FF),
    accentColor: kPrimaryColor,
    backgroundImage: 'assets/categories/nutrition_diet.jpg',
    subcategories: [
      'nutrition',
      'diet',
      'weight loss',
      'supplements',
      'meal plan',
      'healthy eating',
    ],
  ),
  WellnessCategory(
    name: 'Mind & Body Wellness',
    emoji: '🧘',
    subtitle: '5 specializations',
    backgroundColor: Color(0xFFF6F0FF),
    accentColor: kSecondaryColor,
    backgroundImage: 'assets/categories/mind_body.jpg',
    subcategories: [
      'yoga',
      'meditation',
      'mindfulness',
      'stress management',
      'sleep',
    ],
  ),
  WellnessCategory(
    name: 'Rehabilitation & Recovery',
    emoji: '🏥',
    subtitle: '5 specializations',
    backgroundColor: Color(0xFFEDE4FF),
    accentColor: kPrimaryColor,
    backgroundImage: 'assets/categories/rehab_recovery.jpg',
    subcategories: [
      'physiotherapy',
      'rehab',
      'injury recovery',
      'post surgery',
      'pain relief',
    ],
  ),
  WellnessCategory(
    name: 'Lifestyle & General Wellness',
    emoji: '✨',
    subtitle: '5 specializations',
    backgroundColor: Color(0xFFF9F4FF),
    accentColor: kSecondaryColor,
    backgroundImage: 'assets/categories/lifestyle_wellness.jpg',
    subcategories: [
      'lifestyle',
      'habit',
      'self care',
      'productivity',
      'wellness',
    ],
  ),
  WellnessCategory(
    name: 'Goals',
    emoji: '🎯',
    subtitle: '7 specializations',
    backgroundColor: Color(0xFFE2D6FF),
    accentColor: kPrimaryColor,
    backgroundImage: 'assets/categories/goals.jpg',
    subcategories: [
      'weight loss goal',
      'muscle gain goal',
      'challenge',
      'marathon',
      'transformation',
      'coaching',
      'accountability',
    ],
  ),
];

// ---------- COMMON PAGE TRANSITION ----------

Route _buildPageRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, animation, __) => page,
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final offsetAnim = Tween<Offset>(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: offsetAnim, child: child),
      );
    },
  );
}

// ---------- COMMON PROFILE OPEN HELPER ----------

Future<void> openUserProfile(BuildContext context, String userId) async {
  try {
    final doc =
    await FirebaseFirestore.instance.collection('users').doc(userId).get();

    final accountType =
        doc.data()?['accountType']?.toString().toLowerCase() ?? 'aspirant';

    Widget page;

    if (accountType == 'wellness') {
      page = wellness_profile.WellnessProfilePage(profileUserId: userId);
    } else if (accountType == 'guru') {
      page = guru_profile.GuruProfilePage(profileUserId: userId);
    } else {
      page = aspirant_profile.ProfilePage(profileUserId: userId);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  } catch (e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => aspirant_profile.ProfilePage(profileUserId: userId),
      ),
    );
  }
}

// ---------- SEARCH PAGE ----------

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WellnessCategory> get _filteredCategories {
    if (_query.trim().isEmpty) return _allCategories;
    final q = _query.toLowerCase();
    return _allCategories
        .where((c) =>
    c.name.toLowerCase().contains(q) ||
        c.subtitle.toLowerCase().contains(q))
        .toList();
  }

  // Build user search results widget
  Widget _buildUserSearchResults() {
    if (_query.trim().isEmpty) return const SizedBox.shrink();

    final searchQuery = _query.trim().toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      stream:
      FirebaseFirestore.instance.collection('users').limit(20).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final allUsers = snapshot.data!.docs;
        final filteredUsers = allUsers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final username =
          (data['username'] ?? '').toString().toLowerCase();
          final name = (data['name'] ??
              data['full_name'] ??
              data['business_name'] ??
              '')
              .toString()
              .toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();

          return username.contains(searchQuery) ||
              name.contains(searchQuery) ||
              email.contains(searchQuery);
        }).toList();

        if (filteredUsers.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No users found matching "$_query"',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Users (${filteredUsers.length})',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),
            ...filteredUsers.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final userId = doc.id;
              final username = data['username'] ?? '';
              final name = data['name'] ??
                  data['full_name'] ??
                  data['business_name'] ??
                  'Unnamed User';
              final profilePhoto = data['profilePhoto'] as String?;
              final accountType =
              (data['accountType'] ?? '').toString().toLowerCase();

              return _UserSearchResultCard(
                userId: userId,
                username: username.toString(),
                name: name.toString(),
                profilePhoto: profilePhoto,
                accountType: accountType,
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      // ❌ No AppBar → black bar gone
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kBackgroundColor, Color(0xFFE9E2F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 2;
              if (constraints.maxWidth >= 900) crossAxisCount = 3;
              if (constraints.maxWidth >= 1200) crossAxisCount = 4;

              final categories = _filteredCategories;

              return SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 🔙 Custom back row instead of AppBar
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: kSecondaryColor),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Search',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: kSecondaryColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 🧾 Main title (kept, looks good)
                    Text(
                      'Discover Your Wellness Journey',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 30,
                        letterSpacing: 0.15,
                        color: const Color(0xFF1F1033),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Connect with expert trainers, nutritionists, and wellness professionals\ntailored to your goals',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 26),

                    // 🔍 Search bar
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _query = val),
                        style: textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF1F1033),
                        ),
                        decoration: InputDecoration(
                          hintText:
                          'Search experts by name, username, or expertise...',
                          hintStyle: textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: kSecondaryColor),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 18, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // User search results section
                    if (_query.trim().isNotEmpty) ...[
                      _buildUserSearchResults(),
                      const SizedBox(height: 20),
                      Divider(
                        color: Colors.grey.shade300,
                        thickness: 1,
                      ),
                      const SizedBox(height: 14),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _query.trim().isEmpty
                              ? 'Browse by category'
                              : 'Categories',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        Text(
                          '${categories.length} categories',
                          style: textTheme.labelMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // GRID VIEW
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: GridView.builder(
                        key: ValueKey(
                            'grid_${categories.length}_${_query.trim()}'),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: categories.length,
                        gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.0,
                        ),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return _CategoryCard(
                            category: category,
                            onTap: () {
                              Navigator.of(context).push(
                                _buildPageRoute(
                                  SubCategoryPage(category: category),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ------- CATEGORY CARD -------

class _CategoryCard extends StatefulWidget {
  final WellnessCategory category;
  final VoidCallback onTap;

  const _CategoryCard({
    Key? key,
    required this.category,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  void _setHovered(bool value) {
    if (_isHovered == value) return;
    setState(() => _isHovered = value);
  }

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final active = _isHovered || _isPressed;
    final scale = active ? 1.03 : 1.0;

    final shadow = [
      BoxShadow(
        blurRadius: active ? 24 : 10,
        spreadRadius: active ? -4 : -6,
        offset: Offset(0, active ? 16 : 8),
        color: Colors.black.withOpacity(active ? 0.16 : 0.08),
      ),
    ];

    final textTheme = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: widget.category.backgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: shadow,
            image: widget.category.backgroundImage != null
                ? DecorationImage(
              image: AssetImage(widget.category.backgroundImage!),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.12),
                BlendMode.darken,
              ),
            )
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: widget.onTap,
              onTapDown: (_) => _setPressed(true),
              onTapCancel: () => _setPressed(false),
              onTapUp: (_) => _setPressed(false),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.category.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.category.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F1033),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.category.subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- SUBCATEGORY PAGE ----------

class SubCategoryPage extends StatelessWidget {
  final WellnessCategory category;

  const SubCategoryPage({Key? key, required this.category}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final subs = category.subcategories;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          category.name,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F1033),
          ),
        ),
        backgroundColor: category.backgroundColor,
        foregroundColor: const Color(0xFF1F1033),
        elevation: 0,
      ),
      backgroundColor: kBackgroundColor,
      body: subs.isEmpty
          ? Center(
        child: Text(
          'No subcategories configured for this category.',
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: subs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final sub = subs[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              leading: Text(
                category.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(
                sub,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F1033),
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: kSecondaryColor,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExpertsListPage(
                      subcategory: sub,
                      emoji: category.emoji,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------- USER SEARCH RESULT CARD ----------

class _UserSearchResultCard extends StatelessWidget {
  final String userId;
  final String username;
  final String name;
  final String? profilePhoto;
  final String accountType;

  const _UserSearchResultCard({
    Key? key,
    required this.userId,
    required this.username,
    required this.name,
    this.profilePhoto,
    required this.accountType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            spreadRadius: -2,
            offset: const Offset(0, 2),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => openUserProfile(context, userId),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: kPrimaryColor.withOpacity(0.1),
                  backgroundImage: profilePhoto != null &&
                      profilePhoto!.isNotEmpty
                      ? NetworkImage(profilePhoto!)
                      : null,
                  child: profilePhoto == null || profilePhoto!.isEmpty
                      ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: kSecondaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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
                        name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F1033),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (username.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@$username',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- EXPERTS PAGE (same as your previous simple version) ----------

class ExpertsListPage extends StatelessWidget {
  final String subcategory;
  final String emoji;

  const ExpertsListPage({
    Key? key,
    required this.subcategory,
    required this.emoji,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('users')
        .where('interests', arrayContains: subcategory.toLowerCase());

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          subcategory,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F1033),
          ),
        ),
        backgroundColor: kBackgroundColor,
        foregroundColor: const Color(0xFF1F1033),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No experts found.',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final userId = doc.id;
              final name = data['business_name'] ?? 'Unnamed';
              final username = data['username'] ?? '';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: kPrimaryColor.withOpacity(0.12),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                title: Text(name),
                subtitle: Text(username),
                onTap: () => openUserProfile(context, userId),
              );
            },
          );
        },
      ),
    );
  }
}
