import 'package:flutter/foundation.dart';

/// TEMPORARY diagnostics for the "UI does not restore an active download" bug.
///
/// Both isolates print through here so a single logcat filter shows the whole
/// round trip in order:
///
///   adb logcat -s flutter | findstr FGS_TRACE
///
/// [side] is 'UI' or 'BG' so the two isolates can be told apart — they share
/// one logcat stream and are otherwise indistinguishable.
///
/// Delete this file and its call sites once the failing step is identified.
void fgsTrace(String side, String step, [Object? detail]) {
  final time = DateTime.now().toIso8601String().substring(11, 23);
  final suffix = detail == null ? '' : ' | $detail';
  debugPrint('FGS_TRACE [$time][$side] $step$suffix');
}
