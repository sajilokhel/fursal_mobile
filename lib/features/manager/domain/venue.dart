class Venue {
  final String? id;
  final String name;
  final String location;
  final String? description;
  final double pricePerHour;
  final Map<String, dynamic>? metadata;

  Venue({
    this.id,
    required this.name,
    required this.location,
    this.description,
    required this.pricePerHour,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location': location,
      'description': description,
      'pricePerHour': pricePerHour,
      'metadata': metadata,
    };
  }

  factory Venue.fromMap(Map<String, dynamic> map, String id) {
    return Venue(
      id: id,
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      description: map['description'],
      pricePerHour: (map['pricePerHour'] ?? 0).toDouble(),
      metadata: map['metadata'],
    );
  }
}
