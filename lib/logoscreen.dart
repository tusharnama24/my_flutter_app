import 'dart:async';
import 'package:classic_1/Bottom%20Pages/HomePage.dart';
import 'package:classic_1/Category/categorypage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:classic_1/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LogoScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _LogoScreenState();
}

class _LogoScreenState extends State<LogoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // Initialize Animation Controller
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3), // Animation duration
    );

    // Define Tween Animation
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    // Start animation
    _controller.forward();

    // Navigate to the next page after animation completes
    _navigationTimer = Timer(Duration(seconds: 4), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel(); // Cancel the navigation timer
    _controller.dispose(); // Dispose animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Color(0xFFF5F5F5), // HEX color for the background
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Text
              ScaleTransition(
                scale: _animation,
                child: Text(
                  'Halo',
                  style: GoogleFonts.pacifico(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: Colors.black, // Changed text color to black for visibility
                  ),
                ),
              ),

              SizedBox(height: 1), // Spacing between text and image

              // Animated Image
              ScaleTransition(
                scale: _animation,
                child: Image.asset(
                  'assets/images/Halo.png', // Replace with your image path
                  height: 200,
                  width: 300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}