
class Unit {
  final int? id;
  final String name;

  Unit({this.id, required this.name});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Unit.fromMap(Map<String, dynamic> map) {
    return Unit(
      id: map['id'],
      name: map['name'],
    );
  }
}
