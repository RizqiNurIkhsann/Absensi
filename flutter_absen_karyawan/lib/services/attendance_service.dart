import 'package:dio/dio.dart';
import 'api_client.dart';

class AttendanceService {
  final ApiClient _apiClient = ApiClient();

  Future<String> clockIn(double lat, double lng, String deviceId, String photoPath, bool isFakeGps) async {
    try {
      FormData formData = FormData.fromMap({
        'lat': lat,
        'lng': lng,
        'device_id': deviceId,
        'is_fake_gps': isFakeGps ? 1 : 0,
      });

      if (photoPath.isNotEmpty) {
        formData.files.add(MapEntry(
          'photo',
          await MultipartFile.fromFile(photoPath, filename: 'clockin.jpg'),
        ));
      }

      final response = await _apiClient.dio.post('/attendance/clock-in', data: formData);
      return response.data['message'];
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Terjadi kesalahan jaringan');
    }
  }

  Future<String> clockOut(double lat, double lng, String deviceId, String photoPath, bool isFakeGps) async {
    try {
      FormData formData = FormData.fromMap({
        'lat': lat,
        'lng': lng,
        'device_id': deviceId,
        'is_fake_gps': isFakeGps ? 1 : 0,
      });

      if (photoPath.isNotEmpty) {
        formData.files.add(MapEntry(
          'photo',
          await MultipartFile.fromFile(photoPath, filename: 'clockout.jpg'),
        ));
      }

      final response = await _apiClient.dio.post('/attendance/clock-out', data: formData);
      return response.data['message'];
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Terjadi kesalahan jaringan');
    }
  }
}
