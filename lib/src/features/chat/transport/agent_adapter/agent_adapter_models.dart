import 'package:pocket_relay/src/core/models/connection_models.dart';

part 'models/agent_adapter_event_models.dart';
part 'models/agent_adapter_thread_models.dart';
part 'models/agent_adapter_catalog_models.dart';
part 'models/agent_adapter_turn_models.dart';

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
