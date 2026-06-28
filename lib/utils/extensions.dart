import 'dart:ui';
import 'package:flutter/material.dart';

extension BlurExtension on Widget {
  Widget blurred(double radius) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: radius, sigmaY: radius),
      child: this,
    );
  }
}
