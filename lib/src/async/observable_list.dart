// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: deprecated_member_use_from_same_package
library change_notifier.src.observable_list;

import 'dart:async';
import 'dart:collection' show ListBase, UnmodifiableListView;

import 'differs.dart';
import 'change_notifier.dart';
import 'records.dart';

/// Represents an observable list of model values. If any items are added,
/// removed, or replaced, then observers that are listening to [changes]
/// will be notified.
class ObservableList<E> extends ListBase<E>
    with AsyncChangeNotifier, PropertyChangeNotifier<Symbol> {
  /// Adapts [source] to be a `ObservableList<T>`.
  ///
  /// Any time the list would produce an element that is not a [T],
  /// the element access will throw.
  ///
  /// Any time a [T] value is attempted stored into the adapted list,
  /// the store will throw unless the value is also an instance of [S].
  ///
  /// If all accessed elements of [source] are actually instances of [T],
  /// and if all elements stored into the returned list are actually instance
  /// of [S], then the returned list can be used as a `ObservableList<T>`.
  static ObservableList<T> castFrom<S, T>(ObservableList<S> source) =>
      ObservableList<T>.spy(source._list.cast<T>(),
          notifyWhenEqual: source.notifyWhenEqual);

  List<ListChangeRecord<E>>? _listRecords;

  StreamController<List<ListChangeRecord<E>>>? _listChanges;

  /// The inner [List<E>] with the actual storage.
  final List<E> _list;

  /// Whether to notify when an index is set to the same value.
  final bool notifyWhenEqual;

  /// Creates an empty observable list.
  ObservableList({this.notifyWhenEqual = false}) : _list = <E>[];

  /// Creates an observable list with the elements of [other]. The order in
  /// the list will be the order provided by the iterator of [other].
  ObservableList.from(Iterable<E> other, {this.notifyWhenEqual = false})
      : _list = List<E>.from(other);

  ObservableList.spy(List<E> other, {this.notifyWhenEqual = false})
      : _list = other;

  /// Returns a view of this list as a list of [T] instances.
  ///
  /// If this list contains only instances of [T], all read operations
  /// will work correctly. If any operation tries to access an element
  /// that is not an instance of [T], the access will throw instead.
  ///
  /// Elements added to the list (e.g., by using [add] or [addAll])
  /// must be instance of [T] to be valid arguments to the adding function,
  /// and they must be instances of [E] as well to be accepted by
  /// this list as well.
  @override
  ObservableList<T> cast<T>() => ObservableList.castFrom<E, T>(this);

  /// The stream of summarized list changes, delivered asynchronously.
  ///
  /// Each list change record contains information about an individual mutation.
  /// The records are projected so they can be applied sequentially. For
  /// example, this set of mutations:
  ///
  ///     var model = new ObservableList.from(['a', 'b']);
  ///     model.listChanges.listen((records) => records.forEach(print));
  ///     model.removeAt(1);
  ///     model.insertAll(0, ['c', 'd', 'e']);
  ///     model.removeRange(1, 3);
  ///     model.insert(1, 'f');
  ///
  /// The change records will be summarized so they can be "played back", using
  /// the final list positions to figure out which item was added:
  ///
  ///     #<ListChangeRecord index: 0, removed: [], addedCount: 2>
  ///     #<ListChangeRecord index: 3, removed: [b], addedCount: 0>
  ///
  /// [deliverChanges] can be called to force synchronous delivery.
  Stream<List<ListChangeRecord<E>>> get listChanges {
    _listChanges ??= StreamController.broadcast(
      sync: true,
      onCancel: () {
        _listChanges = null;
      },
    );
    return _listChanges!.stream;
  }

  bool get hasListObservers => _listChanges?.hasListener ?? false;

  @override
  int get length => _list.length;

  @override
  set length(int value) {
    var len = _list.length;
    if (len == value) return;

    // Produce notifications if needed
    _notifyChangeLength(len, value);
    if (hasListObservers) {
      if (value < len) {
        _notifyListChange(value, removed: _list.getRange(value, len).toList());
      } else {
        _notifyListChange(len, addedCount: value - len);
      }
    }

    _list.length = value;
  }

  @override
  bool operator ==(Object other) {
    if (other is ObservableList<E>) {
      return _list == other._list;
    } else if (other is List<E>) {
      return _list == other;
    }
    return false;
  }

  @override
  int get hashCode {
    return _list.hashCode;
  }

  @override
  E operator [](int index) => _list[index];

  @override
  void operator []=(int index, E value) {
    var oldValue = _list[index];
    if (hasListObservers && (notifyWhenEqual || oldValue != value)) {
      _notifyListChange(index, addedCount: 1, removed: [oldValue]);
    }
    _list[index] = value;
  }

  // Forwarders so we can reflect on the properties.
  @override
  bool get isEmpty => super.isEmpty;

  @override
  bool get isNotEmpty => super.isNotEmpty;

  // TODO(jmesserly): should we support first/last/single? They're kind of
  // dangerous to use in a path because they throw exceptions. Also we'd need
  // to produce property change notifications which seems to conflict with our
  // existing list notifications.

  // The following methods are here so that we can provide nice change events.
  @override
  void setAll(int index, Iterable<E> iterable) {
    if (iterable is! List && iterable is! Set) {
      iterable = iterable.toList();
    }
    var length = iterable.length;
    if (hasListObservers && length > 0) {
      _notifyListChange(index,
          addedCount: length, removed: _list.sublist(index, length));
    }
    _list.setAll(index, iterable);
  }

  @override
  void add(E element) {
    var len = _list.length;
    _notifyChangeLength(len, len + 1);
    if (hasListObservers) {
      _notifyListChange(len, addedCount: 1);
    }

    _list.add(element);
  }

  @override
  void addAll(Iterable<E> iterable) {
    var len = _list.length;
    _list.addAll(iterable);

    _notifyChangeLength(len, _list.length);

    var added = _list.length - len;
    if (hasListObservers && added > 0) {
      _notifyListChange(len, addedCount: added);
    }
  }

  @override
  bool remove(Object? element) {
    for (var i = 0; i < length; i++) {
      if (this[i] == element) {
        removeRange(i, i + 1);
        return true;
      }
    }
    return false;
  }

  @override
  void removeRange(int start, int end) {
    _rangeCheck(start, end);
    var rangeLength = end - start;
    var len = _list.length;

    _notifyChangeLength(len, len - rangeLength);
    if (hasListObservers && rangeLength > 0) {
      _notifyListChange(start, removed: _list.getRange(start, end).toList());
    }

    _list.removeRange(start, end);
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    if (index < 0 || index > length) {
      throw RangeError.range(index, 0, length);
    }
    // TODO(floitsch): we can probably detect more cases.
    if (iterable is! List && iterable is! Set) {
      iterable = iterable.toList();
    }
    var len = _list.length;

    _list.insertAll(index, iterable);

    _notifyChangeLength(len, _list.length);

    var insertionLength = length - len;
    if (hasListObservers && insertionLength > 0) {
      _notifyListChange(index, addedCount: insertionLength);
    }
  }

  @override
  void insert(int index, E element) {
    if (index == length) {
      add(element);
      return;
    }
    // We are modifying the length just below these checks. Without the checks
    // Array.copy could throw an exception, leaving the list in a bad state
    // (with a length that has been increased, but without a new element).
    RangeError.checkValidIndex(index, this);
    
    _list
      // Increase the length by adding [element], in case [E] isn't nullable.
      ..add(element)
      ..setRange(index + 1, length, this, index);

    _notifyChangeLength(_list.length - 1, _list.length);
    if (hasListObservers) {
      _notifyListChange(index, addedCount: 1);
    }
    _list[index] = element;
  }

  @override
  E removeAt(int index) {
    var result = this[index];
    removeRange(index, index + 1);
    return result;
  }

  void _rangeCheck(int start, int end) {
    if (start < 0 || start > length) {
      throw RangeError.range(start, 0, length);
    }
    if (end < start || end > length) {
      throw RangeError.range(end, start, length);
    }
  }

  void _notifyListChange(
    int index, {
    List<E>? removed,
    int addedCount = 0,
  }) {
    if (!hasListObservers) return;
    if (_listRecords == null) {
      _listRecords = [];
      scheduleMicrotask(deliverListChanges);
    }
    _listRecords!.add(ListChangeRecord<E>(
      this,
      index,
      removed: removed,
      addedCount: addedCount,
    ));
  }

  void _notifyChangeLength(int oldValue, int newValue) {
    notifyPropertyChange(#length, oldValue, newValue);
    notifyPropertyChange(#isEmpty, oldValue == 0, newValue == 0);
    notifyPropertyChange(#isNotEmpty, oldValue != 0, newValue != 0);
  }

  void discardListChanges() {
    // Leave _listRecords set so we don't schedule another delivery.
    if (_listRecords != null) _listRecords = [];
  }

  bool deliverListChanges() {
    if (_listRecords == null) return false;
    //projectListSplices removes equal entries so skip the call when requested
    final records = projectListSplices<E>(this, _listRecords!,
        notifyWhenEqual: notifyWhenEqual);
    _listRecords = null;

    if (hasListObservers && records.isNotEmpty) {
      _listChanges!.add(UnmodifiableListView<ListChangeRecord<E>>(records));
      return true;
    }
    return false;
  }

  /// Calculates the changes to the list, if lacking individual splice mutation
  /// information.
  ///
  /// This is not needed for change records produced by [ObservableList] itself,
  /// but it can be used if the list instance was replaced by another list.
  ///
  /// The minimal set of splices can be synthesized given the previous state and
  /// final state of a list. The basic approach is to calculate the edit
  /// distance matrix and choose the shortest path through it.
  ///
  /// Complexity is `O(l * p)` where `l` is the length of the current list and
  /// `p` is the length of the old list.
  static List<ListChangeRecord<E>> calculateChangeRecords<E>(
    List<E> oldValue,
    List<E> newValue,
  ) {
    return ListDiffer<E>().diff(oldValue, newValue);
  }

  /// Updates the [previous] list using the [changeRecords]. For added items,
  /// the [current] list is used to find the current value.
  static void applyChangeRecords<E>(List<Object> previous, List<Object> current,
      List<ListChangeRecord<E>> changeRecords) {
    if (identical(previous, current)) {
      throw ArgumentError("can't use same list for previous and current");
    }

    for (var change in changeRecords) {
      var addEnd = change.index + change.addedCount;
      var removeEnd = change.index + change.removed.length;

      var addedItems = current.getRange(change.index, addEnd);
      previous.replaceRange(change.index, removeEnd, addedItems);
    }
  }
}
