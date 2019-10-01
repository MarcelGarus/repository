import 'package:meta/meta.dart';

import '../id.dart';
import '../repository.dart';

/// A repository that only supports fetching all items at once.
class OnlyCollectionFetcher<Item> extends Repository<Item> {
  Future<Map<Id<Item>, Item>> Function() _fetchAll;

  OnlyCollectionFetcher({
    @required Future<Map<Id<Item>, Item>> Function() fetchAll,
  })  : _fetchAll = fetchAll,
        super(isFinite: true, isMutable: false);

  @override
  Stream<Item> fetch(Id<Item> id) async* {
    throw UnsupportedError(
        'The fetch method was called on an OnlyCollectionFetcher repository. '
        'You should not request individual items from an OnlyCollectionFetcher, '
        'because this is inefficient since all items are fetched. If you are '
        'aware of these hidden costs, you might want to use '
        '`fetchAll().map((items) => items[id])`.');
  }

  @override
  Stream<Map<Id<Item>, Item>> fetchAll() async* {
    yield await _fetchAll();
  }
}
