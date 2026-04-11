import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'external_progress_widget_service.dart';

class StepCounterService {
  StepCounterService._();

  static final StepCounterService instance = StepCounterService._();

  static const String _stepsDateKey = 'steps.current_date';
  static const String _stepsBaselineKey = 'steps.sensor_baseline';
  static const String _stepsPermissionAskedKey = 'steps.permission_asked';
  static const String _stepsHistoryKey = 'steps.history';

  final ValueNotifier<int> dailySteps = ValueNotifier<int>(0);
  final ValueNotifier<Map<String, int>> stepHistory = ValueNotifier(
    <String, int>{},
  );

  StreamSubscription<StepCount>? _stepSubscription;
  bool _initialized = false;

  int get currentSteps => dailySteps.value;

  List<MapEntry<DateTime, int>> getLast7DaysHistory() {
    final history = stepHistory.value;
    final now = DateTime.now();

    return List<MapEntry<DateTime, int>>.generate(7, (index) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - index));
      final key = _dateKey(date);
      return MapEntry(date, history[key] ?? 0);
    });
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    await syncCurrentDay();
    await _startStepCounter();
  }

  Future<void> syncCurrentDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final savedDate = prefs.getString(_stepsDateKey);
    final history = _readHistory(prefs);

    if (savedDate != today) {
      await prefs.setString(_stepsDateKey, today);
      await prefs.setInt('pasos', 0);
      history[today] = 0;
      await _writeHistory(prefs, history);
      stepHistory.value = Map<String, int>.from(history);
      dailySteps.value = 0;
      await ExternalProgressWidgetService.syncFromPrefs();
      return;
    }

    history.putIfAbsent(today, () => prefs.getInt('pasos') ?? 0);
    await _writeHistory(prefs, history);
    stepHistory.value = Map<String, int>.from(history);
    dailySteps.value = prefs.getInt('pasos') ?? 0;
  }

  Future<void> _startStepCounter() async {
    if (!_isSupportedPlatform) {
      return;
    }

    final granted = await _requestPermissionIfNeeded();
    if (!granted) {
      return;
    }

    _stepSubscription ??= Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<bool> _requestPermissionIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final status = await Permission.activityRecognition.status;

    if (status.isGranted) {
      return true;
    }

    final alreadyAsked = prefs.getBool(_stepsPermissionAskedKey) ?? false;
    if (alreadyAsked && status.isPermanentlyDenied) {
      return false;
    }

    await prefs.setBool(_stepsPermissionAskedKey, true);
    final requested = await Permission.activityRecognition.request();
    return requested.isGranted;
  }

  Future<void> _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final savedDate = prefs.getString(_stepsDateKey);
    final history = _readHistory(prefs);
    var baseline = prefs.getInt(_stepsBaselineKey);

    if (savedDate != today) {
      baseline = event.steps;
      await prefs.setString(_stepsDateKey, today);
      await prefs.setInt(_stepsBaselineKey, baseline);
      await prefs.setInt('pasos', 0);
      history[today] = 0;
      await _writeHistory(prefs, history);
      stepHistory.value = Map<String, int>.from(history);
      dailySteps.value = 0;
      await ExternalProgressWidgetService.syncFromPrefs();
      return;
    }

    if (baseline == null) {
      final storedSteps = prefs.getInt('pasos') ?? 0;
      baseline = event.steps - storedSteps;
      if (baseline < 0) {
        baseline = event.steps;
      }
      await prefs.setInt(_stepsBaselineKey, baseline);
    }

    if (event.steps < baseline) {
      baseline = event.steps;
      await prefs.setInt(_stepsBaselineKey, baseline);
      await prefs.setInt('pasos', 0);
      history[today] = 0;
      await _writeHistory(prefs, history);
      stepHistory.value = Map<String, int>.from(history);
      dailySteps.value = 0;
      await ExternalProgressWidgetService.syncFromPrefs();
      return;
    }

    final newDailySteps = event.steps - baseline;
    if (newDailySteps != dailySteps.value) {
      dailySteps.value = newDailySteps;
      await prefs.setInt('pasos', newDailySteps);
      history[today] = newDailySteps;
      await _writeHistory(prefs, history);
      stepHistory.value = Map<String, int>.from(history);
      await ExternalProgressWidgetService.syncFromPrefs();
    }
  }

  Map<String, int> _readHistory(SharedPreferences prefs) {
    final rawHistory = prefs.getString(_stepsHistoryKey);
    if (rawHistory == null || rawHistory.isEmpty) {
      return <String, int>{};
    }

    return Map<String, int>.from(
      (jsonDecode(rawHistory) as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
    );
  }

  Future<void> _writeHistory(
    SharedPreferences prefs,
    Map<String, int> history,
  ) async {
    final sortedEntries = history.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final trimmedEntries = sortedEntries.length > 30
        ? sortedEntries.sublist(sortedEntries.length - 30)
        : sortedEntries;
    final trimmedHistory = <String, int>{
      for (final entry in trimmedEntries) entry.key: entry.value,
    };

    await prefs.setString(_stepsHistoryKey, jsonEncode(trimmedHistory));
  }

  bool get _isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String _todayKey() {
    return _dateKey(DateTime.now());
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
