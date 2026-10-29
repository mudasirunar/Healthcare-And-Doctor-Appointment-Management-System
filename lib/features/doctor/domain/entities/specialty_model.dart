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
