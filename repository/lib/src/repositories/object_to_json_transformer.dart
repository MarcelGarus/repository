import 'dart:async';

import 'package:flutter/foundation.dart';

import '../id.dart';
import '../repository.dart';
import 'transformer.dart';

typedef FromJsonCallback<T> = T Function(Map<String, dynamic> data);
typedef ToJsonCallback<T> = Map<String, dynamic> Function(T value);

/// A class that can serialize and deserialize a type from and to JSON.
@immutable
abstract class Serializer<T> {
  final FromJsonCallback<T> fromJson;
  final ToJsonCallback<T> toJson;

  const Serializer({
    @required this.fromJson,
    @required this.toJson,
  })  : assert(fromJson != null),
        assert(toJson != null);
}

/// A storage that saves objects into a [Repository<Map<<String, dynamic>>>] by
/// serializing and deserializing them from and to json.
class ObjectToJsonTransformer<Item>
    extends Transformer<Item, Map<String, dynamic>> {
  final Serializer<Item> serializer;

  ObjectToJsonTransformer({
    @required this.serializer,
    @required Repository<Map<String, dynamic>> source,
  })  : assert(serializer != null),
        super(
          source: source,
          fromSourceItem: serializer.fromJson,
          toSourceItem: serializer.toJson,
        );
}
