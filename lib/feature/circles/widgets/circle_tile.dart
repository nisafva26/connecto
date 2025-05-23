import 'package:connecto/feature/circles/models/circle_model.dart';
import 'package:connecto/helper/color_helper.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Widget buildCircleTile(CircleModel circle, BuildContext context) {
  
  final fontColor = hexToColor(circle.circleColor).computeLuminance() > 0.5
      ? Colors.black
      : Colors.white;
  return InkWell(
    onTap: () {
      context.go(
        '/bond/group-chat/${circle.id}',
        extra: circle,
      );
    },
    child: Container(
      margin: EdgeInsets.only(bottom: 21),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hexToColor(circle.circleColor),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          Row(
            // mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(circle.circleName,
                  style: TextStyle(
                    color:
                        hexToColor(circle.circleColor).computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  )),
              Spacer(),
              Text(circle.registeredUsers.length.toString(),
                  style: TextStyle(
                      color: hexToColor(circle.circleColor).computeLuminance() >
                              0.5
                          ? Colors.black
                          : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w400)),
              SizedBox(
                width: 5,
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: hexToColor(circle.circleColor).computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
                size: 15,
              )
            ],
          ),
          SizedBox(
            height: 32,
          ),
          Row(
            spacing: 8,
            children: [
              for (int i = 0; i < circle.registeredUsers.length; i++)
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                      // border: Border.all(color: fontColor),
                      shape: BoxShape.circle,
                      color: fontColor.withOpacity(0.2)),
                  child: Center(
                    child: Text(
                      getInitials(circle.registeredUsers[i].fullName),
                      style: TextStyle(
                          color: fontColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          )
        ],
      ),
    ),
  );
}
