library repository_hive;

import 'dart:async';

import 'package:hive/hive.dart';
import 'package:repository/repository.dart';

/// A repository that stores items in a hive database.
class HiveRepository<Item> extends Repository<Item> {
  Future<Box> _boxOpener;
  Box _box;

  HiveRepository(String key) : super(isFinite: true, isMutable: true) {
    _boxOpener = Hive.openBox(key);
    _boxOpener.then((box) => _box = box);
  }

  Future<void> _ensureBoxOpened() async {
    if (_box == null) await _boxOpener;
  }

  @override
  void dispose() => _box?.close();

  @override
  Stream<Item> fetch(Id<Item> id) async* {
    assert(id != null);

    await _ensureBoxOpened();

    if (_box.containsKey(id.id)) {
      yield await _box.get(id.id);
    }

    // Not wrapping this in an async callback leads to unexpected behavior:
    // https://github.com/dart-lang/sdk/issues/34685
    yield* () async* {
      await for (var event in _box.watch()) {
        if (id.matches(event.key)) yield event.value;
      }
    }();
  }

  @override
  Stream<Map<Id<Item>, Item>> fetchAll() async* {
    await _ensureBoxOpened();

    Map<Id<Item>, Item> getCurrent() {
      return {
        for (var entry in _box.toMap().entries) Id<Item>(entry.key): entry.value
      };
    }

    yield getCurrent();

    // Not wrapping this in an async callback leads to unexpected behavior:
    // https://github.com/dart-lang/sdk/issues/34685
    yield* () async* {
      await for (var _ in _box.watch()) yield getCurrent();
    }();
  }

  @override
  Future<void> update(Id<Item> id, Item item) async {
    assert(id != null);
    assert(item != null);

    await _ensureBoxOpened();
    await _box.put(id.id, item);
  }

  @override
  Future<void> remove(Id<Item> id) async {
    assert(id != null);

    await _ensureBoxOpened();
    await _box.delete(id.id);
  }
}
