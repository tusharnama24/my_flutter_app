import 'package:classic_1/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateWellnessAccount extends StatefulWidget{
  @override
  _CreateWellnessAccount createState()=> _CreateWellnessAccount();
}
class _CreateWellnessAccount extends State<CreateWellnessAccount>{
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _yearofcommence = TextEditingController();
  final TextEditingController _hourlyfees = TextEditingController();
  final TextEditingController _location = TextEditingController();
  //final TextEditingController _certification = TextEditingController();
  final TextEditingController _services = TextEditingController();
  final TextEditingController _workinghours = TextEditingController();
  final TextEditingController _offers = TextEditingController();
  final TextEditingController _productoffered = TextEditingController();
  final TextEditingController _membershipplans = TextEditingController();
  String? _selectedBusinessType;
  bool _isFirstToggleOn = true;
  bool _isSecondToggleOn = true;
  String? selectedDate;
  final ImagePicker _imagePicker = ImagePicker();
  String? _selectedFilePath;
  final List<String> _selectedFiles = [];


  // Function to handle form submission
  /*void _register() {
    if (_formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account Created Successfully')),
      );
      // Here, you could save the user's data or navigate to the login page
    }
  }

   */

  Future<void> _pickYearofcommence() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      String formattedDate = DateFormat('dd-MM-yyyy').format(pickedDate);
      setState(() {
        _yearofcommence.text = formattedDate;
        selectedDate = formattedDate; // Store the selected date
      });

    }
  }
// Certification Code
  // Function to pick a document (.pdf)
  /* Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'], // Restrict to .pdf files
      allowMultiple: true, // Allow multiple file selection
    );

    if (result != null) {
      setState(() {
        _selectedFiles.addAll(result.paths.whereType<String>()); // Add selected file paths
        _certification.text = _selectedFiles.map((e) => e.split('/').last).join(", "); // Update TextField
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No document selected.')),
      );
    }
  }

   */
// Certification Code
  /*Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'], // Restrict to .pdf files
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _selectedFiles.addAll(result.paths.whereType<String>());
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.files.length} document(s) selected')),
      );
     /*   setState(() {
        _selectedFilePath = result.files.single.path;
        _certification.text = result.files.single.name; // Update TextField
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected Document: ${result.files.single.name}')),
      );*/
     /* String? filePath = result.files.single.path;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected Document: $filePath')),
      ); */
    }else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No document selected.')),
      );
    }
  } */
// Certification Code
  // Function to pick an image (.png or .jpg)
 /* Future<void> _pickImages() async {
    final List<XFile>? images = await _imagePicker.pickMultiImage( // Allow multiple image picking
      imageQuality: 85, // Optional: compress the image quality
    );

    if (images != null && images.isNotEmpty) {
      setState(() {
        _selectedFiles.addAll(images.map((e) => e.path)); // Add selected image paths
        _certification.text = _selectedFiles.map((e) => e.split('/').last).join(", "); // Update TextField
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No image selected.')),
      );
    }
  }

  void _removeFile(String filePath) {
    setState(() {
      _selectedFiles.remove(filePath); // Remove the file from the list
      _certification.text = _selectedFiles.map((e) => e.split('/').last).join(", "); // Update TextField
    });
  } */
// Certification Code
  /* Future<void> _pickImages() async {
    List<XFile>? images = await _imagePicker.pickMultiImage(
      imageQuality: 85, // Optional: compress image quality
    );
    if (images != null) {
      setState(() {
        _selectedFiles.addAll(images.map((img) => img.path));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${images.length} image(s) selected')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No images selected.')),
      );
    }
  } */

  Future<void> _openFile(String filePath) async {
    await OpenFile.open(filePath);
  }
