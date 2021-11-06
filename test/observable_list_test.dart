// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:change_notifier/change_notifier.dart';
import 'package:test/test.dart';

import 'observable_test_utils.dart';

void main() {
  // TODO(jmesserly): need all standard List API tests.

  StreamSubscription<Object>? sub, sub2;

  tearDown(() {
    sub?.cancel();
    sub2?.cancel();
  });

  group('observe length', () {
    List<ChangeRecord>? changes;

    setUp(() {
      list = toObservableList(<int?>[1, 2, 3]);
      changes = null;
      sub = list.changes.listen((records) {
        changes = getPropertyChangeRecords(records, #length);
      });
    });

    test('add changes length', () {
      list.add(4);
      expect(list, [1, 2, 3, 4]);
      return Future(() {
        expect(changes, changeMatchers([_lengthChange(3, 4)]));
      });
    });

    test('removeObject changes length', () {
      list.remove(2);
      expect(list, orderedEquals(<int>[1, 3]));

      return Future(() {
        expect(changes, changeMatchers([_lengthChange(3, 2)]));
      });
    });

    test('removeRange changes length', () {
      list
        ..add(4)
        ..removeRange(1, 3);
      expect(list, [1, 4]);
      return Future(() {
        expect(changes,
            changeMatchers([_lengthChange(3, 4), _lengthChange(4, 2)]));
      });
    });

    test('removeWhere changes length', () {
      list
        ..add(2)
        ..removeWhere((e) => e == 2);
      expect(list, [1, 3]);
      return Future(() {
        expect(changes,
            changeMatchers([_lengthChange(3, 4), _lengthChange(4, 2)]));
      });
    });

    test('length= changes length', () {
      list.length = 5;
      expect(list, [1, 2, 3, null, null]);
      return Future(() {
        expect(changes, changeMatchers([_lengthChange(3, 5)]));
      });
    });

    test('[]= does not change length', () {
      list[2] = 9000;
      expect(list, [1, 2, 9000]);
      return Future(() {
        expect(changes, null);
      });
    });

    test('clear changes length', () {
      list.clear();
      expect(list, <Object>[]);
      return Future(() {
        expect(changes, changeMatchers([_lengthChange(3, 0)]));
      });
    });
  });

  group('observe index', () {
    List<ListChangeRecord<int?>>? changes;

    setUp(() {
      list = toObservableList([1, 2, 3]);
      changes = null;
      sub = list.listChanges.listen((List<ListChangeRecord<int?>> records) {
        changes = getListChangeRecords(records, 1);
      });
    });

    test('add does not change existing items', () {
      list.add(4);
      expect(list, [1, 2, 3, 4]);
      return Future(() {
        expect(changes, <Object>[]);
      });
    });

    test('[]= changes item', () {
      list[1] = 777;
      expect(list, [1, 777, 3]);
      return Future(() {
        expect(changes, [
          _change(1, addedCount: 1, removed: <int>[2])
        ]);
      });
    });

    test('[]= on a different item does not fire change', () {
      list[2] = 9000;
      expect(list, [1, 2, 9000]);
      return Future(() {
        expect(changes, <Object>[]);
      });
    });

    test('set multiple times results in one change', () {
      list[1] = 777;
      list[1] = 42;
      expect(list, [1, 42, 3]);
      return Future(() {
        expect(changes, [
          _change(1, addedCount: 1, removed: [2]),
        ]);
      });
    });

    test('set length without truncating item means no change', () {
      list.length = 2;
      expect(list, [1, 2]);
      return Future(() {
        expect(changes, <Object>[]);
      });
    });

    test('truncate removes item', () {
      list.length = 1;
      expect(list, [1]);
      return Future(() {
        expect(changes, [
          _change(1, removed: [2, 3])
        ]);
      });
    });

    test('truncate and add new item', () {
      list.length = 1;
      list.add(42);
      expect(list, [1, 42]);
      return Future(() {
        expect(changes, [
          _change(1, removed: [2, 3], addedCount: 1)
        ]);
      });
    });

    test('truncate and add same item', () {
      list.length = 1;
      list.add(2);
      expect(list, [1, 2]);
      return Future(() {
        expect(changes, <Object>[]);
      });
    });
  });

  test('toString', () {
    list = toObservableList([1, 2, 3]);
    expect(list.toString(), '[1, 2, 3]');
  });

  group('change records', () {
    List<ChangeRecord>? propRecords;
    List<ListChangeRecord<int?>>? listRecords;

    setUp(() {
      list = toObservableList([1, 2, 3, 1, 3, 4]);
      propRecords = null;
      listRecords = null;
      sub = list.changes.listen((r) => propRecords = r);
      sub2 = list.listChanges.listen((r) => listRecords = r);
    });

    test('read operations', () {
      expect(list.length, 6);
      expect(list[0], 1);
      expect(list.indexOf(4), 5);
      expect(list.indexOf(1), 0);
      expect(list.indexOf(1, 1), 3);
      expect(list.lastIndexOf(1), 3);
      expect(list.last, 4);
      var copy = <int?>[];
      list.forEach(copy.add);
      expect(copy, orderedEquals(<int>[1, 2, 3, 1, 3, 4]));
      return Future(() {
        // no change from read-only operators
        expect(propRecords, null);
        expect(listRecords, null);
      });
    });

    test('add', () {
      list
        ..add(5)
        ..add(6);
      expect(list, orderedEquals(<int>[1, 2, 3, 1, 3, 4, 5, 6]));

      return Future(() {
        expect(
            propRecords,
            changeMatchers([
              _lengthChange(6, 7),
              _lengthChange(7, 8),
            ]));
        expect(listRecords, [_change(6, addedCount: 2)]);
      });
    });

    test('[]=', () {
      list[1] = list.last;
      expect(list, orderedEquals(<int>[1, 4, 3, 1, 3, 4]));

      return Future(() {
        expect(propRecords, null);
        expect(listRecords, [
          _change(1, addedCount: 1, removed: <int>[2])
        ]);
      });
    });

    test('removeLast', () {
      expect(list.removeLast(), 4);
      expect(list, orderedEquals(<int>[1, 2, 3, 1, 3]));

      return Future(() {
        expect(propRecords, changeMatchers([_lengthChange(6, 5)]));
        expect(listRecords, [
          _change(5, removed: <int>[4])
        ]);
      });
    });

    test('removeRange', () {
      list.removeRange(1, 4);
      expect(list, orderedEquals(<int>[1, 3, 4]));

      return Future(() {
        expect(propRecords, changeMatchers([_lengthChange(6, 3)]));
        expect(listRecords, [
          _change(1, removed: <int>[2, 3, 1])
        ]);
      });
    });

    test('removeWhere', () {
      list.removeWhere((e) => e == 3);
      expect(list, orderedEquals(<int>[1, 2, 1, 4]));

      return Future(() {
        expect(propRecords, changeMatchers([_lengthChange(6, 4)]));
        expect(listRecords, [
          _change(2, removed: <int>[3]),
          _change(3, removed: <int>[3])
        ]);
      });
    });

    test('sort', () {
      list.sort((x, y) => x! - y!);
      expect(list, orderedEquals(<int>[1, 1, 2, 3, 3, 4]));

      return Future(() {
        expect(propRecords, null);
        expect(listRecords, [
          _change(1, addedCount: 1),
          _change(4, removed: <int>[1])
        ]);
      });
    });

    test('sort of 2 elements', () {
      var list = toObservableList([3, 1]);
      // Dummy listener to record changes.
      // TODO(jmesserly): should we just record changes always,
      //  to support the sync api?
      sub = list.listChanges.listen((Object records) {});
      list.sort();
      expect(list.deliverListChanges(), true);
      list.sort();
      expect(list.deliverListChanges(), false);
      list.sort();
      expect(list.deliverListChanges(), false);
    });

    test('clear', () {
      list.clear();
      expect(list, <Object>[]);

      return Future(() {
        expect(
            propRecords,
            changeMatchers([
              _lengthChange(6, 0),
              PropertyChangeRecord<bool, Symbol>(list, #isEmpty, false, true),
              PropertyChangeRecord<bool, Symbol>(
                  list, #isNotEmpty, true, false),
            ]));
        expect(listRecords, [
          _change(0, removed: <int>[1, 2, 3, 1, 3, 4])
        ]);
      });
    });
  });
}

late ObservableList<int?> list;

PropertyChangeRecord<int, Symbol> _lengthChange(int oldValue, int newValue) =>
    PropertyChangeRecord<int, Symbol>(list, #length, oldValue, newValue);

ListChangeRecord<int?> _change(int index,
        {List<int> removed = const [], int addedCount = 0}) =>
    ListChangeRecord(list, index, removed: removed, addedCount: addedCount);
