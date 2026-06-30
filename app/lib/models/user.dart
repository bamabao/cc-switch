class UserProfile {
  final int id;
  final String phone;
  final String role;  // elder | child
  final String? name;
  final String? avatarUrl;

  UserProfile({
    required this.id,
    required this.phone,
    required this.role,
    this.name,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int? ?? 0,
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'elder',
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
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
