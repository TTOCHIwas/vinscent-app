class CoupleCharacter {
  const CoupleCharacter({
    required this.coupleId,
    required this.imagePath,
    required this.drawingDataPath,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    this.imageUrl,
  });

  factory CoupleCharacter.fromJson(
    Map<String, dynamic> json, {
    String? imageUrl,
  }) {
    return CoupleCharacter(
      coupleId: json['couple_id'] as String,
      imagePath: json['image_path'] as String,
      drawingDataPath: json['drawing_data_path'] as String,
      updatedBy: json['updated_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      imageUrl: imageUrl,
    );
  }

  final String coupleId;
  final String imagePath;
  final String drawingDataPath;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;

  CoupleCharacter copyWith({String? imageUrl}) {
    return CoupleCharacter(
      coupleId: coupleId,
      imagePath: imagePath,
      drawingDataPath: drawingDataPath,
      updatedBy: updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class CoupleCharacterStoragePaths {
  const CoupleCharacterStoragePaths._();

  static const bucketId = 'couple-characters';

  static String imagePathFor(String coupleId) {
    return '$coupleId/current.png';
  }

  static String drawingDataPathFor(String coupleId) {
    return '$coupleId/current.json';
  }
}
