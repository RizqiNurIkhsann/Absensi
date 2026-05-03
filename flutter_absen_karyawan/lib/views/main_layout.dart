import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:ntp/ntp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import '../core/app_constants.dart';
import '../models/user_model.dart';
import '../main.dart'; 
import 'dashboard_view.dart';
import 'attendance_view.dart';
import 'settings_view.dart' hide HelpView;
import 'karyawan_view.dart';
import 'help_view.dart';
import 'announcement_view.dart'; 

class LiveClockWidget extends StatefulWidget {
  final TextStyle style;
  final String suffix;
  const LiveClockWidget({super.key, required this.style, this.suffix = ''});

  @override
  State<LiveClockWidget> createState() => _LiveClockWidgetState();
}

class _LiveClockWidgetState extends State<LiveClockWidget> {
  Timer? _timer;
  String _timeString = '--:--:--';
  DateTime? _ntpSyncTime;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _initTimeSync();
  }

  Future<void> _initTimeSync() async {
    try {
      if (!kIsWeb) {
        _ntpSyncTime = await NTP.now(timeout: const Duration(seconds: 3));
        _stopwatch.start();
      }
    } catch (e) {}

    _getTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
  }

  void _getTime() {
    DateTime realTime;
    if (_ntpSyncTime != null && _stopwatch.isRunning) {
      realTime = _ntpSyncTime!.add(_stopwatch.elapsed);
    } else {
      realTime = DateTime.now();
    }

    DateTime witaTime = realTime.toUtc().add(const Duration(hours: 8));
    if (mounted) {
      setState(() {
        _timeString = DateFormat('HH:mm:ss').format(witaTime);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text("$_timeString${widget.suffix}", style: widget.style);
  }
}

class MainLayout extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;

  const MainLayout({super.key, required this.user, required this.onLogout});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  String _currentView = 'dashboard';
  Timer? _shiftCheckTimer;
  String _shiftEndTimeStr = '';

  
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // PENANDA BARU: Mencegah Pop-up muncul sebelum layar benar-benar siap
  bool _canShowPopup = false; 

  @override
  void initState() {
    super.initState();
    
    // Tetap ambil data shift sejak awal, tapi TAHAN kemunculan pop-up-nya
    _fetchTodayShift(); 
    
    // Beri jeda 3 detik agar animasi transisi login -> dashboard selesai sepenuhnya
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _canShowPopup = true; // Buka gerbang pop-up
        _startShiftChecker();
        _checkAndShowPopupNow(); // Cek sekali saat gerbang dibuka
      }
    });
  }

  @override
  void dispose() {
    _shiftCheckTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchTodayShift() async {
    if (widget.user.role == 'admin') return; 

    var attData = await ApiService().getTodayAttendance();
    final prefs = await SharedPreferences.getInstance();

    if (attData == null || attData.isEmpty) {
        await prefs.setBool('is_active_shift', false); 
        if (mounted) {
          setState(() {
            _shiftEndTimeStr = ''; 
          });
        }
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await AndroidAlarmManager.cancel(100);
        }
        return;
    }

    if (attData.containsKey('jam_pulang') && attData['jam_pulang'] != null) {
      await prefs.setBool('is_active_shift', false); 
      if (attData['status_pulang'] == 'Pulang Cepat') {
        if (mounted) {
          setState(() {
            _shiftEndTimeStr = ''; 
          });
        }
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await AndroidAlarmManager.cancel(100);
        }
        return; 
      }
    } else {
      await prefs.setBool('is_active_shift', true); 
    }

    String? exactEndTime;
    String shiftTime = attData['shift_time'] ?? '';
    
    if (shiftTime.contains('-')) {
      exactEndTime = shiftTime.split('-')[1].trim(); 
    }

    if (exactEndTime == null || exactEndTime.isEmpty) {
      try {
        var data = await ApiService().getConfigSite();
        if (data != null) {
          List shifts = data['shifts'] ?? [];
          for (var s in shifts) {
            if (s['name'] == widget.user.shift && (s['area'] == widget.user.area || s['area'] == 'Semua Area')) {
              exactEndTime = s['end'];
              break;
            }
          }
          if (exactEndTime == null && shifts.isNotEmpty) exactEndTime = shifts.first['end'];
        }
      } catch (e) {}
    }

    String finalEndTime = exactEndTime ?? '17:00';
    await prefs.setString('shift_end_time', finalEndTime); 

    if (mounted) {
      if (_shiftEndTimeStr != finalEndTime) {
        setState(() {
          _shiftEndTimeStr = finalEndTime;
        });
        
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          _setupAlarmFromShiftTime(finalEndTime);
        }
      }
    }
  }

  void _setupAlarmFromShiftTime(String endTimeStr) {
    if (endTimeStr.isEmpty) return;
    try {
       DateTime witaNow = DateTime.now().toUtc().add(const Duration(hours: 8));
       List<String> parts = endTimeStr.split(':');
       int h = int.tryParse(parts[0]) ?? 17;
       int m = int.tryParse(parts[1]) ?? 0;
       
       DateTime witaTarget = DateTime.utc(witaNow.year, witaNow.month, witaNow.day, h, m);
       
       if (witaTarget.isBefore(witaNow)) {
          witaTarget = witaTarget.add(const Duration(days: 1));
       }
       
       Duration delay = witaTarget.difference(witaNow);
       DateTime localTargetTime = DateTime.now().add(delay);
       
       _scheduleBackgroundAlarm(localTargetTime);
    } catch (e) {}
  }

  void _scheduleBackgroundAlarm(DateTime shiftEndTime) async {
    try {
      await AndroidAlarmManager.cancel(100);
      await AndroidAlarmManager.oneShotAt(
        shiftEndTime,
        100, 
        alarmCallback,
        exact: true,    
        wakeup: true,   
        rescheduleOnReboot: true,
        alarmClock: true, 
        allowWhileIdle: true,
      );
    } catch (e) {}
  }

  Future<void> _checkAndShowPopupNow() async {
    // PERBAIKAN: Jika masih dalam tahap animasi layar (canShowPopup = false), batalkan popup.
    if (!_canShowPopup || _shiftEndTimeStr.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    DateTime witaNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    String dateToday = DateFormat('yyyy-MM-dd').format(witaNow);
    
    List<String> parts = _shiftEndTimeStr.split(':');
    int h = int.tryParse(parts[0]) ?? 17;
    int m = int.tryParse(parts[1]) ?? 0;

    DateTime shiftEndToday = DateTime.utc(witaNow.year, witaNow.month, witaNow.day, h, m);

    if (!witaNow.isBefore(shiftEndToday) && witaNow.difference(shiftEndToday).inHours < 4) {
      
      String triggerKey = 'popup_${widget.user.id}_${dateToday}_$_shiftEndTimeStr';
      bool hasTriggered = prefs.getBool(triggerKey) ?? false;
      
      if (!hasTriggered) {
        await prefs.setBool(triggerKey, true);
        _triggerShiftEndNotification(); 
      }
    }
  }

  void _startShiftChecker() {
    _shiftCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkAndShowPopupNow();
    });
  }

  void _triggerShiftEndNotification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    
    bool isEnabled = prefs.getBool('notif_enabled_${widget.user.id}') ?? true;
    int soundType = prefs.getInt('notif_sound_${widget.user.id}') ?? 1;

    int lastBgTime = prefs.getInt('last_bg_alarm_time') ?? 0;
    int nowMs = DateTime.now().millisecondsSinceEpoch;
    bool isBgJustPlayed = (nowMs - lastBgTime) < 5000; 

    if (isEnabled && !isBgJustPlayed) {
      String fileName = soundType == 1 ? 'notif_1.mp3' : 'notif_2.mp3';
      _audioPlayer.stop().then((_) {
        _audioPlayer.setVolume(1.0).then((_) {
          if (kIsWeb) {
             _audioPlayer.play(UrlSource('assets/Assets/audio/$fileName'));
          } else {
             _audioPlayer.play(AssetSource('audio/$fileName'));
          }
        });
      }).catchError((e) {
        debugPrint("Gagal memutar audio di dalam aplikasi: $e");
      });
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.alarm_on, color: AppColors.rose500, size: 28),
                    SizedBox(width: 8),
                    Text("WAKTU PULANG!", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.slate800)),
                  ],
                ),
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(color: AppColors.rose50, borderRadius: BorderRadius.circular(16)),
                  child: Text(
                    _shiftEndTimeStr,
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: AppColors.rose500, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  "Jam shift kerja Anda ($_shiftEndTimeStr) telah berakhir.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.slate700, fontWeight: FontWeight.w900, height: 1.5, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Silakan bersiap-siap dan jangan lupa melakukan absensi pulang pada menu Kehadiran.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slate700, fontWeight: FontWeight.w900, height: 1.5, fontSize: 13),
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.rose500,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                      shadowColor: AppColors.rose500.withValues(alpha: 0.4)
                    ),
                    onPressed: () {
                      _audioPlayer.stop(); 
                      Navigator.pop(c);
                      setState(() => _currentView = 'attendance'); 
                    },
                    child: const Text("OKE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14)),
                  ),
                )
              ],
            ),
          ),
        )
      );
    }
  }

  Widget _buildBody(bool isProfileComplete) {
    switch (_currentView) {
      case 'dashboard':
        return DashboardView(user: widget.user);
      case 'attendance':
        if (widget.user.role == 'admin') return _unauthorizedAccess();
        if (!isProfileComplete) return _incompleteProfileAccess();
        return AttendanceView(user: widget.user);
      case 'karyawan':
        if (widget.user.role != 'admin') return _unauthorizedAccess();
        return KaryawanView(user: widget.user);
      case 'pengumuman':
        if (widget.user.role != 'admin') return _unauthorizedAccess();
        return AnnouncementView(user: widget.user);
      case 'pengaturan':
        return SettingsView(
          user: widget.user,
          onLogout: widget.onLogout,
          onChangeView: (view) {
            if (_currentView != view) {
              setState(() => _currentView = view);
            }
          },
        );
      case 'help':
      case 'admin_tickets':
        return HelpView(
          user: widget.user,
          onBack: () {
            if (_currentView != 'pengaturan') {
              setState(() => _currentView = 'pengaturan');
            }
          },
        );
      default:
        return DashboardView(user: widget.user);
    }
  }

  Widget _unauthorizedAccess() {
    return const Center(
      child: Text(
        "Akses Ditolak. Anda tidak memiliki izin untuk halaman ini.",
        style: TextStyle(color: AppColors.rose500, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _incompleteProfileAccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: AppColors.rose50, shape: BoxShape.circle),
              child: const Icon(Icons.portrait,
                  size: 64, color: AppColors.rose500),
            ),
            const SizedBox(height: 24),
            const Text(
              "PROFIL BELUM LENGKAP",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate800),
            ),
            const SizedBox(height: 8),
            const Text(
              "Akses absensi terkunci sementara.\nAnda wajib mengunggah Foto Profil dan melengkapi data diri lainnya agar dapat melakukan kehadiran.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.slate500,
                  fontWeight: FontWeight.bold,
                  height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.yellow500,
                foregroundColor: AppColors.slate900,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                setState(() => _currentView = 'pengaturan');
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("Lengkapi Profil Sekarang",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.user.role == 'admin';
    bool isKaryawan = !isAdmin; 

    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: FutureBuilder<Map<String, dynamic>?>(
          future: ApiService().getUserById(widget.user.id),
          builder: (context, snapshot) {
            bool isProfileComplete = true;
            String? photoBase64;
            String namaLengkap = widget.user.namaLengkap;

            if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
              var data = snapshot.data!;
              String kontak = data['kontak'] ?? '-';
              String alamat = data['alamat'] ?? '-';
              String tglLahir = data['tanggal_lahir'] ?? '';

              photoBase64 = data['photo_base64'];
              namaLengkap = data['nama_lengkap'] ?? widget.user.namaLengkap;

              if (!isAdmin) {
                if (kontak == '-' ||
                    kontak.isEmpty ||
                    alamat == '-' ||
                    alamat.isEmpty ||
                    tglLahir.isEmpty ||
                    photoBase64 == null ||
                    photoBase64.isEmpty) {
                  isProfileComplete = false;
                }
              }
            } else {
              if (!isAdmin) isProfileComplete = false;
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                bool isDesktop = constraints.maxWidth > 800;

                Widget mainContent;

                if (isDesktop) {
                  mainContent = Row(
                    children: [
                      Container(
                        width: 280,
                        color: AppColors.slate900,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: AppColors.slate800),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: kIsWeb
                                        ? Image.network(
                                            'UNTR.JK-97580c63.png',
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                              Icons.security,
                                              size: 32,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Image.asset(
                                            'web/UNTR.JK-97580c63.png',
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                              Icons.security,
                                              size: 32,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text(
                                            "UNITED TRACTORS",
                                            style: TextStyle(
                                              color: Color.fromARGB(
                                                  255, 255, 255, 255),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 2),
                                          Padding(
                                            padding:
                                                EdgeInsets.only(right: 1.0),
                                            child: Text(
                                              "member of ASTRA",
                                              style: TextStyle(
                                                color: AppColors.blue500,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDesktopNavItem(
                                      'dashboard',
                                      'Beranda',
                                      Icons.dashboard,
                                    ),
                                    if (isKaryawan)
                                      _buildDesktopNavItem(
                                        'attendance',
                                        'Kehadiran',
                                        Icons.event_available,
                                      ),
                                    if (isAdmin) ...[
                                      const Padding(
                                        padding: EdgeInsets.only(
                                          left: 32,
                                          top: 32,
                                          bottom: 12,
                                        ),
                                        child: Text(
                                          "MANAJEMEN",
                                          style: TextStyle(
                                            color: AppColors.slate500,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ),
                                      _buildDesktopNavItem(
                                        'karyawan',
                                        'Data Karyawan',
                                        Icons.people,
                                      ),
                                      _buildDesktopNavItem(
                                        'pengumuman',
                                        'Info & Pengumuman',
                                        Icons.campaign,
                                      ),
                                    ],
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        left: 32,
                                        top: 32,
                                        bottom: 12,
                                      ),
                                      child: Text(
                                        "AKUN & SISTEM",
                                        style: TextStyle(
                                          color: AppColors.slate500,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                    _buildDesktopNavItem(
                                      'pengaturan',
                                      'Pengaturan',
                                      Icons.settings,
                                      showBadge: !isProfileComplete && !isAdmin,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!isAdmin)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: AppColors.slate800),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.yellow500,
                                      radius: 20,
                                      backgroundImage: photoBase64 != null &&
                                              photoBase64.isNotEmpty
                                          ? MemoryImage(
                                              base64Decode(photoBase64))
                                          : null,
                                      child: photoBase64 == null ||
                                              photoBase64.isEmpty
                                          ? Text(
                                              namaLengkap.isNotEmpty
                                                  ? namaLengkap[0].toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                color: AppColors.slate900,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            namaLengkap.toUpperCase(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            snapshot.data != null &&
                                                    snapshot.data!.containsKey('jabatan')
                                                ? snapshot.data!['jabatan']
                                                    .toString()
                                                    .toUpperCase()
                                                : widget.user.role
                                                    .toUpperCase(),
                                            style: const TextStyle(
                                              color: AppColors.slate400,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Konten Utama
                      Expanded(
                        child: Column(
                          children: [
                            // Topbar Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 24,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(color: AppColors.slate100),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.blue50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          size: 20,
                                          color: AppColors.blue500,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        widget.user.role == 'admin'
                                            ? "Sistem Pemantauan UT"
                                            : widget.user.area.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.slate700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.slate900,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.slate900
                                              .withOpacity(0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: AppColors.yellow500,
                                        ),
                                        const SizedBox(width: 12),
                                        const LiveClockWidget(
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            "WITA",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (!isProfileComplete &&
                                _currentView == 'dashboard' &&
                                !isAdmin)
                              Container(
                                margin:
                                    const EdgeInsets.fromLTRB(32, 24, 32, 0),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.rose50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.rose200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        color: AppColors.rose500, size: 24),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Text(
                                        "Profil Anda belum lengkap! Silakan lengkapi data diri (termasuk foto profil) di menu Pengaturan agar data absensi dan borang lebih akurat.",
                                        style: TextStyle(
                                            color: AppColors.rose600,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.rose500,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      onPressed: () => setState(
                                          () => _currentView = 'pengaturan'),
                                      child: const Text("Lengkapi Sekarang",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11)),
                                    )
                                  ],
                                ),
                              ),

                            // View Body
                            Expanded(child: _buildBody(isProfileComplete)),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  mainContent = Column(
                    children: [
                      AppBar(
                        backgroundColor: AppColors.slate900,
                        elevation: 0,
                        title: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: kIsWeb
                                  ? Image.network(
                                      'UNTR.JK-97580c63.png',
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                        Icons.security,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Image.asset(
                                      'web/UNTR.JK-97580c63.png',
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                        Icons.security,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text(
                                      "UNITED TRACTORS",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(right: 1.0),
                                      child: Text(
                                        "member of ASTRA",
                                        style: TextStyle(
                                          color: AppColors.blue500,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 8,
                                          letterSpacing: 1.0,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          Container(
                            margin: const EdgeInsets.all(10),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.slate800,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: AppColors.yellow500,
                                ),
                                SizedBox(width: 6),
                                LiveClockWidget(
                                  suffix: ' WITA',
                                  style: TextStyle(
                                    color: AppColors.yellow500,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // BANNER NOTIFIKASI MOBILE
                      if (!isProfileComplete &&
                          _currentView == 'dashboard' &&
                          !isAdmin)
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.rose50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.rose200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: AppColors.rose500, size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      "Profil Anda Belum Lengkap!",
                                      style: TextStyle(
                                          color: AppColors.rose600,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Lengkapi data diri dan foto profil Anda di menu Pengaturan agar data sistem lebih akurat.",
                                style: TextStyle(
                                    color: AppColors.rose500,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    height: 1.4),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.rose500,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  onPressed: () => setState(
                                      () => _currentView = 'pengaturan'),
                                  child: const Text("Lengkapi Sekarang",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11)),
                                ),
                              )
                            ],
                          ),
                        ),

                      // View Body
                      Expanded(
                          child:
                              SafeArea(child: _buildBody(isProfileComplete))),

                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(32)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 20,
                              offset: Offset(0, -5),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: SafeArea(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildMobileNavItem(
                                'dashboard',
                                'Beranda',
                                Icons.dashboard,
                              ),
                              if (isKaryawan)
                                _buildMobileNavItem(
                                  'attendance',
                                  'Absen',
                                  Icons.event_available,
                                ),
                              if (isAdmin)
                                _buildMobileNavItem(
                                  'karyawan',
                                  'Karyawan',
                                  Icons.people,
                                ),
                              if (isAdmin)
                                _buildMobileNavItem(
                                  'pengumuman',
                                  'Info',
                                  Icons.campaign,
                                ),
                              _buildMobileNavItem(
                                'pengaturan',
                                'Setelan',
                                Icons.settings,
                                showBadge: !isProfileComplete && !isAdmin,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Stack(
                  children: [
                    Positioned.fill(child: mainContent),
                  ],
                );
              },
            );
          }),
    );
  }

  Widget _buildDesktopNavItem(String id, String label, IconData icon,
      {bool showBadge = false}) {
    bool isActive = _currentView == id;
    return InkWell(
      onTap: () {
        if (_currentView != id) {
          setState(() => _currentView = id);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? AppColors.yellow500 : AppColors.slate500,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isActive ? AppColors.yellow500 : AppColors.slate400,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            if (showBadge)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.rose500, shape: BoxShape.circle),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavItem(String id, String label, IconData icon,
      {bool showBadge = false}) {
    bool isActive = _currentView == id;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_currentView != id) {
            setState(() => _currentView = id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(clipBehavior: Clip.none, children: [
                  Icon(
                    icon,
                    color: isActive ? AppColors.yellow500 : AppColors.slate400,
                    size: 22,
                  ),
                  if (showBadge)
                    Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: AppColors.rose500,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isActive
                                      ? AppColors.yellow500
                                      : Colors.white,
                                  width: 1.5)),
                        ))
                ]),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.yellow500 : AppColors.slate400,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
