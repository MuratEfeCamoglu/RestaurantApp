import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';

/// `package:sqlite3` needs a native SQLite library to talk to. Flutter apps
/// get this bundled automatically (via `sqlite3_flutter_libs`), but a plain
/// Dart server does not — so we point it at the `sqlite3.dll` that ships
/// next to this backend on Windows, and fall back to the system library on
/// Linux/macOS (install `libsqlite3` there, e.g. `apt install libsqlite3-0`
/// or it's already present on macOS).
void configureSqliteNativeLibrary() {
  final backendDir = p.dirname(p.dirname(Platform.script.toFilePath()));
  // When run via `dart run bin/server.dart` Platform.script points at
  // bin/server.dart, so backendDir above resolves to the backend/ folder.
  // When run from a compiled exe it points at the exe itself; handle both.
  final candidates = <String>[
    p.join(backendDir, 'sqlite3.dll'),
    p.join(p.dirname(Platform.script.toFilePath()), 'sqlite3.dll'),
    p.join(Directory.current.path, 'sqlite3.dll'),
  ];

  open.overrideFor(OperatingSystem.windows, () {
    for (final path in candidates) {
      if (File(path).existsSync()) {
        return DynamicLibrary.open(path);
      }
    }
    // Last resort: hope it's on PATH.
    return DynamicLibrary.open('sqlite3.dll');
  });
}
