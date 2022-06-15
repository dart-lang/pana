class PackageShape {
  final List<LibraryShape> libraries;

  PackageShape(this.libraries);
}

class LibraryShape {
  final String filename;
  final List<ClassShape> classes;

  LibraryShape(this.filename, this.classes);
}

class ClassShape {
  // TODO: to be used later for classes which reference other classes
  // final int id;
  // final List<String> exportedFrom;
  final String name;
  final List<MethodShape> _methods;

  Map<String, MethodShape> get methods =>
      {for (var method in _methods) method.name: method};

  ClassShape(this.name, this._methods);
}

class MethodShape {
  final String name;

  MethodShape(this.name);
}
