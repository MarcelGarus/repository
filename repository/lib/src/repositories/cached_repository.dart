import 'dart:async';

import 'package:meta/meta.dart';

import '../id.dart';
import '../repository.dart';

enum CacheStrategy {
  alwaysFetchFromSource,
  onlyFetchFromSourceIfNotInCache,
}

/// A repository that wraps a source repository. When items are fetched, they
/// are saved in the cache and the next time the item is fetched, it first
/// serves the item from the cache and only after that provides to source's
/// item.
/// You can always call `clearCache` or – if the source repository is finite –
/// call `loadItemsIntoCache` to load all the items from the source to the
/// cache.
class CachedRepository<Item> extends RepositoryWithSource<Item, Item> {
  final Repository<Item> cache;
  CacheStrategy strategy;
  bool _hasFetchedAllFromSource = false;

  CachedRepository({
    @required Repository<Item> source,
    this.cache,
    this.strategy = CacheStrategy.alwaysFetchFromSource,
  })  : assert(cache != null),
        assert(strategy != null),
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

    if (cached == null || strategy == CacheStrategy.alwaysFetchFromSource) {
      // Not wrapping this in an async callback leads to unexpected behavior:
      // https://github.com/dart-lang/sdk/issues/34685
      yield* () async* {
        await for (var item in source.fetch(id)) {
          cache.update(id, item);
          yield item;
        }
      }();
    }
  }

  @override
  Stream<Map<Id<Item>, Item>> fetchAll() async* {
    if (_hasFetchedAllFromSource) {
      var all =
          await cache.fetchAll().firstWhere((a) => true, orElse: () => null);
      yield all;
    }

    if (!_hasFetchedAllFromSource ||
        strategy == CacheStrategy.alwaysFetchFromSource) {
      // Not wrapping this in an async callback leads to unexpected behavior:
      // https://github.com/dart-lang/sdk/issues/34685
      yield* () async* {
        await for (var all in source.fetchAll()) {
          for (final entry in all.entries) {
            cache.update(entry.key, entry.value);
          }
          _hasFetchedAllFromSource = true;
          yield all;
        }
      }();
    }
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
