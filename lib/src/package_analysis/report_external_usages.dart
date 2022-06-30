import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'shapes.dart';

/// Returns the package name from a library identifier/uri, or null if
/// [libraryUri] isn't of the form `package:*/*`.
///
/// Example:
/// `packageFromLibraryUri('package:my_package/my_library.dart')` returns
/// `'my_package'`.
String? packageFromLibraryUri(String libraryUri) {
  if (libraryUri.startsWith('package:') && libraryUri.contains('/')) {
    final endIndex = libraryUri.indexOf('/');
    return libraryUri.substring(8, endIndex);
  }
  return null;
}

class MyAstVisitor extends GeneralizingAstVisitor {
  final requiredFunctions = <String, Set<String>>{};
  final requiredMethods = <String, Set<String>>{};

  /// The name of the package being analysed. Invocations corresponding to
  /// definitions within this package will be ignored.
  final String? rootPackage;

  final void Function(String) warning;

  MyAstVisitor({required this.rootPackage, required this.warning});

  @override
  void visitInvocationExpression(InvocationExpression node) {
    if (node is FunctionExpressionInvocation) {
      // this branch runs in cases like this, and possibly some others:
      // void f(void Function() sayHello) {
      //   sayHello();
      // }
      // TODO: figure out if we're interested in callbacks
    } else if (node is MethodInvocation) {
      var element = node.methodName.staticElement;
      if (element != null) {
        var libraryUri = element.library!.identifier;
        var symbolName = element.name;
        var packageName = packageFromLibraryUri(libraryUri);

        // if the required conditions are met, record the name of the symbol
        if (packageName != null &&
            packageName != rootPackage &&
            element.enclosingElement is! ExtensionElement) {
          if (element.enclosingElement is ClassElement) {
            if (!requiredMethods.containsKey(packageName)) {
              requiredMethods[packageName] = <String>{};
            }
            requiredMethods[packageName]!.add(symbolName!);
          } else if (element.enclosingElement is CompilationUnitElement) {
            if (!requiredFunctions.containsKey(packageName)) {
              requiredFunctions[packageName] = <String>{};
            }
            requiredFunctions[packageName]!.add(symbolName!);
          }
        }
      }
    } else {
      warning('Failed to resolve node subclass.');
    }

    super.visitInvocationExpression(node);
  }
}

Future<RequiredSymbols> reportUsages(
  PackageAnalysisContext packageAnalysisContext,
  String packageLocation,
  String? rootPackageName,
) async {
  var collection = packageAnalysisContext.analysisContextCollection;
  var astVisitor = MyAstVisitor(
    rootPackage: rootPackageName,
    warning: packageAnalysisContext.warning,
  );

  for (var context in collection.contexts) {
    final session = context.currentSession;

    for (var filePath in context.contextRoot.analyzedFiles()) {
      // match [packageLocation]/lib/*.dart
      if (!(path.isWithin(path.join(packageLocation, 'lib'), filePath) &&
          path.extension(filePath) == '.dart')) {
        continue;
      }

      var result = await session.getResolvedUnit(filePath);
      if (result is ResolvedUnitResult) {
        var unit = result.unit;
        astVisitor.visitCompilationUnit(unit);
      } else {
        packageAnalysisContext.warning(
            'Attempting to get a resolved unit resulted in an invalid result.');
      }
    }
  }

  return RequiredSymbols(
    functions: astVisitor.requiredFunctions,
    methods: astVisitor.requiredMethods,
  );
}
