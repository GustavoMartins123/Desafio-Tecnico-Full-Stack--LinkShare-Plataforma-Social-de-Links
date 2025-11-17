import 'link_item.dart';

class Collection {
  final int id;
  final String title;
  final String description;
  final int ownerId;
  final String ownerUsername;
  final bool isPublic;
  final DateTime createdAt;
  final int linkItemsCount;
  final List<LinkItem>? linkItems; // Only populated in detail view

  Collection({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerId,
    required this.ownerUsername,
    required this.isPublic,
    required this.createdAt,
    required this.linkItemsCount,
    this.linkItems,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      ownerId: json['ownerId'],
      ownerUsername: json['ownerUsername'],
      isPublic: json['isPublic'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      linkItemsCount: json['linkItemsCount'] ?? (json['linkItems']?.length ?? 0),
      linkItems: json['linkItems'] != null
          ? (json['linkItems'] as List)
              .map((item) => LinkItem.fromJson(item))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'ownerId': ownerId,
      'ownerUsername': ownerUsername,
      'isPublic': isPublic,
      'createdAt': createdAt.toIso8601String(),
      'linkItemsCount': linkItemsCount,
      if (linkItems != null)
        'linkItems': linkItems!.map((item) => item.toJson()).toList(),
    };
  }
}
