import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiService {
  late Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }

  // ============================================================
  // AUTH
  // ============================================================
  Future<Response> login(String email, String password) async {
    return await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> register(Map<String, dynamic> data) async {
    return await _dio.post('/auth/register', data: data);
  }

  Future<Response> getProfile() async {
    return await _dio.get('/auth/profile');
  }

  Future<Response> updateProfile(Map<String, dynamic> data) async {
    return await _dio.put('/auth/profile', data: data);
  }

  Future<Response> changePassword(String current, String newPass) async {
    return await _dio.put('/auth/change-password', data: {
      'currentPassword': current,
      'newPassword': newPass,
    });
  }

  // ============================================================
  // ADMIN - USER MANAGEMENT
  // ============================================================
  Future<Response> getAllUsers() async {
    return await _dio.get('/auth/users');
  }

  Future<Response> getPendingUsers() async {
    return await _dio.get('/auth/users/pending');
  }

  Future<Response> updateUserStatus(int id, String status) async {
    return await _dio.put('/auth/users/$id/status', data: {'status': status});
  }

  Future<Response> updateUserRole(int id, String role) async {
    return await _dio.put('/auth/users/$id/role', data: {'role': role});
  }

  // ============================================================
  // ACADEMIC
  // ============================================================
  Future<Response> getBatches() async {
    return await _dio.get('/academic/batches');
  }

  Future<Response> createBatch(Map<String, dynamic> data) async {
    return await _dio.post('/academic/batches', data: data);
  }

  Future<Response> updateBatch(int id, Map<String, dynamic> data) async {
    return await _dio.put('/academic/batches/$id', data: data);
  }

  Future<Response> deleteBatch(int id) async {
    return await _dio.delete('/academic/batches/$id');
  }

  Future<Response> getSemesters(int batchId) async {
    return await _dio.get('/academic/semesters/batch/$batchId');
  }

  Future<Response> createSemester(Map<String, dynamic> data) async {
    return await _dio.post('/academic/semesters', data: data);
  }

  Future<Response> getCourses(int semesterId) async {
    return await _dio.get('/academic/courses/semester/$semesterId');
  }

  Future<Response> createCourse(Map<String, dynamic> data) async {
    return await _dio.post('/academic/courses', data: data);
  }

  Future<Response> getEnrollments(int courseId) async {
    return await _dio.get('/academic/enrollments/course/$courseId');
  }

  Future<Response> bulkEnroll(int courseId, List<int> studentIds) async {
    return await _dio.post('/academic/enrollments/bulk', data: {
      'course_id': courseId,
      'student_ids': studentIds,
    });
  }

  Future<Response> getPracticals(int courseId) async {
    return await _dio.get('/academic/practicals/course/$courseId');
  }

  Future<Response> getPracticalById(int id) async {
    return await _dio.get('/academic/practicals/$id');
  }

  Future<Response> createPractical(Map<String, dynamic> data) async {
    return await _dio.post('/academic/practicals', data: data);
  }

  // ============================================================
  // BOOKINGS
  // ============================================================
  Future<Response> getLabAvailability(String date) async {
    return await _dio.get('/bookings/availability', queryParameters: {'date': date});
  }

  Future<Response> createBooking(Map<String, dynamic> data) async {
    return await _dio.post('/bookings/', data: data);
  }

  Future<Response> getMyBookingRequests() async {
    return await _dio.get('/bookings/my-requests');
  }

  Future<Response> getMySchedule() async {
    return await _dio.get('/bookings/my-schedule');
  }

  Future<Response> getAllBookingRequests({String? status, String? date}) async {
    Map<String, dynamic> params = {};
    if (status != null) params['status'] = status;
    if (date != null) params['date'] = date;
    return await _dio.get('/bookings/all', queryParameters: params);
  }

  Future<Response> getBookingById(int id) async {
    return await _dio.get('/bookings/$id');
  }

  Future<Response> addBookingComment(int id, String comment) async {
    return await _dio.post('/bookings/$id/comment', data: {'comment': comment});
  }

  Future<Response> updateBookingStatus(int id, String status, {String? remarks}) async {
    return await _dio.put('/bookings/$id/status', data: {
      'status': status,
      'incharge_remarks': remarks,
    });
  }

  // ============================================================
  // EQUIPMENT
  // ============================================================
  Future<Response> getAllEquipment({String? status}) async {
    Map<String, dynamic> params = {};
    if (status != null) params['status'] = status;
    return await _dio.get('/equipment', queryParameters: params);
  }

  Future<Response> getEquipmentById(int id) async {
    return await _dio.get('/equipment/$id');
  }

  Future<Response> createEquipment(Map<String, dynamic> data) async {
    return await _dio.post('/equipment', data: data);
  }

  Future<Response> updateEquipment(int id, Map<String, dynamic> data) async {
    return await _dio.put('/equipment/$id', data: data);
  }

  Future<Response> deleteEquipment(int id) async {
    return await _dio.delete('/equipment/$id');
  }

  Future<Response> logMaintenance(int equipmentId, Map<String, dynamic> data) async {
    return await _dio.post('/equipment/$equipmentId/maintenance', data: data);
  }

  Future<Response> getMaintenanceLogs(int equipmentId) async {
    return await _dio.get('/equipment/$equipmentId/maintenance');
  }

  Future<Response> logCalibration(int equipmentId, Map<String, dynamic> data) async {
    return await _dio.post('/equipment/$equipmentId/calibration', data: data);
  }

  Future<Response> getCalibrations(int equipmentId) async {
    return await _dio.get('/equipment/$equipmentId/calibration');
  }

  Future<Response> approveEquipment(int id) async {
    return await _dio.put('/equipment/$id/approve');
  }

  // ============================================================
  // CONSUMABLES
  // ============================================================
  Future<Response> getAllConsumables({bool? lowStock}) async {
    Map<String, dynamic> params = {};
    if (lowStock == true) params['low_stock'] = 'true';
    return await _dio.get('/consumables', queryParameters: params);
  }

  Future<Response> getConsumableById(int id) async {
    return await _dio.get('/consumables/$id');
  }

  Future<Response> createConsumable(Map<String, dynamic> data) async {
    return await _dio.post('/consumables', data: data);
  }

  Future<Response> updateConsumable(int id, Map<String, dynamic> data) async {
    return await _dio.put('/consumables/$id', data: data);
  }

  Future<Response> deleteConsumable(int id) async {
    return await _dio.delete('/consumables/$id');
  }

  Future<Response> recordUsage(int consumableId, Map<String, dynamic> data) async {
    return await _dio.post('/consumables/$consumableId/usage', data: data);
  }

  Future<Response> getUsageLogs(int consumableId) async {
    return await _dio.get('/consumables/$consumableId/usage');
  }

  Future<Response> recordReplenishment(int consumableId, Map<String, dynamic> data) async {
    return await _dio.post('/consumables/$consumableId/replenish', data: data);
  }

  Future<Response> getLowStockItems() async {
    return await _dio.get('/consumables/low-stock');
  }

  Future<Response> approveConsumable(int id) async {
    return await _dio.put('/consumables/$id/approve');
  }

  // ============================================================
  // CLEANING
  // ============================================================
  Future<Response> getCleaningSchedules() async {
    return await _dio.get('/cleaning/schedules');
  }

  Future<Response> getCleaningScheduleById(int id) async {
    return await _dio.get('/cleaning/schedules/$id');
  }

  Future<Response> createCleaningSchedule(Map<String, dynamic> data) async {
    return await _dio.post('/cleaning/schedules', data: data);
  }

  Future<Response> updateCleaningSchedule(int id, Map<String, dynamic> data) async {
    return await _dio.put('/cleaning/schedules/$id', data: data);
  }

  Future<Response> deleteCleaningSchedule(int id) async {
    return await _dio.delete('/cleaning/schedules/$id');
  }

  Future<Response> logCleaningCompletion(int scheduleId, Map<String, dynamic> data) async {
    return await _dio.post('/cleaning/schedules/$scheduleId/complete', data: data);
  }

  Future<Response> getCleaningLogs({String? status, String? from, String? to}) async {
    Map<String, dynamic> params = {};
    if (status != null) params['status'] = status;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return await _dio.get('/cleaning/logs', queryParameters: params);
  }

  Future<Response> getOverdueCleaningTasks() async {
    return await _dio.get('/cleaning/overdue');
  }

  // ============================================================
  // DASHBOARD
  // ============================================================
  Future<Response> getDashboardSummary() async {
    return await _dio.get('/dashboard/summary');
  }

  // ============================================================
  // USERS (for instructor selection)
  // ============================================================
  Future<Response> getUsersByRole(String role) async {
    return await _dio.get('/auth/users', queryParameters: {'role': role});
  }

  Future<Response> getApprovedStudents() async {
    return await _dio.get('/auth/users', queryParameters: {'role': 'student', 'status': 'approved'});
  }
}
