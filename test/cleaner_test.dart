import 'package:flutter_test/flutter_test.dart';
import 'package:tidypika/core/cleaner.dart';

void main() {
  group('isProtected', () {
    test('refuses a system binary', () {
      expect(isProtected(r'C:\Windows\System32\ntdll.dll'), isTrue);
      expect(isProtected(r'C:\Windows\explorer.exe'), isTrue);
      expect(isProtected(r'C:\Program Files\App\driver.sys'), isTrue);
      expect(isProtected(r'C:\Program Files (x86)\App\setup.msi'), isTrue);
    });

    test('allows the folders that exist to be emptied', () {
      // The bug this guards against: an expanded update payload is made of
      // exactly the extensions the guard is there for, so Windows Update Cache
      // and the Windows temp folder cleaned almost nothing.
      expect(
        isProtected(
          r'C:\Windows\SoftwareDistribution\Download\abc\update.dll',
        ),
        isFalse,
      );
      expect(isProtected(r'C:\Windows\Temp\installer.exe'), isFalse);
      expect(isProtected(r'C:\Windows\Logs\setup.cat'), isFalse);
      expect(isProtected(r'C:\Windows\System32\LogFiles\old.mui'), isFalse);
    });

    test('only ever refuses the extensions it lists', () {
      expect(isProtected(r'C:\Windows\System32\config.txt'), isFalse);
      expect(isProtected(r'C:\Windows\memory.dmp'), isFalse);
    });

    test('leaves everything outside the protected roots alone', () {
      expect(isProtected(r'D:\Games\game.exe'), isFalse);
      expect(isProtected(r'C:\Users\me\Downloads\installer.exe'), isFalse);
    });

    test('does not care about case', () {
      expect(isProtected(r'c:\WINDOWS\SYSTEM32\NTDLL.DLL'), isTrue);
      expect(isProtected(r'C:\WINDOWS\TEMP\SETUP.EXE'), isFalse);
    });
  });
}
