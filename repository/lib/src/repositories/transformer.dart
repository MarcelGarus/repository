import 'package:meta/meta.dart';

import '../id.dart';
import '../repository.dart';

/// A storage that saves objects into a [Repository<Map<<String, dynamic>>>] by
/// serializing and deserializing them from and to json.
class Transformer<Item, SourceItem>
    extends RepositoryWithSource<Item, SourceItem> {
  Item Function(SourceItem item) fromSourceItem;
  SourceItem Function(Item item) toSourceItem;

  Transformer({
    @required Repository<SourceItem> source,
    @required this.fromSourceItem,
    @required this.toSourceItem,
  })  : assert(fromSourceItem != null),
        assert(toSourceItem != null),
        super(source);

  @override
  Stream<Item> fetch(Id<Item> id) =>
      source.fetch(id.cast<SourceItem>()).map(fromSourceItem);

  @override
  Stream<Map<Id<Item>, Item>> fetchAll() => source.fetchAll().map((items) {
        Map<Id<Item>, Item> transformed = {};
        for (var key in items.keys)
          transformed[key.cast<Item>()] = fromSourceItem(items[key]);
        return transformed;
      });

  @override
  Future<void> update(Id<Item> id, Item item) =>
      source.update(id.cast<SourceItem>(), toSourceItem(item));

  @override
  Future<void> remove(Id<Item> id) => source.remove(id.cast<SourceItem>());
}
