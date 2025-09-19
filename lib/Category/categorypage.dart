import 'package:classic_1/Category/createaspirantaccount.dart';
import 'package:classic_1/Category/createguruaccount.dart';
import 'package:classic_1/Category/createwellnessaccount.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryPage extends StatefulWidget {
  @override
  _CategoryPageState createState() => _CategoryPageState();
}
class _CategoryPageState extends State<CategoryPage>{
  @override


  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: 70.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // Align items to the center
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20.0, left: 10.0), // Spacing at the top
                  child: Text(
                    "Choose Your Preference", // First text at the top
                    style: TextStyle(fontSize: 25, color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0, left: 10.0), // Spacing after the first text
                  child: Text(
                    "Pick your account type", // Second text immediately after the first
                    style: TextStyle(fontSize: 20, color: Colors.black),
                  ),
                ),
                SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Spread out content
                  children: [
                    // Left-aligned image and text
                    Padding(
                      padding: const EdgeInsets.only(left: 15, bottom: 2),
                      child: Column(
                        //crossAxisAlignment: CrossAxisAlignment.start, // Align to the left
                        children: [
                          Text(
                            "Wellness", // Text above the first image
                            style: TextStyle(fontSize: 22, color: Colors.black),
                          ),
                      GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateWellnessAccount(), // New page
                              ),
                            );
                          },
                          child: Image.asset(
                            'assets/images/Wellness.png', // Replace with your image path
                            width: 100,
                            height: 100,
                          ),
                      ),
                          Text(
                            "Promote your product \n& services and attract\nfitness-focused individuals", // Text below the first image
                            textAlign:TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 0.5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end, // Spread out content
                      children: [// Right-aligned image and text
                      Padding(
                        padding: const EdgeInsets.only(right: 15, bottom: 2),
                        child: Center(
                          child: Column(
                          //crossAxisAlignment: CrossAxisAlignment.end, // Align to the right
                          children: [
                            Text(
                              "Aspirant", // Text above the third image
                              style: TextStyle(fontSize: 22, color: Colors.black),
                            ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateAspirantAccount(), // New page
                                ),
                              );
                            },
                            child: Image.asset(
                              'assets/images/Aspirant.png', // Replace with your image path
                              width: 100,
                              height: 100,
                            ),
                          ),
                            Text(
                              "Find your fitness path with\nexpert guidance tailored for you", // Text below the third image
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.black),
                            ),
                          ],
                          ),
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 0.5), // Spacing between the rows of images
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween, // Spread out content
                       children: [
                            Padding(
                             padding: const EdgeInsets.only(left: 15 ),
                              child: Column(
                              children: [
                                Text(
                                 "Guru", // Text above the second image
                                   style: TextStyle(fontSize: 22, color: Colors.black),
                                 ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CreateGuruAccount(), // New page
                                    ),
                                  );
                                },
                                child: Image.asset(
                                    'assets/images/Guru.png', // Replace with your image path
                                  width: 100,
                                    height: 100,
                                 ),
                              ),
                                 Text(
                                   "Share your expertise\nand connect with those\nseeking your guidance.", // Text below the second image
                                   textAlign: TextAlign.center,
                                   style: TextStyle(fontSize: 12, color: Colors.black),
                                ),
                               ],
                              ),
                            ),
                          ],
                       ),
                        SizedBox(height: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
