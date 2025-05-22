import 'dart:developer';

import 'package:connecto/common_widgets/continue_button.dart';
import 'package:connecto/feature/auth/controller/auth_provider.dart';
import 'package:connecto/feature/auth/screens/login_success.dart';
import 'package:connecto/my_app.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:lottie/lottie.dart';
import 'package:pinput/pinput.dart';

final justLoggedInProvider = StateProvider<bool>((ref) => false);

class LoginScreen extends ConsumerStatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  TextEditingController phoneController = TextEditingController();
  TextEditingController otpController = TextEditingController();
  String? phoneNumber;
  bool isPhoneValid = false;
  int countryPhoneLength = 9;

  // void _validatePhoneNumber(String? number, bool isValid) {
  //   setState(() {
  //     phoneNumber = number;
  //     isPhoneValid = isValid;
  //   });
  // }

  void _onContinuePressed() {
    final authNotifier = ref.read(authProvider.notifier);
    final authState = ref.watch(authProvider);

    if (authState == AuthState.idle || authState == AuthState.error) {
      if (phoneController.text.length < countryPhoneLength ||
          phoneController.text.length > countryPhoneLength) {
        authNotifier.sendOTP('+91${phoneController.text.trim()}', ref);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please enter a valid phone number")),
        );
      }
    } else if (authState == AuthState.otpSent ||
        authState == AuthState.otpError) {
      log('otp controller.text = ${otpController.text}');
      authNotifier.verifyOTP(otpController.text, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next == AuthState.authenticated) {
        log('====authneticated , going to success screen');
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (context) => SuccessScreen()),
        // );

        // ✅ Set "just logged in" state to true
        ref.read(justLoggedInProvider.notifier).state = true;

        context.go('/success');
      } else if (next == AuthState.otpError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Invalid OTP. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    log('===state : ====$authState');

    return Scaffold(
  backgroundColor: const Color(0xFF001311),
  body: LayoutBuilder(
    builder: (context, constraints) {
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
               padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0)
                  .copyWith(top: 40),
              child: IntrinsicHeight(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (widget, animation) {
                    return FadeTransition(opacity: animation, child: widget);
                  },
                  child: (authState == AuthState.otpSent ||
                          authState == AuthState.otpError ||
                          authState == AuthState.verifying)
                      ? buildOTPInput()
                      : buildPhoneNumberInput(),
                ),
              ),
            ),
          ),
          buildCustomNumberPad(), // stays fixed below
          const SizedBox(height: 10),
        ],
      );
    },
  ),
);

  }

  Widget buildPhoneNumberInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 30),
        Container(
            height: 118,
            width: 118,
            child: Lottie.asset('assets/lottie/mobile_notification.json')),
        Text("Enter your\nmobile number",
            style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 50 / 40)),
        SizedBox(height: 10),
        Text(
            "Please enter your phone number then we will send OTP to verify you.",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.grey[400])),
        SizedBox(height: 30),
        IntlPhoneField(
          controller: phoneController,
          disableLengthCheck: true,
          keyboardType: TextInputType.none,
          decoration: InputDecoration(
            filled: true,
            fillColor: Color(0xFF091F1E),
            labelText: 'Phone Number',
            floatingLabelBehavior: FloatingLabelBehavior.never,
            labelStyle: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w400),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white24, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF03FFE2), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          ),
          initialCountryCode: 'IN',
          // onChanged: (phone) {
          //   _validatePhoneNumber(phone.completeNumber, phone.isValidNumber());
          // },
          onCountryChanged: (value) {
            setState(() {
              countryPhoneLength = value.minLength;
            });
          },
        ),
        // Spacer(),
        SizedBox(height: 20),
        ContinueButton(
          onPressed:
              // ref.watch(authProvider) == AuthState.sendingOtp
              //     ? () {}
              //     :
              _onContinuePressed,
        ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget buildOTPInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 20,
        ),
        Container(
            height: 118,
            width: 118,
            child: Lottie.asset('assets/lottie/pin_lock.json')),
        Text(
          "Enter your\npasscode",
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 50 / 40,
          ),
        ),
        SizedBox(height: 10),
        Text(
          "Check your SMS inbox, we have sent the code at \n+971 000 000 000.",
          style: TextStyle(fontSize: 16, color: Colors.grey[400]),
        ),
        SizedBox(height: 20),
        Container(
          width: MediaQuery.of(context).size.width,
          child: Pinput(
            length: 6,
            autofocus: true,

            controller: otpController,
            keyboardType: TextInputType.none, // Prevents default keyboard
            defaultPinTheme: PinTheme(
              // width: 83,
              height: 64,
              textStyle: TextStyle(
                fontSize: 408,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white),
              ),
            ),
            focusedPinTheme: PinTheme(
              // width: 83,
              height: 64,
              textStyle: TextStyle(
                fontSize: 40,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF03FFE2), width: 2),
              ),
            ),
            submittedPinTheme: PinTheme(
              // width: 83,
              height: 64,
              textStyle: TextStyle(
                fontSize: 40,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white),
              ),
            ),
            onSubmitted: (value) {
              log('submitted : $value');
            },
            onCompleted: (value) {
              log('completed : $value');
              _onContinuePressed();
            },
          ),
        ),
        SizedBox(height: 40),
        Row(
          children: [
            TextButton(
              onPressed: () {},
              child: Text("Did not receive code?",
                  style: TextStyle(fontSize: 14, color: Colors.white)),
            ),
            Spacer(),
            TextButton(
              onPressed: () {},
              child: Text("Resend Code",
                  style: TextStyle(
                      fontSize: 14,
                      color: Color(
                        0xFF03FFE2,
                      ),
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        // ContinueButton(
        //   onPressed: ref.watch(authProvider) == AuthState.verifying
        //       ? () {}
        //       : _onContinuePressed,
        // ),
      ],
    );
  }

  Widget buildCustomNumberPad() {
    List<String> keys = [
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      ".",
      "0",
      "⌫"
    ];
    final authState = ref.watch(authProvider); // Get the current auth state

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15).copyWith(top: 0),
      child: GridView.builder(
        padding: EdgeInsets.symmetric(vertical: 8).copyWith(bottom: 18),
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 120 / 78,
        ),
        itemCount: keys.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _onKeyPressed(keys[index], authState),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Color(0xff091f1e),
              ),
              alignment: Alignment.center,
              child: Text(
                keys[index],
                style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
            ),
          );
        },
      ),
    );
  }

  void _onKeyPressed(String value, AuthState authState) {
    // HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);

    setState(() {
      if (authState == AuthState.idle ||
          authState == AuthState.sendingOtp ||
          authState == AuthState.error) {
        // User is entering phone number
        if (value == "⌫") {
          if (phoneController.text.isNotEmpty) {
            phoneController.text = phoneController.text
                .substring(0, phoneController.text.length - 1);
          }
        } else if (phoneController.text.length < 10) {
          // Restrict phone number length
          phoneController.text += value;
        }
      } else if (authState == AuthState.otpSent) {
        // User is entering OTP
        if (value == "⌫") {
          if (otpController.text.isNotEmpty) {
            otpController.text =
                otpController.text.substring(0, otpController.text.length - 1);
          }
        } else if (otpController.text.length < 6) {
          // Restrict OTP length
          otpController.text += value;
        }
      }
    });
  }
}
