import 'dart:isolate';

import 'cleaner.dart';
import 'duplicate_finder.dart';
import 'models.dart';
import 'scanner.dart';

/// Scans run on their own isolate so a walk of C:\ never blocks the frame loop.
sealed class TaskEvent {}

class TaskProgress extends TaskEvent {
  TaskProgress(this.progress);

  final ScanProgress progress;
}

class TaskDone extends TaskEvent {
  TaskDone(this.value);

  final Object? value;
}

class TaskFailure extends TaskEvent {
  TaskFailure(this.message);

  final String message;
}

/// Cancelling the returned stream's subscription kills the isolate, which is
/// how a running scan is stopped.
Stream<TaskEvent> _run(
  void Function(List<Object?>) entry, [
  Object? argument,
]) async* {
  final receive = ReceivePort();
  final isolate = await Isolate.spawn(entry, [receive.sendPort, argument]);

  try {
    await for (final message in receive) {
      final event = message as TaskEvent;
      yield event;
      if (event is TaskDone || event is TaskFailure) return;
    }
  } finally {
    receive.close();
    isolate.kill(priority: Isolate.immediate);
  }
}

Stream<TaskEvent> scanTempFiles() => _run(_tempEntry);

Stream<TaskEvent> scanLargeFilesTask(
  String root,
  int minSizeBytes, {
  int? untouchedForDays,
}) =>
    _run(_largeEntry, [root, minSizeBytes, untouchedForDays]);

Stream<TaskEvent> findDuplicatesTask(String root) =>
    _run(_duplicatesEntry, root);

Stream<TaskEvent> analyzeDirectoryTask(String root) =>
    _run(_analyzeEntry, root);

Stream<TaskEvent> cleanTask(List<String> files, bool useRecycleBin) =>
    _run(_cleanEntry, [files, useRecycleBin]);

void _tempEntry(List<Object?> args) {
  final send = args[0] as SendPort;
  try {
    final results = scanAllTargets(
      onProgress: (progress) => send.send(TaskProgress(progress)),
    );
    send.send(TaskDone(results));
  } catch (error) {
    send.send(TaskFailure(error.toString()));
  }
}

void _largeEntry(List<Object?> args) {
  final send = args[0] as SendPort;
  final params = args[1]! as List<Object?>;

  try {
    final results = scanLargeFiles(
      params[0]! as String,
      params[1]! as int,
      untouchedForDays: params[2] as int?,
      onProgress: (progress) => send.send(TaskProgress(progress)),
    );
    send.send(TaskDone(results));
  } catch (error) {
    send.send(TaskFailure(error.toString()));
  }
}

void _duplicatesEntry(List<Object?> args) {
  final send = args[0] as SendPort;

  try {
    final results = findDuplicates(
      args[1]! as String,
      onProgress: (progress) => send.send(TaskProgress(progress)),
    );
    send.send(TaskDone(results));
  } catch (error) {
    send.send(TaskFailure(error.toString()));
  }
}

void _analyzeEntry(List<Object?> args) {
  final send = args[0] as SendPort;

  try {
    final results = analyzeDirectory(
      args[1]! as String,
      onProgress: (progress) => send.send(TaskProgress(progress)),
    );
    send.send(TaskDone(results));
  } catch (error) {
    send.send(TaskFailure(error.toString()));
  }
}

void _cleanEntry(List<Object?> args) {
  final send = args[0] as SendPort;
  final params = args[1]! as List<Object?>;

  try {
    final result = deleteFiles(
      (params[0]! as List).cast<String>(),
      useRecycleBin: params[1]! as bool,
      onProgress: (progress) => send.send(TaskProgress(progress)),
    );
    send.send(TaskDone(result));
  } catch (error) {
    send.send(TaskFailure(error.toString()));
  }
}
