// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/element/element.dart';

enum Kind { method, function, getter, setter }

enum ParentKind { classKind, extensionKind, enumKind }

extension KindConverter on ElementKind {
  static const _kindMap = <ElementKind, Kind>{
    ElementKind.METHOD: Kind.method,
    ElementKind.FUNCTION: Kind.function,
    ElementKind.GETTER: Kind.getter,
    ElementKind.SETTER: Kind.setter,
  };
  static const _parentKindMap = <ElementKind, ParentKind>{
    ElementKind.CLASS: ParentKind.classKind,
    ElementKind.EXTENSION: ParentKind.extensionKind,
    ElementKind.ENUM: ParentKind.enumKind,
  };

  Kind toKind() {
    if (_kindMap.containsKey(this)) {
      return _kindMap[this]!;
    } else {
      throw StateError('Unexpected identifier ElementKind $this.');
    }
  }

  ParentKind toParentKind() {
    if (_parentKindMap.containsKey(this)) {
      return _parentKindMap[this]!;
    } else {
      throw StateError('Unexpected parent ElementKind $this.');
    }
  }
}
