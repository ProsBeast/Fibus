import 'package:fibus/main_commuter.dart' as commuter;

/// Default entry point used by `flutter run` without `-t`.
///
/// Fibus ships as two apps, each with its own entry point and Android flavor:
///   flutter run --flavor commuter -t lib/main_commuter.dart
///   flutter run --flavor tracker -t lib/main_tracker.dart
/// This file starts the Commuter app so a bare run still opens something useful.
void main() => commuter.main();
