import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classic_1/Bottom Pages/MessagePage.dart';
import 'package:classic_1/UserProfile.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  List<DocumentSnapshot> userResults = [];
  bool isLoading = false;
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool showCategories = false;

  final List<String> categories = [
    'Yoga', 'Cardio', 'Strength', 'Nutrition',
    'Meditation', 'Martial Arts', 'Dance', 'Boxing', 'Gym',
  ];

  @override
  void initState() {
    super.initState();
    searchFocusNode.addListener(() {
      setState(() {
        showCategories = searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  void onCategoryTap(String category) {
    searchController.text = category;
    searchFocusNode.unfocus();
    setState(() => showCategories = false);
    print("Search triggered for: $category");
  }

  void searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => userResults = []);
      return;
    }
    setState(() => isLoading = true);

    try {
      final lowerQuery = query.toLowerCase().trim();
      print('Searching for: $lowerQuery');

      // Server-side filtering for username
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: lowerQuery)
          .where('username', isLessThanOrEqualTo: lowerQuery + '\uf8ff')
          .get();

      print('Total users matched: ${snapshot.docs.length}');

      final allDocs = snapshot.docs
          .where((doc) => doc.id != currentUserId)
          .toList();

      setState(() {
        userResults = allDocs;
        isLoading = false;
      });
    } catch (e) {
      print('Error during search: $e');
      setState(() {
        isLoading = false;
        userResults = [];
      });
    }
  }

  Future<bool> isFollowing(String otherUserId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    final following = doc.data()?['followingList'] ?? [];
    return following.contains(otherUserId);
  }

  void followUser(String otherUserId) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
    final otherRef = FirebaseFirestore.instance.collection('users').doc(otherUserId);
    await userRef.update({
      'followingList': FieldValue.arrayUnion([otherUserId])
    });
    await otherRef.update({
      'followersList': FieldValue.arrayUnion([currentUserId])
    });
    setState(() {});
  }

  void unfollowUser(String otherUserId) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
    final otherRef = FirebaseFirestore.instance.collection('users').doc(otherUserId);
    await userRef.update({
      'followingList': FieldValue.arrayRemove([otherUserId])
    });
    await otherRef.update({
      'followersList': FieldValue.arrayRemove([currentUserId])
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Search')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search users by username...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: searchUsers,
            ),
            SizedBox(height: 20),
            isLoading
                ? Center(child: CircularProgressIndicator())
                : userResults.isEmpty && searchController.text.isNotEmpty
                ? Center(child: Text('No users found'))
                : Expanded(
              child: ListView.builder(
                itemCount: userResults.length,
                itemBuilder: (context, index) {
                  final user = userResults[index];
                  final userId = user.id;
                  final data = user.data() as Map<String, dynamic>;
                  final name = data['name'] ?? '';
                  final username = data['username'] ?? '';
                  final profilePic = data.containsKey('profilePic') ? data['profilePic'] : null;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                      child: profilePic == null ? Icon(Icons.person) : null,
                    ),
                    title: Text(name.isNotEmpty ? name : username),
                    subtitle: Text('@$username'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FutureBuilder<bool>(
                          future: isFollowing(userId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return SizedBox.shrink();
                            final following = snapshot.data!;
                            return ElevatedButton(
                              onPressed: () {
                                if (following) {
                                  unfollowUser(userId);
                                } else {
                                  followUser(userId);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: following ? Colors.grey : Colors.blue,
                              ),
                              child: Text(following ? 'Following' : 'Follow'),
                            );
                          },
                        ),
                        // IconButton(
                        //   icon: Icon(Icons.message),
                        //   onPressed: () {
                        //     Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder: (context) => ChatScreen(
                        //           receiverId: userId,
                        //           receiverName: name.isNotEmpty ? name : username,
                        //         ),
                        //       ),
                        //     );
                        //   },
                        // ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Userprofile(userId: userId),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// class ChatScreen extends StatelessWidget {
//   final String receiverId;
//   final String receiverName;
//
//   const ChatScreen({Key? key, required this.receiverId, required this.receiverName}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(receiverName)),
//       body: Center(
//         child: Text('Chat with $receiverName (ID: $receiverId)'),
//       ),
//     );
//   }
// }