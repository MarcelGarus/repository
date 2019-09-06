When you have a large project, you probably want to manage data—you need to store it, fetch it from a server etc.

The `repository` package introduces a bottom-up high-level data management abstraction layer that lets you do just that!

There are only a few key concepts:

**Repositories** can store objects.  
Objects which are stored in repositories are called **items**.  
Among all items in a repository, an item can be uniquely identified by its **ID**.

## So, what can repositories do?

* Every repository can `fetch` items, returning a *stream of items* to the caller. Oftentimes, the stream will just contain one item, but there are times when it's very useful to return a sequence of items.
* Some repositories are *finite*, so you can `fetchAll` the items.
* Some repositories are *mutable*, so you can `update` items.

There are already some repositories implemented.
Here's just a quick look at three very different ones:

* `InMemoryStorage` is a mutable and finite repository, allowing you to store objects in the device's memory.
* `JsonToStringTransformer` stores items by serializing them and saving them to a provided `Repository<String>`.
* The `CachedRepository` accepts a `source` and a `cache` repository. When fetching items, it first returns the item from the `cache` and returns the item from the `source` afterwards.
* Of course, you can also create your own repositories, i.e. one that downloads data from a server when items are fetched.

By now, you probably realized that all of these repositories only do very simple, deterministic tasks.
Because that makes repositories modular, they can be composed into more powerful, higher-level repositories that elegantly handle the complex organization of streams from a variety of sources.

Here's an example of how that might look:

![repository chains](https://github.com/marcelgarus/repository/raw/master/repository/Repository_chains.svg)

```dart
CachedRepository<Article>(
  source: ArticleDownloader(),
  cache: ObjectToJsonTransformer(
    serializer: ArticleSerializer(),
    source: JsonToStringTransformer(
      source: SharedPreferencesStorage(keyPrefix: 'articles'),
    ),
  ),
)
```

If you're familiar with Flutter widgets, you'll immediately notice the style that favors composition over inheritance, allowing for incredibly flexible structures and abstractions.
