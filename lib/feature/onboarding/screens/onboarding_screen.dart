import 'dart:developer';

import 'package:connecto/feature/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int currentIndex = 0;

  final List<Map<String, String>> onboardingData = [
    {
      "text": "Send personalized haptic messages. 🔥",
      "image": "assets/lottie/pulsing_circle.json",
    },
    {
      "text":
          "Stay close to your friends and create your own communication language.",
      "image": "assets/lottie/team_avatar.json",
    },
    {
      "text":
          "Bring on a smile on the face. The people you care about the most.",
      "image": "assets/lottie/smiles.json",
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        currentIndex = _controller.page?.round() ?? 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF001311),
      extendBodyBehindAppBar: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(0),
            child: PageView.builder(
              controller: _controller,
              itemCount: onboardingData.length,
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return OnboardingPage(
                  text: onboardingData[index]["text"]!,
                  image: onboardingData[index]["image"]!,
                  isFirstPage: index == 0,
                );
              },
            ),
          ),

          // Page Indicator
          Positioned(
            bottom: 50,
            child: SmoothPageIndicator(
              controller: _controller,
              count: onboardingData.length,
              effect: SwapEffect(
                dotColor: Colors.grey,
                activeDotColor: Color(0xFF03FFE2),
                dotHeight: 8,
                dotWidth: 8,
              ),
            ),
          ),

          // Next Button
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              backgroundColor: Color(0xFF03FFE2),
              shape: CircleBorder(),
              onPressed: () {
                if (currentIndex < onboardingData.length - 1) {
                  _controller.nextPage(
                    duration: Duration(milliseconds: 500),
                    curve: Curves.ease,
                  );
                } else {
                  log('===else section===');
                  // Navigate to Home or Login Screen
                  Navigator.push(context, MaterialPageRoute(builder:(context) => LoginScreen(),));
                }
              },
              child: Icon(Icons.arrow_right_alt, color: Colors.black, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String text;
  final String image;
  final bool isFirstPage;

  const OnboardingPage({
    required this.text,
    required this.image,
    required this.isFirstPage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          flex: isFirstPage ? 4 : 2,
          child: isFirstPage
              ? Lottie.asset(
                  image,
                )
              : Transform.translate(
                  offset: Offset(-50, 0), // Moves it 50px to the left
                  child: Lottie.asset(image, fit: BoxFit.cover),
                ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  text,
                  style: TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      height: 1.25),
                  textAlign: TextAlign.left,
                ),
              ),
              SizedBox(height: 158),
            ],
          ),
        ),
      ],
    );
  }
}
