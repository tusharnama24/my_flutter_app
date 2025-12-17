import 'package:classic_1/Category/createaspirantaccount.dart';
import 'package:classic_1/Category/createguruaccount.dart';
import 'package:classic_1/Category/createwellnessaccount.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// HALO Theme Colors
const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep Purple
const Color kDarkTop = Color(0xFF111111);
const Color kDarkBottom = Color(0xFF050505);

class CategoryPage extends StatefulWidget {
  @override
  _CategoryPageState createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOut,
          ),
        );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kDarkTop, kDarkBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // BACK BUTTON
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: kPrimaryColor,
                            size: 26,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),

                      const SizedBox(height: 10),

                      // TITLE
                      Text(
                        "Choose Your Preference",
                        style: textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Pick your account type",
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // CARDS (all equal)
                      _animatedCard(
                        child: _CategoryCard(
                          title: "Wellness",
                          description:
                          "Promote your products & services\nand attract fitness-focused individuals.",
                          imagePath: "assets/images/Wellness.png",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateWellnessAccount(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      _animatedCard(
                        child: _CategoryCard(
                          title: "Aspirant",
                          description:
                          "Find your fitness path with\nexpert guidance tailored for you.",
                          imagePath: "assets/images/Aspirant.png",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateAspirantAccount(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      _animatedCard(
                        child: _CategoryCard(
                          title: "Guru",
                          description:
                          "Share your expertise\nand connect with seekers.",
                          imagePath: "assets/images/Guru.png",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateGuruAccount(),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // fade+slide animation wrapper for each card
  Widget _animatedCard({required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------
//  Category Card with hover zoom + glow & equal size
// -----------------------------------------------------
class _CategoryCard extends StatefulWidget {
  final String title;
  final String description;
  final String imagePath;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textTheme =
    GoogleFonts.poppinsTextTheme(Theme
        .of(context)
        .textTheme);

    double size = MediaQuery
        .of(context)
        .size
        .width * 0.70;
    size = size.clamp(200, 300); // Square size (min 200, max 300)

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) => setState(() => _isHovered = false),
        onTapCancel: () => setState(() => _isHovered = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          scale: _isHovered ? 1.05 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: size,
            // SQUARE WIDTH
            height: size,
            // SQUARE HEIGHT
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xFF221E36),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isHovered
                    ? kPrimaryColor.withOpacity(0.9)
                    : Colors.white.withOpacity(0.12),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? kPrimaryColor.withOpacity(0.55)
                      : Colors.black.withOpacity(0.70),
                  blurRadius: _isHovered ? 32 : 22,
                  spreadRadius: _isHovered ? -4 : -12,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: textTheme.titleLarge?.copyWith(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Image.asset(
                  widget.imagePath,
                  width: size * 0.33,
                  height: size * 0.33,
                ),
                Text(
                  widget.description,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}