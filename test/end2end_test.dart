// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:pana/pana.dart';
import 'package:test/test.dart';

import 'end2end/http_data.dart' as http_data;
import 'end2end/pub_server_data.dart' as pub_server_data;
import 'end2end/shared.dart';
import 'end2end/skiplist_data.dart' as skiplist_data;
import 'end2end/stream_broken_data.dart' as stream_broken_data;

void main() {
  Directory tempDir;
  PackageAnalyzer analyzer;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('pana-test');
    var pubCacheDir = await tempDir.resolveSymbolicLinks();
    analyzer = await PackageAnalyzer.create(pubCacheDir: pubCacheDir);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  void _verifyPackage(E2EData data) {
    group('${data.name} ${data.version}', () {
      Map actualMap;

      setUpAll(() async {
        var summary = await analyzer.inspectPackage(
          data.name,
          version: data.version,
          keepTransitiveLibs: true,
        );

        // summary.toJson contains types which are not directly JSON-able
        // throwing it through `JSON.encode` does the trick
        actualMap = JSON.decode(JSON.encode(summary));
      });

      test('matches known good', () {
        expect(actualMap, data.data);
      });

      test('Summary can round-trip', () {
        var summary = new Summary.fromJson(actualMap);

        var roundTrip = JSON.decode(JSON.encode(summary));
        expect(roundTrip, actualMap);
      });
    }, timeout: const Timeout.factor(2));
  }

  _verifyPackage(pub_server_data.data);
  _verifyPackage(http_data.data);
  _verifyPackage(skiplist_data.data);
  _verifyPackage(stream_broken_data.data);

  test('can parse v0.6 output', () {
    var actualMap = JSON.decode(_v6Output);

    // NOTE! As of 0.7.0 `fromJson` updates `actualMap` to have a valid semver
    // value for `sdkVersion`. This is how the `expect` call below succeeds.
    var summary = new Summary.fromJson(actualMap);

    var roundTrip = JSON.decode(JSON.encode(summary));
    expect(roundTrip, actualMap);
  });
}

