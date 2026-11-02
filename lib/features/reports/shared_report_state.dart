import 'package:flutter/foundation.dart';

class SharedReportState {
  static final ValueNotifier<int> selectedMonth = ValueNotifier<int>(DateTime.now().month);
  static final ValueNotifier<int> selectedYear = ValueNotifier<int>(DateTime.now().year);
}
