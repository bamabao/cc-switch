class UserProfile {
  final int id;
  final String phone;
  final String role;  // elder | child
  final String? name;
  final String? avatarUrl;
  final int totalPoints;
  final int currentStreak;
  final int longestStreak;
  final String? voicePreference;
  final int? fontScale;
  final List<Map<String, dynamic>> familyMembers;

  UserProfile({
    required this.id,
    required this.phone,
    required this.role,
    this.name,
    this.avatarUrl,
    this.totalPoints = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.voicePreference,
    this.fontScale,
    this.familyMembers = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final members = (json['family_members'] as List<dynamic>? ?? [])
        .map((m) => {
              'name': (m as Map)['nickname'] ?? '',
              'role': m['role'] ?? '',
            })
        .toList();
    return UserProfile(
      id: json['id'] as int? ?? 0,
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'elder',
      name: json['nickname'] as String? ?? (json['name'] as String?),  // nickname from auth/me
      avatarUrl: json['avatar_url'] as String?,
      totalPoints: json['total_points'] as int? ?? 0,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      voicePreference: json['voice_preference'] as String?,
      fontScale: json['font_scale'] as int?,
      familyMembers: members,
    );
  }
}

class PointBalance {
  final int totalPoints;
  final int usedPoints;
  final int availablePoints;

  PointBalance({
    required this.totalPoints,
    required this.usedPoints,
    required this.availablePoints,
  });

  factory PointBalance.fromJson(Map<String, dynamic> json) {
    return PointBalance(
      totalPoints: json['total_points'] as int? ?? 0,
      usedPoints: json['used_points'] as int? ?? 0,
      availablePoints: json['available_points'] as int? ?? 0,
    );
  }
}

class PointProduct {
  final int id;
  final String name;
  final String? description;
  final int pointsRequired;
  final String? imageUrl;
  final int stock;

  PointProduct({
    required this.id,
    required this.name,
    this.description,
    required this.pointsRequired,
    this.imageUrl,
    this.stock = 0,
  });

  factory PointProduct.fromJson(Map<String, dynamic> json) {
    return PointProduct(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      pointsRequired: json['points_required'] as int? ?? 0,
      imageUrl: json['image_url'] as String?,
      stock: json['stock'] as int? ?? 0,
    );
  }
}

class PointOrder {
  final int id;
  final int productId;
  final int pointsSpent;
  final String status;
  final DateTime createdAt;

  PointOrder({
    required this.id,
    required this.productId,
    required this.pointsSpent,
    required this.status,
    required this.createdAt,
  });

  factory PointOrder.fromJson(Map<String, dynamic> json) {
    return PointOrder(
      id: json['id'] as int? ?? 0,
      productId: json['product_id'] as int? ?? 0,
      pointsSpent: json['points_spent'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
