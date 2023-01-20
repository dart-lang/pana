// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Characters that will be used in the reduced filename.
final _acceptedFileCharacters = RegExp(r'[a-z0-9]');

/// File-based data access to cached files in PANA_CACHE.
class PanaCache {
  final _PanaCacheStorage _storage;
  final Duration _ttl;

  PanaCache._(this._storage, this._ttl);

  factory PanaCache({
    String? path,
    Duration? ttl,
  }) {
    final storage =
        path == null ? _MemoryPanaCacheStorage() : _FilePanaCacheStorage(path);
    return PanaCache._(storage, ttl ?? const Duration(hours: 4));
  }

  Future<Map<String, dynamic>?> readData(
    String type,
    String id, {
    Duration? ttl,
  }) async {
    ttl ??= _ttl;
    final path = _filePath(type, id);
    final bytes = await _storage.readBytes(path);
    if (bytes == null) {
      return null;
    }
    final map = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
    final storedId = map['id'] as String;
    if (storedId != id) {
      return null;
    }

    final ts = DateTime.parse(map['ts'] as String);
    if (ts.add(ttl).isBefore(DateTime.now())) {
      await _storage.delete(path);
      return null;
    }

    return map['data'] as Map<String, dynamic>?;
  }

  Future<void> writeData(
    String type,
    String id,
    Map<String, dynamic> data,
  ) async {
    final bytes = utf8.encode(json.encode({
      'id': id,
      'ts': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    }));
    await _storage.writeBytes(_filePath(type, id), bytes);
  }

  String _filePath(String type, String id) {
    final hash = sha256.convert(utf8.encode(id)).toString();
    var reducedId = _acceptedFileCharacters
        .allMatches(id.toLowerCase())
        .map((e) => e.group(0))
        .join();
    if (reducedId.length > 40) {
      reducedId = reducedId.substring(0, 40);
    }
    final baseName = [if (reducedId.isNotEmpty) reducedId, hash].join('-');
    return p.join(type, '$baseName.json');
  }
}

abstract class _PanaCacheStorage {
  Future<void> writeBytes(String path, List<int> bytes);
  Future<List<int>?> readBytes(String path);
  Future<void> delete(String path);
}

class _FilePanaCacheStorage implements _PanaCacheStorage {
  final String _dir;
  _FilePanaCacheStorage(this._dir);

  @override
  Future<void> writeBytes(String path, List<int> bytes) async {
    final file = File(p.join(_dir, path));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  @override
  Future<List<int>?> readBytes(String path) async {
    final file = File(p.join(_dir, path));
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<void> delete(String path) async {
    final file = File(p.join(_dir, path));
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class _MemoryPanaCacheStorage implements _PanaCacheStorage {
  final _cache = <String, List<int>>{};

  @override
  Future<void> writeBytes(String path, List<int> bytes) async {
    _cache[path] = bytes;
  }

  @override
  Future<List<int>?> readBytes(String path) async {
    return _cache[path];
  }

  @override
  Future<void> delete(String path) async {
    _cache.remove(path);
  }
}
