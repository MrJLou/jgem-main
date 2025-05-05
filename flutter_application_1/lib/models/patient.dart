class Patient {
  final String id;
  final String fullName;
  final DateTime birthDate;
  final String gender;
  final String? contactNumber;
  final String? address;
  final String? bloodType;
  final String? allergies;
  final DateTime createdAt;
  final DateTime updatedAt;

  Patient({
    required this.id,
    required this.fullName,
    required this.birthDate,
    required this.gender,
    this.contactNumber,
    this.address,
    this.bloodType,
    this.allergies,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      fullName: json['fullName'],
      birthDate: DateTime.parse(json['birthDate']),
      gender: json['gender'],
      contactNumber: json['contactNumber'],
      address: json['address'],
      bloodType: json['bloodType'],
      allergies: json['allergies'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'birthDate': birthDate.toIso8601String(),
      'gender': gender,
      'contactNumber': contactNumber,
      'address': address,
      'bloodType': bloodType,
      'allergies': allergies,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Patient copyWith({
    String? id,
    String? fullName,
    DateTime? birthDate,
    String? gender,
    String? contactNumber,
    String? address,
    String? bloodType,
    String? allergies,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Patient(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      contactNumber: contactNumber ?? this.contactNumber,
      address: address ?? this.address,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
