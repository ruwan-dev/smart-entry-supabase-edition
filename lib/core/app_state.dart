import 'package:flutter/foundation.dart';

class AppState {
  static final ValueNotifier<String?> currentOrganizationId = ValueNotifier<String?>(null);
  static final ValueNotifier<String?> currentUsername = ValueNotifier<String?>(null);

  static String? get orgId => currentOrganizationId.value;
  static String? get username => currentUsername.value;
}
