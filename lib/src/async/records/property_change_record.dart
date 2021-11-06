// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of change_notifier.src.records;

/// A change record to a field of a generic observable object.
class PropertyChangeRecord<T, K> implements ChangeRecord {
  /// Object that changed.
  final Object object;

  /// Identifier of the property that changed.
  final K name;

  /// Previous value of the property.
  final T oldValue;

  /// New value of the property.
  final T newValue;

  const PropertyChangeRecord(
    this.object,
    this.name,
    this.oldValue,
    this.newValue,
  );

  @override
  bool operator ==(Object other) =>
      other is PropertyChangeRecord<T, K> &&
      identical(object, other.object) &&
      name == other.name &&
      oldValue == other.oldValue &&
      newValue == other.newValue;

  @override
  int get hashCode => hash4(object, name, oldValue, newValue);

  @override
  String toString() => ''
      '#<$PropertyChangeRecord $name from $oldValue to: $newValue>';
}
