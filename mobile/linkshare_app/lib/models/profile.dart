class Profile {
  final int id;
  final int userId;
  final String username;
  final String displayName;
  final String bio;
  final String? profilePictureUrl;

  Profile({
    required this.id,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.bio,
    this.profilePictureUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      userId: json['userId'],
      username: json['username'],
      displayName: json['displayName'] ?? '',
      bio: json['bio'] ?? '',
      profilePictureUrl: json['profilePictureUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'profilePictureUrl': profilePictureUrl,
    };
  }

  Profile copyWith({
    int? id,
    int? userId,
    String? username,
    String? displayName,
    String? bio,
    String? profilePictureUrl,
  }) {
    return Profile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
    );
  }
}
