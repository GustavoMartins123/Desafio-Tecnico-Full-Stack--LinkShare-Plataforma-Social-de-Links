class SharedCollection {
  final int id;
  final String name;
  final String? description;
  final bool isPublic;
  final int ownerId;
  final String ownerUsername;
  final String ownerDisplayName;
  final DateTime sharedAt;
  final bool canEdit;
  final int linkCount;

  SharedCollection({
    required this.id,
    required this.name,
    this.description,
    required this.isPublic,
    required this.ownerId,
    required this.ownerUsername,
    required this.ownerDisplayName,
    required this.sharedAt,
    required this.canEdit,
    required this.linkCount,
  });

  factory SharedCollection.fromJson(Map<String, dynamic> json) {
    return SharedCollection(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      isPublic: json['isPublic'] as bool,
      ownerId: json['ownerId'] as int,
      ownerUsername: json['ownerUsername'] as String,
      ownerDisplayName: json['ownerDisplayName'] as String,
      sharedAt: DateTime.parse(json['sharedAt'] as String),
      canEdit: json['canEdit'] as bool,
      linkCount: json['linkCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isPublic': isPublic,
      'ownerId': ownerId,
      'ownerUsername': ownerUsername,
      'ownerDisplayName': ownerDisplayName,
      'sharedAt': sharedAt.toIso8601String(),
      'canEdit': canEdit,
      'linkCount': linkCount,
    };
  }
}
