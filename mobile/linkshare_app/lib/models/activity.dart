enum ActivityType {
  linkAdded,
  collectionCreated,
  collectionShared,
}

class Activity {
  final int userId;
  final String username;
  final String userDisplayName;
  final String? userProfilePictureUrl;
  final ActivityType activityType;
  final DateTime timestamp;

  // Collection-related fields
  final int? collectionId;
  final String? collectionTitle;
  final bool? collectionIsPublic;

  // Link-related fields
  final int? linkItemId;
  final String? linkItemTitle;
  final String? linkItemUrl;
  final String? linkItemDescription;

  Activity({
    required this.userId,
    required this.username,
    required this.userDisplayName,
    this.userProfilePictureUrl,
    required this.activityType,
    required this.timestamp,
    this.collectionId,
    this.collectionTitle,
    this.collectionIsPublic,
    this.linkItemId,
    this.linkItemTitle,
    this.linkItemUrl,
    this.linkItemDescription,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      userId: json['userId'] as int,
      username: json['username'] as String,
      userDisplayName: json['userDisplayName'] as String,
      userProfilePictureUrl: json['userProfilePictureUrl'] as String?,
      activityType: _parseActivityType(json['activityType'] as int),
      timestamp: DateTime.parse(json['timestamp'] as String),
      collectionId: json['collectionId'] as int?,
      collectionTitle: json['collectionTitle'] as String?,
      collectionIsPublic: json['collectionIsPublic'] as bool?,
      linkItemId: json['linkItemId'] as int?,
      linkItemTitle: json['linkItemTitle'] as String?,
      linkItemUrl: json['linkItemUrl'] as String?,
      linkItemDescription: json['linkItemDescription'] as String?,
    );
  }

  static ActivityType _parseActivityType(int value) {
    switch (value) {
      case 0:
        return ActivityType.linkAdded;
      case 1:
        return ActivityType.collectionCreated;
      case 2:
        return ActivityType.collectionShared;
      default:
        return ActivityType.linkAdded;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'userDisplayName': userDisplayName,
      'userProfilePictureUrl': userProfilePictureUrl,
      'activityType': activityType.index,
      'timestamp': timestamp.toIso8601String(),
      'collectionId': collectionId,
      'collectionTitle': collectionTitle,
      'collectionIsPublic': collectionIsPublic,
      'linkItemId': linkItemId,
      'linkItemTitle': linkItemTitle,
      'linkItemUrl': linkItemUrl,
      'linkItemDescription': linkItemDescription,
    };
  }
}
