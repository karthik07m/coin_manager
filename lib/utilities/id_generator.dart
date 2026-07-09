import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Collision-proof record id. Replaces the old
/// `DateTime.now().millisecondsSinceEpoch.toString()` pattern, which produced
/// duplicate ids when two records were created within the same millisecond
/// (rapid taps, batch generation, imports).
String newId() => _uuid.v4();
