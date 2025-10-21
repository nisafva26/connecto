import 'dart:developer';

import 'package:connecto/feature/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  late final ValueNotifier<int> _currentPage = ValueNotifier(0)
    ..addListener(() => setState(() {}));
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
          "Plan the hangout in seconds. Find your spot, rally your people, add polls, and skip the 47-text group chat.",
      "image": "assets/lottie/gathering.json",
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        currentIndex = _controller.page?.round() ?? 0;
        _currentPage.value = currentIndex;
      });
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _currentPage.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF001311),
      extendBodyBehindAppBar: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
             // 1. Lottie/Image Area (FIXED LAYOUT) - Positioned at the top
        // This is what changes with a delay (AnimatedSwitcher)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          // You must specify a height for the image area since you can't use Expanded.
          // The height logic should match the flex ratios you intended (4/6 for index 0, 2/4 for others).
          height: currentIndex == 0 
                  ? MediaQuery.of(context).size.height * (4/6) // flex 4 out of 6 total
                  : MediaQuery.of(context).size.height * (2/4), // flex 2 out of 4 (approximate)
          child: ValueListenableBuilder<int>(
            valueListenable: _currentPage,
            builder: (_, value, __) {
              return AnimatedSwitcher(
                duration: Duration(milliseconds: 600),
                child: KeyedSubtree(
                  key: ValueKey(value),
                  child: Container( // Use Container instead of Expanded
                    // The Container takes the size defined by Positioned above
                    child: currentIndex == 0
                        ? Lottie.asset(
                            onboardingData[currentIndex]["image"]!,
                            fit: BoxFit.cover, // Ensure it covers the area
                          )
                        : Lottie.asset(
                            onboardingData[currentIndex]["image"]!,
                            fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
        ),
          Padding(
            padding: const EdgeInsets.all(0),
            child: PageView.builder(
              controller: _controller,
              itemCount: onboardingData.length,
              onPageChanged: (index) {
                HapticFeedback.mediumImpact();
                setState(() {
                  currentIndex = index;
                  _currentPage.value = currentIndex;
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

          // ValueListenableBuilder<int>(
          //   valueListenable: _currentPage,
          //   builder: (_, value, __) {
          //     return AnimatedSwitcher(
          //       duration: Duration(milliseconds: 300),
          //       child: KeyedSubtree(
          //         key: ValueKey(
          //             value), // so AnimatedSwitcher sees it as a different child.
          //         child: Expanded(
          //           flex: currentIndex == 0 ? 4 : 2,
          //           child: currentIndex == 0
          //               ? Lottie.asset(
          //                   onboardingData[currentIndex]["image"]!,
          //                 )
          //               : Transform.translate(
          //                   offset: Offset(-20, 0), // Moves it 50px to the left
          //                   child: Lottie.asset(
          //                       onboardingData[currentIndex]["image"]!,
          //                       fit: BoxFit.cover),
          //                 ),
          //         ),
          //       ),
          //     );
          //   },
          // ),

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
              onPressed: () async {
                if (currentIndex < onboardingData.length - 1) {
                  HapticFeedback.mediumImpact();
                  _controller.nextPage(
                    duration: Duration(milliseconds: 500),
                    curve: Curves.ease,
                  );
                } else {
                  log('=== Onboarding completed ===');
                  final prefs = await SharedPreferences.getInstance();
                  prefs.setBool('has_seen_onboarding', true);

                  // Use GoRouter to avoid stacking routes

                  // context.go(
                  //     '/'); // goes to Login, then your redirects handle the rest

                  // log('===else section===');
                  // // Navigate to Home or Login Screen
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(),
                      ));
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
        // Expanded(
        //   flex: isFirstPage ? 4 : 2,
        //   child: isFirstPage
        //       ? Lottie.asset(
        //           image,
        //         )
        //       : Transform.translate(
        //           offset: Offset(-20, 0), // Moves it 50px to the left
        //           child: Lottie.asset(image, fit: BoxFit.cover),
        //         ),
        // ),
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
