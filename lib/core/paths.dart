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
