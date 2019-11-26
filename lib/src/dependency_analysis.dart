import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Dependencies for library at `package:` [uri] under some configuration of
/// declared variables.
class LibraryDependencies {
  final Uri uri;
  final Set<Uri> dependencies;

  LibraryDependencies(this.uri, Iterable<Uri> dependencies)
      : dependencies = Set.from(dependencies);

  @override
  String toString() => '[library at \'$uri\' depends on '
      '${dependencies.map((u) => "'$u'").join(", ")}]';
}

/// Parse dependencies (import/export directives) of library at `package:`
/// [uri], returns `null` if the file is a part or parsing fails.
///
/// This returns dependencies as `package:` [Uri]'s using the declared-variables
/// given to the analysis context. Hence, the [LibraryDependencies] object
/// returned is specific the the declared-variables.
LibraryDependencies parseDependencies(AnalysisSession session, Uri uri) {
  final unitResult = session.getParsedUnit(
    session.uriConverter.uriToPath(uri),
  );
  if (unitResult.isPart || unitResult.unit == null) {
    // TODO: Verify that part files cannot contain import/export directives.
    //       And see if we can ensure this code is updated if that changes.
    return null;
  }
  final dependencies = <Uri>{};
  for (final node in unitResult.unit.sortedDirectivesAndDeclarations) {
    if (node is! ImportDirective && node is! ExportDirective) {
      continue;
    }
    // We have:
    //
    //    directive ::=
    //        'import' stringLiteral (configuration)*
    //      | 'export' stringLiteral (configuration)*
    //
    // Hence, we have dependency upon `directive.uri` resolved relative to this
    // library `uri`. Unless there is a `configuration` for which the `test`
    // evaluates to true.
    final directive = node as NamespaceDirective;
    var dependency = uri.resolve(directive.uri.stringValue);

    for (final configuration in directive.configurations) {
      // We have:
      //
      //    configuration ::=
      //        'if' '(' test ')' uri
      //
      //    test ::=
      //        dottedName ('==' stringLiteral)?

      // Get the dottedName
      final dottedName = configuration.name.toString();

      // Get the value that `dottedName` is declared as:
      final value = session.declaredVariables.get(dottedName);

      if (configuration.equalToken != null) {
        // If `configuration` has an `equalToken`, we must compare value against
        // the `stringLiteral` in the test.
        if (configuration.value != null &&
            configuration.value.stringValue == value) {
          dependency = uri.resolve(configuration.uri.stringValue);
          break; // always pick the first satisfied configuration
        }
      } else {
        // If `configuration` doesn't have an `equalToken` then the `value` that
        // `dottedName` was declared as must be 'true' or 'false', or we have
        // an error.
        if (value == 'true') {
          dependency = uri.resolve(configuration.uri.stringValue);
          break; // always pick the first satisfied configuration
        } else if (value == 'false') {
          continue; // skip configuration that is false.
        } else {
          // Error, the dottedName variable is unknown. For the purpose of
          // dependency analysis we can simply ignore this configuration.
          // The configuration is probably not active.
          continue;
        }
      }
    }

    //TODO: Determine if there is any need to normalize the `dependency` Uri
    // Add the dependency that was decided above.
    dependencies.add(dependency);
  }
  return LibraryDependencies(uri, dependencies);
}
