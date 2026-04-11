import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationSettingsData {
  final bool trainingEnabled;
  final int trainingHour;
  final int trainingMinute;
  final bool breakfastEnabled;
  final int breakfastHour;
  final int breakfastMinute;
  final bool lunchEnabled;
  final int lunchHour;
  final int lunchMinute;
  final bool dinnerEnabled;
  final int dinnerHour;
  final int dinnerMinute;
  final bool waterEnabled;
  final int waterStartHour;
  final int waterEndHour;
  final int waterIntervalHours;
  final bool summaryEnabled;
  final int summaryHour;
  final int summaryMinute;

  const NotificationSettingsData({
    required this.trainingEnabled,
    required this.trainingHour,
    required this.trainingMinute,
    required this.breakfastEnabled,
    required this.breakfastHour,
    required this.breakfastMinute,
    required this.lunchEnabled,
    required this.lunchHour,
    required this.lunchMinute,
    required this.dinnerEnabled,
    required this.dinnerHour,
    required this.dinnerMinute,
    required this.waterEnabled,
    required this.waterStartHour,
    required this.waterEndHour,
    required this.waterIntervalHours,
    required this.summaryEnabled,
    required this.summaryHour,
    required this.summaryMinute,
  });

  factory NotificationSettingsData.defaults() {
    return const NotificationSettingsData(
      trainingEnabled: true,
      trainingHour: 18,
      trainingMinute: 0,
      breakfastEnabled: true,
      breakfastHour: 8,
      breakfastMinute: 0,
      lunchEnabled: true,
      lunchHour: 13,
      lunchMinute: 0,
      dinnerEnabled: true,
      dinnerHour: 19,
      dinnerMinute: 0,
      waterEnabled: true,
      waterStartHour: 8,
      waterEndHour: 20,
      waterIntervalHours: 2,
      summaryEnabled: true,
      summaryHour: 21,
      summaryMinute: 0,
    );
  }

  NotificationSettingsData copyWith({
    bool? trainingEnabled,
    int? trainingHour,
    int? trainingMinute,
    bool? breakfastEnabled,
    int? breakfastHour,
    int? breakfastMinute,
    bool? lunchEnabled,
    int? lunchHour,
    int? lunchMinute,
    bool? dinnerEnabled,
    int? dinnerHour,
    int? dinnerMinute,
    bool? waterEnabled,
    int? waterStartHour,
    int? waterEndHour,
    int? waterIntervalHours,
    bool? summaryEnabled,
    int? summaryHour,
    int? summaryMinute,
  }) {
    return NotificationSettingsData(
      trainingEnabled: trainingEnabled ?? this.trainingEnabled,
      trainingHour: trainingHour ?? this.trainingHour,
      trainingMinute: trainingMinute ?? this.trainingMinute,
      breakfastEnabled: breakfastEnabled ?? this.breakfastEnabled,
      breakfastHour: breakfastHour ?? this.breakfastHour,
      breakfastMinute: breakfastMinute ?? this.breakfastMinute,
      lunchEnabled: lunchEnabled ?? this.lunchEnabled,
      lunchHour: lunchHour ?? this.lunchHour,
      lunchMinute: lunchMinute ?? this.lunchMinute,
      dinnerEnabled: dinnerEnabled ?? this.dinnerEnabled,
      dinnerHour: dinnerHour ?? this.dinnerHour,
      dinnerMinute: dinnerMinute ?? this.dinnerMinute,
      waterEnabled: waterEnabled ?? this.waterEnabled,
      waterStartHour: waterStartHour ?? this.waterStartHour,
      waterEndHour: waterEndHour ?? this.waterEndHour,
      waterIntervalHours: waterIntervalHours ?? this.waterIntervalHours,
      summaryEnabled: summaryEnabled ?? this.summaryEnabled,
      summaryHour: summaryHour ?? this.summaryHour,
      summaryMinute: summaryMinute ?? this.summaryMinute,
    );
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _remindersChannelId = 'fitapp_recordatorios';
  static const String _summaryChannelId = 'fitapp_resumen';
  static const List<int> _defaultNotificationIds = <int>[
    100,
    101,
    102,
    103,
    200,
    201,
    202,
    203,
    204,
    205,
    206,
    207,
    208,
    209,
    210,
    211,
    212,
    213,
    214,
    215,
    216,
    217,
    218,
    219,
    220,
    221,
    222,
    223,
    300,
  ];

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    tz.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    await _notifications.initialize(settings: settings);
    await _requestPermissions();
  }

  Future<void> scheduleDefaultNotifications() async {
    await saveSettings(NotificationSettingsData.defaults());
    await scheduleSavedNotifications();
  }

  Future<NotificationSettingsData> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = NotificationSettingsData.defaults();

    return NotificationSettingsData(
      trainingEnabled:
          prefs.getBool('notifications.training.enabled') ??
          defaults.trainingEnabled,
      trainingHour:
          prefs.getInt('notifications.training.hour') ?? defaults.trainingHour,
      trainingMinute:
          prefs.getInt('notifications.training.minute') ??
          defaults.trainingMinute,
      breakfastEnabled:
          prefs.getBool('notifications.breakfast.enabled') ??
          defaults.breakfastEnabled,
      breakfastHour:
          prefs.getInt('notifications.breakfast.hour') ??
          defaults.breakfastHour,
      breakfastMinute:
          prefs.getInt('notifications.breakfast.minute') ??
          defaults.breakfastMinute,
      lunchEnabled:
          prefs.getBool('notifications.lunch.enabled') ?? defaults.lunchEnabled,
      lunchHour: prefs.getInt('notifications.lunch.hour') ?? defaults.lunchHour,
      lunchMinute:
          prefs.getInt('notifications.lunch.minute') ?? defaults.lunchMinute,
      dinnerEnabled:
          prefs.getBool('notifications.dinner.enabled') ??
          defaults.dinnerEnabled,
      dinnerHour:
          prefs.getInt('notifications.dinner.hour') ?? defaults.dinnerHour,
      dinnerMinute:
          prefs.getInt('notifications.dinner.minute') ?? defaults.dinnerMinute,
      waterEnabled:
          prefs.getBool('notifications.water.enabled') ?? defaults.waterEnabled,
      waterStartHour:
          prefs.getInt('notifications.water.startHour') ??
          defaults.waterStartHour,
      waterEndHour:
          prefs.getInt('notifications.water.endHour') ?? defaults.waterEndHour,
      waterIntervalHours:
          prefs.getInt('notifications.water.intervalHours') ??
          defaults.waterIntervalHours,
      summaryEnabled:
          prefs.getBool('notifications.summary.enabled') ??
          defaults.summaryEnabled,
      summaryHour:
          prefs.getInt('notifications.summary.hour') ?? defaults.summaryHour,
      summaryMinute:
          prefs.getInt('notifications.summary.minute') ??
          defaults.summaryMinute,
    );
  }

  Future<void> saveSettings(NotificationSettingsData settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      'notifications.training.enabled',
      settings.trainingEnabled,
    );
    await prefs.setInt('notifications.training.hour', settings.trainingHour);
    await prefs.setInt(
      'notifications.training.minute',
      settings.trainingMinute,
    );

    await prefs.setBool(
      'notifications.breakfast.enabled',
      settings.breakfastEnabled,
    );
    await prefs.setInt('notifications.breakfast.hour', settings.breakfastHour);
    await prefs.setInt(
      'notifications.breakfast.minute',
      settings.breakfastMinute,
    );

    await prefs.setBool('notifications.lunch.enabled', settings.lunchEnabled);
    await prefs.setInt('notifications.lunch.hour', settings.lunchHour);
    await prefs.setInt('notifications.lunch.minute', settings.lunchMinute);

    await prefs.setBool('notifications.dinner.enabled', settings.dinnerEnabled);
    await prefs.setInt('notifications.dinner.hour', settings.dinnerHour);
    await prefs.setInt('notifications.dinner.minute', settings.dinnerMinute);

    await prefs.setBool('notifications.water.enabled', settings.waterEnabled);
    await prefs.setInt(
      'notifications.water.startHour',
      settings.waterStartHour,
    );
    await prefs.setInt('notifications.water.endHour', settings.waterEndHour);
    await prefs.setInt(
      'notifications.water.intervalHours',
      settings.waterIntervalHours,
    );

    await prefs.setBool(
      'notifications.summary.enabled',
      settings.summaryEnabled,
    );
    await prefs.setInt('notifications.summary.hour', settings.summaryHour);
    await prefs.setInt('notifications.summary.minute', settings.summaryMinute);
  }

  Future<void> scheduleSavedNotifications() async {
    if (!_supportsLocalNotifications) {
      return;
    }

    for (final id in _defaultNotificationIds) {
      await _notifications.cancel(id: id);
    }

    final settings = await loadSettings();

    if (settings.trainingEnabled) {
      await _scheduleDailyNotification(
        id: 100,
        title: 'Hora de entrenar',
        body:
            'Tu rutina te espera. Hoy toca moverte a las ${formatTime(settings.trainingHour, settings.trainingMinute)}.',
        hour: settings.trainingHour,
        minute: settings.trainingMinute,
        channelId: _remindersChannelId,
        channelName: 'Recordatorios diarios',
      );
    }

    if (settings.breakfastEnabled) {
      await _scheduleDailyNotification(
        id: 101,
        title: 'Desayuno',
        body:
            'Es hora de registrar tu desayuno: ${formatTime(settings.breakfastHour, settings.breakfastMinute)}.',
        hour: settings.breakfastHour,
        minute: settings.breakfastMinute,
        channelId: _remindersChannelId,
        channelName: 'Recordatorios diarios',
      );
    }

    if (settings.lunchEnabled) {
      await _scheduleDailyNotification(
        id: 102,
        title: 'Almuerzo',
        body:
            'Es hora de registrar tu almuerzo: ${formatTime(settings.lunchHour, settings.lunchMinute)}.',
        hour: settings.lunchHour,
        minute: settings.lunchMinute,
        channelId: _remindersChannelId,
        channelName: 'Recordatorios diarios',
      );
    }

    if (settings.dinnerEnabled) {
      await _scheduleDailyNotification(
        id: 103,
        title: 'Cena',
        body:
            'Es hora de registrar tu cena: ${formatTime(settings.dinnerHour, settings.dinnerMinute)}.',
        hour: settings.dinnerHour,
        minute: settings.dinnerMinute,
        channelId: _remindersChannelId,
        channelName: 'Recordatorios diarios',
      );
    }

    if (settings.waterEnabled) {
      var notificationId = 200;
      for (
        var hour = settings.waterStartHour;
        hour <= settings.waterEndHour && notificationId <= 223;
        hour += settings.waterIntervalHours
      ) {
        await _scheduleDailyNotification(
          id: notificationId,
          title: 'Toma agua',
          body:
              'Recordatorio de hidratacion: toma agua a las ${formatTime(hour, 0)}.',
          hour: hour,
          minute: 0,
          channelId: _remindersChannelId,
          channelName: 'Recordatorios diarios',
        );
        notificationId++;
      }
    }

    if (settings.summaryEnabled) {
      await _scheduleSummaryNotification(settings);
    }
  }

  Future<void> refreshDailySummaryNotification() async {
    if (!_supportsLocalNotifications) {
      return;
    }

    final settings = await loadSettings();
    await _notifications.cancel(id: 300);

    if (!settings.summaryEnabled) {
      return;
    }

    await _scheduleSummaryNotification(settings);
  }

  bool get _supportsLocalNotifications {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _requestPermissions() async {
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();

    final iosImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final macImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String channelId,
    required String channelName,
  }) async {
    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleSummaryNotification(
    NotificationSettingsData settings,
  ) async {
    await _scheduleDailyNotification(
      id: 300,
      title: 'Resumen diario',
      body: await buildDailySummaryBody(),
      hour: settings.summaryHour,
      minute: settings.summaryMinute,
      channelId: _summaryChannelId,
      channelName: 'Resumen diario',
    );
  }

  Future<String> buildDailySummaryBody() async {
    final prefs = await SharedPreferences.getInstance();

    final consumedCalories = _readNumericPreference(prefs, 'calorias');
    final steps = prefs.getInt('pasos') ?? 0;
    final trained = prefs.getBool('entreno') ?? false;

    final age = prefs.getInt('age') ?? 0;
    final height = _readNumericPreference(prefs, 'height');
    final weightLb = _readNumericPreference(prefs, 'weight');
    final calorieGoal = _calculateDailyCalorieGoal(
      age: age,
      heightCm: height,
      weightLb: weightLb,
    );

    final caloriesText = calorieGoal > 0
        ? '${consumedCalories.toStringAsFixed(0)}/${calorieGoal.toStringAsFixed(0)} kcal'
        : '${consumedCalories.toStringAsFixed(0)} kcal';
    final stepsText = '$steps/10000 pasos';
    final trainingText = trained ? 'entreno completado' : 'entreno pendiente';

    return 'Hoy llevas $caloriesText, $stepsText y $trainingText.';
  }

  double _readNumericPreference(SharedPreferences prefs, String key) {
    final doubleValue = prefs.getDouble(key);
    if (doubleValue != null) {
      return doubleValue;
    }

    final intValue = prefs.getInt(key);
    if (intValue != null) {
      return intValue.toDouble();
    }

    return 0;
  }

  double _calculateDailyCalorieGoal({
    required int age,
    required double heightCm,
    required double weightLb,
  }) {
    if (age == 0 || heightCm == 0 || weightLb == 0) {
      return 0;
    }

    final weightKg = weightLb * 0.453592;
    return (10 * weightKg + 6.25 * heightCm - 5 * age + 5) * 1.2;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  static String formatTime(int hour, int minute) {
    final normalizedHour = hour % 24;
    final paddedMinute = minute.toString().padLeft(2, '0');

    if (normalizedHour == 0) {
      return '12:$paddedMinute AM';
    }

    if (normalizedHour < 12) {
      return '$normalizedHour:$paddedMinute AM';
    }

    if (normalizedHour == 12) {
      return '12:$paddedMinute PM';
    }

    return '${normalizedHour - 12}:$paddedMinute PM';
  }
}
