import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/file_system.dart' hide File;
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/source/package_map_resolver.dart';
import 'package:analyzer/source/pub_package_map_provider.dart';
import 'package:analyzer/src/dart/sdk/sdk.dart' show FolderBasedDartSdk;
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/sdk.dart' show DartSdk;
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:cli_util/cli_util.dart' as cli;
import 'package:path/path.dart' as p;

import 'utils.dart';

class LibraryScanner {
  final String _package;
  final String _projectPath;
  final UriResolver _packageResolver;
  final AnalysisContext _context;
  final Map<String, List<String>> _cachedLibs = {};

  LibraryScanner._(
      this._package, this._projectPath, this._packageResolver, this._context);

  factory LibraryScanner(String package, String projectPath) {
    // TODO: fail more clearly if this...fails
    var sdkPath = cli.getSdkDir().path;

    JavaSystemIO.setProperty("com.google.dart.sdk", sdkPath);
    var resourceProvider = PhysicalResourceProvider.INSTANCE;
    DartSdk sdk = new FolderBasedDartSdk(
        resourceProvider, resourceProvider.getFolder(sdkPath));

    var dotPackagesPath = p.join(projectPath, '.packages');
    if (!FileSystemEntity.isFileSync(dotPackagesPath)) {
      throw new StateError('A package configuration file was not found at the '
          'expectetd location. $dotPackagesPath');
    }
    var pubPackageMapProvider =
        new PubPackageMapProvider(PhysicalResourceProvider.INSTANCE, sdk);
    var packageMapInfo = pubPackageMapProvider.computePackageMap(
        PhysicalResourceProvider.INSTANCE.getResource(projectPath));
    var packageMap = packageMapInfo.packageMap;
    if (packageMap == null) {
      throw new StateError('An error occurred getting the package map.');
    }
    UriResolver packageResolver = new PackageMapUriResolver(
        PhysicalResourceProvider.INSTANCE, packageMap);

    var resolvers = [
      new DartUriResolver(sdk),
      new ResourceUriResolver(PhysicalResourceProvider.INSTANCE),
      packageResolver,
    ];

    AnalysisEngine.instance.processRequiredPlugins();

    var options = new AnalysisOptionsImpl()..analyzeFunctionBodies = false;

    AnalysisContext context = AnalysisEngine.instance.createAnalysisContext()
      ..analysisOptions = options
      ..sourceFactory = new SourceFactory(resolvers);
    return new LibraryScanner._(package, projectPath, packageResolver, context);
  }

  Future<Map<String, List<String>>> scanDirectLibs() =>
      _scanPackage(_package, _projectPath);

  Future<Map<String, List<String>>> scanTransitiveLibs() async {
    Map<String, List<String>> results = new SplayTreeMap();
    Map<String, List<String>> direct =
        await _scanPackage(_package, _projectPath);
    for (String key in direct.keys) {
      Set<String> processed = new Set();
      Set<String> todo = new Set.from(direct[key]);
      while (todo.isNotEmpty) {
        String lib = todo.first;
        todo.remove(lib);
        if (processed.contains(lib)) continue;
        processed.add(lib);
        if (lib.startsWith('dart:')) {
          // nothing to do
        } else if (_cachedLibs.containsKey(lib)) {
          todo.addAll(_cachedLibs[lib]);
        } else if (lib.startsWith('package:')) {
          todo.addAll(await _scanUri(lib));
        }
      }

      results[key] = processed.toList()..sort();
    }
    return results;
  }

  Future<List<String>> _scanUri(String libUri) async {
    Uri uri = Uri.parse(libUri);
    String package = uri.path.split('/').first;
    String fullPath = _packageResolver.resolveAbsolute(uri).fullName;
    String relativePath =
        p.join('lib', libUri.substring(libUri.indexOf('/') + 1));
    if (fullPath.endsWith('/$relativePath')) {
      String packageDir =
          fullPath.substring(0, fullPath.length - relativePath.length - 1);
      List<String> libs = _parseLibs(package, packageDir, relativePath);
      _cachedLibs[libUri] = libs;
      return libs;
    } else {
      return [];
    }
  }

  Future<Map<String, List<String>>> _scanPackage(
      String package, String packageDir) async {
    Map<String, List<String>> results = new SplayTreeMap();
    List<String> dartFiles = await listFiles(packageDir, endsWith: '.dart');
    List<String> mainFiles = dartFiles
        .where((path) => path.startsWith('lib/') || path.startsWith('bin/'))
        .toList();
    for (String relativePath in mainFiles) {
      String uri = _toUri(package, relativePath);
      if (!_cachedLibs.containsKey(uri)) {
        _cachedLibs[uri] = _parseLibs(package, packageDir, relativePath);
      }
      results[uri] = _cachedLibs[uri];
    }
    return results;
  }

  List<String> _parseLibs(
      String package, String packageDir, String relativePath) {
    String fullPath = p.join(packageDir, relativePath);
    LibraryElement lib = _getLibraryElement(fullPath);
    if (lib == null) return [];
    Set<String> refs = new SplayTreeSet();
    lib.importedLibraries.forEach((le) {
      refs.add(_normalizeLibRef(le.librarySource.uri, package, packageDir));
    });
    lib.exportedLibraries.forEach((le) {
      refs.add(_normalizeLibRef(le.librarySource.uri, package, packageDir));
    });
    refs.remove('dart:core');
    return refs.toList();
  }

  LibraryElement _getLibraryElement(String path) {
    Source source = new FileBasedSource(new JavaFile(path));
    if (_context.computeKindOf(source) == SourceKind.LIBRARY) {
      return _context.computeLibraryElement(source);
    }
    return null;
  }
}

String _normalizeLibRef(Uri uri, String package, String packageDir) {
  if (uri.isScheme('file')) {
    String relativePath = p.relative(p.fromUri(uri), from: packageDir);
    return _toUri(package, relativePath);
  } else if (uri.isScheme('package') || uri.isScheme('dart')) {
    return uri.toString();
  }

  throw "not supported - $uri";
}

String _toUri(String package, String relativePath) {
  if (relativePath.startsWith('lib/')) {
    return 'package:$package/${relativePath.substring(4)}';
  } else {
    return 'path:$package/$relativePath';
  }
}
