import 'dart:ffi';
import 'dart:io';

import 'bridge_generated.dart';

const _libName = 'ch57x_keyboard_tool';

Future<KeyboardApi> initApi() async {
  final library = _open();
  return KeyboardApiImpl(library);
}

DynamicLibrary _open() {
  final candidates = <String>[
    // Prefer a colocated native build under flutter_gui/native
    'native/${_fileName()}',
    // Fallback to default loader search locations
    _fileName(),
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return DynamicLibrary.open(candidate);
    }
  }

  // Let the platform loader search default paths (e.g. /usr/lib)
  return DynamicLibrary.open(_fileName());
}

String _fileName() {
  if (Platform.isMacOS) return 'lib$_libName.dylib';
  if (Platform.isWindows) return '$_libName.dll';
  return 'lib$_libName.so';
}
