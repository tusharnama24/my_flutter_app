// lib/widgets/google_sign_in_button.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../home_page.dart';

class GoogleSignInButton extends StatefulWidget {
  @override
  _GoogleSignInButtonState createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isSigningIn = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isSigningIn = true);

    try {
      // Temporary implementation - Google Sign-In API has changed
      // This is a placeholder until the API is properly updated
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In temporarily disabled. Please use email/password login.')),
      );
      
      setState(() => _isSigningIn = false);
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }

    setState(() => _isSigningIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(Icons.login),
      label: Text(_isSigningIn ? 'Signing In...' : 'Sign in with Google'),
      onPressed: _isSigningIn ? null : _signInWithGoogle,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
}
