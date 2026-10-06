class UserProfile {
  final dynamic id;
  final String phone;
  final String fullName;
  final String role;
  final String language;
  final String location;
  final int cropsCount;
  final List<String> mainCrops;
  final bool isVerified;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.role,
    required this.language,
    required this.location,
    required this.cropsCount,
    required this.mainCrops,
    required this.isVerified,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '0',
      phone: json['phone'] as String? ?? json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? json['first_name'] as String? ?? '',
      role: json['role'] as String? ?? 'farmer',
      language: json['language'] as String? ?? 'fr',
      location: json['location'] as String? ?? 'Sénégal',
      cropsCount: (json['crops_count'] is int)
          ? json['crops_count'] as int
          : (int.tryParse(json['crops_count']?.toString() ?? '0') ?? 0),
      mainCrops: (json['main_crops'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : (json['date_joined'] != null
              ? DateTime.tryParse(json['date_joined'] as String)
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'full_name': fullName,
      'role': role,
      'language': language,
      'location': location,
      'crops_count': cropsCount,
      'main_crops': mainCrops,
      'is_verified': isVerified,
    };
  }

  UserProfile copyWith({
    dynamic id,
    String? phone,
    String? fullName,
    String? role,
    String? language,
    String? location,
    int? cropsCount,
    List<String>? mainCrops,
    bool? isVerified,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      language: language ?? this.language,
      location: location ?? this.location,
      cropsCount: cropsCount ?? this.cropsCount,
      mainCrops: mainCrops ?? this.mainCrops,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Initiales pour l'avatar (ex: "Moussa Diallo" -> "MD")
  String get initials {
    if (fullName.trim().isEmpty) {
      return phone.isNotEmpty ? phone.substring(0, 1).toUpperCase() : 'NA';
    }
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Libellé du rôle lisible en français
  String get roleDisplay {
    switch (role.toLowerCase()) {
      case 'farmer':
        return 'Producteur / Agriculteur';
      case 'admin':
        return 'Administrateur';
      default:
        return 'Producteur / Agriculteur';
    }
  }
}
