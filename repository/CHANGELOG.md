## [2.0.0] - 2019-10-02

* Major rewrite of `CachedRepository` so that it returns `CacheItem<Item>`
  instead of `Item`s. This is a breaking change as it's no longer mutable.
  But it allows for cooler advanced functionality as it offers new information
  to users.

## [1.0.4] - 2019-10-01

* Add `OnlyCollectionFetcher`.

## [1.0.3] - 2019-09-13

* Major rewrite of `CachedRepository` to be more efficient and gracefully
  handle the different cache strategies as well as caches yielding multiple
  values.

## [1.0.2] - 2019-09-09

* `CachedRepository` allowing multiple cache strategies.

## [1.0.1] - 2019-09-09

* Minor fixes allowing `fetch` stream subscription to be closed after first
  event.

## [1.0.0] - 2019-09-06

* Removed unnecessary dependencies `flutter`, `hive`, `path_provider`,
  `provider` and `shared_preferences`.
* Fixed pubspec description and homepage.
* Added example.

## [0.0.1] - 2019-08-22

* Initial release with basic `Repository` and `Id` structure, as well as `InMemoryStorage`, `Transformer`, `ObjectToJsonTransformer`, `JsonToStringTransformer`, and `CachedRepository`.
