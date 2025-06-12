import 'dart:math';

class Patient {
  final String id;
  final String fullName;
  final DateTime birthDate;
  final String gender;
  final String? contactNumber;
  final String? email;
  final String? address;
  final String? bloodType;
  final String? allergies;
  final String? currentMedications;
  final String? medicalHistory;
  final String? emergencyContactName;
  final String? emergencyContactNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  Patient({
    required this.id,
    required this.fullName,
    required this.birthDate,
    required this.gender,
    this.contactNumber,
    this.email,
    this.address,
    this.bloodType,
    this.allergies,
    this.currentMedications,
    this.medicalHistory,
    this.emergencyContactName,
    this.emergencyContactNumber,
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
      email: json['email'],
      address: json['address'],
      bloodType: json['bloodType'],
      allergies: json['allergies'],
      currentMedications: json['currentMedications'],
      medicalHistory: json['medicalHistory'],
      emergencyContactName: json['emergencyContactName'],
      emergencyContactNumber: json['emergencyContactNumber'],
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
      'email': email,
      'address': address,
      'bloodType': bloodType,
      'allergies': allergies,
      'currentMedications': currentMedications,
      'medicalHistory': medicalHistory,
      'emergencyContactName': emergencyContactName,
      'emergencyContactNumber': emergencyContactNumber,
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
    String? email,
    String? address,
    String? bloodType,
    String? allergies,
    String? currentMedications,
    String? medicalHistory,
    String? emergencyContactName,
    String? emergencyContactNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Patient(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      currentMedications: currentMedications ?? this.currentMedications,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactNumber: emergencyContactNumber ?? this.emergencyContactNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Generate a 6-digit ID
  static String generateId() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString(); // Generates number between 100000-999999
  }

  // Format an existing ID to ensure it's 6 digits
  static String formatId(String id) {
    // Remove any non-numeric characters
    final numericId = id.replaceAll(RegExp(r'[^0-9]'), '');
    
    // If the ID is longer than 6 digits, take the last 6
    if (numericId.length > 6) {
      return numericId.substring(numericId.length - 6);
    }
    
    // If the ID is shorter than 6 digits, pad with zeros
    return numericId.padLeft(6, '0');
  }
}
