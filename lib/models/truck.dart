class Truck {
  const Truck({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.source,
    required this.categoryTags,
    required this.isActive,
    this.coverImageUrl,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String source;
  final List<String> categoryTags;
  final bool isActive;
  final String? coverImageUrl;

  bool get isOfficialSource =>
      source == 'admin_manual' || source == 'insta_auto';

  factory Truck.fromMap(Map<String, dynamic> map) {
    final tags = map['category_tags'];
    return Truck(
      id: map['id'] as String,
      name: map['name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      source: map['source'] as String,
      categoryTags: tags is List
          ? tags.map((e) => e.toString()).toList()
          : const <String>[],
      isActive: map['is_active'] as bool? ?? true,
      coverImageUrl: map['cover_image_url'] as String?,
    );
  }
}
