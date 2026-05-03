import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://127.0.0.1:8000/api',
    headers: {'Accept': 'application/json'},
  ));
  
  try {
    // 1. Login
    print('Logging in...');
    final loginRes = await dio.post('/login', data: {
      'nik': 'admin',
      'password': 'password',
      'mobileDeviceId': '',
      'desktopDeviceId': 'test-device'
    });
    
    final token = loginRes.data['token'];
    print('Token: $token');
    
    // 2. PUT config
    print('Updating config...');
    final putRes = await dio.put(
      '/config/site',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
      data: {
        'locations': [
          {
            "id": "site-1776084064233",
            "siteName": "Ketintang",
            "lat": -7.3116,
            "lng": 112.7274,
            "radius": 203,
            "isLocked": true,
            "isWfhMode": false
          }
        ]
      }
    );
    
    print('Success: \${putRes.data}');
  } catch (e) {
    if (e is DioException) {
      print('DioError: \${e.response?.statusCode} - \${e.response?.data}');
    } else {
      print('Error: $e');
    }
  }
}
