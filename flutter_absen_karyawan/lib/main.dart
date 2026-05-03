import 'dart:async';
import 'dart:ui'; 
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/user_model.dart';
import 'views/login_screen.dart';
import 'views/main_layout.dart';

// --- 1. NOTIFICATION SERVICE ---
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'shift_channel_default', 
      'Notifikasi Jam Kerja',
      description: 'Membangunkan layar saat jam shift berakhir',
      importance: Importance.max,
      playSound: true, // Menggunakan suara notifikasi default HP
      enableVibration: true,
      enableLights: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> requestPermission() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
  }

  static Future<void> showInstantNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'shift_channel_default', 
      'Notifikasi Jam Kerja',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecond, title, body, platformChannelSpecifics,
    );
  }
}

// --- 2. ALARM CALLBACK (BERJALAN DI LATAR BELAKANG SAAT LAYAR MATI) ---
@pragma('vm:entry-point')
void alarmCallback() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized(); 
    
    await NotificationService.init();

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setInt('last_bg_alarm_time', DateTime.now().millisecondsSinceEpoch);

    // Mencegah GHOST ALARM: Tarik status absensi & jadwal pulang
    bool isActiveShift = prefs.getBool('is_active_shift') ?? false;
    String? shiftEndStr = prefs.getString('shift_end_time');

    // Jika karyawan belum absen masuk hari ini atau data shift kosong, jangan tampilkan!
    if (!isActiveShift || shiftEndStr == null) {
      debugPrint("Ghost Alarm Diblokir: Tidak ada shift aktif.");
      return;
    }

    // Validasi Keakuratan Waktu (Max toleransi melenceng = 15 Menit)
    List<String> parts = shiftEndStr.split(':');
    int h = int.tryParse(parts[0]) ?? 17;
    int m = int.tryParse(parts[1]) ?? 0;

    DateTime witaNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    DateTime shiftEndToday = DateTime.utc(witaNow.year, witaNow.month, witaNow.day, h, m);

    // Jika alarm tertunda dan muncul jauh melebihi waktunya (karena HP baru nyala / install via USB), abaikan!
    if (witaNow.difference(shiftEndToday).inMinutes.abs() > 15) {
       debugPrint("Ghost Alarm Diblokir: Waktu terlalu melenceng (diabaikan).");
       return; 
    }

    // Tampilkan Notifikasi Banner dengan suara HP bawaan
    await NotificationService.showInstantNotification(
      "UNITED TRACTORS Tbk", 
      "Jam shift Anda telah berakhir. Silakan absen pulang sekarang."
    );

  } catch (e) {
    debugPrint("Background Alarm Error: $e");
  }
}

// --- 3. MAIN FUNCTION ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);

  // FORCE LOGOUT TO CLEAR ZOMBIE TOKEN
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('auth_token');
  await prefs.remove('user_role');

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await NotificationService.init();
    await NotificationService.requestPermission(); 
    try {
      await AndroidAlarmManager.initialize();
    } catch (e) {
      debugPrint("Alarm Manager Error: $e");
    }
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'United Tractors Absensi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.amber, fontFamily: 'Roboto'),
      home: const AuthWrapperApp(),
    );
  }
}

class AuthWrapperApp extends StatefulWidget {
  const AuthWrapperApp({super.key});

  @override
  State<AuthWrapperApp> createState() => _AuthWrapperAppState();
}

class _AuthWrapperAppState extends State<AuthWrapperApp> {
  UserModel? _currentUser;

  @override
  Widget build(BuildContext context) {
    return _currentUser == null
        ? LoginScreen(onLogin: (u) => setState(() => _currentUser = u))
        : MainLayout(user: _currentUser!, onLogout: () => setState(() => _currentUser = null));
  }
}