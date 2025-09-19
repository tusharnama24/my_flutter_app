import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  final List<Map<String, dynamic>> notifications = [
    {"user": "User1", "type": "liked your post", "time": "2m", "image": "assets/user1.png"},
    {"user": "User2", "type": "commented: Nice post!", "time": "5m", "image": "assets/user2.png"},
    {"user": "User3", "type": "started following you", "time": "10m", "image": "assets/user3.png"},
    {"user": "User4", "type": "mentioned you in a comment", "time": "15m", "image": "assets/user4.png"},
    {"user": "User5", "type": "liked your story", "time": "20m", "image": "assets/user5.png"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: AssetImage(notification["image"]),
              radius: 25,
            ),
            title: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.black),
                children: [
                  TextSpan(text: notification["user"], style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: " ${notification["type"]}"),
                ],
              ),
            ),
            trailing: Text(notification["time"], style: TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () {
              // Handle navigation or action when a notification is tapped
            },
          );
        },
      ),
    );
  }
}
