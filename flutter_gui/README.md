# Flutter GUI for CH57x keyboard tool

This directory contains a Flutter UI that talks to the Rust core through
`flutter_rust_bridge`. It renders a clickable grid of keys and knobs that mirrors
the supported keyboard layouts and lets you validate or upload a YAML mapping.

## Prerequisites

* Flutter/Dart SDK
* A compiled native library from this repository (see below)
* `flutter_rust_bridge_codegen` (v1.82.6 was used here)

> Note: The checked-in `pubspec.lock` is a placeholder to let the codegen run in
> environments without the Dart SDK. Replace it by running `flutter pub get`.

## Rebuilding the bindings

1. Ensure Dart/Flutter dependencies are installed:
   ```bash
   cd flutter_gui
   flutter pub get
   ```
2. Regenerate the bridge files after making Rust or Dart API changes:
   ```bash
   flutter_rust_bridge_codegen \
     --rust-input ../src/bridge.rs \
     --rust-output ../src/bridge_generated.rs \
     --dart-output lib/bridge_generated.dart \
     --class-name KeyboardApi
   ```

## Building the native library

From the repository root:

```bash
cargo build --release --lib
```

Copy the resulting artifact to `flutter_gui/native/` so the Flutter loader can
find it:

* Linux: `target/release/libch57x_keyboard_tool.so`
* macOS: `target/release/libch57x_keyboard_tool.dylib`
* Windows: `target/release/ch57x_keyboard_tool.dll`

## Running the app

```bash
cd flutter_gui
flutter run
```

The home screen shows a dropdown for the supported layouts, a grid of buttons
and knobs you can click to mirror the physical device, and a YAML editor with
Validate/Upload actions backed by the Rust core.