// Certification Code
/*  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85, // Optional: compress the image quality
    );

    if (image != null) {
      setState(() {
        _selectedFilePath = image.path;
        _certification.text = image.name; // Update TextField
      });
      String filePath = image.path;
      if (filePath.endsWith(".png") || filePath.endsWith(".jpg"))  {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected Image: $filePath')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid file format selected.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No image selected.')),
      );
    }
  }*/

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    // Regex to validate the password rules
    final passwordRegEx =
        r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#\$&*~]).{8,}$';
    if (!RegExp(passwordRegEx).hasMatch(value)) {
      return 'Password must contain:\n- 1 uppercase letter\n- 1 lowercase letter\n- 1 symbol\n- 1 number';
    }
    return null;
  }

  Future<bool> _isUsernameUnique(String username) async {
    final querySnapshot = await _firestore.collection('users')
        .where('username', isEqualTo: username)
        .get();
    return querySnapshot.docs.isEmpty;
  }

  Future<void> _register() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_isFirstToggleOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You must agree to terms & conditions')),
        );
        return;
      }

      // Check username uniqueness
      bool isUnique = await _isUsernameUnique(_usernameController.text.trim());
      if (!isUnique) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Username already exists! Choose another one.')),
        );
        return;
      }

      try {
        // Create User with Firebase Authentication
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),

        );

        // Store additional user details in Firestore
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'category': 'Wellness',  // Fixed category for this page
          'username': _usernameController.text.trim(),
          'business_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'confirm_password': _confirmPasswordController.text.trim(),
          'business_type':_selectedBusinessType,
          'Year_of_commence': _yearofcommence.text.trim(),
          'Hourly_fees': _hourlyfees.text.trim(),
          'location': _location.text.trim(),
         // 'certification': _certification.text.trim(),
          'services': _services.text.trim(),
          'working_hours': _workinghours.text.trim(),
          'offers': _offers.text.trim(),
          'product_offered': _productoffered.text.trim(),
          'membershipplans': _membershipplans.text.trim(),
          'terms_accepted': _isFirstToggleOn,
          'promotional_emails': _isSecondToggleOn,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account Created Successfully!')),
        );

        // Navigate to Login Page
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.toString()}')),
        );
      }
    }
  }



 /* void _showDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Choose a option"),
          content: Text("Your file is in which format?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _pickDocument();
              },
              child: Text(".pdf"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _pickImages();
              },
              child: Text(".png/.jpg"),
            ),
          ],
        );
      },
    );
  }

  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(45.0),
          child: AppBar(
            title: Text('Create Account', style: GoogleFonts.rubik(
              fontSize: 16,
              fontWeight: FontWeight.bold,),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(2.0), // Thickness of the line
              child: Container(
                color: Colors.black, // Color of the line
                height: 2, // Height of the line
              ),
            ),
          ),
        ),
        //backgroundColor: Color(0xFFE6E6FA),
        //backgroundColor: Color(0xFFF5F5F5),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Business Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Business Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your Business Name';
                        }
                        if (value.length < 3) {
                          return 'Full name must be at least 3 characters long';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your Mobile Number';
                        }
                        if (value.length < 10) {
                          return 'Mobile Number is not valid';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      validator: _validatePassword,
                    ),
                    SizedBox(height: 16),

                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Business Type Selection
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Business Type',
                        prefixIcon: Icon(Icons.business_center),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      value: _selectedBusinessType,
                      items: [
                        'Artist',
                        'Beauty/Cosmetic',
                        'Blogger',
                        'Clothing Brand',
                        'Community',
                        'Digital creator',
                        'Education',
                        'Entrepreneur',
                        'Gamer',
                        'Gym/Fitness',
                        'Health',
                        'Musician/band',
                        'Photographer',
                        'Product/Services',
                        'Restaurant',
                        'Shopping/Retail',
                        'Store',
                        'Writer'
                      ]
                          .map((Businesstype) => DropdownMenuItem(
                        value: Businesstype,
                        child: Text(Businesstype),
                      ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBusinessType = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your Business Type';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Year of Commence Field
                    TextFormField(
                      controller: _yearofcommence,
                      readOnly: true, // Make it read-only to prevent manual input
                      decoration: InputDecoration(
                        labelText: 'Year of Commence (DD-MM-YYYY)',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      onTap: _pickYearofcommence, // Show the date picker
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your Year of Commence';
                        }else{
                          Text(
                            '$selectedDate',
                            style: const TextStyle(fontSize: 16),
                          );
                        }
                        return null;
                      },
                    ),
                   /* if (selectedDate != null)
                      Text(
                        '$selectedDate',
                        style: const TextStyle(fontSize: 16),
                      ),*/
                    SizedBox(height: 16),

                    // Hourly charges
                    TextFormField(
                      controller: _hourlyfees,
                      decoration: InputDecoration(
                        labelText: 'Hourly Charges/Fees(.Rs)',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Location
                    TextFormField(
                      controller: _location,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Certification
                 /*   TextFormField(
                      controller: _certification,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Certification',
                        prefixIcon: Icon(Icons.workspace_premium),
                        suffixIcon: GestureDetector(
                          onTap: _showDialog, // Handles tap on the arrow icon
                          child: Icon(Icons.arrow_circle_up_outlined), // Arrow icon on the right
                        ),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                    if (_selectedFiles.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _selectedFiles.map((filePath) {
                          return ListTile(
                            leading: Icon(Icons.insert_drive_file, color: Colors.blueAccent),
                            title: Text(
                              filePath.split('/').last, // Show only file name
                              style: TextStyle(fontSize: 14),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min, // Ensures the row takes up minimal space
                              children: [
                                IconButton(
                                  icon: Icon(Icons.open_in_new, color: Colors.green),
                                  onPressed: () => _openFile(filePath), // Open the selected file
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeFile(filePath), // Remove the selected file
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    SizedBox(height: 16),

                  */


                    // Services
                    TextFormField(
                      controller: _services,
                      decoration: InputDecoration(
                        labelText: 'Services/Facilities',
                        prefixIcon: Icon(Icons.local_mall),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Working Hours and Working Days
                    TextFormField(
                      controller: _workinghours,
                      decoration: InputDecoration(
                        labelText: 'Working Hours and Working Days',
                        prefixIcon: Icon(Icons.hourglass_bottom),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                    SizedBox(height: 16),

                    //  Offers
                    TextFormField(
                      controller: _offers,
                      decoration: InputDecoration(
                        labelText: 'Special Offers/Scheme',
                        prefixIcon: Icon(Icons.local_offer),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                    SizedBox(height: 16),

                    //  Product Offered
                    TextFormField(
                      controller: _productoffered,
                      decoration: InputDecoration(
                        labelText: 'Product Offered',
                        prefixIcon: Icon(Icons.local_mall_outlined),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                    SizedBox(height: 16),

                    //  Membership Plans
                    TextFormField(
                      controller: _membershipplans,
                      decoration: InputDecoration(
                        labelText: 'Membership Plans',
                        prefixIcon: Icon(Icons.card_membership),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                      ),
                    ),
                    SizedBox(height: 24),


                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Agree to terms & Condition',
                          style: TextStyle(fontSize: 16),
                        ),
                        Switch(
                          value: _isFirstToggleOn,
                          onChanged: (value) {
                            setState(() {
                              _isFirstToggleOn = value;
                            });
                          },
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.grey,
                        ),
                      ],
                    ),
                    // SizedBox(height: ),
                    // Second Toggle Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Send Promotional Stuff',
                          style: TextStyle(fontSize: 16),
                        ),
                        Switch(
                          value: _isSecondToggleOn,
                          onChanged: (value) {
                            setState(() {
                              _isSecondToggleOn = value;
                            });
                          },
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.grey,
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8), // Rounded corners
                          ),
                          side: BorderSide( // Add border
                            color: Colors.black, // Border color
                            width: 1, // Border thickness
                          ),
                        ),
                        child: Text('Start your journey',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          //style: ElevatedButton.styleFrom(
                          //minimumSize: Size(double.infinity, 50),
                        ),
                      ),
                    ),

                    // Login Link
                    SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) {return LoginPage();},)); // Navigate back to login page
                        },
                        child: Text(
                          'Already have an account? Login',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ),

                  ],
                )
            ),
          ),
        )
    );
  }

}