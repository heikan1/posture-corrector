import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const String _keyTargetDuration = 'target_upright_duration_mins';
  static const String _keyTargetSteps = 'target_steps';
  static const String _keyTargetStanding = 'target_standing_mins';
  static const String _keyUprightThreshold = 'upright_angle_threshold';
  static const String _keyVibrationEnabled = 'vibration_enabled';
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyVibrationDelay = 'vibration_delay';
  static const String _keyPostureSyncEnabled = 'posture_sync_enabled';

  static const String _keyAiHeightCm = 'ai_user_height_cm';
  static const String _keyAiWeightKg = 'ai_user_weight_kg';
  static const String _keyAiPainDescription = 'ai_user_pain_description';
  static const String _keyAiWorkType = 'ai_work_type';
  static const String _keyAiWorkDays = 'ai_work_days';
  static const String _keyAiProfileSaved = 'ai_profile_saved';

  static Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationsEnabled) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  static Future<int> getTargetDurationMins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTargetDuration) ?? 120;
  }

  static Future<int> getTargetSteps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTargetSteps) ?? 5000;
  }

  static Future<int> getTargetStandingMins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyTargetStanding) ?? 60;
  }

  static Future<double> getUprightThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyUprightThreshold) ?? 15.0;
  }

  static Future<bool> getVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVibrationEnabled) ?? true;
  }

  static Future<int> getVibrationDelay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyVibrationDelay) ?? 5;
  }

  static Future<bool> getPostureSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPostureSyncEnabled) ?? false;
  }

  static Future<void> setTargetDurationMins(int mins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTargetDuration, mins);
  }

  static Future<void> setTargetSteps(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTargetSteps, steps);
  }

  static Future<void> setTargetStandingMins(int mins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTargetStanding, mins);
  }

  static Future<void> setUprightThreshold(double threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyUprightThreshold, threshold);
  }

  static Future<void> setVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVibrationEnabled, enabled);
  }

  static Future<void> setVibrationDelay(int delaySecs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyVibrationDelay, delaySecs);
  }

  static Future<void> setPostureSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPostureSyncEnabled, enabled);
  }

  static Future<bool> getAiProfileSaved() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAiProfileSaved) ?? false;
  }

  static Future<int> getAiHeightCm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAiHeightCm) ?? 0;
  }

  static Future<int> getAiWeightKg() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAiWeightKg) ?? 0;
  }

  static Future<String> getAiPainDescription() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAiPainDescription) ?? '';
  }

  static Future<String> getAiWorkType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAiWorkType) ?? 'office';
  }

  static Future<List<int>> getAiWorkDays() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyAiWorkDays);
    if (raw == null) return [1, 2, 3, 4, 5];
    return List<int>.from(jsonDecode(raw));
  }

  static Future<void> setAiProfileSaved(bool saved) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAiProfileSaved, saved);
  }

  static Future<void> setAiHeightCm(int cm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAiHeightCm, cm);
  }

  static Future<void> setAiWeightKg(int kg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAiWeightKg, kg);
  }

  static Future<void> setAiPainDescription(String description) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiPainDescription, description);
  }

  static Future<void> setAiWorkType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiWorkType, type);
  }

  static Future<void> setAiWorkDays(List<int> days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiWorkDays, jsonEncode(days));
  }
}
