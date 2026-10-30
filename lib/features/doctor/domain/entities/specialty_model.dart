import 'package:flutter/material.dart';

class SpecialtyModel {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final int activeDoctorCount;

  const SpecialtyModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    this.activeDoctorCount = 0,
  });

  /// Returns a crisp, distinctive vector icon for the medical specialty.
  IconData get iconData {
    final key = '${id.toLowerCase()} ${name.toLowerCase()} ${iconName.toLowerCase()}';
    if (key.contains('cardio') || key.contains('favorite') || key.contains('heart')) {
      return Icons.monitor_heart_rounded;
    }
    if (key.contains('derm') || key.contains('spa') || key.contains('skin')) {
      return Icons.face_retouching_natural_rounded;
    }
    if (key.contains('ortho') || key.contains('access') || key.contains('bone') || key.contains('joint')) {
      return Icons.accessibility_new_rounded;
    }
    if (key.contains('pediatric') || key.contains('spec_ped') || key.contains('child')) {
      return Icons.child_care_rounded;
    }
    if (key.contains('neuro') || key.contains('psych') || key.contains('brain')) {
      return Icons.psychology_rounded;
    }
    if (key.contains('general') || key.contains('medical_services')) {
      return Icons.medical_services_rounded;
    }
    if (key.contains('ophthal') || key.contains('eye') || key.contains('vision')) {
      return Icons.visibility_rounded;
    }
    if (key.contains('dent') || key.contains('tooth')) {
      return Icons.medication_liquid_rounded;
    }
    if (key.contains('ent') || key.contains('ear')) {
      return Icons.hearing_rounded;
    }
    return Icons.health_and_safety_rounded;
  }

  /// Unified brand color for all specialty icons.
  Color get accentColor => const Color(0xFF0A66C2);

  SpecialtyModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    int? activeDoctorCount,
  }) {
    return SpecialtyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      activeDoctorCount: activeDoctorCount ?? this.activeDoctorCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconName': iconName,
      'activeDoctorCount': activeDoctorCount,
    };
  }

  factory SpecialtyModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return SpecialtyModel(
      id: id ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      iconName: map['iconName'] as String? ?? 'healing',
      activeDoctorCount: (map['activeDoctorCount'] as num?)?.toInt() ?? 0,
    );
  }
}
