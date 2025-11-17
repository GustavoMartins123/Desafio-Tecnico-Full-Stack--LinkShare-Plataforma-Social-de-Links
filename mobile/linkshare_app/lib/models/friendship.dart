enum FriendshipStatus {
  pending,
  accepted,
  declined,
  blocked;

  static FriendshipStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return FriendshipStatus.pending;
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'declined':
        return FriendshipStatus.declined;
      case 'blocked':
        return FriendshipStatus.blocked;
      default:
        return FriendshipStatus.pending;
    }
  }
}

class Friendship {
  final int id;
  final int requesterId;
  final String requesterUsername;
  final String requesterDisplayName;
  final int addresseeId;
  final String addresseeUsername;
  final String addresseeDisplayName;
  final FriendshipStatus status;
  final DateTime requestedAt;
  final DateTime updatedAt;

  Friendship({
    required this.id,
    required this.requesterId,
    required this.requesterUsername,
    required this.requesterDisplayName,
    required this.addresseeId,
    required this.addresseeUsername,
    required this.addresseeDisplayName,
    required this.status,
    required this.requestedAt,
    required this.updatedAt,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'],
      requesterId: json['requesterId'],
      requesterUsername: json['requesterUsername'],
      requesterDisplayName: json['requesterDisplayName'] ?? json['requesterUsername'],
      addresseeId: json['addresseeId'],
      addresseeUsername: json['addresseeUsername'],
      addresseeDisplayName: json['addresseeDisplayName'] ?? json['addresseeUsername'],
      status: FriendshipStatus.fromString(json['status'].toString()),
      requestedAt: DateTime.parse(json['requestedAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requesterId': requesterId,
      'requesterUsername': requesterUsername,
      'requesterDisplayName': requesterDisplayName,
      'addresseeId': addresseeId,
      'addresseeUsername': addresseeUsername,
      'addresseeDisplayName': addresseeDisplayName,
      'status': status.name,
      'requestedAt': requestedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
