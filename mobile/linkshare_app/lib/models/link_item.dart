class LinkItem {
  final int id;
  final String title;
  final String url;
  final String description;
  final int collectionId;
  final DateTime createdAt;

  LinkItem({
    required this.id,
    required this.title,
    required this.url,
    required this.description,
    required this.collectionId,
    required this.createdAt,
  });

  factory LinkItem.fromJson(Map<String, dynamic> json) {
    return LinkItem(
      id: json['id'],
      title: json['title'],
      url: json['url'],
      description: json['description'] ?? '',
      collectionId: json['collectionId'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'description': description,
      'collectionId': collectionId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
