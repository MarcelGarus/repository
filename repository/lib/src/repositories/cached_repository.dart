import 'dart:async';

import 'package:meta/meta.dart';

import '../id.dart';
import '../repository.dart';

enum CacheStrategy {
  alwaysFetchFromSource,
  onlyFetchFromSourceIfNotInCache,
}

enum ItemOrigin { source, cache }

@immutable
class CacheItem<Item> {
  final ItemOrigin origin;
  bool get isFromSource => origin == ItemOrigin.source;
  bool get isFromCache => origin == ItemOrigin.cache;

  final Item data;
  bool get hasData => data != null;

  final dynamic error;
  bool get hasError => error != null;

  CacheItem._({@required this.origin, this.data, this.error})
      : assert(origin != null),
        assert(data == null || error != null);
}

/// A repository that wraps a source repository. When items are fetched, they
/// are saved in the cache and the next time the item is fetched, it first
/// serves the item from the cache and only after that provides to source's
/// item.
/// You can always call `clearCache` or – if the source repository is finite –
/// call `loadItemsIntoCache` to load all the items from the source to the
/// cache.
class CachedRepository<Item>
    extends RepositoryWithSource<CacheItem<Item>, Item> {
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

  bool get isMutable => false;

  @override
  Stream<CacheItem<Item>> fetch(Id<CacheItem<Item>> id) {
    final controller = StreamController<CacheItem<Item>>();
    final itemId = id.cast<Item>();

    /// Fetches items from the cache and the source simultaneously. When the
    /// source returns items, cancels the cache fetch and updates the cache.
    Future<void> alwaysFetchFromSource() async {
      StreamSubscription<Item> cached = cache.fetch(itemId).listen(
        (item) {
          controller.add(CacheItem<Item>._(
            origin: ItemOrigin.cache,
            data: item,
          ));
        },
        onError: (_) {},
      );
      source.fetch(itemId).listen(
        (item) {
          cached.cancel();
          controller.add(CacheItem<Item>._(
            origin: ItemOrigin.source,
            data: item,
          ));
          cache.update(itemId, item);
        },
        onError: (error) {
          cached.cancel();
          controller.addError(CacheItem<Item>._(
            origin: ItemOrigin.source,
            error: error,
          ));
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
        controller.add(CacheItem<Item>._(
          origin: ItemOrigin.cache,
          data: await cache.fetch(itemId).first,
        ));
      } on ItemNotFound catch (_) {
        await source.fetch(itemId).listen((item) {
          controller.add(CacheItem<Item>._(
            origin: ItemOrigin.source,
            data: item,
          ));
          cache.update(itemId, item);
        }).asFuture();
      } catch (error) {
        controller.addError(CacheItem<Item>._(
          origin: ItemOrigin.source,
          error: error,
        ));
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
  Stream<Map<Id<CacheItem<Item>>, CacheItem<Item>>> fetchAll() {
    assert(isFinite);

    final controller =
        StreamController<Map<Id<CacheItem<Item>>, CacheItem<Item>>>();

    Map<Id<CacheItem<Item>>, CacheItem<Item>> mapToCacheItemsWithOrigin<Item>(
        Map<Id<Item>, Item> allItems, ItemOrigin origin) {
      return {
        for (var entry in allItems.entries)
          Id<CacheItem<Item>>(entry.key.id): CacheItem<Item>._(
            origin: origin,
            data: entry.value,
          ),
      };
    }

    /// Fetches all items from the cache and the source simultaneously. When
    /// the source returns items, cancels the cache fetch and updates the
    /// cache.
    Future<void> alwaysFetchFromSource() async {
      StreamSubscription<Map<Id<Item>, Item>> cached = cache.fetchAll().listen(
        (all) {
          controller.add(mapToCacheItemsWithOrigin(all, ItemOrigin.cache));
        },
        onError: (_) {},
      );
      source.fetchAll().listen(
        (all) {
          cached.cancel();
          controller.add(mapToCacheItemsWithOrigin(all, ItemOrigin.source));
          for (final entry in all.entries) {
            cache.update(entry.key, entry.value);
          }
        },
        onError: (error) {
          cached.cancel();
          controller.addError(CacheItem<Item>._(
            origin: ItemOrigin.source,
            error: error,
          ));
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
        await controller.addStream(cache
            .fetchAll()
            .map((all) => mapToCacheItemsWithOrigin(all, ItemOrigin.cache)));
      } else {
        await source.fetchAll().listen((all) {
          controller.add(mapToCacheItemsWithOrigin(all, ItemOrigin.source));
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