final _v6Output = r'''{
  "panaVersion": "0.6.2",
  "sdkVersion": "Dart VM version: 2.0.0-dev.7.0 (Thu Nov  9 19:08:06 2017) on \"linux_x64\"",
  "packageName": "angular",
  "packageVersion": "4.0.0",
  "pubspec": {
   "version": "4.0.0",
   "dependencies": {
    "code_builder": "^1.0.0-beta+4",
    "dart_style": ">=0.1.8 <2.0.0",
    "quiver": ">=0.22.0 <0.26.0",
    "build_barback": "^0.4.0",
    "collection": "^1.12.0",
    "meta": "^1.0.3",
    "barback": "^0.15.2+2",
    "html": ">=0.12.0 <0.14.0",
    "csslib": "^0.14.0",
    "glob": "^1.0.0",
    "stack_trace": "^1.6.5",
    "source_gen": "^0.7.0",
    "intl": ">=0.13.0 <0.16.0",
    "path": "^1.0.0",
    "build": "^0.10.0",
    "logging": ">=0.9.0 <0.12.0",
    "source_span": "^1.4.0",
    "js": "^0.6.0",
    "angular_compiler": "^0.3.0",
    "tuple": "^1.0.1",
    "func": ">=0.1.0 <2.0.0",
    "analyzer": ">=0.29.10 <0.31.0"
   },
   "name": "angular",
   "author": "Dart Team <web@dartlang.org>",
   "description": "Fast and productive web framework",
   "homepage": "https://webdev.dartlang.org/angular",
   "environment": {
    "sdk": ">=1.24.0 <2.0.0"
   },
   "transformers": [
    "angular",
    {
     "$dart2js": {
      "commandLineOptions": [
       "--show-package-warnings"
      ]
     }
    }
   ],
   "documentation": "https://webdev.dartlang.org/angular/api"
  },
  "pkgResolution": {
   "dependencies": [
    {
     "package": "analyzer",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": ">=0.29.10 <0.31.0",
     "resolved": "0.30.0+4",
     "available": "0.31.0-alpha.1"
    },
    {
     "package": "angular_compiler",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^0.3.0",
     "resolved": "0.3.0",
     "available": "0.4.0-alpha"
    },
    {
     "package": "args",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "1.0.2"
    },
    {
     "package": "async",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "1.13.3",
     "available": "2.0.1"
    },
    {
     "package": "barback",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^0.15.2+2",
     "resolved": "0.15.2+13"
    },
    {
     "package": "build",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^0.10.0",
     "resolved": "0.10.2+1",
     "available": "0.11.0"
    },
    {
     "package": "build_barback",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^0.4.0",
     "resolved": "0.4.0+1",
     "available": "0.4.0+2"
    },
    {
     "package": "charcode",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "1.1.1"
    },
    {
     "package": "cli_util",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "0.1.2+1"
    },
    {
     "package": "code_builder",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^1.0.0-beta+4",
     "resolved": "1.0.4",
     "available": "2.1.0"
    },
    {
     "package": "code_transformers",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "0.5.1+3"
    },
    {
     "package": "collection",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^1.12.0",
     "resolved": "1.14.3"
    },
    {
     "package": "convert",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "2.0.1"
    },
    {
     "package": "crypto",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "2.0.2+1"
    },
    {
     "package": "csslib",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^0.14.0",
     "resolved": "0.14.1"
    },
    {
     "package": "dart_style",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": ">=0.1.8 <2.0.0",
     "resolved": "1.0.8"
    },
    {
     "package": "front_end",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "0.1.0-alpha.4.1",
     "available": "0.1.0-alpha.6"
    },
    {
     "package": "func",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": ">=0.1.0 <2.0.0",
     "resolved": "1.0.0"
    },
    {
     "package": "glob",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^1.0.0",
     "resolved": "1.1.5"
    },
    {
     "package": "html",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": ">=0.12.0 <0.14.0",
     "resolved": "0.13.2"
    },
    {
     "package": "intl",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": ">=0.13.0 <0.16.0",
     "resolved": "0.15.2"
    },
    {
     "package": "isolate",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "1.1.0"
    },
    {
     "package": "js",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^0.6.0",
     "resolved": "0.6.1"
    },
    {
     "package": "kernel",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "0.3.0-alpha.1.1",
     "available": "0.3.0-alpha.3"
    },
    {
     "package": "logging",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": ">=0.9.0 <0.12.0",
     "resolved": "0.11.3+1"
    },
    {
     "package": "matcher",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "0.12.1+4"
    },
    {
     "package": "meta",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^1.0.3",
     "resolved": "1.1.2"
    },
    {
     "package": "package_config",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "1.0.3"
    },
    {
     "package": "path",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^1.0.0",
     "resolved": "1.5.0"
    },
    {
     "package": "plugin",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "0.2.0+2"
    },
    {
     "package": "pool",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "1.3.3"
    },
    {
     "package": "quiver",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": ">=0.22.0 <0.26.0",
     "resolved": "0.25.0",
     "available": "0.26.2"
    },
    {
     "package": "quiver_hashcode",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "1.0.0"
    },
    {
     "package": "source_gen",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^0.7.0",
     "resolved": "0.7.2+1"
    },
    {
     "package": "source_maps",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "0.10.4"
    },
    {
     "package": "source_span",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^1.4.0",
     "resolved": "1.4.0"
    },
    {
     "package": "stack_trace",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^1.6.5",
     "resolved": "1.9.1"
    },
    {
     "package": "string_scanner",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "1.0.2"
    },
    {
     "package": "tuple",
     "dependencyType": "direct",
     "constraintType": "normal",
     "constraint": "^1.0.1",
     "resolved": "1.0.1"
    },
    {
     "package": "typed_data",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "1.1.5"
    },
    {
     "package": "utf",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "0.9.0+3"
    },
    {
     "package": "watcher",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "0.9.7+4"
    },
    {
     "package": "yaml",
     "dependencyType": "transitive",
     "constraintType": "inherited",
     "resolved": "2.1.13"
    }
   ]
  },
  "dartFiles": {
   "lib/angular.dart": {
    "uri": "package:angular/angular.dart",
    "size": 963,
    "isFormatted": true,
    "codeProblems": [],
    "directLibs": [
     "package:angular/core.dart",
     "package:angular/src/common/common_directives.dart",
     "package:angular/src/common/directives.dart",
     "package:angular/src/common/pipes.dart",
     "package:angular/src/core/angular_entrypoint.dart",
     "package:angular/src/core/application_tokens.dart",
     "package:angular/src/platform/bootstrap.dart",
     "package:angular/src/platform/dom/dom_tokens.dart",
     "package:angular/src/platform/dom/events/event_manager.dart"
    ],
    "platform": {
     "worksEverywhere": false,
     "restrictedTo": [
      "web"
     ]
    },
    "fitness": {
     "magnitude": 29.0,
     "shortcoming": 0.0
    }
   },
   "lib/core.dart": {
    "uri": "package:angular/core.dart",
    "size": 834,
    "isFormatted": true,
    "codeProblems": [
     {
      "severity": "INFO",
      "errorType": "HINT",
      "errorCode": "DEPRECATED_MEMBER_USE",
      "file": "lib/core.dart",
      "line": 24,
      "col": 42,
      "description": "'UrlResolver' is deprecated and shouldn't be used."
     }
    ],
    "directLibs": [
     "package:angular/src/core/angular_entrypoint.dart",
     "package:angular/src/core/application_common_providers.dart",
     "package:angular/src/core/application_ref.dart",
     "package:angular/src/core/application_tokens.dart",
     "package:angular/src/core/change_detection.dart",
     "package:angular/src/core/di.dart",
     "package:angular/src/core/linker.dart",
     "package:angular/src/core/metadata.dart",
     "package:angular/src/core/render.dart",
     "package:angular/src/core/testability/testability.dart",
     "package:angular/src/core/url_resolver.dart",
     "package:angular/src/core/zone.dart",
     "package:angular/src/facade/facade.dart"
    ],
    "platform": {
     "worksEverywhere": false,
     "restrictedTo": [
      "web"
     ]
    },
    "fitness": {
     "magnitude": 32.0,
     "shortcoming": 1.0
    }
   },
   "lib/di.dart": {
    "uri": "package:angular/di.dart",
    "size": 588,
    "isFormatted": true,
    "codeProblems": [
     {
      "severity": "INFO",
      "errorType": "HINT",
      "errorCode": "DEPRECATED_MEMBER_USE",
      "file": "lib/di.dart",
      "line": 13,
      "col": 10,
      "description": "'EventEmitter' is deprecated and shouldn't be used."
     }
    ],
    "directLibs": [
     "package:angular/src/core/change_detection/pipe_transform.dart",
     "package:angular/src/core/di.dart",
     "package:angular/src/core/metadata.dart",
     "package:angular/src/core/testability/testability.dart",
     "package:angular/src/core/zone/ng_zone.dart",
     "package:angular/src/facade/facade.dart"
    ],
    "platform": {
     "worksEverywhere": true
    },
    "fitness": {
     "magnitude": 17.0,
     "shortcoming": 1.0
    }
   },
   "lib/experimental.dart": {
    "uri": "package:angular/experimental.dart",
    "size": 1617,
    "isFormatted": true,
    "codeProblems": [],
    "directLibs": [
     "package:angular/src/core/linker/app_view.dart",
     "package:angular/src/core/linker/app_view_utils.dart",
     "package:angular/src/di/injector/injector.dart",
     "package:meta/meta.dart"
    ],
    "platform": {
     "worksEverywhere": false,
     "restrictedTo": [
      "web"
     ]
    },
    "fitness": {
     "magnitude": 33.0,
     "shortcoming": 0.0
    }
   },
   "lib/security.dart": {
    "uri": "package:angular/security.dart",
    "size": 536,
    "isFormatted": true,
    "codeProblems": [],
    "directLibs": [
     "package:angular/src/security/dom_sanitization_service.dart",
     "package:angular/src/security/safe_inner_html.dart"
    ],
    "platform": {
     "worksEverywhere": false,
     "restrictedTo": [
      "web"
     ]
    },
    "fitness": {
     "magnitude": 13.0,
     "shortcoming": 0.0
    }
   },
   "lib/source_gen.dart": {
    "uri": "package:angular/source_gen.dart",
    "size": 81,
    "isFormatted": true,
    "codeProblems": [],
    "directLibs": [
     "package:angular/src/source_gen/source_gen.dart"
    ],
    "platform": {
     "worksEverywhere": false,
     "restrictedTo": [
      "server"
     ]
    },
    "fitness": {
     "magnitude": 3.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/common_directives.dart": {
    "uri": "package:angular/src/common/common_directives.dart",
    "size": 1481,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 33.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/directives.dart": {
    "uri": "package:angular/src/common/directives.dart",
    "size": 437,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 8.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/directives/core_directives.dart": {
    "uri": "package:angular/src/common/directives/core_directives.dart",
    "size": 1705,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 40.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/directives/ng_class.dart": {
    "uri": "package:angular/src/common/directives/ng_class.dart",
    "size": 6063,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 126.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/directives/ng_for.dart": {
    "uri": "package:angular/src/common/directives/ng_for.dart",
    "size": 6937,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 136.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/directives/ng_if.dart": {
    "uri": "package:angular/src/common/directives/ng_if.dart",
    "size": 2121,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 42.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/directives/ng_style.dart": {
    "uri": "package:angular/src/common/directives/ng_style.dart",
    "size": 3042,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 60.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/directives/ng_switch.dart": {
    "uri": "package:angular/src/common/directives/ng_switch.dart",
    "size": 7286,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 147.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/directives/ng_template_outlet.dart": {
    "uri": "package:angular/src/common/directives/ng_template_outlet.dart",
    "size": 936,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 17.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/pipes.dart": {
    "uri": "package:angular/src/common/pipes.dart",
    "size": 522,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 10.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/pipes/async_pipe.dart": {
    "uri": "package:angular/src/common/pipes/async_pipe.dart",
    "size": 4576,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 101.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/pipes/common_pipes.dart": {
    "uri": "package:angular/src/common/pipes/common_pipes.dart",
    "size": 839,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 18.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/pipes/date_pipe.dart": {
    "uri": "package:angular/src/common/pipes/date_pipe.dart",
    "size": 5278,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 87.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/pipes/invalid_pipe_argument_exception.dart": {
    "uri": "package:angular/src/common/pipes/invalid_pipe_argument_exception.dart",
    "size": 251,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 4.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/pipes/json_pipe.dart": {
    "uri": "package:angular/src/common/pipes/json_pipe.dart",
    "size": 373,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 7.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/pipes/lowercase_pipe.dart": {
    "uri": "package:angular/src/common/pipes/lowercase_pipe.dart",
    "size": 480,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 10.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/pipes/number_pipe.dart": {
    "uri": "package:angular/src/common/pipes/number_pipe.dart",
    "size": 5267,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 106.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/pipes/replace_pipe.dart": {
    "uri": "package:angular/src/common/pipes/replace_pipe.dart",
    "size": 2513,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 47.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/pipes/slice_pipe.dart": {
    "uri": "package:angular/src/common/pipes/slice_pipe.dart",
    "size": 3017,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 54.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/common/pipes/uppercase_pipe.dart": {
    "uri": "package:angular/src/common/pipes/uppercase_pipe.dart",
    "size": 491,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 10.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/analyzed_class.dart": {
    "uri": "package:angular/src/compiler/analyzed_class.dart",
    "size": 3948,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 79.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/attribute_matcher.dart": {
    "uri": "package:angular/src/compiler/attribute_matcher.dart",
    "size": 3243,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 65.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/chars.dart": {
    "uri": "package:angular/src/compiler/chars.dart",
    "size": 1238,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 50.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/compile_metadata.dart": {
    "uri": "package:angular/src/compiler/compile_metadata.dart",
    "size": 16415,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 360.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/compiler.dart": {
    "uri": "package:angular/src/compiler/compiler.dart",
    "size": 139,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 3.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/compiler_utils.dart": {
    "uri": "package:angular/src/compiler/compiler_utils.dart",
    "size": 717,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 16.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/directive_normalizer.dart": {
    "uri": "package:angular/src/compiler/directive_normalizer.dart",
    "size": 7175,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 135.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/expression_parser/ast.dart": {
    "uri": "package:angular/src/compiler/expression_parser/ast.dart",
    "size": 13193,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 308.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/expression_parser/lexer.dart": {
    "uri": "package:angular/src/compiler/expression_parser/lexer.dart",
    "size": 10921,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 286.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/expression_parser/parser.dart": {
    "uri": "package:angular/src/compiler/expression_parser/parser.dart",
    "size": 22610,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 530.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/html_ast.dart": {
    "uri": "package:angular/src/compiler/html_ast.dart",
    "size": 2462,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 60.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/html_events.dart": {
    "uri": "package:angular/src/compiler/html_events.dart",
    "size": 1629,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 42.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/html_lexer.dart": {
    "uri": "package:angular/src/compiler/html_lexer.dart",
    "size": 22826,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 532.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/html_parser.dart": {
    "uri": "package:angular/src/compiler/html_parser.dart",
    "size": 8391,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 189.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/html_tags.dart": {
    "uri": "package:angular/src/compiler/html_tags.dart",
    "size": 10359,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 232.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/identifiers.dart": {
    "uri": "package:angular/src/compiler/identifiers.dart",
    "size": 14133,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 228.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/logging.dart": {
    "uri": "package:angular/src/compiler/logging.dart",
    "size": 329,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 6.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/offline_compiler.dart": {
    "uri": "package:angular/src/compiler/offline_compiler.dart",
    "size": 8684,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 170.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/output/abstract_emitter.dart": {
    "uri": "package:angular/src/compiler/output/abstract_emitter.dart",
    "size": 17197,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 440.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/output/dart_emitter.dart": {
    "uri": "package:angular/src/compiler/output/dart_emitter.dart",
    "size": 16808,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 408.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/output/output_ast.dart": {
    "uri": "package:angular/src/compiler/output/output_ast.dart",
    "size": 40432,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 860.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/output/path_util.dart": {
    "uri": "package:angular/src/compiler/output/path_util.dart",
    "size": 2492,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 53.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/parse_util.dart": {
    "uri": "package:angular/src/compiler/parse_util.dart",
    "size": 335,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 8.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/provider_parser.dart": {
    "uri": "package:angular/src/compiler/provider_parser.dart",
    "size": 19780,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 387.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/schema/dom_element_schema_registry.dart": {
    "uri": "package:angular/src/compiler/schema/dom_element_schema_registry.dart",
    "size": 14309,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 239.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/schema/element_schema_registry.dart": {
    "uri": "package:angular/src/compiler/schema/element_schema_registry.dart",
    "size": 265,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 5.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/selector.dart": {
    "uri": "package:angular/src/compiler/selector.dart",
    "size": 12373,
    "isFormatted": true,
    "codeProblems": [
     {
      "severity": "INFO",
      "errorType": "HINT",
      "errorCode": "UNUSED_ELEMENT",
      "file": "lib/src/compiler/selector.dart",
      "line": 6,
      "col": 7,
      "description": "The top level variable '_EMPTY_ATTR_VALUE' isn't used."
     }
    ],
    "fitness": {
     "magnitude": 272.0,
     "shortcoming": 1.0
    }
   },
   "lib/src/compiler/shadow_css.dart": {
    "uri": "package:angular/src/compiler/shadow_css.dart",
    "size": 23475,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 467.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/source_module.dart": {
    "uri": "package:angular/src/compiler/source_module.dart",
    "size": 433,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 8.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/style_compiler.dart": {
    "uri": "package:angular/src/compiler/style_compiler.dart",
    "size": 4243,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 84.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/style_url_resolver.dart": {
    "uri": "package:angular/src/compiler/style_url_resolver.dart",
    "size": 3034,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 69.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/template_ast.dart": {
    "uri": "package:angular/src/compiler/template_ast.dart",
    "size": 10591,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 226.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/template_parser.dart": {
    "uri": "package:angular/src/compiler/template_parser.dart",
    "size": 44279,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 888.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/template_preparser.dart": {
    "uri": "package:angular/src/compiler/template_preparser.dart",
    "size": 2947,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 65.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/compile_binding.dart": {
    "uri": "package:angular/src/compiler/view_compiler/compile_binding.dart",
    "size": 224,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 5.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/compile_element.dart": {
    "uri": "package:angular/src/compiler/view_compiler/compile_element.dart",
    "size": 27908,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 535.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/compile_method.dart": {
    "uri": "package:angular/src/compiler/view_compiler/compile_method.dart",
    "size": 2710,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 59.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/compile_pipe.dart": {
    "uri": "package:angular/src/compiler/view_compiler/compile_pipe.dart",
    "size": 3852,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 83.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/compile_query.dart": {
    "uri": "package:angular/src/compiler/view_compiler/compile_query.dart",
    "size": 5641,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 118.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/compile_view.dart": {
    "uri": "package:angular/src/compiler/view_compiler/compile_view.dart",
    "size": 6562,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 140.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/constants.dart": {
    "uri": "package:angular/src/compiler/view_compiler/constants.dart",
    "size": 1983,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 41.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/directive_compiler.dart": {
    "uri": "package:angular/src/compiler/view_compiler/directive_compiler.dart",
    "size": 5634,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 118.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/event_binder.dart": {
    "uri": "package:angular/src/compiler/view_compiler/event_binder.dart",
    "size": 7969,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 160.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/expression_converter.dart": {
    "uri": "package:angular/src/compiler/view_compiler/expression_converter.dart",
    "size": 13185,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 283.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/lifecycle_binder.dart": {
    "uri": "package:angular/src/compiler/view_compiler/lifecycle_binder.dart",
    "size": 4868,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 89.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/parse_utils.dart": {
    "uri": "package:angular/src/compiler/view_compiler/parse_utils.dart",
    "size": 1575,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 35.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/perf_profiler.dart": {
    "uri": "package:angular/src/compiler/view_compiler/perf_profiler.dart",
    "size": 1988,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 39.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/property_binder.dart": {
    "uri": "package:angular/src/compiler/view_compiler/property_binder.dart",
    "size": 23588,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 459.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/view_binder.dart": {
    "uri": "package:angular/src/compiler/view_compiler/view_binder.dart",
    "size": 7867,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 161.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/view_builder.dart": {
    "uri": "package:angular/src/compiler/view_compiler/view_builder.dart",
    "size": 54189,
    "isFormatted": true,
    "codeProblems": [
     {
      "severity": "INFO",
      "errorType": "HINT",
      "errorCode": "USES_DYNAMIC_AS_BOTTOM",
      "file": "lib/src/compiler/view_compiler/view_builder.dart",
      "line": 877,
      "col": 18,
      "description": "A function of type '(ClassMethod) → bool' can't be assigned to a variable of type '(dynamic) → bool'."
     }
    ],
    "fitness": {
     "magnitude": 1076.0,
     "shortcoming": 1.0
    }
   },
   "lib/src/compiler/view_compiler/view_compiler.dart": {
    "uri": "package:angular/src/compiler/view_compiler/view_compiler.dart",
    "size": 6042,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 117.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/view_compiler_utils.dart": {
    "uri": "package:angular/src/compiler/view_compiler/view_compiler_utils.dart",
    "size": 7583,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 155.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/compiler/view_compiler/view_name_resolver.dart": {
    "uri": "package:angular/src/compiler/view_compiler/view_name_resolver.dart",
    "size": 3546,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 79.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/angular_entrypoint.dart": {
    "uri": "package:angular/src/core/angular_entrypoint.dart",
    "size": 522,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 12.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/application_common_providers.dart": {
    "uri": "package:angular/src/core/application_common_providers.dart",
    "size": 899,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 16.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/application_ref.dart": {
    "uri": "package:angular/src/core/application_ref.dart",
    "size": 16812,
    "isFormatted": true,
    "codeProblems": [
     {
      "severity": "INFO",
      "errorType": "HINT",
      "errorCode": "USES_DYNAMIC_AS_BOTTOM",
      "file": "lib/src/core/application_ref.dart",
      "line": 272,
      "col": 51,
      "description": "A function of type '(NgZoneError) → Null' can't be assigned to a variable of type '(dynamic) → void'."
     }
    ],
    "fitness": {
     "magnitude": 353.0,
     "shortcoming": 1.0
    }
   },
   "lib/src/core/application_tokens.dart": {
    "uri": "package:angular/src/core/application_tokens.dart",
    "size": 1456,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 25.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/change_detection.dart": {
    "uri": "package:angular/src/core/change_detection.dart",
    "size": 366,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 7.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/change_detection/change_detection.dart": {
    "uri": "package:angular/src/core/change_detection/change_detection.dart",
    "size": 551,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 11.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/change_detection/change_detection_util.dart": {
    "uri": "package:angular/src/core/change_detection/change_detection_util.dart",
    "size": 1918,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 44.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/change_detection/change_detector_ref.dart": {
    "uri": "package:angular/src/core/change_detection/change_detector_ref.dart",
    "size": 5521,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 116.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/change_detection/component_state.dart": {
    "uri": "package:angular/src/core/change_detection/component_state.dart",
    "size": 1007,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 21.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/change_detection/constants.dart": {
    "uri": "package:angular/src/core/change_detection/constants.dart",
    "size": 2010,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 34.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/change_detection/differs/default_iterable_differ.dart": {
    "uri": "package:angular/src/core/change_detection/differs/default_iterable_differ.dart",
    "size": 24614,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 536.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/change_detection/differs/default_keyvalue_differ.dart": {
    "uri": "package:angular/src/core/change_detection/differs/default_keyvalue_differ.dart",
    "size": 8049,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 200.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/change_detection/directive_change_detector.dart": {
    "uri": "package:angular/src/core/change_detection/directive_change_detector.dart",
    "size": 2066,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 42.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/change_detection/pipe_transform.dart": {
    "uri": "package:angular/src/core/change_detection/pipe_transform.dart",
    "size": 893,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 18.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/di.dart": {
    "uri": "package:angular/src/core/di.dart",
    "size": 300,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 6.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/di/decorators.dart": {
    "uri": "package:angular/src/core/di/decorators.dart",
    "size": 5916,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 138.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/di/opaque_token.dart": {
    "uri": "package:angular/src/core/di/opaque_token.dart",
    "size": 1047,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 22.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/di/provider.dart": {
    "uri": "package:angular/src/core/di/provider.dart",
    "size": 112,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 1.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker.dart": {
    "uri": "package:angular/src/core/linker.dart",
    "size": 664,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 12.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker/app_view.dart": {
    "uri": "package:angular/src/core/linker/app_view.dart",
    "size": 23294,
    "isFormatted": true,
    "codeProblems": [
     {
      "severity": "INFO",
      "errorType": "HINT",
      "errorCode": "UNUSED_ELEMENT",
      "file": "lib/src/core/linker/app_view.dart",
      "line": 731,
      "col": 9,
      "description": "The top level variable '_temporaryTodo' isn't used."
     }
    ],
    "fitness": {
     "magnitude": 488.0,
     "shortcoming": 1.0
    }
   },
   "lib/src/core/linker/app_view_utils.dart": {
    "uri": "package:angular/src/core/linker/app_view_utils.dart",
    "size": 14562,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 374.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker/component_factory.dart": {
    "uri": "package:angular/src/core/linker/component_factory.dart",
    "size": 3090,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 61.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker/component_loader.dart": {
    "uri": "package:angular/src/core/linker/component_loader.dart",
    "size": 3809,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 73.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker/component_resolver.dart": {
    "uri": "package:angular/src/core/linker/component_resolver.dart",
    "size": 1360,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 27.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker/dynamic_component_loader.dart": {
    "uri": "package:angular/src/core/linker/dynamic_component_loader.dart",
    "size": 1822,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 36.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker/element_ref.dart": {
    "uri": "package:angular/src/core/linker/element_ref.dart",
    "size": 680,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 11.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker/exceptions.dart": {
    "uri": "package:angular/src/core/linker/exceptions.dart",
    "size": 2040,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 38.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker/query_list.dart": {
    "uri": "package:angular/src/core/linker/query_list.dart",
    "size": 1808,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 45.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker/template_ref.dart": {
    "uri": "package:angular/src/core/linker/template_ref.dart",
    "size": 1741,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 30.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker/view_container.dart": {
    "uri": "package:angular/src/core/linker/view_container.dart",
    "size": 7341,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 160.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker/view_container_ref.dart": {
    "uri": "package:angular/src/core/linker/view_container_ref.dart",
    "size": 4024,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 69.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker/view_ref.dart": {
    "uri": "package:angular/src/core/linker/view_ref.dart",
    "size": 3383,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 72.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/linker/view_type.dart": {
    "uri": "package:angular/src/core/linker/view_type.dart",
    "size": 433,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 7.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/metadata.dart": {
    "uri": "package:angular/src/core/metadata.dart",
    "size": 27455,
    "isFormatted": true,
    "codeProblems": [
     {
      "severity": "INFO",
      "errorType": "HINT",
      "errorCode": "DEPRECATED_MEMBER_USE",
      "file": "lib/src/core/metadata.dart",
      "line": 86,
      "col": 12,
      "description": "'inputs' is deprecated and shouldn't be used."
     }
    ],
    "fitness": {
     "magnitude": 598.0,
     "shortcoming": 1.0
    }
   },
   "lib/src/core/metadata/lifecycle_hooks.dart": {
    "uri": "package:angular/src/core/metadata/lifecycle_hooks.dart",
    "size": 13862,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 279.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/metadata/view.dart": {
    "uri": "package:angular/src/core/metadata/view.dart",
    "size": 539,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 9.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/metadata/visibility.dart": {
    "uri": "package:angular/src/core/metadata/visibility.dart",
    "size": 132,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 2.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/render.dart": {
    "uri": "package:angular/src/core/render.dart",
    "size": 77,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 1.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/render/api.dart": {
    "uri": "package:angular/src/core/render/api.dart",
    "size": 3098,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 66.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/security.dart": {
    "uri": "package:angular/src/core/security.dart",
    "size": 1386,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 27.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/testability/testability.dart": {
    "uri": "package:angular/src/core/testability/testability.dart",
    "size": 3931,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 88.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/url_resolver.dart": {
    "uri": "package:angular/src/core/url_resolver.dart",
    "size": 1972,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 45.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/zone.dart": {
    "uri": "package:angular/src/core/zone.dart",
    "size": 77,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 1.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/core/zone/ng_zone.dart": {
    "uri": "package:angular/src/core/zone/ng_zone.dart",
    "size": 12859,
    "isFormatted": true,
    "codeProblems": [
     {
      "severity": "ERROR",
      "errorType": "STATIC_WARNING",
      "errorCode": "ARGUMENT_TYPE_NOT_ASSIGNABLE",
      "file": "lib/src/core/zone/ng_zone.dart",
      "line": 144,
      "col": 13,
      "description": "The argument type '(Zone, ZoneDelegate, Zone, () → dynamic) → dynamic' can't be assigned to the parameter type '<R>(Zone, ZoneDelegate, Zone, () → R) → R'."
     },
     {
      "severity": "ERROR",
      "errorType": "STATIC_WARNING",
      "errorCode": "ARGUMENT_TYPE_NOT_ASSIGNABLE",
      "file": "lib/src/core/zone/ng_zone.dart",
      "line": 145,
      "col": 13,
      "description": "The argument type '(Zone, ZoneDelegate, Zone, (dynamic) → dynamic, dynamic) → dynamic' can't be assigned to the parameter type '<R,T>(Zone, ZoneDelegate, Zone, (T) → R, T) → R'."
     },
     {
      "severity": "ERROR",
      "errorType": "STATIC_WARNING",
      "errorCode": "ARGUMENT_TYPE_NOT_ASSIGNABLE",
      "file": "lib/src/core/zone/ng_zone.dart",
      "line": 146,
      "col": 13,
      "description": "The argument type '(Zone, ZoneDelegate, Zone, (dynamic, dynamic) → dynamic, dynamic, dynamic) → dynamic' can't be assigned to the parameter type '<R,T1,T2>(Zone, ZoneDelegate, Zone, (T1, T2) → R, T1, T2) → R'."
     },
     {
      "severity": "ERROR",
      "errorType": "STATIC_TYPE_WARNING",
      "errorCode": "RETURN_OF_INVALID_TYPE",
      "file": "lib/src/core/zone/ng_zone.dart",
      "line": 310,
      "col": 12,
      "description": "The return type 'void' isn't a 'R', as defined by the method 'runGuarded'."
     }
    ],
    "fitness": {
     "magnitude": 269.0,
     "shortcoming": 215.20000000000002
    }
   },
   "lib/src/debug/by.dart": {
    "uri": "package:angular/src/debug/by.dart",
    "size": 914,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 19.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/debug/debug_app_view.dart": {
    "uri": "package:angular/src/debug/debug_app_view.dart",
    "size": 13750,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 299.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/debug/debug_context.dart": {
    "uri": "package:angular/src/debug/debug_context.dart",
    "size": 3269,
    "isFormatted": true,
    "codeProblems": [
     {
      "severity": "INFO",
      "errorType": "HINT",
      "errorCode": "UNUSED_ELEMENT",
      "file": "lib/src/debug/debug_context.dart",
      "line": 15,
      "col": 5,
      "description": "The top level variable '_EMPTY_REF_TOKENS' isn't used."
     }
    ],
    "fitness": {
     "magnitude": 68.0,
     "shortcoming": 1.0
    }
   },
   "lib/src/debug/debug_node.dart": {
    "uri": "package:angular/src/debug/debug_node.dart",
    "size": 4757,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 106.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/debug/profile_keys.dart": {
    "uri": "package:angular/src/debug/profile_keys.dart",
    "size": 302,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 5.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/debug/profile_runtime.dart": {
    "uri": "package:angular/src/debug/profile_runtime.dart",
    "size": 6624,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 144.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/di/injector/element.dart": {
    "uri": "package:angular/src/di/injector/element.dart",
    "size": 1447,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 34.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/di/injector/empty.dart": {
    "uri": "package:angular/src/di/injector/empty.dart",
    "size": 941,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 19.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/di/injector/hierarchical.dart": {
    "uri": "package:angular/src/di/injector/hierarchical.dart",
    "size": 2377,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 46.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/di/injector/injector.dart": {
    "uri": "package:angular/src/di/injector/injector.dart",
    "size": 3622,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 67.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/di/injector/map.dart": {
    "uri": "package:angular/src/di/injector/map.dart",
    "size": 683,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 15.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/di/injector/reflective.dart": {
    "uri": "package:angular/src/di/injector/reflective.dart",
    "size": 9337,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 197.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/di/provider.dart": {
    "uri": "package:angular/src/di/provider.dart",
    "size": 2839,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 60.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/di/reflector.dart": {
    "uri": "package:angular/src/di/reflector.dart",
    "size": 3126,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 58.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/facade/async.dart": {
    "uri": "package:angular/src/facade/async.dart",
    "size": 1246,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 28.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/facade/exception_handler.dart": {
    "uri": "package:angular/src/facade/exception_handler.dart",
    "size": 3261,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 70.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/facade/exceptions.dart": {
    "uri": "package:angular/src/facade/exceptions.dart",
    "size": 703,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 19.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/facade/facade.dart": {
    "uri": "package:angular/src/facade/facade.dart",
    "size": 167,
    "isFormatted": true,
    "codeProblems": [
     {
      "severity": "INFO",
      "errorType": "HINT",
      "errorCode": "DEPRECATED_MEMBER_USE",
      "file": "lib/src/facade/facade.dart",
      "line": 2,
      "col": 26,
      "description": "'EventEmitter' is deprecated and shouldn't be used."
     }
    ],
    "fitness": {
     "magnitude": 3.0,
     "shortcoming": 1.0
    }
   },
   "lib/src/facade/lang.dart": {
    "uri": "package:angular/src/facade/lang.dart",
    "size": 2477,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 44.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/platform/bootstrap.dart": {
    "uri": "package:angular/src/platform/bootstrap.dart",
    "size": 5881,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 105.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/platform/browser/exceptions.dart": {
    "uri": "package:angular/src/platform/browser/exceptions.dart",
    "size": 462,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 10.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/platform/browser/testability.dart": {
    "uri": "package:angular/src/platform/browser/testability.dart",
    "size": 4253,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 93.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/platform/browser/tools/common_tools.dart": {
    "uri": "package:angular/src/platform/browser/tools/common_tools.dart",
    "size": 2610,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 51.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/platform/browser/tools/tools.dart": {
    "uri": "package:angular/src/platform/browser/tools/tools.dart",
    "size": 854,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 18.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/platform/browser_common.dart": {
    "uri": "package:angular/src/platform/browser_common.dart",
    "size": 2365,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 42.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/platform/dom/dom_tokens.dart": {
    "uri": "package:angular/src/platform/dom/dom_tokens.dart",
    "size": 410,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 6.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/platform/dom/events/dom_events.dart": {
    "uri": "package:angular/src/platform/dom/events/dom_events.dart",
    "size": 589,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 13.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/platform/dom/events/event_manager.dart": {
    "uri": "package:angular/src/platform/dom/events/event_manager.dart",
    "size": 2165,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 48.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/platform/dom/events/hammer_common.dart": {
    "uri": "package:angular/src/platform/dom/events/hammer_common.dart",
    "size": 910,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 20.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/platform/dom/events/hammer_gestures.dart": {
    "uri": "package:angular/src/platform/dom/events/hammer_gestures.dart",
    "size": 3072,
    "isFormatted": true,
    "codeProblems": [
     {
      "severity": "INFO",
      "errorType": "HINT",
      "errorCode": "USES_DYNAMIC_AS_BOTTOM",
      "file": "lib/src/platform/dom/events/hammer_gestures.dart",
      "line": 26,
      "col": 28,
      "description": "A function of type '(Object, String) → void' can't be assigned to a variable of type '(dynamic, dynamic) → void'."
     }
    ],
    "fitness": {
     "magnitude": 80.0,
     "shortcoming": 1.0
    }
   },
   "lib/src/platform/dom/events/key_events.dart": {
    "uri": "package:angular/src/platform/dom/events/key_events.dart",
    "size": 4158,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 104.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/platform/dom/shared_styles_host.dart": {
    "uri": "package:angular/src/platform/dom/shared_styles_host.dart",
    "size": 1737,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 45.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/security/dom_sanitization_service.dart": {
    "uri": "package:angular/src/security/dom_sanitization_service.dart",
    "size": 5217,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 92.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/security/dom_sanitization_service_impl.dart": {
    "uri": "package:angular/src/security/dom_sanitization_service_impl.dart",
    "size": 4561,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 96.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/security/html_sanitizer.dart": {
    "uri": "package:angular/src/security/html_sanitizer.dart",
    "size": 2485,
    "isFormatted": true,
    "codeProblems": [
     {
      "severity": "INFO",
      "errorType": "HINT",
      "errorCode": "UNUSED_ELEMENT",
      "file": "lib/src/security/html_sanitizer.dart",
      "line": 4,
      "col": 6,
      "description": "The top level variable '_inertIsTemplate' isn't used."
     }
    ],
    "fitness": {
     "magnitude": 52.0,
     "shortcoming": 1.0
    }
   },
   "lib/src/security/safe_inner_html.dart": {
    "uri": "package:angular/src/security/safe_inner_html.dart",
    "size": 2202,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 40.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/security/style_sanitizer.dart": {
    "uri": "package:angular/src/security/style_sanitizer.dart",
    "size": 4173,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 84.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/security/url_sanitizer.dart": {
    "uri": "package:angular/src/security/url_sanitizer.dart",
    "size": 2204,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 37.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/source_gen/common/annotation_matcher.dart": {
    "uri": "package:angular/src/source_gen/common/annotation_matcher.dart",
    "size": 3677,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 70.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/source_gen/common/logging.dart": {
    "uri": "package:angular/src/source_gen/common/logging.dart",
    "size": 1316,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 29.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/source_gen/common/ng_compiler.dart": {
    "uri": "package:angular/src/source_gen/common/ng_compiler.dart",
    "size": 1421,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 26.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/source_gen/common/url_resolver.dart": {
    "uri": "package:angular/src/source_gen/common/url_resolver.dart",
    "size": 2691,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 54.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/source_gen/source_gen.dart": {
    "uri": "package:angular/src/source_gen/source_gen.dart",
    "size": 878,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 15.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/source_gen/template_compiler/code_builder.dart": {
    "uri": "package:angular/src/source_gen/template_compiler/code_builder.dart",
    "size": 1727,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 36.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/source_gen/template_compiler/compile_metadata.dart": {
    "uri": "package:angular/src/source_gen/template_compiler/compile_metadata.dart",
    "size": 19758,
    "isFormatted": true,
    "codeProblems": [
     {
      "severity": "INFO",
      "errorType": "HINT",
      "errorCode": "USES_DYNAMIC_AS_BOTTOM",
      "file": "lib/src/source_gen/template_compiler/compile_metadata.dart",
      "line": 420,
      "col": 31,
      "description": "A function of type '(DartObject) → CompileDiDependencyMetadata' can't be assigned to a variable of type '(dynamic) → CompileDiDependencyMetadata'."
     }
    ],
    "fitness": {
     "magnitude": 378.0,
     "shortcoming": 1.0
    }
   },
   "lib/src/source_gen/template_compiler/dart_object_utils.dart": {
    "uri": "package:angular/src/source_gen/template_compiler/dart_object_utils.dart",
    "size": 5316,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 105.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/source_gen/template_compiler/find_components.dart": {
    "uri": "package:angular/src/source_gen/template_compiler/find_components.dart",
    "size": 23603,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 455.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/source_gen/template_compiler/generator.dart": {
    "uri": "package:angular/src/source_gen/template_compiler/generator.dart",
    "size": 2286,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 45.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/source_gen/template_compiler/pipe_visitor.dart": {
    "uri": "package:angular/src/source_gen/template_compiler/pipe_visitor.dart",
    "size": 1298,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 27.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/source_gen/template_compiler/template_compiler_outputs.dart": {
    "uri": "package:angular/src/source_gen/template_compiler/template_compiler_outputs.dart",
    "size": 307,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 6.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/source_gen/template_compiler/template_processor.dart": {
    "uri": "package:angular/src/source_gen/template_compiler/template_processor.dart",
    "size": 2962,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 55.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/asset_consumer/transformer.dart": {
    "uri": "package:angular/src/transform/asset_consumer/transformer.dart",
    "size": 561,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 12.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/common/eager_transformer_wrapper.dart": {
    "uri": "package:angular/src/transform/common/eager_transformer_wrapper.dart",
    "size": 1219,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 25.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/common/logging.dart": {
    "uri": "package:angular/src/transform/common/logging.dart",
    "size": 4517,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 97.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/common/mirror_matcher.dart": {
    "uri": "package:angular/src/transform/common/mirror_matcher.dart",
    "size": 1760,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 30.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/common/naive_eval.dart": {
    "uri": "package:angular/src/transform/common/naive_eval.dart",
    "size": 893,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 16.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/common/names.dart": {
    "uri": "package:angular/src/transform/common/names.dart",
    "size": 3467,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 64.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/common/ng_compiler.dart": {
    "uri": "package:angular/src/transform/common/ng_compiler.dart",
    "size": 1319,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 25.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/common/zone.dart": {
    "uri": "package:angular/src/transform/common/zone.dart",
    "size": 2807,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 56.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/reflection_remover/codegen.dart": {
    "uri": "package:angular/src/transform/reflection_remover/codegen.dart",
    "size": 1130,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 22.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/reflection_remover/entrypoint_matcher.dart": {
    "uri": "package:angular/src/transform/reflection_remover/entrypoint_matcher.dart",
    "size": 1773,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 35.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/reflection_remover/remove_reflection_capabilities.dart": {
    "uri": "package:angular/src/transform/reflection_remover/remove_reflection_capabilities.dart",
    "size": 933,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 19.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/reflection_remover/rewriter.dart": {
    "uri": "package:angular/src/transform/reflection_remover/rewriter.dart",
    "size": 9728,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 190.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/reflection_remover/transformer.dart": {
    "uri": "package:angular/src/transform/reflection_remover/transformer.dart",
    "size": 1745,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 32.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/stylesheet_compiler/processor.dart": {
    "uri": "package:angular/src/transform/stylesheet_compiler/processor.dart",
    "size": 2792,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 54.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/stylesheet_compiler/transformer.dart": {
    "uri": "package:angular/src/transform/stylesheet_compiler/transformer.dart",
    "size": 1559,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 32.0,
     "shortcoming": 0.0
    }
   },
   "lib/src/transform/transformer.dart": {
    "uri": "package:angular/src/transform/transformer.dart",
    "size": 1304,
    "isFormatted": true,
    "codeProblems": [],
    "fitness": {
     "magnitude": 26.0,
     "shortcoming": 0.0
    }
   },
   "lib/transform/codegen.dart": {
    "uri": "package:angular/transform/codegen.dart",
    "size": 1603,
    "isFormatted": true,
    "codeProblems": [],
    "directLibs": [
     "package:angular/source_gen.dart",
     "package:angular/src/transform/asset_consumer/transformer.dart",
     "package:angular/src/transform/common/eager_transformer_wrapper.dart",
     "package:angular/src/transform/stylesheet_compiler/transformer.dart",
     "package:angular_compiler/angular_compiler.dart",
     "package:barback/barback.dart",
     "package:build_barback/build_barback.dart"
    ],
    "platform": {
     "worksEverywhere": false,
     "restrictedTo": [
      "server"
     ]
    },
    "fitness": {
     "magnitude": 38.0,
     "shortcoming": 0.0
    }
   },
   "lib/transform/reflection_remover.dart": {
    "uri": "package:angular/transform/reflection_remover.dart",
    "size": 2405,
    "isFormatted": true,
    "codeProblems": [],
    "directLibs": [
     "dart:async",
     "package:angular/src/transform/reflection_remover/transformer.dart",
     "package:angular_compiler/angular_compiler.dart",
     "package:barback/barback.dart"
    ],
    "platform": {
     "worksEverywhere": false,
     "restrictedTo": [
      "server"
     ]
    },
    "fitness": {
     "magnitude": 46.0,
     "shortcoming": 0.0
    }
   },
   "lib/transformer.dart": {
    "uri": "package:angular/transformer.dart",
    "size": 87,
    "isFormatted": true,
    "codeProblems": [],
    "directLibs": [
     "package:angular/src/transform/transformer.dart"
    ],
    "platform": {
     "worksEverywhere": false,
     "restrictedTo": [
      "server"
     ]
    },
    "fitness": {
     "magnitude": 3.0,
     "shortcoming": 0.0
    }
   }
  },
  "platform": {
   "worksEverywhere": false,
   "restrictedTo": [
    "web"
   ],
   "reason": "primary library - `package:angular/angular.dart`"
  },
  "licenses": [
   {
    "path": "LICENSE",
    "name": "MIT"
   }
  ],
  "maintenance": {
   "missingChangelog": false,
   "missingExample": false,
   "missingReadme": false,
   "missingAnalysisOptions": true,
   "oldAnalysisOptions": false,
   "strongModeEnabled": false,
   "isExperimentalVersion": false,
   "isPreReleaseVersion": false,
   "errorCount": 1,
   "warningCount": 0,
   "hintCount": 0
  },
  "fitness": {
   "magnitude": 21662.0,
   "shortcoming": 227.20000000000002
  },
  "suggestions": [
   {
    "level": "error",
    "title": "Fix `lib/src/core/zone/ng_zone.dart`.",
    "description": "Strong-mode analysis of `lib/src/core/zone/ng_zone.dart` failed with the following error:\n\nline: 144 col: 13  \nThe argument type '(Zone, ZoneDelegate, Zone, () → dynamic) → dynamic' can't be assigned to the parameter type '<R>(Zone, ZoneDelegate, Zone, () → R) → R'.\n",
    "file": "lib/src/core/zone/ng_zone.dart"
   }
  ]
 }
''';
