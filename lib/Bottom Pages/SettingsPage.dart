import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? currentUser;
  
  // Settings state
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _darkMode = false;
  bool _showOnlineStatus = true;
  bool _allowTagging = true;
  bool _allowComments = true;
  bool _showActivityStatus = true;

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (currentUser == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
          _emailNotifications = data['emailNotifications'] ?? true;
          _pushNotifications = data['pushNotifications'] ?? true;
          _darkMode = data['darkMode'] ?? false;
          _showOnlineStatus = data['showOnlineStatus'] ?? true;
          _allowTagging = data['allowTagging'] ?? true;
          _allowComments = data['allowComments'] ?? true;
          _showActivityStatus = data['showActivityStatus'] ?? true;
        });
      }
      
      // Load local preferences
      setState(() {
        _darkMode = prefs.getBool('darkMode') ?? false;
      });
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (currentUser == null) return;
    
    try {
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'notificationsEnabled': _notificationsEnabled,
        'emailNotifications': _emailNotifications,
        'pushNotifications': _pushNotifications,
        'darkMode': _darkMode,
        'showOnlineStatus': _showOnlineStatus,
        'allowTagging': _allowTagging,
        'allowComments': _allowComments,
        'showActivityStatus': _showActivityStatus,
      });
      
      // Save local preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', _darkMode);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settings saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.rubik(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text(
              'Save',
              style: GoogleFonts.rubik(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Section
            _buildSectionHeader('Account', Icons.person),
            _buildSettingsCard([
              _buildSettingsItem(
                'Edit Profile',
                'Update your personal information',
                Icons.edit,
                () {
                  // Navigate to edit profile
                  Navigator.pop(context, 'edit_profile');
                },
              ),
              _buildSettingsItem(
                'Change Password',
                'Update your account password',
                Icons.lock,
                () {
                  _showChangePasswordDialog();
                },
              ),
              _buildSettingsItem(
                'Account Information',
                'View your account details',
                Icons.info,
                () {
                  _showAccountInfo();
                },
              ),
            ]),

            SizedBox(height: 20),

            // Privacy & Security Section
            _buildSectionHeader('Privacy & Security', Icons.security),
            _buildSettingsCard([
              _buildSettingsItem(
                'Privacy Settings',
                'Control who can see your content',
                Icons.visibility,
                () {
                  Navigator.pop(context, 'privacy');
                },
              ),
              _buildSettingsItem(
                'Blocked Users',
                'Manage blocked accounts',
                Icons.block,
                () {
                  _showBlockedUsers();
                },
              ),
              _buildSettingsItem(
                'Two-Factor Authentication',
                'Add extra security to your account',
                Icons.security,
                () {
                  _showTwoFactorAuth();
                },
              ),
            ]),

            SizedBox(height: 20),

            // Notifications Section
            _buildSectionHeader('Notifications', Icons.notifications),
            _buildSettingsCard([
              _buildSwitchItem(
                'Push Notifications',
                'Receive notifications on your device',
                Icons.notifications_active,
                _pushNotifications,
                (value) => setState(() => _pushNotifications = value),
              ),
              _buildSwitchItem(
                'Email Notifications',
                'Receive notifications via email',
                Icons.email,
                _emailNotifications,
                (value) => setState(() => _emailNotifications = value),
              ),
              _buildSwitchItem(
                'Activity Status',
                'Show when you were last active',
                Icons.access_time,
                _showActivityStatus,
                (value) => setState(() => _showActivityStatus = value),
              ),
            ]),

            SizedBox(height: 20),

            // Content & Interactions Section
            _buildSectionHeader('Content & Interactions', Icons.content_copy),
            _buildSettingsCard([
              _buildSwitchItem(
                'Allow Tagging',
                'Let others tag you in posts',
                Icons.label,
                _allowTagging,
                (value) => setState(() => _allowTagging = value),
              ),
              _buildSwitchItem(
                'Allow Comments',
                'Let others comment on your posts',
                Icons.comment,
                _allowComments,
                (value) => setState(() => _allowComments = value),
              ),
              _buildSwitchItem(
                'Show Online Status',
                'Display when you are online',
                Icons.circle,
                _showOnlineStatus,
                (value) => setState(() => _showOnlineStatus = value),
              ),
            ]),

            SizedBox(height: 20),

            // Display Section
            _buildSectionHeader('Display', Icons.palette),
            _buildSettingsCard([
              _buildSwitchItem(
                'Dark Mode',
                'Use dark theme throughout the app',
                Icons.dark_mode,
                _darkMode,
                (value) => setState(() => _darkMode = value),
              ),
            ]),

            SizedBox(height: 20),

            // Support Section
            _buildSectionHeader('Support', Icons.help),
            _buildSettingsCard([
              _buildSettingsItem(
                'Help Center',
                'Get help and support',
                Icons.help_center,
                () {
                  _showHelpCenter();
                },
              ),
              _buildSettingsItem(
                'Contact Us',
                'Send feedback or report issues',
                Icons.contact_support,
                () {
                  _showContactUs();
                },
              ),
              _buildSettingsItem(
                'About',
                'App version and information',
                Icons.info_outline,
                () {
                  _showAbout();
                },
              ),
            ]),

            SizedBox(height: 30),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showLogoutConfirmation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Logout',
                  style: GoogleFonts.rubik(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.rubik(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsItem(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(
        title,
        style: GoogleFonts.rubik(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(
        title,
        style: GoogleFonts.rubik(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
        activeTrackColor: Colors.blue.withOpacity(0.3),
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: Colors.grey.withOpacity(0.3),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Password'),
        content: Text('Password change functionality will be implemented soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAccountInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Account Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${currentUser?.email ?? 'Not available'}'),
            SizedBox(height: 8),
            Text('User ID: ${currentUser?.uid ?? 'Not available'}'),
            SizedBox(height: 8),
            Text('Account Created: ${currentUser?.metadata.creationTime?.toString().substring(0, 10) ?? 'Not available'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBlockedUsers() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Blocked users management coming soon!')),
    );
  }

  void _showTwoFactorAuth() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Two-factor authentication coming soon!')),
    );
  }

  void _showHelpCenter() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Help center coming soon!')),
    );
  }

  void _showContactUs() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Contact us feature coming soon!')),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About Halo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Build: 2024.01.01'),
            SizedBox(height: 8),
            Text('A social fitness platform for wellness enthusiasts.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, 'logout');
            },
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }
}
