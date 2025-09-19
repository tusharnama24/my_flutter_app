import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:classic_1/services/cloudinary_service.dart';

class WellnessProfilePage extends StatefulWidget {
  @override
  _WellnessProfilePageState createState() => _WellnessProfilePageState();
}

class _WellnessProfilePageState extends State<WellnessProfilePage> {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();
  
  // Profile data
  String username = "fitlabjaipur";
  String name = "Fitlab";
  String bio = "Fitlab is a personal training studio located in Jaipur, Rajasthan. We provide comprehensive fitness solutions including strength training, cardio, nutrition guidance, and yoga sessions.";
  String location = "Jaipur, Rajasthan";
  String status = "Online";
  bool isOnline = true;
  
  // Stats
  int following = 12;
  int followers = 58000;
  int posts = 200;
  int likes = 1000000;
  double rating = 4.5;
  
  // Profile images
  File? profilePhoto;
  File? headerPhoto;

  // Sample data
  List<Map<String, dynamic>> popularProducts = [
    {
      'title': 'Eli/Protein Powder',
      'price': 'Rs 549.99',
      'badge': 'Best Seller',
      'image': 'assets/images/Profile.png'
    },
    {
      'title': 'Jubilee Resistance Bands Set',
      'price': 'Rs 999.99',
      'badge': 'New Arrival',
      'image': 'assets/images/Profile.png'
    },
  ];
  
  List<Map<String, dynamic>> recommendedCoaches = [
    {'name': 'Pawan Kumar', 'image': 'assets/images/Profile.png'},
    {'name': 'Vivek Singh', 'image': 'assets/images/Profile.png'},
    {'name': 'Pooja Sharma', 'image': 'assets/images/Profile.png'},
  ];
  
  List<Map<String, dynamic>> recentPosts = [
    {
      'username': '@FITLABJAIPUR',
      'time': '2 hours ago',
      'caption': 'Just finished a great workout session! 💪 #FitnessJourney',
      'tags': ['Fitness', 'Workout'],
      'image': 'assets/images/Profile.png'
    },
  ];
  
  List<String> services = ['Strength Training', 'Cardio & HIIT', 'Nutrition', 'Yoga'];
  List<String> availability = ['Monday - Friday: 6 AM - 10 PM', 'Saturday - Sunday: 7 AM - 8 PM'];
  
  List<Map<String, dynamic>> reviews = [
    {'name': 'Raman', 'rating': 4.5, 'comment': 'Really love the facilities and trainers.'},
    {'name': 'Suresh', 'rating': 4.5, 'comment': 'Great knowledge and very helpful virtual PT sessions.'},
  ];
  
