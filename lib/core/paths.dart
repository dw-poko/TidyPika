/// A Windows path as the steps that reach it.
///
/// `C:\Users\me` becomes the drive and each folder under it, paired with the
/// path that gets there — which is what a breadcrumb needs and what makes
/// clicking one of them a plain analyse of that path.
List<(String, String)> pathCrumbs(String path) {
  final parts = path.replaceAll('/', r'\').split(r'\')
    ..removeWhere((part) => part.isEmpty);
  if (parts.isEmpty) return const [];

  final crumbs = <(String, String)>[(parts.first, '${parts.first}\\')];
  var reached = crumbs.first.$2;

  for (final part in parts.skip(1)) {
    reached = reached.endsWith(r'\') ? '$reached$part' : '$reached\\$part';
    crumbs.add((part, reached));
  }

  return crumbs;
}

/// Length at which a path is handed to Windows in its extended form.
///
/// Below the limit rather than at it: a directory this long has children
/// longer still, and the prefix has to go on before the name that overflows
/// is built, not after.
const int _extendedPathThreshold = 240;

/// The longest a path can be in the plain Win32 form.
const int maxPath = 260;

/// A path in the form Win32 accepts past 260 characters.
///
/// Only absolute paths are prefixed. The extended form does not accept a
/// relative path, and it turns off the normalising Windows otherwise does —
/// which is why forward slashes are squared away first and why a path that
/// does not need the prefix does not get one.
String extendedPath(String path) {
  if (path.startsWith(r'\\?\')) return path;

  final normalised = path.replaceAll('/', r'\');
  if (normalised.length < _extendedPathThreshold) return normalised;

  // A UNC path takes a form of its own: \\server\share becomes
  // \\?\UNC\server\share.
  if (normalised.startsWith(r'\\')) {
    return r'\\?\UNC\' + normalised.substring(2);
  }

  final isDrivePath =
      normalised.length >= 3 && normalised[1] == ':' && normalised[2] == r'\';

  return isDrivePath ? r'\\?\' + normalised : normalised;
}

/// The path as it should be shown and stored — without the prefix, which is a
/// detail of how Windows was asked rather than where the file is.
String displayPath(String path) {
  if (path.startsWith(r'\\?\UNC\')) return r'\\' + path.substring(8);
  if (path.startsWith(r'\\?\')) return path.substring(4);

  return path;
}

/// Whether a path is longer than the shell can handle.
///
/// The Recycle Bin is reached through `SHFileOperation`, which predates the
/// extended form and will not take it, so a file this deep can be found and
/// measured but not recycled.
bool exceedsMaxPath(String path) => displayPath(path).length >= maxPath;
