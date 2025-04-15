import 'dart:developer';

import 'package:connecto/common_widgets/continue_button.dart';
import 'package:connecto/feature/auth/controller/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:lottie/lottie.dart';
import 'package:pinput/pinput.dart';

enum LoginState { enterNumber, enterOTP }

class LoginScreen extends ConsumerStatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  LoginState _currentState = LoginState.enterNumber;
  TextEditingController phoneController = TextEditingController();
  TextEditingController otpController = TextEditingController();

  String? phoneNumber;
  bool isPhoneValid = false;
  bool isOtpValid = false;

  int countryPhoneLength = 9;

  void _onKeyPressed(String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_currentState == LoginState.enterNumber) {
        if (value == "⌫") {
          if (phoneController.text.isNotEmpty) {
            phoneController.text = phoneController.text
                .substring(0, phoneController.text.length - 1);
          }
        } else {
          phoneController.text += value;
        }
      } else {
        if (value == "⌫") {
          if (otpController.text.isNotEmpty) {
            otpController.text =
                otpController.text.substring(0, otpController.text.length - 1);
          }
        } else if (otpController.text.length < 4) {
          otpController.text += value;
        }
      }
    });

    // Validate OTP length
    if (_currentState == LoginState.enterOTP) {
      setState(() {
        isOtpValid = otpController.text.length == 4;
      });
    }
  }

  void _validatePhoneNumber(String? number, bool isValid) {
    print('inside validate phone number');
    setState(() {
      phoneNumber = number;
      isPhoneValid = isValid;
    });
  }

  void _onContinuePressed() {
    if (_currentState == LoginState.enterNumber) {
      if (isPhoneValid) {
        setState(() {
          _currentState = LoginState.enterOTP;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please enter a valid phone number")),
        );
      }
    } else {
      if (isOtpValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP Verified! 🎉")),
        );
        // Proceed with verification
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please enter a 4-digit OTP")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

     final authState = ref.watch(authProvider);

     log('===state : ====$authState');
    // log('print testing...');
    return Scaffold(
      backgroundColor: Color(0xFF001311),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0)
                  .copyWith(top: 40),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 500), // Animation duration
                transitionBuilder: (widget, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: widget,
                  );
                },
                child: _currentState == LoginState.enterNumber
                    ? KeyedSubtree(
                        key: ValueKey("PhoneInput"),
                        child: buildPhoneNumberInput(),
                      )
                    : KeyedSubtree(
                        key: ValueKey("OTPInput"),
                        child: buildOTPInput(),
                      ),
              ),
            ),
          ),
          buildCustomNumberPad(),
          SizedBox(
            height: 10,
          )
        ],
      ),
    );
  }

  Widget buildPhoneNumberInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 30,
        ),
        Container(
            height: 118,
            width: 118,
            child: Lottie.asset('assets/lottie/mobile_notification.json')),
        Text(
          "Enter your\nmobile number",
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 50 / 40,
          ),
        ),
        SizedBox(height: 10),
        Text(
          "Please enter your phone number then we will send OTP to verify you.",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.grey[400],
          ),
        ),
        SizedBox(height: 30),

        IntlPhoneField(
          controller: phoneController,
          disableLengthCheck: true,
          keyboardType: TextInputType.none,
          // autofocus: true,

          decoration: InputDecoration(
            filled: true,
            fillColor: Color(0xFF091F1E), // Background color from Figma
            labelText: 'Phone Number',
            floatingLabelBehavior: FloatingLabelBehavior.never,

            labelStyle: TextStyle(
              color: Colors.white70, // Light grey text for hint
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), // Rounded corners
              borderSide: BorderSide(
                color: Colors.white24, // Light border color
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Color(0xFF03FFE2), // Neon blue-green focus color
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          ),
          dropdownIcon: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white70, // Dropdown arrow color
          ),
          dropdownTextStyle:
              TextStyle(color: Colors.white), // Country code text color
          dropdownIconPosition: IconPosition.leading,
          initialCountryCode: 'AE',
          onCountryChanged: (value) {
            setState(() {
              countryPhoneLength = value.minLength;
            });
          },

          style:
              TextStyle(color: Colors.white, fontSize: 18), // Input text color
          // onChanged: (phone) {
          //   log('inside onchnaged');
          //   _validatePhoneNumber(phone.completeNumber, phone.isValidNumber());

          // },
        ),

        Spacer(),

        ContinueButton(
          onPressed: () {
            log('phone number length : ${phoneController.text.length}');
            log('country length : $countryPhoneLength');
            if (phoneController.text.length < countryPhoneLength ||
                phoneController.text.length > countryPhoneLength) {
              // Adjust length as needed
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Please enter a valid phone number')),
              );
            } else {
              setState(() {
                _currentState = LoginState.enterOTP;
              });
            }
          },
        ),
        SizedBox(height: 20),
        // Spacer()
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

    return Container(
      // color: Colors.red,
      padding: EdgeInsets.symmetric(horizontal: 15).copyWith(top: 0),
      child: GridView.builder(
        padding: EdgeInsets.symmetric(vertical: 8).copyWith(bottom: 25),
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 3 columns
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 120 / 78, // Button width & height ratio
        ),
        itemCount: keys.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _onKeyPressed(keys[index]),
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
}