  List<String> socialLinks = ['YouTube', 'Instagram', 'Facebook'];
  List<String> musicPlaylists = ['Best Workout', 'Active Beats', 'Chill', 'Focus', 'Motivation'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(username),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header stack (match ProfilePage)
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

            // Name, bio and stats row (match ProfilePage layout)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(posts.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Posts'),
                        ],
                      ),
                      SizedBox(width: 20),
                      Column(
                        children: [
                          Text(followers.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Followers'),
                        ],
                      ),
                      SizedBox(width: 20),
                      Column(
                        children: [
                          Text(following.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Following'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(),

            // Tab layout to mirror ProfilePage
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
                    height: 800,
                    child: TabBarView(
                      children: [
                        // Grid: show recent posts images placeholder grid
                        _buildRecentGrid(),

                        // More: include all rich sections built earlier
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildActionButtons(),
                              _buildPopularProducts(),
                              _buildRecommendedCoaches(),
                              _buildRecentPosts(),
                              _buildFitnessEvents(),
                              _buildFitnessLocations(),
                              _buildServicesAvailability(),
                              _buildReviewsRatings(),
                              _buildSocialLinks(),
                              _buildAppleMusic(),
                              _buildInstagram(),
                              SizedBox(height: 24),
                            ],
                          ),
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
                );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Profile Picture
          Center(
                  child: GestureDetector(
              onTap: () => _changePhoto(false),
                    child: CircleAvatar(
                      radius: 50,
                backgroundColor: Colors.grey[300],
                        backgroundImage: profilePhoto != null
                            ? FileImage(profilePhoto!)
                            : AssetImage('assets/images/Profile.png') as ImageProvider,
                      ),
                    ),
                  ),
          
          SizedBox(height: 16),
          
          // Name and Handle
          Center(
                    child: Column(
                      children: [
                        Text(
                          name,
                  style: GoogleFonts.rubik(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                        ),
                        Text(
                  '@$username',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                        ),
                      ],
                    ),
                  ),

          SizedBox(height: 16),
          
          // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
              _buildStatColumn('$following', 'Following'),
              _buildStatColumn('${(followers / 1000).toStringAsFixed(0)}K', 'Followers'),
              _buildStatColumn('$posts', 'Posts'),
              _buildStatColumn('${(likes / 1000000).toStringAsFixed(1)}M', 'Likes'),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Bio
          Text(
            bio,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String number, String label) {
    return Column(
                        children: [
        Text(
          number,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // Match ProfilePage: show options for header/profile photo
  void _showProfileOptions(BuildContext context, bool isHeader) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

  Widget _buildRecentGrid() {
    // Build a 3-column grid using recentPosts placeholder images
    final items = recentPosts;
    if (items.isEmpty) {
      return Center(child: Text('No content available.'));
    }
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final img = item['image']?.toString() ?? '';
        return Container(
          color: Colors.grey.shade200,
          child: img.isNotEmpty
              ? Image.asset(img, fit: BoxFit.cover)
              : Center(child: Icon(Icons.image, color: Colors.grey)),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Follow', style: TextStyle(color: Colors.white)),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Message', style: TextStyle(color: Colors.white)),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Share', style: TextStyle(color: Colors.white)),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Report', style: TextStyle(color: Colors.white)),
            ),
                  ),
                ],
              ),
    );
  }

  Widget _buildPopularProducts() {
    return Container(
      padding: EdgeInsets.all(16),
              child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              Text(
                'Popular Products',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text('View all >'),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: popularProducts.map((product) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        child: Center(
                          child: Text('Image.url', style: TextStyle(color: Colors.grey[600])),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product['badge'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              product['title'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              product['price'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedCoaches() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recommended Coaches',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text('View all >'),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: recommendedCoaches.map((coach) {
              return Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: AssetImage(coach['image']),
                    ),
                    SizedBox(height: 8),
                    Text(
                      coach['name'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPosts() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Posts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          ...recentPosts.map((post) {
            return Container(
              margin: EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: AssetImage(post['image']),
                      ),
                      SizedBox(width: 8),
                      Text(
                        post['username'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        post['time'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('Image.url', style: TextStyle(color: Colors.grey[600])),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    post['caption'],
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: (post['tags'] as List<String>).map((tag) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[800],
                ),
              ),
            );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildFitnessEvents() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'Fitness Events',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildFitnessLocations() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
      children: [
          Center(
            child: Icon(
              Icons.location_on,
              size: 40,
              color: Colors.grey[600],
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Fitness Locations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesAvailability() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[600],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services & Availability',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Services: ${services.join(', ')}',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          SizedBox(height: 8),
          Text(
            'Availability:',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          ...availability.map((avail) {
            return Text(
              '• $avail',
              style: TextStyle(color: Colors.white, fontSize: 14),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildReviewsRatings() {
    return Container(
      padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Text(
            'Reviews & Ratings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          ...reviews.map((review) {
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    review['name'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Row(
                    children: List.generate(5, (index) {
                      if (index < review['rating'].floor()) {
                        return Icon(Icons.star, size: 16, color: Colors.amber);
                      } else if (index == review['rating'].floor() && review['rating'] % 1 != 0) {
                        return Icon(Icons.star_half, size: 16, color: Colors.amber);
                      } else {
                        return Icon(Icons.star_border, size: 16, color: Colors.amber);
                      }
                    }),
                  ),
              SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      review['comment'],
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSocialLinks() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Social Links',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: socialLinks.map((link) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: 8),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    link,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppleMusic() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
                children: [
              Icon(Icons.music_note, size: 24),
              SizedBox(width: 8),
              Text(
                'Apple Music',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Playlist names\nThe artist names',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: musicPlaylists.map((playlist) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  playlist,
                  style: TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInstagram() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.camera_alt, size: 24),
              SizedBox(width: 8),
              Text(
                'Instagram',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Recent Posts',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          SizedBox(height: 12),
          Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: 8),
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(Icons.image, color: Colors.grey[600]),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

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
}