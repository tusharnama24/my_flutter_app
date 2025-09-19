import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InterestSelectionPage extends StatefulWidget {
  final bool isFromSettings;

  const InterestSelectionPage({super.key, this.isFromSettings = false});

  @override
  State<InterestSelectionPage> createState() => _InterestSelectionPageState();
}

class _InterestSelectionPageState extends State<InterestSelectionPage> {
  final List<_Interest> _allInterests = const [
    _Interest(key: 'fitness', label: 'Fitness', icon: Icons.fitness_center),
    _Interest(key: 'yoga', label: 'Yoga', icon: Icons.self_improvement),
    _Interest(key: 'nutrition', label: 'Nutrition', icon: Icons.restaurant),
    _Interest(key: 'mental_health', label: 'Mental Health', icon: Icons.favorite),
    _Interest(key: 'productivity', label: 'Productivity', icon: Icons.timer),
    _Interest(key: 'music', label: 'Music', icon: Icons.music_note),
    _Interest(key: 'reading', label: 'Reading', icon: Icons.menu_book),
    _Interest(key: 'travel', label: 'Travel', icon: Icons.flight_takeoff),
  ];

  final Set<String> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('user_interests') ?? [];
    setState(() {
      _selected.addAll(existing);
      _loading = false;
    });
  }

  Future<void> _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_interests', _selected.toList());
    await prefs.setBool('interests_completed', true);
    // Also persist to Firestore if a user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'interests': _selected.toList()}, SetOptions(merge: true));
      } catch (_) {
        // ignore write errors silently; local prefs still saved
      }
    }
    if (mounted) {
      if (widget.isFromSettings) {
        Navigator.pop(context);
      } else {
        Navigator.pop(context, true); // let caller route to home
      }
    }
  }

  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('interests_completed', true);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your interests'),
        actions: [
          if (!widget.isFromSettings)
            TextButton(
              onPressed: _skip,
              child: const Text('Skip'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Pick 2–5 to personalize your feed'),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: _allInterests.length,
                    itemBuilder: (context, index) {
                      final interest = _allInterests[index];
                      final selected = _selected.contains(interest.key);
                      return _InterestTile(
                        interest: interest,
                        selected: selected,
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selected.remove(interest.key);
                            } else {
                              _selected.add(interest.key);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveAndContinue,
                        child: const Text('Continue'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InterestTile extends StatelessWidget {
  final _Interest interest;
  final bool selected;
  final VoidCallback onTap;

  const _InterestTile({required this.interest, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(interest.icon, size: 36, color: selected ? Colors.white : Colors.black),
            const SizedBox(height: 12),
            Text(
              interest.label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Interest {
  final String key;
  final String label;
  final IconData icon;

  const _Interest({required this.key, required this.label, required this.icon});
}


