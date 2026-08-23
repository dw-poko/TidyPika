import 'dart:async';

/// Announced whenever this app has changed what is on disk.
///
/// The dashboard reads its figures once and then sits in an IndexedStack,
/// alive but never rebuilt, so a clean on another page left it showing the
/// free space from before. Rather than have every page know about the
/// dashboard, the pages say what they did and whoever is showing a figure
/// about the disk decides to read it again.
///
/// A broadcast stream rather than a notifier: this is core, and core has no
/// Flutter in it.
final StreamController<void> _changes = StreamController<void>.broadcast();

Stream<void> get storageChanged => _changes.stream;

void announceStorageChanged() => _changes.add(null);
