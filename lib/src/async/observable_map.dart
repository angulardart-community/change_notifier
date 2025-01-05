// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: deprecated_member_use_from_same_package
library change_notifier.src.observable_map;

import 'dart:collection';

import 'change_notifier.dart';
import 'records.dart';

// TODO(jmesserly): this needs to be faster. We currently require multiple
// lookups per key to get the old value.
// TODO(jmesserly): this doesn't implement the precise interfaces like
// LinkedHashMap, SplayTreeMap or HashMap. However it can use them for the
// backing store.

/// Represents an observable map of model values. If any items are added,
/// removed, or replaced, then observers that are listening to [changes]
/// will be notified.
class ObservableMap<K, V>
    with AsyncChangeNotifier<ChangeRecord>, PropertyChangeNotifier<Symbol>
    implements Map<K, V> {
  /// Adapts [source] to be a `ObservableMap<K2, V2>`.
  ///
  /// Any time the map would produce a key or value that is not a [K2] or [V2]
  /// the access will throw.
  ///
  /// Any time [K2] key or [V2] value is attempted added into the adapted map,
  /// the store will throw unless the key is also an instance of [K] and the
  /// value is also an instance of [V].
  ///
  /// If all accessed entries of [source] have [K2] keys and [V2] values and if
  /// all entries added to the returned map have [K] keys and [V] values, then
  /// the returned map can be used as a `Map<K2, V2>`.
  static ObservableMap<K2, V2> castFrom<K, V, K2, V2>(
    ObservableMap<K, V> source,
  ) {
    return ObservableMap<K2, V2>.spy(source._map.cast<K2, V2>(),
        notifyWhenEqual: source.notifyWhenEqual);
  }

  final Map<K, V> _map;

  /// Whether to notify when an index is set to the same value.
  final bool notifyWhenEqual;

  /// Creates an observable map.
  ObservableMap({this.notifyWhenEqual = false}) : _map = HashMap<K, V>();

  /// Creates a new observable map using a [LinkedHashMap].
  ObservableMap.linked({this.notifyWhenEqual = false}) : _map = <K, V>{};

  /// Creates a new observable map using a [SplayTreeMap].
  ObservableMap.sorted({this.notifyWhenEqual = false})
      : _map = SplayTreeMap<K, V>();

  /// Creates an observable map that contains all key value pairs of [other].
  /// It will attempt to use the same backing map type if the other map is a
  /// [LinkedHashMap], [SplayTreeMap], or [HashMap]. Otherwise it defaults to
  /// [HashMap].
  ///
  /// Note this will perform a shallow conversion. If you want a deep conversion
  /// you should use [toObservable].
  factory ObservableMap.from(Map<K, V> other, {bool notifyWhenEqual = false}) {
    return ObservableMap<K, V>.createFromType(other,
        notifyWhenEqual: notifyWhenEqual)
      ..addAll(other);
  }

  /// Like [ObservableMap.from], but creates an empty map.
  factory ObservableMap.createFromType(Map<K, V> other,
      {bool notifyWhenEqual = false}) {
    ObservableMap<K, V> result;
    if (other is SplayTreeMap) {
      result = ObservableMap<K, V>.sorted(notifyWhenEqual: notifyWhenEqual);
    } else if (other is LinkedHashMap) {
      result = ObservableMap<K, V>.linked(notifyWhenEqual: notifyWhenEqual);
    } else {
      result = ObservableMap<K, V>(notifyWhenEqual: notifyWhenEqual);
    }
    return result;
  }

  /// Creates a new observable map wrapping [other].
  ObservableMap.spy(Map<K, V> other, {this.notifyWhenEqual = false})
      : _map = other;

  @override
  Iterable<K> get keys => _map.keys;

  @override
  Iterable<V> get values => _map.values;

  @override
  int get length => _map.length;

  @override
  bool get isEmpty => length == 0;

  @override
  bool get isNotEmpty => !isEmpty;

  @override
  bool containsValue(Object? value) => _map.containsValue(value);

  @override
  bool containsKey(Object? key) => _map.containsKey(key);

  @override
  bool operator ==(Object other) {
    if (other is ObservableMap<K, V>) {
      return _map == other._map;
    } else if (other is Map<K, V>) {
      return _map == other;
    }
    return false;
  }

  @override
  int get hashCode {
    return _map.hashCode;
  }

  @override
  V? operator [](Object? key) => _map[key];

  @override
  void operator []=(K key, V value) {
    if (!hasObservers) {
      _map[key] = value;
      return;
    }

    var len = _map.length;
    var oldValue = _map[key];

    _map[key] = value;

    if (len != _map.length) {
      notifyPropertyChange(#length, len, _map.length);
      notifyChange(MapChangeRecord<K, V>.insert(key, value));
      _notifyKeysValuesChanged();
    } else if (notifyWhenEqual || oldValue != value) {
      notifyChange(MapChangeRecord<K, V>(key, oldValue, value));
      _notifyValuesChanged();
    }
  }

  @override
  void addAll(Map<K, V> other) {
    other.forEach((K key, V value) {
      this[key] = value;
    });
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    var len = _map.length;
    var result = _map.putIfAbsent(key, ifAbsent);
    if (hasObservers && len != _map.length) {
      notifyPropertyChange(#length, len, _map.length);
      notifyChange(MapChangeRecord<K, V>.insert(key, result));
      _notifyKeysValuesChanged();
    }
    return result;
  }

  @override
  V? remove(Object? key) {
    var len = _map.length;
    var result = _map.remove(key);
    if (hasObservers && len != _map.length) {
      notifyChange(MapChangeRecord<K, V>.remove(key as K, result));
      notifyPropertyChange(#length, len, _map.length);
      _notifyKeysValuesChanged();
    }
    return result;
  }

  @override
  void clear() {
    var len = _map.length;
    if (hasObservers && len > 0) {
      _map.forEach((key, value) {
        notifyChange(MapChangeRecord<K, V>.remove(key, value));
      });
      notifyPropertyChange(#length, len, 0);
      _notifyKeysValuesChanged();
    }
    _map.clear();
  }

  @override
  void forEach(void Function(K key, V value) f) => _map.forEach(f);

  @override
  String toString() => MapBase.mapToString(this);

  @override
  ObservableMap<K2, V2> cast<K2, V2>() {
    return ObservableMap.castFrom<K, V, K2, V2>(this);
  }

  @override
  Iterable<MapEntry<K, V>> get entries => _map.entries;

  @override
  void addEntries(Iterable<MapEntry<K, V>> entries) {
    _map.addEntries(entries);
  }

  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) transform) {
    return _map.map(transform);
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    return _map.update(key, update, ifAbsent: ifAbsent);
  }

  @override
  void updateAll(V Function(K key, V value) update) => _map.updateAll(update);

  @override
  void removeWhere(bool Function(K key, V value) test) =>
      _map.removeWhere(test);

  // Note: we don't really have a reasonable old/new value to use here.
  // But this should fix "keys" and "values" in templates with minimal overhead.
  void _notifyKeysValuesChanged() {
    notifyChange(
        PropertyChangeRecord<Object?, Symbol>(this, #keys, null, null));
    _notifyValuesChanged();
  }

  void _notifyValuesChanged() {
    notifyChange(
        PropertyChangeRecord<Object?, Symbol>(this, #values, null, null));
  }
}
