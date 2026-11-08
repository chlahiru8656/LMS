import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  
  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _token;
  Map<String, dynamic>? _user;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  String? get error => _error;
  String get userRole => _user?['role'] ?? '';
  String get userName => _user?['name'] ?? '';
  int get userId => _user?['id'] ?? 0;
  String get userStatus => _user?['status'] ?? '';

  bool get isMasterAdmin => userRole == 'master_admin';
  bool get isCourseCoordinator => userRole == 'course_coordinator';
  bool get isInstructor => userRole == 'instructor';
  bool get isLabIncharge => userRole == 'lab_incharge';
  bool get isLabTO => userRole == 'lab_to';
  bool get isLabAssistant => userRole == 'lab_assistant';
  bool get isStudent => userRole == 'student';
  bool get isLabStaff => isLabIncharge || isLabTO || isLabAssistant;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userData = prefs.getString('user');
    if (_token != null && userData != null) {
      _user = Map<String, dynamic>.from(
        Uri.splitQueryString(userData).map((k, v) => MapEntry(k, v)),
      );
      _isLoggedIn = true;
      // Refresh profile from server
      try {
        final response = await _api.getProfile();
        _user = Map<String, dynamic>.from(response.data);
        await _saveUserData();
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.login(email, password);
      _token = response.data['token'];
      _user = Map<String, dynamic>.from(response.data['user']);
      _isLoggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await _saveUserData();

      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _isLoading = false;
      _error = e.response?.data?['message'] ?? 'Login failed';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Connection error. Is the server running?';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _api.register(data);
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _isLoading = false;
      _error = e.response?.data?['message'] ?? 'Registration failed';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Connection error';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    _token = null;
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_user != null) {
      final encoded = _user!.entries
          .map((e) => '${e.key}=${e.value ?? ""}')
          .join('&');
      await prefs.setString('user', encoded);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
