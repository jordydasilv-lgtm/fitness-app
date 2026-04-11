import 'package:flutter/foundation.dart';

class AppDataSyncService {
  AppDataSyncService._();

  static final AppDataSyncService instance = AppDataSyncService._();

  final ValueNotifier<int> refreshTick = ValueNotifier<int>(0);

  void notifyDataChanged() {
    refreshTick.value++;
  }
}
