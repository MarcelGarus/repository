library repository_shared_preferences;

import 'dart:async';

import 'package:repository/repository.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart' as sp;

/// A wrapper to store [String]s in the system's shared preferences.
class SharedPreferences extends Repository<String> {
  final String _keyPrefix;
  Map<String, BehaviorSubject<String>> _controllers;
  final BehaviorSubject<Map<Id<String>, String>> _allEntriesController;
  Future<sp.SharedPreferences> get _prefs => sp.SharedPreferences.getInstance();

  SharedPreferences(String name)
      : assert(name != null),
        _keyPrefix = '${name}_',
        _allEntriesController = BehaviorSubject(),
        super(isFinite: true, isMutable: true) {
    _controllers = Map<String, BehaviorSubject<String>>();
    _prefs.then((prefs) {
      // When starting up, load all existing values from SharedPreferences.
      // All the SharedPreferences properties managed by this repository have
      // [_keyPrefix] as a prefix in their key.
      prefs.getKeys().where((key) => key.startsWith(_keyPrefix)).forEach((key) {
        _controllers[key.substring(_keyPrefix.length)] = BehaviorSubject()
          ..add(prefs.getString(key));
      });
      _updateAllEntriesController();
    });
  }

  String _getKey(Id<String> id) => '$_keyPrefix${id.id}';

  @override
  Stream<String> fetch(Id<String> id) {
    if (_controllers.containsKey(id.id)) {
      return _controllers[id.id].stream;
    } else {
      throw ItemNotFound(id);
    }
  }

  @override
  Stream<Map<Id<String>, String>> fetchAll() => _allEntriesController.stream;

  void _updateAllEntriesController() async {
    _allEntriesController.add({
      for (var id in _controllers.keys) Id(id): await _controllers[id].first,
    });
  }

  @override
  Future<void> update(Id<String> id, String item) async {
    assert(id != null);
    assert(item != null);

    final prefs = await _prefs;

    prefs.setString(_getKey(id), item);
    _controllers.putIfAbsent(id.id, () => BehaviorSubject()).add(item);
    _updateAllEntriesController();
  }

  @override
  Future<void> remove(Id<String> id) async {
    assert(id != null);

    (await _prefs).remove(_getKey(id));
    _controllers.remove(id.id)?.close();
    _updateAllEntriesController();
  }

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.close());
    _allEntriesController.close();
  }
}
