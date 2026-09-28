class Country {
  final String name;
  final String cca2;

  const Country({required this.name, required this.cca2});

  String get flagUrl => 'https://flagcdn.com/w320/${cca2.toLowerCase()}.png';

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      name: json['name']['common'] as String,
      cca2: json['cca2'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Country &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          cca2 == other.cca2;

  @override
  int get hashCode => name.hashCode ^ cca2.hashCode;

  @override
  String toString() => 'Country(name: $name, cca2: $cca2)';
}
