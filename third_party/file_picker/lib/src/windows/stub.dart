import 'package:file_picker/file_picker.dart';

/// Placeholder implementation used on platforms where `dart:ffi` is not
/// available (for example, Flutter Web). All operations throw by default to
/// match the behaviour of the real Windows implementation when it cannot
/// operate.
class FilePickerWindows extends FilePicker {
  FilePickerWindows();
}

/// Stub method to support both dart:ffi and web.
FilePicker filePickerWithFFI() =>
    throw UnsupportedError('Windows file picker is not available.');
