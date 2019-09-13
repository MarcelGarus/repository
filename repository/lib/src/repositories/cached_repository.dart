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
  Stream<Item> fetch(Id<Item> id) {
    final controller = StreamController<Item>();

    /// Fetches items from the cache and the source simultaneously. When the
    /// source returns items, cancels the cache fetch and updates the cache.
    Future<void> alwaysFetchFromSource() async {
      StreamSubscription<Item> cached =
          cache.fetch(id).listen(controller.add, onError: (_) {});
      source.fetch(id).listen(
        (item) {
          cached.cancel();
          controller.add(item);
          cache.update(id, item);
        },
        onError: (error) {
          cached.cancel();
          controller.addError(error);
        },
        onDone: () {
          cached.cancel();
          controller.close();
        },
      );
    }

    /// First tries to fetch from the cache. Only if it throws an ItemNotFound
    /// error, tries to fetch from the source.
    Future<void> onlyFetchFromSourceIfNotInCache() async {
      try {
        controller.add(await cache.fetch(id).first);
      } on ItemNotFound catch (_) {
        await source.fetch(id).listen((item) {
          controller.add(item);
          cache.update(id, item);
        }).asFuture();
      } catch (error) {
        controller.addError(error);
      } finally {
        controller.close();
      }
    }

    switch (strategy) {
      case CacheStrategy.alwaysFetchFromSource:
        alwaysFetchFromSource();
        break;
      case CacheStrategy.onlyFetchFromSourceIfNotInCache:
        onlyFetchFromSourceIfNotInCache();
        break;
      default:
        throw AssertionError('Unknown cache strategy $strategy.');
    }

    return controller.stream;
  }

  @override
  Stream<Map<Id<Item>, Item>> fetchAll() {
    assert(isFinite);

    final controller = StreamController<Map<Id<Item>, Item>>();

    /// Fetches all items from the cache and the source simultaneously. When
    /// the source returns items, cancels the cache fetch and updates the
    /// cache.
    Future<void> alwaysFetchFromSource() async {
      StreamSubscription<Map<Id<Item>, Item>> cached =
          cache.fetchAll().listen(controller.add, onError: (_) {});
      source.fetchAll().listen(
        (all) {
          cached.cancel();
          controller.add(all);
          for (final entry in all.entries) {
            cache.update(entry.key, entry.value);
          }
        },
        onError: (error) {
          cached.cancel();
          controller.addError(error);
        },
        onDone: () {
          cached.cancel();
          controller.close();
        },
      );
    }

    /// First tries to fetch from the cache. Only if it throws an ItemNotFound
    /// error, tries to fetch from the source.
    Future<void> onlyFetchFromSourceIfNotInCache() async {
      if (_hasFetchedAllFromSource) {
        await controller.addStream(cache.fetchAll());
      } else {
        await source.fetchAll().listen((all) {
          controller.add(all);
          for (final entry in all.entries) {
            cache.update(entry.key, entry.value);
          }
        }).asFuture();
      }
      controller.close();
    }

    switch (strategy) {
      case CacheStrategy.alwaysFetchFromSource:
        alwaysFetchFromSource();
        break;
      case CacheStrategy.onlyFetchFromSourceIfNotInCache:
        onlyFetchFromSourceIfNotInCache();
        break;
      default:
        throw AssertionError('Unknown cache strategy $strategy.');
    }

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
