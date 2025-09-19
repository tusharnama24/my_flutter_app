import 'package:classic_1/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateAspirantAccount extends StatefulWidget{
  @override
  _CreateAspirantAccount createState()=> _CreateAspirantAccount();
}
  class _CreateAspirantAccount extends State<CreateAspirantAccount>{
    final _formKey = GlobalKey<FormState>();
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final TextEditingController _usernameController = TextEditingController();
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _phoneController = TextEditingController();
    final TextEditingController _emailController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();
    final TextEditingController _confirmPasswordController = TextEditingController();
    final TextEditingController _dobController = TextEditingController();
    final TextEditingController _fitnessgoals = TextEditingController();
    final TextEditingController _location = TextEditingController();
    final TextEditingController _preferredtrainer = TextEditingController();
    final TextEditingController _fitnesslevel = TextEditingController();
    final TextEditingController _healthconcern = TextEditingController();
    final TextEditingController _preferredlocation = TextEditingController();
    //final TextEditingController _TBC = TextEditingController();
    String? _selectedTrainerGender;
    String? _selectedGender;
    bool _isFirstToggleOn = true;
    bool _isSecondToggleOn = true;
    String? selectedDate;

    Future<void> _pickDateOfBirth() async {
      DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
      );
      if (pickedDate != null) {
        String formattedDate = DateFormat('dd-MM-yyyy').format(pickedDate);
        setState(() {
          _dobController.text = formattedDate;
          //  selectedDate = formattedDate; // Store the selected date
        });
      }
    }

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
    // Check if username is unique
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
            'category': 'Aspirant',  // Fixed category for this page
            'username': _usernameController.text.trim(),
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': _emailController.text.trim(),
            'password': _passwordController.text.trim(),
            'confirm_password': _confirmPasswordController.text.trim(),
            'dob': _dobController.text.trim(),
            'gender': _selectedGender,
            'fitness_goals': _fitnessgoals.text.trim(),
            'location': _location.text.trim(),
            'preferred_trainer': _preferredtrainer.text.trim(),
            'preferred_trainer_gender': _selectedTrainerGender,
            'fitness_level': _fitnesslevel.text.trim(),
            'health_concern': _healthconcern.text.trim(),
            'preferred_location': _preferredlocation.text.trim(),
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
                  // Full Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your Full Name';
                      }
                      if (value.length < 3) {
                        return 'Full name must be at least 3 characters long';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  // Full Name
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

                  // Gender Selection
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    value: _selectedGender,
                    items: ['Male', 'Female', 'Other']
                        .map((gender) => DropdownMenuItem(
                      value: gender,
                      child: Text(gender),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your gender';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Date of Birth Field
                  TextFormField(
                    controller: _dobController,
                    readOnly: true, // Make it read-only to prevent manual input
                    decoration: InputDecoration(
                      labelText: 'Date of Birth (DD-MM-YYYY)',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    onTap: _pickDateOfBirth, // Show the date picker
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your date of birth';
                      }else{
                        Text(
                          '$selectedDate',
                          style: const TextStyle(fontSize: 16),
                        );
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Fitness Goals
                  TextFormField(
                    controller: _fitnessgoals,
                    decoration: InputDecoration(
                      labelText: 'Fitness Goals',
                      prefixIcon: Icon(Icons.fitness_center),
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

                  // Preferred Trainer
                  TextFormField(
                    controller: _preferredtrainer,
                    decoration: InputDecoration(
                      labelText: 'Preferred Trainer',
                      prefixIcon: Icon(Icons.person_search),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Gender Selection
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Preferred Trainer Gender',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    value: _selectedTrainerGender,
                    items: ['None', 'Male', 'Female', 'Other']
                        .map((gender) => DropdownMenuItem(
                      value: gender,
                      child: Text(gender),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTrainerGender = value;
                      });
                    },
                    validator: (value) {
                      if (_preferredtrainer.text.isEmpty) {
                        return 'Please select your gender';
                      } else {
                        return null;
                      }

                    },
                  ),
                  SizedBox(height: 16),

                  // Fitness Level
                  TextFormField(
                    controller: _fitnesslevel,
                    decoration: InputDecoration(
                      labelText: 'Fitness Level',
                      prefixIcon: Icon(Icons.leaderboard),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Health Concern
                  TextFormField(
                    controller: _healthconcern,
                    decoration: InputDecoration(
                      labelText: 'Health Concern/Limitation',
                      prefixIcon: Icon(Icons.health_and_safety_outlined),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                  SizedBox(height: 16),

                  //  Preferred Location
                  TextFormField(
                    controller: _preferredlocation,
                    decoration: InputDecoration(
                      labelText: 'Preferred Location',
                      prefixIcon: Icon(Icons.location_city),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                  SizedBox(height: 16),

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
  

