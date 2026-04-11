import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExternalProgressWidgetService {
  ExternalProgressWidgetService._();

  static const String prefsKey = 'mostrarWidgetProgreso';
  static const String qualifiedAndroidName =
      'com.jaae.nutrifyngo.FitProgressWidgetProvider';

  static bool get _isSupported {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android;
  }

  static Future<void> setActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, active);
    await syncFromPrefs();
  }

  static Future<bool> canRequestPinWidget() async {
    if (!_isSupported) {
      return false;
    }

    return await HomeWidget.isRequestPinWidgetSupported() ?? false;
  }

  static Future<void> requestPin() async {
    if (!_isSupported) {
      return;
    }

    await HomeWidget.requestPinWidget(
      qualifiedAndroidName: qualifiedAndroidName,
    );
    await syncFromPrefs();
  }

  static Future<void> syncFromPrefs() async {
    if (!_isSupported) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(prefsKey) ?? false;
    final goal = prefs.getString('goal') ?? 'Mantener';
    final sex = prefs.getString('sex') ?? 'Hombre';
    final age = prefs.getInt('age') ?? 0;
    final weight = prefs.getDouble('weight') ?? 0;
    final height = prefs.getDouble('height') ?? 0;
    final caloriesConsumed = prefs.getDouble('calorias') ?? 0;
    final caloriesExercise = prefs.getDouble('caloriasEjercicio') ?? 0;
    final water = prefs.getDouble('aguaConsumida') ?? 0;
    final steps = prefs.getInt('pasos') ?? 0;

    final caloriesGoal = _calculateCaloriesGoal(
      sex: sex,
      age: age,
      weight: weight,
      height: height,
      goal: goal,
    );
    final waterGoal = _calculateWaterGoal(
      sex: sex,
      age: age,
      weight: weight,
      goal: goal,
    );
    final stepsGoal = _calculateStepsGoal(goal);
    final netCalories = (caloriesConsumed - caloriesExercise)
        .clamp(0, caloriesGoal > 0 ? caloriesGoal * 1.5 : 3000)
        .toDouble();

    final now = DateTime.now();
    final dateLabel =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}';

    await HomeWidget.saveWidgetData<bool>('active', active);
    await HomeWidget.saveWidgetData<String>(
      'title',
      active ? 'Progreso de hoy' : 'Widget pausado',
    );
    await HomeWidget.saveWidgetData<String>(
      'subtitle',
      active
          ? 'Fuera de la app • $dateLabel'
          : 'Activalo desde NutrifynGo para ver tus datos',
    );
    await HomeWidget.saveWidgetData<String>(
      'status',
      active
          ? 'Toca el widget para abrir NutrifynGo'
          : 'Activalo y agregalo a tu pantalla',
    );
    await HomeWidget.saveWidgetData<String>(
      'calories_value',
      '${netCalories.toStringAsFixed(0)} / ${caloriesGoal.toStringAsFixed(0)} kcal',
    );
    await HomeWidget.saveWidgetData<String>(
      'water_value',
      '${water.toStringAsFixed(2)} / ${waterGoal.toStringAsFixed(2)} L',
    );
    await HomeWidget.saveWidgetData<String>(
      'steps_value',
      '$steps / $stepsGoal',
    );
    await HomeWidget.saveWidgetData<String>(
      'calories_hint',
      active
          ? _buildCaloriesHint(netCalories, caloriesGoal)
          : 'Sincronizacion detenida',
    );
    await HomeWidget.saveWidgetData<String>(
      'water_hint',
      active ? _buildWaterHint(water, waterGoal) : 'Sincronizacion detenida',
    );
    await HomeWidget.saveWidgetData<String>(
      'steps_hint',
      active ? _buildStepsHint(steps, stepsGoal) : 'Sincronizacion detenida',
    );

    await HomeWidget.updateWidget(qualifiedAndroidName: qualifiedAndroidName);
  }

  static double _calculateCaloriesGoal({
    required String sex,
    required int age,
    required double weight,
    required double height,
    required String goal,
  }) {
    if (weight <= 0 || height <= 0 || age <= 0) {
      return 2000;
    }

    final weightKg = weight * 0.453592;
    final sexAdjustment = sex == 'Mujer' ? -161 : 5;
    final baseCalories =
        (10 * weightKg + 6.25 * height - 5 * age + sexAdjustment) * 1.2;

    switch (goal) {
      case 'Bajar peso':
        return (baseCalories - 350).clamp(1200, double.infinity).toDouble();
      case 'Subir masa':
        return baseCalories + 300;
      default:
        return baseCalories;
    }
  }

  static double _calculateWaterGoal({
    required String sex,
    required int age,
    required double weight,
    required String goal,
  }) {
    if (weight <= 0) {
      return 2.0;
    }

    final weightKg = weight * 0.453592;
    double multiplier = sex == 'Mujer' ? 0.031 : 0.035;

    if (goal == 'Bajar peso') {
      multiplier += 0.002;
    } else if (goal == 'Subir masa') {
      multiplier += 0.003;
    }

    if (age >= 50) {
      multiplier += 0.05;
    }

    return (weightKg * multiplier).clamp(1.8, 5.5).toDouble();
  }

  static int _calculateStepsGoal(String goal) {
    switch (goal) {
      case 'Bajar peso':
        return 12000;
      case 'Subir masa':
        return 9000;
      default:
        return 10000;
    }
  }

  static String _buildCaloriesHint(double current, double goal) {
    if (current >= goal) {
      return 'Meta de calorias cubierta';
    }

    return '${(goal - current).clamp(0, goal).toStringAsFixed(0)} kcal restantes';
  }

  static String _buildWaterHint(double current, double goal) {
    if (current >= goal) {
      return 'Hidratacion cumplida';
    }

    return '${(goal - current).clamp(0, goal).toStringAsFixed(1)} L faltan';
  }

  static String _buildStepsHint(int current, int goal) {
    if (current >= goal) {
      return 'Meta de pasos cumplida';
    }

    return '${goal - current} pasos restantes';
  }
}
