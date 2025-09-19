import 'dart:io';
import 'package:classic_1/newpostpage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../editprofilepage.dart';
import '../../postdetailspage.dart';
import '../../newpostpage.dart';
import '../../main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../spotify_player_widget.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// change from here
// import 'package:classic_1/edit_profile_page.dart';
import 'package:flutter/material.dart';


class ProfilePage extends StatefulWidget {

  ProfilePage();
  @override
  _ProfilePageState createState() => _ProfilePageState();

}

class _ProfilePageState extends State<ProfilePage> {
  String username = "";
  String name = "";
  String bio = "";
  String gender = "";
  String professiontype = "";
  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> reels = [];
  List<dynamic> followersList = [];
  List<dynamic> followingList = [];
  final double reviews = 4.5;
  bool isFollowing = false;
  bool isLiked = false;
  File? profilePhoto;
  File? headerPhoto;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? currentUser;

  final ImagePicker _picker = ImagePicker();

  List<Map<String, String>> workouts = [
    {'title': 'Leg Day', 'duration': '60 mins', 'intensity': 'High'},
    {'title': 'Cardio Blast', 'duration': '45 mins', 'calories': '300'},
    {'title': 'Zumba', 'duration': '45 mins', 'calories': '300'},
  ];

  List<String> challenges = ['Flexible Freak', 'Marathon Runner'];
  List<String> events = ['Devils Circuit', '5K Marathon'];

  void _addWorkout() {
    print("Add Workout button pressed");
    // Logic to add workout (dialog/input field can be implemented)
  }

  void _addChallenge() {
    print("Add Challenge button pressed");
    // Logic to add challenge
  }

  void _addEvent() {
    print("Add Event button pressed");
    // Logic to add event
  }

