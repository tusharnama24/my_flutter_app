import '../widgets/google_sign_in_button.dart';
import '../signuppage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Halo.",
                style: GoogleFonts.pacifico(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // Username/email field
              TextField(
                decoration: InputDecoration(
                  labelText: "Username / Email / Phone",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Password field
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password / OTP",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  // Add custom login logic here
                },
                child: Text("Sign In"),
              ),

              const SizedBox(height: 20),

              // Create Account Link
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => SignupPage(),
                    ));
                  },
                  child: Text(
                    "Don't have an account? Sign up",
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              Text(
                "Login with Social",
                style: GoogleFonts.rubik(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              GoogleSignInButton(), // <--- Your working button
            ],
          ),
        ),
      ),
    );
  }
}