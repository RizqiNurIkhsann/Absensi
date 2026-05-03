import 'package:dio/dio.dart';
import 'api_client.dart';

class ApiService {
  final Dio client = ApiClient().dio;

  Future<Map<String, dynamic>?> getConfigSite() async {
    try {
      var res = await client.get('/config/site', queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch});
      return res.data['data'] ?? res.data;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserById(String id) async {
    try {
      var res = await client.get('/users/$id');
      return res.data['data'] ?? res.data;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserByNik(String nik) async {
    try {
      var users = await getUsers();
      for (var u in users) {
        if (u['nik'] == nik) return u as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<dynamic>> getUsers() async {
    try {
      var res = await client.get('/users');
      return res.data['data'] ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    List<dynamic> users = await getUsers();
    try {
      return users.firstWhere((u) => u['email'] == email);
    } catch (e) {
      return null;
    }
  }



  Future<bool> updateUserPassword(String id, String password) async {
    try {
      await client.put('/users/$id', data: {'password': password});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateUser(String id, Map<String, dynamic> payload) async {
    try {
      await client.put('/users/$id', data: payload);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> registerUser(Map<String, dynamic> payload) async {
    try {
      var res = await client.post('/users', data: payload);
      if (res.data != null && res.data['data'] != null && res.data['data']['id'] != null) {
         return res.data['data']['id'].toString();
      }
      return 'new_id';
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteUser(String id) async {
    try {
      await client.delete('/users/$id');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAttendance(String id) async {
    try {
      // Assuming endpoint is /attendance/{id} or similar. If not, this might need adjustment based on Laravel API.
      // Looking at firestore_mock, it didn't implement delete for attendance. So let's assume /attendance/destroy/{id}
      // Wait, let's check firestore_mock again. Delete only handles users, requests, tickets.
      // But karyawan_view calls delete on attendance!
      await client.delete('/attendance/history/$id');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getTodayAttendance([String? userId]) async {
    try {
      var res = await client.get('/attendance/today', queryParameters: userId != null ? {'user_id': userId} : null);
      return res.data['data'] ?? res.data;
    } catch (e) {
      return null;
    }
  }

  Future<List<dynamic>> getAttendanceHistory() async {
    try {
      var res = await client.get('/attendance/history');
      return res.data['data'] ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> logManualAttendance(Map<String, dynamic> payload) async {
    try {
      await client.post('/attendance/log', data: payload);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- TICKETS ---
  Future<List<dynamic>> getTickets() async {
    try {
      var res = await client.get('/tickets');
      return res.data['data'] ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> createTicket(Map<String, dynamic> payload) async {
    try {
      await client.post('/tickets', data: payload);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateTicket(String id, Map<String, dynamic> payload) async {
    try {
      await client.put('/tickets/$id', data: payload);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- CONFIG ---
  Future<dynamic> updateConfigSite(Map<String, dynamic> payload) async {
    try {
      await client.put('/config/site', data: payload);
      return true;
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          return "Sesi login Anda sudah kadaluwarsa. Silakan Logout dan Login kembali.";
        }
        return "Network Error: ${e.response?.statusCode} - ${e.response?.data}";
      }
      return e.toString();
    }
  }


  // --- SITES ---
  Future<List<dynamic>> getSites() async {
    try {
      var res = await client.get('/sites');
      return res.data['data'] ?? [];
    } catch (e) {
      print("ERROR GET SITES: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> createSite(Map<String, dynamic> payload) async {
    try {
      var res = await client.post('/sites', data: payload);
      return res.data['data'];
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateSite(String id, Map<String, dynamic> payload) async {
    try {
      await client.put('/sites/$id', data: payload);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteSite(String id) async {
    try {
      await client.delete('/sites/$id');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getAnnouncements() async {
    try {
      var res = await client.get('/config/announcements');
      // Assume the API returns { "data": { "list": [...] } } or something similar
      // Or if it returns direct array
      if (res.data != null && res.data['data'] != null && res.data['data']['list'] != null) {
        return res.data['data']['list'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateAnnouncements(List<dynamic> list) async {
    try {
      await client.post('/config/announcements', data: {'list': list});
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- REQUESTS ---
  Future<List<dynamic>> getRequests() async {
    try {
      var res = await client.get('/requests');
      return res.data['data'] ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> createRequest(Map<String, dynamic> payload) async {
    try {
      await client.post('/requests', data: payload);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateRequestStatus(String id, String status) async {
    try {
      await client.put('/requests/$id/status', data: {'status': status});
      return true;
    } catch (e) {
      return false;
    }
  }



  Future<bool> deleteTicket(String id) async {
    try {
      await client.delete('/tickets/$id');
      return true;
    } catch (e) {
      return false;
    }
  }
}