  // Show Options for Profile Picture
  void _showProfileOptions(BuildContext context, bool isHeader) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.remove_red_eye),
              title: Text('Show Photo'),
              onTap: () {
                Navigator.of(context).pop();
                _showPhoto(isHeader ? headerPhoto : profilePhoto);
              },
            ),
            if (!isHeader) // Add Story option only for Profile Picture
              ListTile(
                leading: Icon(Icons.add_a_photo),
                title: Text('Add Story'),
                onTap: () {
                  Navigator.of(context).pop();
                  _captureStory();
                },
              ),
            ListTile(
              leading: Icon(Icons.photo),
              title: Text('Change Photo'),
              onTap: () {
                Navigator.of(context).pop();
                _changePhoto(isHeader);
              },
            ),
          ],
        );
      },
    );
  }

  // Show Full-Screen Photo
  void _showPhoto(File? photo) {
    if (photo == null) {
      Fluttertoast.showToast(msg: 'No photo to display.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            Scaffold(
              appBar: AppBar(title: Text('Photo')),
              body: Center(
                child: Image.file(photo),
              ),
            ),
      ),
    );
  }

  // Open Camera to Add Story
  Future<void> _captureStory() async {
    final XFile? story = await _picker.pickImage(source: ImageSource.camera);
    if (story != null) {
      Fluttertoast.showToast(msg: 'Story added!');
      // Handle the captured story as needed
    }
  }

  // Change Profile or Header Photo
  Future<void> _changePhoto(bool isHeader) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() {
        if (isHeader) {
          headerPhoto = File(photo.path);
        } else {
          profilePhoto = File(photo.path);
        }
      });
      Fluttertoast.showToast(msg: 'Photo updated!');
    }
  }
  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Add Post'),
              onTap: () {
                Navigator.of(context).pop();
                _openGalleryForPost(); // Functionality for adding a post
              },
            ),
            ListTile(
              leading: Icon(Icons.add_a_photo),
              title: Text('Add Story'),
              onTap: () {
                Navigator.of(context).pop();
                _captureStory(); // Functionality for adding a story
              },
            ),
            /*  ListTile(
              leading: Icon(Icons.videocam),
              title: Text('Add Reel'),
              onTap: () {
                Navigator.of(context).pop();
                _openGalleryForReel(); // Placeholder for adding a reel
              },
            ),*/
          ],
        );
      },
    );
  }
  void _toggleLike() {
    setState(() {
      isLiked = !isLiked;
    });
  }

  // Placeholder function for adding a reel
  void _addReel() {
    Fluttertoast.showToast(msg: 'Reels feature is under development!');
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  Future<void> _loadUserData() async {
    currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final doc = await _firestore.collection('users').doc(currentUser!.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        username = data['username'] ?? '';
        name = data['name'] ?? '';
        bio = data['bio'] ?? '';
        gender = data['gender'] ?? '';
        professiontype = data['professiontype'] ?? '';
        followersList = data['followersList'] ?? [];
        followingList = data['followingList'] ?? [];
      });
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(username),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              // Open the gallery for post creation
              _showAddMenu(context);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'Logout') {
                _showLogoutConfirmation(context);
              }
              else if (value == 'Edit Profile') {
                final updatedData = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfilePage(
                      initialUsername: username,
                      initialName: name,
                      initialBio: bio,
                      initialGender: gender,
                      initialprofessiontype: professiontype,
                    ),
                  ),
                );
                if (updatedData != null) {
                  setState(() async {
                    await _firestore.collection('users').doc(currentUser!.uid).update({
                      'username': updatedData['username'],
                      'name': updatedData['name'],
                      'bio': updatedData['bio'],
                      'gender': updatedData['gender'],
                      'professiontype': updatedData['professiontype'],
                    });

                    //username = updatedData['username'];
                    //name = updatedData['name'];
                    //bio = updatedData['bio'];
                  });
                }
              }
              else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selected: $value')),
                );
              }
            },
            icon: Icon(Icons.settings),
            itemBuilder: (context) =>
            [
              PopupMenuItem(
                value: 'Settings',
                child: Text('Settings'),
              ),
              PopupMenuItem(
                value: 'Privacy',
                child: Text('Privacy'),
              ),
              PopupMenuItem(
                value: 'Edit Profile',
                child: Text('Edit Profile'),
              ),
              PopupMenuItem(
                value: 'Logout',
                child: Text('Logout'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () => _showProfileOptions(context, true),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: headerPhoto != null
                            ? FileImage(headerPhoto!)
                            : AssetImage('assets/images/bio.png') as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: 20,
                  child: GestureDetector(
                    onTap: () => _showProfileOptions(context, false),
                    onLongPress: () => _changePhoto(false),
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 23,
                        backgroundImage: profilePhoto != null
                            ? FileImage(profilePhoto!)
                            : AssetImage('assets/images/Profile.png') as ImageProvider,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image (Kept empty since it's already placed in the stack)
                  //SizedBox(width: 200), // Creates space for the profile image

                  // Name and Bio
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.rubik(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),

                  // Stats Section (Posts, Followers, Following)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(posts.length.toString(),
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Posts'),
                        ],
                      ),
                      SizedBox(width: 20), // Spacing between items
                      Column(
                        children: [
                          Text(followersList.length.toString(),
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Followers'),
                        ],
                      ),
                      SizedBox(width: 20), // Spacing between items
                      Column(
                        children: [
                          Text(followingList.length.toString(),
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Following'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(),

            // Tabs Section
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: Colors.black,
                    tabs: [
                      Tab(icon: Icon(Icons.grid_on)),
                      Tab(icon: Icon(Icons.more_horiz)),
                    ],
                  ),
                  SizedBox(
                    height: 400,
                    child: TabBarView(
                      children: [
                    StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator()));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(child: Text('No posts yet'));
                      }
                      final posts = snapshot.data!.docs;
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return Column(
                            children: [
                              Image.network(post['imageUrl']),
                              Text(post['caption'] ?? ''),
                            ],
                          );
                        },
                      );
                    },

                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),




      /* SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () => _showProfileOptions(context, true),
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: headerPhoto != null
                            ? FileImage(headerPhoto!)
                            : AssetImage(
                            'assets/images/bio.png') as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  left: MediaQuery.of(context).size.width/4  - 75,
                  child: GestureDetector(
                    onTap: () => _showProfileOptions(context, false),
                    onLongPress: () => _changePhoto(false),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 45,
                        backgroundImage: profilePhoto != null
                            ? FileImage(profilePhoto!)
                            : AssetImage(
                            'assets/images/Profile.png') as ImageProvider,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 40),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 16, top: 16),
                  child: Row(
                     //crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                     //  SizedBox(width: MediaQuery.of(context).size.width / 4 - 85),
                     Column(
                      //crossAxisAlignment: CrossAxisAlignment.start,
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                        Text(
                          name,
                          style: GoogleFonts.rubik(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                        ),
                        //SizedBox(height: 8),
                      /*  OutlinedButton(
                          onPressed: () async {
                            final updatedData = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditProfilePage(
                                      initialUsername: username,
                                      initialName: name,
                                      initialBio: bio,
                                      initialGender: 'Male',
                                    ),
                              ),
                            );
                            if (updatedData != null) {
                              setState(() {
                                username = updatedData['username'];
                                name = updatedData['name'];
                                bio = updatedData['bio'];
                              });
                            }
                          },
                          child: Text('Edit Profile'),
                        ),*/
                      ],
                     ),
                    ],
                  ),
                ),
            // Stats Section
         //   Padding(
         //     padding: const EdgeInsets.symmetric(horizontal: 16.0),
             // child:
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text(posts.length.toString(),
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Posts'),
                    ],
                  ),
                  Column(
                    children: [
                      Text(followersList.length.toString(),
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Followers'),
                    ],
                  ),
                  Column(
                    children: [
                      Text(followingList.length.toString(),
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Following'),
                    ],
                  ),
                ],
               ),
               // ),
             ],
           ),
          /*   Divider(),
            // New Buttons Section
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                /*  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            if (isFollowing) {
                              followers -= 1; // Decrease followers
                            } else {
                              followers += 1; // Increase followers
                            }
                            isFollowing = !isFollowing; // Toggle button state
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? Colors.green.shade50
                              : Colors.blue.shade50,
                          minimumSize: Size(double.infinity, 50),

                        ),
                        child: Text(isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold),),

                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(
                                'Messaging feature not implemented yet!')),
                          );
                        },
                        child: Text('Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50),
                        ),
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final updatedData = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              EditProfilePage(
                                initialUsername: username,
                                initialName: name,
                                initialBio: bio,
                                initialGender: 'Male',
                              ),
                        ),
                      );
                      if (updatedData != null) {
                        setState(() {
                          username = updatedData['username'];
                          name = updatedData['name'];
                          bio = updatedData['bio'];
                        });
                      }
                    },
                    child: Text('Edit Profile'),
                  ),*/
                ],
              ),
            ),*/
            Divider(),
            // Posts/Reels/Tagged Section
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: Colors.black,
                    tabs: [
                      Tab(icon: Icon(Icons.grid_on)),
                      //Tab(icon: Icon(Icons.video_library)),
                      Tab(icon: Icon(Icons.more_horiz)),
                    ],
                  ),
                  SizedBox(
                    height: 400,
                    child: TabBarView(
                      children: [
                        // Posts Tab
                        _buildGridView(posts, isVideo: false),
                        // Reels Tab
                        //_buildGridView(reels, isVideo: true),
                        _buildMoreDetailsTab(),
                      ],
                    ),
                  ),
                  Divider(),
                  // Posts Grid

                 ]
              ),
            ),
          ],
        ),
      ),*/
    );
    bottomNavigationBar: Padding(
      padding: const EdgeInsets.all(8.0),
      child: SpotifyPlayerWidget(),
    );
  }
  Widget _buildGridView(List<Map<String, dynamic>> items, {bool isVideo = false}) {
    return items.isEmpty
        ? Center(child: Text('No content available.'))
        : GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(
                  username: username,
                  items: items,
                  initialIndex: index,
                  isVideo: isVideo,
                  onItemsUpdated: (updatedItems) {
                    // Update posts or reels in the parent widget
                    /* if (isVideo) {
                      reels = updatedItems;
                    } else {*/
                    posts = updatedItems;
                    //  }
                  },
                ),
              ),
            );
          },
          child: isVideo
              ? Container(
            color: Colors.grey.shade300,
            child: Center(
              child: Icon(Icons.videocam, size: 50, color: Colors.grey),
            ),
          )
              : Image.file(
            File(item['image'].path),
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
  Widget _buildSectionHeader(String title, VoidCallback onAddPressed) {
    print("Building section header: $title");
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: onAddPressed,
        ),
      ],
    );
  }

  Widget _buildMoreDetailsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Last Workouts", _addWorkout),
          ...workouts.map((workout) {
            print("Rendering workout: ${workout['title']}");
            return ListTile(
              leading: Icon(Icons.fitness_center),
              title: Text(workout['title']!),
              subtitle: Text("Duration: ${workout['duration']}"),
              trailing: Text(workout.containsKey('intensity')
                  ? "Intensity: ${workout['intensity']}"
                  : "Calories Burned: ${workout['calories']}"),
            );
          }),
          SizedBox(height: 16),
          _buildSectionHeader("Events & Challenges", _addChallenge),
          Card(
            color: Colors.redAccent,
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Challenges", style: TextStyle(color: Colors.white)),
                  ...challenges.map((c) {
                    print("Rendering challenge: $c");
                    return Text(c, style: TextStyle(color: Colors.white));
                  }),
                  SizedBox(height: 8),
                  Text("Events", style: TextStyle(color: Colors.white)),
                  ...events.map((e) {
                    print("Rendering event: $e");
                    return Text(e, style: TextStyle(color: Colors.white));
                  }),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          _buildSectionHeader("Social Links", () {}),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(Icons.video_library),
              SizedBox(width: 8),
              Text("YouTube"),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(Icons.music_note),
              SizedBox(width: 8),
              Text("Apple Music"),
            ],
          ),
          SizedBox(height: 16),
          _buildSectionHeader("Fitness Articles", () {}),
          Card(
            child: ListTile(
              leading: Icon(Icons.article),
              title: Text("Benefits of Yoga"),
              subtitle: Text("Discover the benefits of yoga in your fitness routine."),
            ),
          ),
          SizedBox(height: 16),
          _buildSectionHeader("Fitness Stats", () {}),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text("Steps", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("6,500"),
                ],
              ),
              Column(
                children: [
                  Text("Calories Burned", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("450"),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  // details Sections

/*  Widget _buildMoreDetailsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Social Links",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          TextField(
            controller: socialLinksController,
            decoration: InputDecoration(
              hintText: "Enter your social profile link",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          Text(
            "Last Workout Details",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          TextField(
            controller: workoutDetailsController,
            decoration: InputDecoration(
              hintText: "Enter your last workout details",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                socialLinks = socialLinksController.text;
                workoutDetails = workoutDetailsController.text;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Details Updated')),
              );
            },
            child: Text("Save Details"),
          ),
        ],
      ),
    );
  }*/

  Future<void> _openGalleryForPost() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Newpostpage(
            imagePath: image.path,
            onPostSubmit: (caption) async {
              // 1. Upload image to Firebase Storage
              String fileName = DateTime.now().millisecondsSinceEpoch.toString();
              Reference ref = FirebaseStorage.instance.ref().child('posts').child(fileName);
              UploadTask uploadTask = ref.putFile(File(image.path));
              TaskSnapshot snapshot = await uploadTask;
              String downloadUrl = await snapshot.ref.getDownloadURL();

              // 2. Save post data to Firestore
              User? user = FirebaseAuth.instance.currentUser;
              await FirebaseFirestore.instance.collection('posts').add({
                'imageUrl': downloadUrl,
                'caption': caption,
                'userId': user?.uid,
                'timestamp': FieldValue.serverTimestamp(),
              });

              // Optionally, show a success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Post uploaded!')),
              );
            },
          ),
        ),
      );
    }
  }
  /* void _openGalleryForReel() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        reels.insert(0, {
          'videoPath': video.path,
          'caption': 'New Reel', // Placeholder caption, modify as needed
        });// Save video to reels list
      });
      Fluttertoast.showToast(msg: 'Reel added successfully!');
    }
  }*/
  /* Widget _buildGridView(List<Map<String, dynamic>> items, {bool isVideo = false}) {
    return items.isEmpty
        ? Center(child: Text('No content available.'))
        : GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (isVideo) {
          return Container(
            color: Colors.grey.shade300,
            child: Center(
              child: Icon(Icons.videocam, size: 50, color: Colors.grey),
            ),
          );
        } else {
          return Image.file(
            File(item['imagePath']),
            fit: BoxFit.cover,
          );
        }
      },
    );
  }*/

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Logout'),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginPage(),
                  ),
                );
              },
              child: Text('Yes, Logout'),
            ),
          ],
        );
      },
    );
  }
}
