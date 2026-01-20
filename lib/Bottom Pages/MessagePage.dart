import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:halo/Bottom%20Pages/HomePage.dart';

// User model class
class User {
  final String id;
  final String name;
  final String profileImage;
  final String lastMessage;
  final String lastMessageTime;
  final List<String> followers;
  final List<String> following;

  User({
    required this.id,
    required this.name,
    required this.profileImage,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.followers,
    required this.following,
  });
}

class MessagePage extends StatefulWidget {
  @override
  _MessagePageState createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final TextEditingController _searchController = TextEditingController();
  List<User> filteredUsers = [];
  
  // Sample user data - Replace this with your actual user data from backend
  final List<User> users = [
    User(
      id: '1',
      name: 'John Doe',
      profileImage: 'assets/user_placeholder.png',
      lastMessage: 'Hey, how are you?',
      lastMessageTime: '2m ago',
      followers: ['2', '3', '4'],
      following: ['2', '3'],
    ),
    User(
      id: '2',
      name: 'Jane Smith',
      profileImage: 'assets/user_placeholder.png',
      lastMessage: 'See you tomorrow!',
      lastMessageTime: '5m ago',
      followers: ['1', '3'],
      following: ['1', '4'],
    ),
    User(
      id: '3',
      name: 'Mike Johnson',
      profileImage: 'assets/user_placeholder.png',
      lastMessage: 'Thanks for the help!',
      lastMessageTime: '1h ago',
      followers: ['1', '2', '4'],
      following: ['1', '2'],
    ),
    User(
      id: '4',
      name: 'Sarah Wilson',
      profileImage: 'assets/user_placeholder.png',
      lastMessage: 'Did you see the new update?',
      lastMessageTime: '3h ago',
      followers: ['2', '3'],
      following: ['1', '2', '3'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    filteredUsers = List.from(users);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers(String query) {
    setState(() {
      filteredUsers = users
          .where((user) =>
              user.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _navigateToChat(User user) {
    // TODO: Implement navigation to chat screen
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => ChatScreen(user: user),
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
        return false;
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.velocity.pixelsPerSecond.dx > 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          }
        },
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(45.0),
            child: AppBar(
              title: Text(
                'Messages',
                style: GoogleFonts.rubik(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterUsers,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: AssetImage(user.profileImage),
                        radius: 25,
                      ),
                      title: Text(
                        user.name,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.lastMessage),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${user.followers.length} followers',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '${user.following.length} following',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Text(
                        user.lastMessageTime,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      onTap: () => _navigateToChat(user),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
