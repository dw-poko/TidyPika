import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Minimal hand-rolled bindings for the three Win32 areas this app needs:
/// drive capacity, Recycle Bin deletion, and the UI language. Declaring them
/// here rather than depending on a bindings package keeps the surface small
/// and the struct layout under our own control.

final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');
final DynamicLibrary _shell32 = DynamicLibrary.open('shell32.dll');

/// Bitmask of drive letters currently present, A: as bit 0.
final int Function() getLogicalDrives = _kernel32
    .lookupFunction<Uint32 Function(), int Function()>('GetLogicalDrives');

final int Function(Pointer<Utf16>) getDriveType =
    _kernel32.lookupFunction<Uint32 Function(Pointer<Utf16>),
        int Function(Pointer<Utf16>)>('GetDriveTypeW');

final int Function(
  Pointer<Utf16>,
  Pointer<Uint64>,
  Pointer<Uint64>,
  Pointer<Uint64>,
) getDiskFreeSpaceEx = _kernel32.lookupFunction<
    Int32 Function(
      Pointer<Utf16>,
      Pointer<Uint64>,
      Pointer<Uint64>,
      Pointer<Uint64>,
    ),
    int Function(
      Pointer<Utf16>,
      Pointer<Uint64>,
      Pointer<Uint64>,
      Pointer<Uint64>,
    )>('GetDiskFreeSpaceExW');

final int Function() getUserDefaultUILanguage =
    _kernel32.lookupFunction<Uint16 Function(), int Function()>(
  'GetUserDefaultUILanguage',
);

const int driveRemovable = 2;
const int driveFixed = 3;

const int foDelete = 0x0003;
const int fofSilent = 0x0004;
const int fofNoConfirmation = 0x0010;
const int fofAllowUndo = 0x0040;
const int fofNoErrorUi = 0x0400;

final class ShFileOpStruct extends Struct {
  external Pointer<Void> hwnd;

  @Uint32()
  external int wFunc;

  external Pointer<Utf16> pFrom;
  external Pointer<Utf16> pTo;

  @Uint16()
  external int fFlags;

  @Int32()
  external int fAnyOperationsAborted;

  external Pointer<Void> hNameMappings;
  external Pointer<Utf16> lpszProgressTitle;
}

final int Function(Pointer<ShFileOpStruct>) shFileOperation =
    _shell32.lookupFunction<Int32 Function(Pointer<ShFileOpStruct>),
        int Function(Pointer<ShFileOpStruct>)>('SHFileOperationW');

/// Builds the double-null-terminated path list `SHFileOperation` expects:
/// `path1\0path2\0\0`.
///
/// `toNativeUtf16` preserves embedded nulls and appends one of its own, so
/// joining on a null and adding a trailing null produces the required form.
Pointer<Utf16> toPathList(List<String> paths, Allocator allocator) {
  final nul = String.fromCharCode(0);
  return '${paths.join(nul)}$nul'.toNativeUtf16(allocator: allocator);
}

/// Primary language id of the Windows UI, e.g. 0x12 for Korean.
int primaryUiLanguage() => getUserDefaultUILanguage() & 0x3FF;

const int langKorean = 0x12;
