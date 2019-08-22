import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import '../id.dart';
import '../repository.dart';

/// A repository that wraps a source repository. When items are fetched, they
/// are saved in the cache and the next time the item is fetched, it first
/// serves the item from the cache and only after that provides to source's
/// item.
/// You can always call `clearCache` or – if the source repository is finite –
/// call `loadItemsIntoCache` to load all the items from the source to the
/// cache.
class CachedRepository<Item> extends RepositoryWithSource<Item, Item> {
  final Repository<Item> cache;

  CachedRepository({
    @required Repository<Item> source,
    this.cache,
  })  : assert(cache != null),
        assert(
            !source.isFinite || cache.isFinite,
            "Provided source repository $source is finite but the cache $cache "
            "isn't."),
        assert(cache.isMutable,
            "Can't cache items if the provided cache $cache is immutable."),
        super(source);

  @override
  Stream<Item> fetch(Id<Item> id) async* {
    var cached =
        await cache.fetch(id).firstWhere((_) => true, orElse: () => null);
    if (cached != null) yield cached;

    await for (final item in source.fetch(id)) {
      cache.update(id, item);
      yield item;
    }
  }

  @override
  Stream<Map<Id<Item>, Item>> fetchAll() {
    // Why no async* pattern was used: https://stackoverflow.com/questions/56813471/is-it-possible-to-yield-to-an-outer-scope-in-dart

    var sentSourceEntries = false;
    var controller = BehaviorSubject<Map<Id<Item>, Item>>(
      onListen: () {},
      onCancel: () {},
    );

    cache
        .fetchAll()
        .firstWhere((a) => true, orElse: () => null)
        .then((entries) {
      if (entries != null && !sentSourceEntries) controller.add(entries);
    });

    source.fetchAll().listen(
      (all) {
        controller.add(all);
        sentSourceEntries = true;
        for (final entry in all.entries) {
          cache.update(entry.key, entry.value);
        }
      },
      onDone: () => controller.close(),
      onError: (e, st) => controller.addError(e, st),
    );

    return controller.stream;
  }

  @override
  Future<void> update(Id<Item> id, Item value) async {
    await Future.wait([
      source.update(id, value),
      cache.update(id, value),
    ]);
  }

  @override
  Future<void> remove(Id<Item> id) async {
    await Future.wait([
      source.remove(id),
      cache.remove(id),
    ]);
  }

  Future<void> clearCache() async {
    await cache.clear();
  }

  /// Loads all the items from the source into the cache. May only be called if
  /// the source [isFinite]. Is asynchronous and returns when all items are
  /// loaded into the cache.
  Future<void> loadItemsIntoCache() async {
    assert(source.isFinite);
    final all = await source.fetchAll().first;
    await Future.wait(
        all.entries.map((entry) => cache.update(entry.key, entry.value)));
  }

  @override
  void dispose() {
    source.dispose();
    cache.dispose();
  }
}
