
class Unit {
  final int? id;
  final String name;
  final int? parentId;

  Unit({this.id, required this.name, this.parentId});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parent_id': parentId,
    };
  }

  factory Unit.fromMap(Map<String, dynamic> map) {
    return Unit(
      id: map['id'],
      name: map['name'],
      parentId: map['parent_id'],
    );
  }
}
