import 'package:meta/meta.dart';

import 'repository.dart';

/// Identifier that uniquely identifies an item among others in the same
/// repository.
@immutable
class Id<T> {
  final String id;

  const Id(this.id) : assert(id != null);

  Stream<T> fetchFrom(Repository<T> repo) => repo.fetch(this);

  Id<OtherType> cast<OtherType>() => Id<OtherType>(id);
  String toString() => id;

  bool matches(String id) => this.id == id;
  operator ==(Object other) => other is Id<T> && other.id == id;
  int get hashCode => id.hashCode;

  factory Id.fromJson(Map<String, dynamic> json) => Id(json['id']);
  Map<String, dynamic> toJson() => {'id': id};
}
