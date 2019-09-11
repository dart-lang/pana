// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection' show UnmodifiableListView, UnmodifiableMapView;
import 'package:meta/meta.dart' show sealed, required;

/// Valid field names in [TagPattern].
final _fieldNamePattern = RegExp(r'^[a-z][a-z0-9-]*$');

/// Characters allowed in tags.
///
/// Do **NOT** change this expression without discussion with pub.dev owners.
/// Changing this will affect UX and could break APIs, it's for a good reason
/// that tags cannot contain spaces.
final _tagCharacters = 'a-z:A-Z0-9+.*_-'; // RELAX THIS WITH CARE

/// Pattern that all tags must satisfy.
final _tagPattern = RegExp('^[a-z][$_tagCharacters]*\$'); // DO NOT RELAX THIS

/// List of all alllowed tagging patterns.
///
/// Package analysis can associate tags with a package, these tags are fairly
/// free-form. But we require that all patterns used are registered here.
/// Tags will be validated against this list when created.
final List<TagPattern> tagPatterns = UnmodifiableListView([
  TagPattern(
    pattern: 'license:<license>',
    fields: {
      'license': 'SPDX license identifier',
    },
    description: 'License under which the package is distributed',
  ),
]);

/// Find registered [TagPattern] from [tagPatterns] that matches [tag].
///
/// Returns a [TagPattern] or `null` if [tag] does match a registered
/// [TagPattern].
TagPattern findTagPattern(String tag) => tagPatterns.firstWhere(
      (p) => p.match(tag),
      orElse: () => null,
    );

/// Returns `true` if tag is a valid tag that matches a registered [TagPattern].
bool isValidTag(String tag) =>
    _tagPattern.hasMatch(tag) && findTagPattern(tag) != null;

/// Description of a tagging pattern.
@sealed
class TagPattern {
  /// A tag pattern, optionally containing `<fields>`.
  ///
  /// Example: `license:<license-identifier>`, all fields must be specified
  /// in the [fields] property.
  final String pattern;

  /// Mapping from _field name_ to field description.
  final Map<String, String> fields;

  /// Description of what this tagging pattern covers.
  final String description;

  /// Lazily created validator
  RegExp _validator;

  /// Define a [TagPattern], this should only be used in [tagPatterns].
  TagPattern({
    @required this.pattern,
    Map<String, String> fields = const {},
    @required this.description,
  }) : fields = UnmodifiableMapView(fields) {
    ArgumentError.checkNotNull(pattern, 'pattern');
    ArgumentError.checkNotNull(fields, 'fields');
    ArgumentError.checkNotNull(description, 'description');

    // Ensure fields match a reasonable pattern
    if (!fields.keys.every(_fieldNamePattern.hasMatch)) {
      throw ArgumentError.value(
          fields, 'fields', 'Field names must match $_fieldNamePattern');
    }

    // Check that pattern doesn't start with a field
    if (pattern.startsWith('<')) {
      throw ArgumentError.value(
          pattern, 'pattern', 'Patterns cannot start with a field');
    }

    // Replace all fields with empty-string and validate the result.
    // This ensures that all fields used in the string are listed in [fields].
    final fakeTag = fields.keys.fold<String>(
      pattern,
      (p, field) => p.replaceAll('<$field>', ''),
    );
    if (!_tagPattern.hasMatch(fakeTag)) {
      throw ArgumentError.value(pattern, 'pattern',
          'must match $_tagPattern when fields are removed');
    }

    // Check that all fields are used.
    if (!fields.keys.every((field) => pattern.contains('<$field>'))) {
      throw ArgumentError.value(
          fields, 'fields', 'All fields must be present in tag pattern');
    }
  }

  /// Return `true` if [tag] matches this tagging pattern.
  bool match(String tag) {
    // Lazily create and cache validator pattern.
    _validator ??= RegExp('^' +
        fields.keys.fold<String>(
          pattern,
          (p, field) => p.replaceAll('<$field>', '[$_tagCharacters]*'),
        ) +
        '\$');

    ArgumentError.checkNotNull(tag, 'tag');

    return _validator.hasMatch(tag);
  }
}
