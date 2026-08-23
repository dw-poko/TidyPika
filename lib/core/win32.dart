import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Minimal hand-rolled bindings for the Win32 areas this app needs: drive
/// capacity, Recycle Bin deletion, the UI language, and whether the process is
/// elevated. Declaring them here rather than depending on a bindings package
/// keeps the surface small and the struct layout under our own control.

final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');
final DynamicLibrary _shell32 = DynamicLibrary.open('shell32.dll');
final DynamicLibrary _advapi32 = DynamicLibrary.open('advapi32.dll');

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

final int Function() getCurrentProcess = _kernel32
    .lookupFunction<IntPtr Function(), int Function()>('GetCurrentProcess');

final int Function(int) closeHandle = _kernel32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');

final int Function(int, int, Pointer<IntPtr>) openProcessToken =
    _advapi32.lookupFunction<Int32 Function(IntPtr, Uint32, Pointer<IntPtr>),
        int Function(int, int, Pointer<IntPtr>)>('OpenProcessToken');

final int Function(int, int, Pointer<Void>, int, Pointer<Uint32>)
    getTokenInformation = _advapi32.lookupFunction<
        Int32 Function(IntPtr, Int32, Pointer<Void>, Uint32, Pointer<Uint32>),
        int Function(int, int, Pointer<Void>, int, Pointer<Uint32>)>(
  'GetTokenInformation',
);

final int Function(
  Pointer<Void>,
  Pointer<Utf16>,
  Pointer<Utf16>,
  Pointer<Utf16>,
  Pointer<Utf16>,
  int,
) shellExecute = _shell32.lookupFunction<
    IntPtr Function(
      Pointer<Void>,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Int32,
    ),
    int Function(
      Pointer<Void>,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Pointer<Utf16>,
      int,
    )>('ShellExecuteW');

const int _tokenQuery = 0x0008;
const int _tokenElevation = 20;
const int _swShowNormal = 1;

/// Whether this process holds an elevated token.
///
/// Being in the Administrators group is not the same thing: under UAC the
/// process starts with the filtered token, which is why the Windows folders
/// refuse a delete even for an administrator.
bool isElevated() {
  final token = calloc<IntPtr>();
  final elevated = calloc<Uint32>();
  final returned = calloc<Uint32>();

  try {
    if (openProcessToken(getCurrentProcess(), _tokenQuery, token) == 0) {
      return false;
    }

    try {
      final ok = getTokenInformation(
        token.value,
        _tokenElevation,
        elevated.cast<Void>(),
        sizeOf<Uint32>(),
        returned,
      );

      return ok != 0 && elevated.value != 0;
    } finally {
      closeHandle(token.value);
    }
  } catch (_) {
    return false;
  } finally {
    calloc
      ..free(token)
      ..free(elevated)
      ..free(returned);
  }
}

/// Starts this executable again through the `runas` verb, which is what puts
/// the UAC prompt on screen. False means the prompt was dismissed, so the
/// caller should stay where it is.
bool relaunchElevated() {
  final verb = 'runas'.toNativeUtf16(allocator: calloc);
  final file = Platform.resolvedExecutable.toNativeUtf16(allocator: calloc);

  try {
    return shellExecute(nullptr, verb, file, nullptr, nullptr, _swShowNormal) >
        32;
  } catch (_) {
    return false;
  } finally {
    calloc
      ..free(verb)
      ..free(file);
  }
}
