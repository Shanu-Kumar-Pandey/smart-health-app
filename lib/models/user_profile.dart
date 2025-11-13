class UserProfile {
  final String? name;
  final String? provider;
  final int? age;
  final String? gender;
  final String? role;
  final String? bloodGroup;
  final String? weight;
  final String? contact;
  final String? email;
  final String? address;
  final String? photoURL;
  final List<String>? allergies;
  final List<String>? medications;
  final List<String>? vitalSigns;
  final List<String>? labReports;
  final List<String>? chronicConditions;
  final List<String>? vaccinations;
  final List<String>? surgeries;
  final List<String>? insurance;
  final List<String>? emergencyContacts;
  final List<String>? lifestyleGoals;
  final String? isVerified;

  UserProfile({
    this.name,
    this.age,
    this.gender,
    this.role,
    this.bloodGroup,
    this.weight,
    this.contact,
    this.email,
    this.address,
    this.photoURL,
    this.allergies,
    this.medications,
    this.vitalSigns,
    this.labReports,
    this.chronicConditions,
    this.vaccinations,
    this.surgeries,
    this.insurance,
    this.emergencyContacts,
    this.lifestyleGoals,
    this.isVerified,
    this.provider,
  });

  factory UserProfile.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return UserProfile();
    }
    return UserProfile(
      name: data['name'],
      age: data['age'],
      gender: data['gender'],
      role: data['role'],
      bloodGroup: data['bloodGroup'],
      weight: data['weight'],
      contact: data['contact'],
      email: data['email'],
      address: data['address'],
      photoURL: data['photoURL'],
      allergies: data['allergies'] != null ? List<String>.from(data['allergies']) : null,
      // medications: data['medications'] != null ? List<String>.from(data['medications']) : null,
      // vitalSigns: data['vitalSigns'] != null ? List<String>.from(data['vitalSigns']) : null,
      // labReports: data['labReports'] != null ? List<String>.from(data['labReports']) : null,
      chronicConditions: data['chronicConditions'] != null ? List<String>.from(data['chronicConditions']) : null,
      // vaccinations: data['vaccinations'] != null ? List<String>.from(data['vaccinations']) : null,
      // surgeries: data['surgeries'] != null ? List<String>.from(data['surgeries']) : null,
      // insurance: data['insurance'] != null ? List<String>.from(data['insurance']) : null,
      emergencyContacts: data['emergencyContacts'] != null ? List<String>.from(data['emergencyContacts']) : null,
      lifestyleGoals: data['lifestyleGoals'] != null ? List<String>.from(data['lifestyleGoals']) : null,
      isVerified: data['isVerified'],
      provider: data['provider'] as String? ?? 'email',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'role': role,
      'bloodGroup': bloodGroup,
      'weight': weight,
      'contact': contact,
      'email': email,
      'address': address,
      'photoURL': photoURL,
      'allergies': allergies,
      // 'medications': medications,
      // 'vitalSigns': vitalSigns,
      // 'labReports': labReports,
      'chronicConditions': chronicConditions,
      // 'vaccinations': vaccinations,
      // 'surgeries': surgeries,
      // 'insurance': insurance,
      // 'emergencyContacts': emergencyContacts,
      'lifestyleGoals': lifestyleGoals,
      'isVerified': isVerified,
      'provider': provider,
    };
  }
}
