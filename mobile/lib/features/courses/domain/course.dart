import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

class Course {
  const Course({required this.id, required this.name, required this.colorHex});

  final int id;
  final String name;
  final String colorHex;

  Color get color => AppColors.fromHex(colorHex);

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'] as int,
        name: json['name'] as String,
        colorHex: json['color'] as String? ?? '#4C6FFF',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': colorHex};
}
