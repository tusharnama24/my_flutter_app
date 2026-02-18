// searchpage.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ✅ NEW profile imports (same pattern as HomePage)
import 'package:halo/Profile%20Pages/aspirant_profile_page.dart'
as aspirant_profile;
import 'package:halo/Profile%20Pages/guru_profile_page.dart'
as guru_profile;
import 'package:halo/Profile%20Pages/wellness_profile_page.dart'
as wellness_profile;

// ------- THEME CONSTANTS (MATCHING YOUR DESIGN SYSTEM) -------

const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep Purple
const Color kBackgroundColor = Color(0xFFF4F1FB); // Light lavender-gray

// ------- MODEL FOR UI CATEGORIES (STATIC) -------
// Subcategories align with user interests (aspirants) and areas_of_specialization (gurus)
// so that browsing by category shows all people with that specialization.
// TODO: Consider loading from Firestore/Remote Config for admin control and localization.

/// One subcategory shown in the list. [interestTerm] matches Firestore `interests` (aspirants);
/// [specializationTerm] matches Firestore `areas_of_specialization` (gurus).
class SubcategorySpec {
  final String displayName;
  final String? interestTerm;      // e.g. 'yoga' for interests array (lowercase)
  final String? specializationTerm; // e.g. 'Yoga & Breathwork' for areas_of_specialization

  const SubcategorySpec({
    required this.displayName,
    this.interestTerm,
    this.specializationTerm,
  });
}

class WellnessCategory {
  final String name;
  final String emoji;
  final String subtitle;
  final Color backgroundColor;
  final Color accentColor;
  final List<SubcategorySpec> subcategorySpecs;
  final String? backgroundImage;

  const WellnessCategory({
    required this.name,
    required this.emoji,
    required this.subtitle,
    required this.backgroundColor,
    required this.accentColor,
    required this.subcategorySpecs,
    this.backgroundImage,
  });

  List<String> get subcategories =>
      subcategorySpecs.map((s) => s.displayName).toList();
}

