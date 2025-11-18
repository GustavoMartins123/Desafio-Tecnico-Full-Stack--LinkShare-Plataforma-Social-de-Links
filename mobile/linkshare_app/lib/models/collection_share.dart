class CollectionShare {
  final int id;
  final int collectionId;
  final String collectionName;
  final int sharedWithUserId;
  final String sharedWithUsername;
  final String sharedWithDisplayName;
  final DateTime sharedAt;
  final bool canEdit;

  CollectionShare({
    required this.id,
    required this.collectionId,
    required this.collectionName,
    required this.sharedWithUserId,
    required this.sharedWithUsername,
    required this.sharedWithDisplayName,
    required this.sharedAt,
    required this.canEdit,
  });

  factory CollectionShare.fromJson(Map<String, dynamic> json) {
    return CollectionShare(
      id: json['id'] as int,
      collectionId: json['collectionId'] as int,
      collectionName: json['collectionName'] as String,
      sharedWithUserId: json['sharedWithUserId'] as int,
      sharedWithUsername: json['sharedWithUsername'] as String,
      sharedWithDisplayName: json['sharedWithDisplayName'] as String,
      sharedAt: DateTime.parse(json['sharedAt'] as String),
      canEdit: json['canEdit'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collectionId': collectionId,
      'collectionName': collectionName,
      'sharedWithUserId': sharedWithUserId,
      'sharedWithUsername': sharedWithUsername,
      'sharedWithDisplayName': sharedWithDisplayName,
      'sharedAt': sharedAt.toIso8601String(),
      'canEdit': canEdit,
    };
  }
}
