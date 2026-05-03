import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../models/user_model.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> login(String nik, String password, String mobileDeviceId, String desktopDeviceId) async {
    try {
      final response = await _apiClient.dio.post('/login', data: {
        'nik': nik,
        'password': password,
        'mobileDeviceId': mobileDeviceId,
        'desktopDeviceId': desktopDeviceId,
      });

      if (response.statusCode == 200) {
        final token = response.data['token'];
        final userData = response.data['user'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        await prefs.setString('user_role', userData['role'] ?? 'Karyawan');
        
        UserModel user = UserModel(
          id: userData['id'].toString(),
          namaLengkap: userData['nama_lengkap'],
          role: userData['role'] ?? 'Karyawan',
          nik: userData['nik'],
          area: userData['area'] ?? '',
          deviceId: mobileDeviceId.isNotEmpty ? mobileDeviceId : desktopDeviceId,
        );
        
        return {'success': true, 'user': user};
      }
      return {'success': false, 'message': 'Gagal login'};
    } on DioException catch (e) {
      return {'success': false, 'message': e.response?.data['message'] ?? 'Error'};
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/logout');
    } catch (e) {
      // Ignore network errors on logout
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_role');
    }
  }
}