// Categories aligned with guru areas_of_specialization + aspirant interests so
// browsing by category shows all users (gurus, wellness, aspirants) with that specialization.
const List<WellnessCategory> _allCategories = [
  WellnessCategory(
    name: 'Physical Fitness',
    emoji: '💪',
    subtitle: '10 specializations',
    backgroundColor: Color(0xFFE9E0FA),
    accentColor: kSecondaryColor,
    backgroundImage: 'assets/categories/physical_fitness.jpg',
    subcategorySpecs: [
      SubcategorySpec(displayName: 'Fitness', interestTerm: 'fitness', specializationTerm: 'General Fitness'),
      SubcategorySpec(displayName: 'Strength Training', specializationTerm: 'Strength Training'),
      SubcategorySpec(displayName: 'Functional Training', specializationTerm: 'Functional Training'),
      SubcategorySpec(displayName: 'CrossFit', specializationTerm: 'CrossFit'),
      SubcategorySpec(displayName: 'Calisthenics', specializationTerm: 'Calisthenics'),
      SubcategorySpec(displayName: 'Bodybuilding', specializationTerm: 'Bodybuilding'),
      SubcategorySpec(displayName: 'Posture Correction', specializationTerm: 'Posture Correction'),
      SubcategorySpec(displayName: 'Flexibility & Mobility', specializationTerm: 'Flexibility & Mobility'),
      SubcategorySpec(displayName: 'Sports Performance', specializationTerm: 'Sports Performance'),
      SubcategorySpec(displayName: 'Injury Prevention', specializationTerm: 'Injury Prevention'),
    ],
  ),
  WellnessCategory(
    name: 'Nutrition & Diet',
    emoji: '🥗',
    subtitle: '4 specializations',
    backgroundColor: Color(0xFFF1E8FF),
    accentColor: kPrimaryColor,
    backgroundImage: 'assets/categories/nutrition_diet.jpg',
    subcategorySpecs: [
      SubcategorySpec(displayName: 'Nutrition', interestTerm: 'nutrition', specializationTerm: 'Nutrition Planning'),
      SubcategorySpec(displayName: 'Weight Loss', specializationTerm: 'Weight Loss'),
      SubcategorySpec(displayName: 'Muscle Gain', specializationTerm: 'Muscle Gain'),
      SubcategorySpec(displayName: 'Diet', specializationTerm: 'Nutrition Planning'),
    ],
  ),
  WellnessCategory(
    name: 'Mind & Body Wellness',
    emoji: '🧘',
    subtitle: '5 specializations',
    backgroundColor: Color(0xFFF6F0FF),
    accentColor: kSecondaryColor,
    backgroundImage: 'assets/categories/mind_body.jpg',
    subcategorySpecs: [
      SubcategorySpec(displayName: 'Yoga', interestTerm: 'yoga', specializationTerm: 'Yoga & Breathwork'),
      SubcategorySpec(displayName: 'Mental Health', interestTerm: 'mental_health'),
      SubcategorySpec(displayName: 'Stress Management', specializationTerm: 'Stress Management'),
      SubcategorySpec(displayName: 'Mindfulness / Meditation', interestTerm: 'mental_health'),
      SubcategorySpec(displayName: 'Holistic Wellness', specializationTerm: 'Holistic Wellness'),
    ],
  ),
  WellnessCategory(
    name: 'Rehabilitation & Recovery',
    emoji: '🏥',
    subtitle: '4 specializations',
    backgroundColor: Color(0xFFEDE4FF),
    accentColor: kPrimaryColor,
    backgroundImage: 'assets/categories/rehab_recovery.jpg',
    subcategorySpecs: [
      SubcategorySpec(displayName: 'Rehab & Recovery', specializationTerm: 'Rehab & Recovery'),
      SubcategorySpec(displayName: 'Pain Management', specializationTerm: 'Pain Management'),
      SubcategorySpec(displayName: 'Injury Prevention', specializationTerm: 'Injury Prevention'),
      SubcategorySpec(displayName: 'Posture Correction', specializationTerm: 'Posture Correction'),
    ],
  ),
  WellnessCategory(
    name: 'Lifestyle & General',
    emoji: '✨',
    subtitle: '4 specializations',
    backgroundColor: Color(0xFFF9F4FF),
    accentColor: kSecondaryColor,
    backgroundImage: 'assets/categories/lifestyle_wellness.jpg',
    subcategorySpecs: [
      SubcategorySpec(displayName: 'Productivity', interestTerm: 'productivity'),
      SubcategorySpec(displayName: 'Wellness Coach', specializationTerm: 'Wellness Coach'),
      SubcategorySpec(displayName: 'Mobility Specialist', specializationTerm: 'Mobility Specialist'),
      SubcategorySpec(displayName: 'Personal Trainer', specializationTerm: 'Personal Trainer'),
    ],
  ),
  WellnessCategory(
    name: 'Other Interests',
    emoji: '🎯',
    subtitle: '4 specializations',
    backgroundColor: Color(0xFFE2D6FF),
    accentColor: kPrimaryColor,
    backgroundImage: 'assets/categories/goals.jpg',
    subcategorySpecs: [
      SubcategorySpec(displayName: 'Music', interestTerm: 'music'),
      SubcategorySpec(displayName: 'Reading', interestTerm: 'reading'),
      SubcategorySpec(displayName: 'Travel', interestTerm: 'travel'),
      SubcategorySpec(displayName: 'Other', specializationTerm: 'Other'),
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
// Pass [knownAccountType] from search/list to avoid duplicate Firestore read.

Future<void> openUserProfile(
  BuildContext context,
  String userId, {
  String? knownAccountType,
}) async {
  String accountType = (knownAccountType ?? '').trim().toLowerCase();
  if (accountType.isEmpty) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      accountType =
          _safeString(doc.data()?['accountType']).toLowerCase();
      if (accountType.isEmpty) accountType = 'aspirant';
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('openUserProfile: failed to load user $userId: $e');
        debugPrint(stack.toString());
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not load profile. Opening default view.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => aspirant_profile.ProfilePage(profileUserId: userId),
          ),
        );
      }
      return;
    }
  }

  if (!context.mounted) return;
  Widget page;
  if (accountType == 'wellness') {
    page = wellness_profile.WellnessProfilePage(profileUserId: userId);
  } else if (accountType == 'guru') {
    page = guru_profile.GuruProfilePage(profileUserId: userId);
  } else {
    page = aspirant_profile.ProfilePage(profileUserId: userId);
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

// Safe read helpers to avoid schema assumptions and wrong types.
String _safeString(dynamic v) {
  if (v == null) return '';
  if (v is String) return v.trim();
  return v.toString().trim();
}

List<String> _safeStringList(dynamic v) {
  if (v == null) return [];
  if (v is List) {
    return v.map((e) => _safeString(e)).where((s) => s.isNotEmpty).toList();
  }
  return [];
}

// ---------- SEARCH PAGE ----------

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _debounceMs = 400;
  static const _minQueryLength = 2;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _debouncedQuery = '';
  Timer? _debounceTimer;
  List<QueryDocumentSnapshot>? _cachedUserDocs;
  String? _cachedQueryFor;
  bool _userSearchLoading = false;
  Object? _userSearchError;
  /// True when last fetch used client-side filter (first 100) instead of prefix query.
  bool _usedFallbackSearch = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() => _query = val);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: _debounceMs), () {
      if (!mounted) return;
      final trimmed = val.trim();
      setState(() {
        _debouncedQuery = trimmed;
        if (trimmed.length < _minQueryLength) {
          _cachedUserDocs = null;
          _cachedQueryFor = null;
          _userSearchError = null;
          _userSearchLoading = false;
          _usedFallbackSearch = false;
        } else {
          _userSearchLoading = _cachedQueryFor != trimmed;
        }
      });
      if (trimmed.length >= _minQueryLength) _fetchUsersOnce(trimmed);
    });
  }

  /// Force refetch for current query (avoids stale cache).
  void _refreshUserSearch() {
    if (_debouncedQuery.length < _minQueryLength) return;
    setState(() {
      _cachedQueryFor = null;
      _cachedUserDocs = null;
      _userSearchLoading = true;
      _userSearchError = null;
    });
    _fetchUsersOnce(_debouncedQuery);
  }

  /// Fetches users: tries server-side prefix query on [searchTerms] first
  /// (requires Firestore index: collection users, field searchTerms Ascending).
  /// Falls back to client-side filter on first 100 if index/field missing.
  Future<void> _fetchUsersOnce(String searchQuery) async {
    final searchLower = searchQuery.trim().toLowerCase();
    if (searchLower.isEmpty) return;
    // Skip if we already have a fresh cache for this exact query (unless refresh was requested).
    if (_cachedQueryFor == searchQuery && _cachedUserDocs != null && !_userSearchLoading) {
      return;
    }
    setState(() {
      _userSearchError = null;
      _userSearchLoading = true;
    });

    const limit = 50;
    List<QueryDocumentSnapshot>? docs;
    bool usedPrefixQuery = false;

    // 1) Try server-side prefix query (correct & scalable when searchTerms exists + index).
    try {
      final prefixSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('searchTerms')
          .startAt([searchLower])
          .endAt([searchLower + '\uf8ff'])
          .limit(limit)
          .get();
      // If prefix returns 0 docs (e.g. no users have searchTerms yet), use fallback so search still works.
      if (prefixSnapshot.docs.isNotEmpty) {
        docs = prefixSnapshot.docs;
        usedPrefixQuery = true;
      }
    } catch (_) {
      // Index or field missing → fall back to client-side.
    }

    // 2) Fallback: first N docs, filter client-side (limited correctness).
    if (docs == null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .limit(100)
            .get();
        docs = snapshot.docs;
      } catch (e, stack) {
        if (kDebugMode) {
          debugPrint('SearchPage user fetch failed: $e');
          debugPrint(stack.toString());
        }
        if (!mounted) return;
        setState(() {
          _userSearchLoading = false;
          _userSearchError = e;
          _cachedUserDocs = null;
          _cachedQueryFor = null;
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _cachedUserDocs = docs;
      _cachedQueryFor = searchQuery;
      _userSearchLoading = false;
      _userSearchError = null;
      _usedFallbackSearch = !usedPrefixQuery;
    });
  }

  List<WellnessCategory> get _filteredCategories {
    final q = _query.trim();
    if (q.isEmpty) return _allCategories;
    final qLower = q.toLowerCase();
    return _allCategories
        .where((c) =>
            c.name.toLowerCase().contains(qLower) ||
            c.subtitle.toLowerCase().contains(qLower) ||
            c.subcategorySpecs.any((s) =>
                s.displayName.toLowerCase().contains(qLower)))
        .toList();
  }

  Widget _buildUserSearchResults() {
    final showQuery = _debouncedQuery;
    final queryNow = _query.trim();

    if (queryNow.isEmpty) return const SizedBox.shrink();

    // Hint when user has typed but not yet 2 chars (no search run yet)
    if (queryNow.length < _minQueryLength) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Type at least $_minQueryLength characters to search users',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      );
    }

    if (showQuery.isEmpty && !_userSearchLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_userSearchLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_userSearchError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Search unavailable. Please try again.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      );
    }

    final docs = _cachedUserDocs ?? [];
    final searchLower = showQuery.toLowerCase();
    final filteredUsers = _usedFallbackSearch
        ? docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final username = _safeString(data['username']).toLowerCase();
            final name = (_safeString(data['name']) != ''
                    ? _safeString(data['name'])
                    : _safeString(data['full_name']) != ''
                        ? _safeString(data['full_name'])
                        : _safeString(data['business_name']))
                .toLowerCase();
            return username.contains(searchLower) || name.contains(searchLower);
          }).toList()
        : docs;

    if (filteredUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No users found matching "$showQuery"',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Users (${filteredUsers.length})',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Refresh results',
              onPressed: _userSearchLoading ? null : _refreshUserSearch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        if (_usedFallbackSearch) ...[
          const SizedBox(height: 6),
          Text(
            'Results from a sample of users. Refresh or add more characters for better matches.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
        const SizedBox(height: 12),
        ...filteredUsers.map((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final userId = doc.id;
          final username = _safeString(data['username']);
          final name = _safeString(data['name']) != ''
              ? _safeString(data['name'])
              : _safeString(data['full_name']) != ''
                  ? _safeString(data['full_name'])
                  : _safeString(data['business_name']) != ''
                      ? _safeString(data['business_name'])
                      : 'Unnamed User';
          final profilePhoto = data['profilePhoto'];
          final profilePhotoUrl =
              profilePhoto is String ? profilePhoto : _safeString(profilePhoto);
          final accountType = _safeString(data['accountType']).toLowerCase();

          return _UserSearchResultCard(
            userId: userId,
            username: username,
            name: name,
            profilePhoto: profilePhotoUrl.isEmpty ? null : profilePhotoUrl,
            accountType: accountType.isEmpty ? 'aspirant' : accountType,
          );
        }),
      ],
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
                        onChanged: _onSearchChanged,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText:
                          'Search experts by name, username, or expertise...',
                          hintStyle: textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
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

                    // User search results section (show hint from 1 char, results from 2+)
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

                    // GRID VIEW (stable key to avoid full rebuild on every keystroke)
                    GridView.builder(
                      key: ValueKey('grid_${categories.length}'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categories.length,
                        gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.92,
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
    final isTouchDevice = Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;
    final active = isTouchDevice ? _isPressed : (_isHovered || _isPressed);

    final shadow = [
      BoxShadow(
        blurRadius: active ? 24 : 10,
        spreadRadius: active ? -4 : -6,
        offset: Offset(0, active ? 16 : 8),
        color: Colors.black.withOpacity(active ? 0.16 : 0.08),
      ),
    ];

    final textTheme = Theme.of(context).textTheme;

    final content = AnimatedScale(
      scale: active ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: widget.category.backgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: shadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.category.backgroundImage != null)
                Image.asset(
                  widget.category.backgroundImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              Container(
                color: Colors.black.withOpacity(0.12),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: widget.onTap,
                  onTapDown: (_) => _setPressed(true),
                  onTapCancel: () => _setPressed(false),
                  onTapUp: (_) => _setPressed(false),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.category.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            widget.category.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F1033),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.category.subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final card = isTouchDevice
        ? content
        : MouseRegion(
            onEnter: (_) => _setHovered(true),
            onExit: (_) => _setHovered(false),
            cursor: SystemMouseCursors.click,
            child: content,
          );

    return Semantics(
      button: true,
      label: '${widget.category.name}, ${widget.category.subtitle}',
      child: card,
    );
  }
}

// ---------- SUBCATEGORY PAGE ----------

class SubCategoryPage extends StatelessWidget {
  final WellnessCategory category;

  const SubCategoryPage({Key? key, required this.category}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final specs = category.subcategorySpecs;
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
      body: specs.isEmpty
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
        itemCount: specs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final spec = specs[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              leading: Semantics(
                label: 'Category ${spec.displayName}',
                child: Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              title: Text(
                spec.displayName,
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
                      displayName: spec.displayName,
                      emoji: category.emoji,
                      interestTerm: spec.interestTerm,
                      specializationTerm: spec.specializationTerm,
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

    return Semantics(
      button: true,
      label: 'Open profile of $name${username.isNotEmpty ? ", @$username" : ""}',
      child: Container(
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
          onTap: () => openUserProfile(
                context,
                userId,
                knownAccountType: accountType,
              ),
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
                    name.trim().isNotEmpty
                        ? name.trim()[0].toUpperCase()
                        : 'U',
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
      ),
    );
  }
}

// ---------- EXPERTS PAGE ----------
// Finds users by category: queries both `interests` (aspirants) and
// `areas_of_specialization` (gurus) so all people with that specialization appear.

class ExpertsListPage extends StatelessWidget {
  final String displayName;
  final String emoji;
  final String? interestTerm;       // for interests array (lowercase)
  final String? specializationTerm; // for areas_of_specialization

  const ExpertsListPage({
    Key? key,
    required this.displayName,
    required this.emoji,
    this.interestTerm,
    this.specializationTerm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasAnyTerm = (interestTerm != null && interestTerm!.trim().isNotEmpty) ||
        (specializationTerm != null && specializationTerm!.trim().isNotEmpty);

    if (!hasAnyTerm) {
      return Scaffold(
        appBar: AppBar(
          title: Text(displayName),
          backgroundColor: kBackgroundColor,
        ),
        body: const Center(child: Text('No category selected.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          displayName,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F1033),
          ),
        ),
        backgroundColor: kBackgroundColor,
        foregroundColor: const Color(0xFF1F1033),
        elevation: 0,
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _fetchUsersByCategory(interestTerm, specializationTerm),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (kDebugMode) {
              debugPrint('ExpertsListPage query error: ${snapshot.error}');
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey.shade600),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load. Check your connection or try again.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!;

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No people found for "$displayName".',
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
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final userId = doc.id;
              final name = _safeString(data['name']) != ''
                  ? _safeString(data['name'])
                  : _safeString(data['full_name']) != ''
                      ? _safeString(data['full_name'])
                      : _safeString(data['business_name']) != ''
                          ? _safeString(data['business_name'])
                          : 'Unnamed';
              final username = _safeString(data['username']);
              final accountType = _safeString(data['accountType']).toLowerCase();
              return ListTile(
                leading: Semantics(
                  label: 'Category $displayName',
                  child: CircleAvatar(
                    backgroundColor: kPrimaryColor.withOpacity(0.12),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                title: Text(name),
                subtitle: username.isEmpty ? null : Text('@$username'),
                onTap: () => openUserProfile(
                  context,
                  userId,
                  knownAccountType:
                      accountType.isEmpty ? null : accountType,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Fetches users who have this category via interests (aspirants) and/or
/// areas_of_specialization (gurus), then merges and dedupes by doc id.
Future<List<QueryDocumentSnapshot>> _fetchUsersByCategory(
  String? interestTerm,
  String? specializationTerm,
) async {
  final Set<String> seenIds = {};
  final List<QueryDocumentSnapshot> merged = [];

  if (interestTerm != null && interestTerm!.trim().isNotEmpty) {
    try {
      final term = interestTerm.trim().toLowerCase();
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('interests', arrayContains: term)
          .get();
      for (final doc in snap.docs) {
        if (seenIds.add(doc.id)) merged.add(doc);
      }
    } catch (_) {}
  }

  if (specializationTerm != null && specializationTerm!.trim().isNotEmpty) {
    try {
      final term = specializationTerm!.trim();
      final snap = await FirebaseFirestore.instance
          .collection('users')  
          .where('areas_of_specialization', arrayContains: term)
          .get();
      for (final doc in snap.docs) {
        if (seenIds.add(doc.id)) merged.add(doc);
      }
    } catch (_) {}
  }

  return merged;
}
