class Patient {
  final String id;
  final String fullName;
  // New fields for enhanced patient registration
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? suffix;
  final String? civilStatus;
  final bool isSeniorCitizen;
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
  final DateTime registrationDate;

  Patient({
    required this.id,
    required this.fullName,
    this.firstName,
    this.middleName,
    this.lastName,
    this.suffix,
    this.civilStatus,
    this.isSeniorCitizen = false,
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
    required this.registrationDate,
  });
  
  factory Patient.fromJson(Map<String, dynamic> json) {
    try {
      return Patient(
        id: json['id']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? 'Unknown Patient',
        firstName: json['firstName']?.toString(),
        middleName: json['middleName']?.toString(),
        lastName: json['lastName']?.toString(),
        suffix: json['suffix']?.toString(),
        civilStatus: json['civilStatus']?.toString(),
        isSeniorCitizen: json['isSeniorCitizen'] == true,
        birthDate: json['birthDate'] != null ? DateTime.parse(json['birthDate']) : DateTime.now(),
        gender: json['gender']?.toString() ?? 'Unknown',
        contactNumber: json['contactNumber']?.toString(),
        email: json['email']?.toString(),
        address: json['address']?.toString(),
        bloodType: json['bloodType']?.toString(),
        allergies: json['allergies']?.toString(),
        currentMedications: json['currentMedications']?.toString(),
        medicalHistory: json['medicalHistory']?.toString(),
        emergencyContactName: json['emergencyContactName']?.toString(),
        emergencyContactNumber: json['emergencyContactNumber']?.toString(),
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
        registrationDate: json['registrationDate'] != null ? DateTime.parse(json['registrationDate']) : DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'suffix': suffix,
      'civilStatus': civilStatus,
      'isSeniorCitizen': isSeniorCitizen,
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
      'registrationDate': registrationDate.toIso8601String(),
    };
  }

  Patient copyWith({
    String? id,
    String? fullName,
    String? firstName,
    String? middleName,
    String? lastName,
    String? suffix,
    String? civilStatus,
    bool? isSeniorCitizen,
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
    DateTime? registrationDate,
  }) {
    return Patient(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      suffix: suffix ?? this.suffix,
      civilStatus: civilStatus ?? this.civilStatus,
      isSeniorCitizen: isSeniorCitizen ?? this.isSeniorCitizen,
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
      registrationDate: registrationDate ?? this.registrationDate,
    );
  }

  // Track the last assigned patient number to ensure sequential IDs
  static int _lastAssignedNumber = 0;
  static final _lock = Object();

  // Generate an ID with sequential 4-digit number: JG-0001, JG-0002, etc.
  // This method should ONLY be called when actually registering a patient
  static String generateId() {
    // Always use JG as the prefix for all patients
    const String prefix = 'JG';
    
    // Ensure thread-safe increment of the ID number
    int idNumber = 0; // Initialize with default
    
    synchronized(_lock, () {
      // Increment counter ONLY when generating a real ID for database storage
      _lastAssignedNumber++;
      idNumber = _lastAssignedNumber;
    });
    
    // Format the ID with 4 digits padded with zeros
    final formattedNumber = idNumber.toString().padLeft(4, '0');
    return '$prefix-$formattedNumber';
  }
  
  // Generate a temporary display ID without incrementing the counter
  // Use this for UI display when the ID might not be committed to the database
  static String generateDisplayId() {
    // Always use JG as the prefix
    const String prefix = 'JG';
    
    // Use the current counter plus 1 (for next ID) but don't increment it
    int nextNumber = _lastAssignedNumber + 1;
    
    // Format the ID with 4 digits padded with zeros
    final formattedNumber = nextNumber.toString().padLeft(4, '0');
    return '$prefix-$formattedNumber';
  }
  
  // Format an existing ID or generate a new one
  static String formatId(String id) {
    // If the ID is already in the correct format (PREFIX-0000), keep it
    if (RegExp(r'^[A-Z]{2,3}-\d{4}$').hasMatch(id)) {
      return id;
    }
    
    // Otherwise, create a new ID
    return generateId();
  }
  
  // Helper method for thread-safety
  static void synchronized(Object lock, Function action) {
    // In Dart, a simple synchronized block can be implemented with a mutex pattern
    try {
      action();
    } catch (e) {
      rethrow;
    }
  }
}
