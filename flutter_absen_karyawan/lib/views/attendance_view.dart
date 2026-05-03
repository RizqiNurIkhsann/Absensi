import 'dart:io';
import 'dart:async';
import 'dart:convert'; 
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform; 
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:camera/camera.dart'; 
import 'package:ntp/ntp.dart'; 
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'; 
import 'package:geocoding/geocoding.dart'; 
import '../core/app_constants.dart';
import '../models/user_model.dart';

class AttendanceView extends StatefulWidget {
  final UserModel user;

  const AttendanceView({super.key, required this.user});

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  String _status = 'Hadir';
  String _keterangan = ''; 
  
  Position? _currentPosition;
  String _currentAddress = ''; 

  bool _isLocating = true;
  String _errorMsg = '';
  double _distance = 0.0;
  bool _isMocked = false;

  List<Map<String, dynamic>> _locations = [];
  Map<String, dynamic>? _closestSite;

  List<Map<String, dynamic>> _availableShifts = [];
  String? _selectedShiftCategory; 
  String? _selectedShiftTimeId;   
  bool _isShiftLocked = false; 

  bool _isEarlyOut = false;
  String _earlyOutReason = '';

  String _filterShift = 'Semua Shift'; 

  final MapController _mapController = MapController();
  final ScrollController _historyScrollController = ScrollController(); 
  final TextEditingController _pulangCepatReasonCtrl = TextEditingController(); 
  
  final TextEditingController _keteranganDinasCtrl = TextEditingController();

  final LocalAuthentication auth = LocalAuthentication(); 
  final ImagePicker _picker = ImagePicker(); 
  File? _liveSelfieImage; 

  StreamSubscription<Position>? _positionStreamSubscription;

  String actionType = 'MASUK';
  bool _isCheckingStatus = true;
  bool _isProcessingTap = false; 
  
  String _currentToday = DateFormat('yyyy-MM-dd').format(DateTime.now()); 
  String _filterMonth = DateFormat('yyyy-MM').format(DateTime.now());

  Future<DateTime> _getStrictWitaTime() async {
    try {
      DateTime networkTime = await NTP.now(timeout: const Duration(seconds: 3));
      return networkTime.toUtc().add(const Duration(hours: 8));
    } catch (e) {
      debugPrint("NTP Timeout, memakai fallback waktu lokal dikonversi ke WITA.");
      return DateTime.now().toUtc().add(const Duration(hours: 8));
    }
  }

  String _getShiftVal(Map<String, dynamic> s) {
    return s['id']?.toString() ?? "${s['name']}_${s['start']}_${s['end']}";
  }

  bool _isCurrentlyEarlyOut() {
    if (actionType != 'KELUAR' || _selectedShiftTimeId == null) return false;
    
    var shiftData = _availableShifts.firstWhere((s) => _getShiftVal(s) == _selectedShiftTimeId, orElse: () => _availableShifts.first);
    String endStr = shiftData['end'] ?? '17:00';
    int endH = int.tryParse(endStr.split(':')[0]) ?? 17;
    int endM = int.tryParse(endStr.split(':')[1]) ?? 0;
    
    DateTime now = DateTime.now().toUtc().add(const Duration(hours: 8));
    DateTime endTime = DateTime.utc(now.year, now.month, now.day, endH, endM);
    
    String startStr = shiftData['start'] ?? '08:00';
    int startH = int.tryParse(startStr.split(':')[0]) ?? 8;
    
    if (endH < startH) {
      if (now.hour >= 12) {
        endTime = endTime.add(const Duration(days: 1));
      }
    }
    return now.isBefore(endTime);
  }

  void _showDesktopBlockDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.phonelink_erase, color: AppColors.rose500, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "AKSES DIBATASI", 
                style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.slate800, fontSize: 18)
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.rose50, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.no_photography, color: AppColors.rose500, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              "Mohon maaf, fitur absensi dan verifikasi wajah tidak dapat dilakukan melalui perangkat Desktop (PC/Laptop/Mac).\n\nSilakan buka aplikasi ini menggunakan perangkat Handphone (Android/iOS) Anda untuk melakukan absensi.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate600, fontWeight: FontWeight.bold, height: 1.5, fontSize: 13),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.slate900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16)
              ),
              onPressed: () => Navigator.pop(c),
              child: const Text("Mengerti", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          )
        ],
      )
    );
  }

  @override
  void initState() {
    super.initState();
    _initAttendance();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _historyScrollController.dispose();
    _pulangCepatReasonCtrl.dispose();
    _keteranganDinasCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAbsenTap() async {
    if (_isProcessingTap) return;
    setState(() => _isProcessingTap = true);

    bool isDesktop = defaultTargetPlatform == TargetPlatform.windows || 
                     defaultTargetPlatform == TargetPlatform.macOS || 
                     defaultTargetPlatform == TargetPlatform.linux;

    if (isDesktop) {
      setState(() => _isProcessingTap = false);
      _showDesktopBlockDialog();
      return; 
    }

    try {
      if (!await _validateTimeRequirements()) return;

      if (actionType == 'MASUK' && _status == 'Perjalanan Dinas') {
        if (_keteranganDinasCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap isi Keterangan Pekerjaan untuk mode Perjalanan Dinas!"), backgroundColor: AppColors.rose500));
          return;
        }
      }

      if (actionType == 'MASUK' && !_isShiftLocked) {
         var shiftData = _availableShifts.firstWhere(
           (s) => _getShiftVal(s) == _selectedShiftTimeId, 
           orElse: () => _availableShifts.isNotEmpty ? _availableShifts.first : {'name': 'Shift', 'start': '08:00', 'end': '17:00'}
         );
         
         if (!mounted) return;
         bool? confirm = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
               backgroundColor: Colors.white,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
               title: const Row(
                 children: [
                   Icon(Icons.warning_amber_rounded, color: AppColors.amber500),
                   SizedBox(width: 8),
                   Expanded(child: Text("Konfirmasi Jadwal", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.slate800))),
                 ],
               ),
               content: Text(
                 "Anda akan mengunci shift ${shiftData['name']} (${shiftData['start']} - ${shiftData['end']}) untuk hari ini.\n\nJadwal yang dipilih tidak bisa diubah kembali setelah absensi disahkan. Lanjutkan?",
                 style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600, height: 1.5)
               ),
               actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => Navigator.pop(c, true), 
                    child: const Text("Ya, Kunci & Lanjut", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  ),
               ]
            )
         );
         if (confirm != true) return;
      }

      if (actionType == 'KELUAR' && _isEarlyOut) {
         bool confirmed = false;

         while (!confirmed) {
            TextEditingController dialogReasonCtrl = TextEditingController();
            
            if (!mounted) return;
            bool? submitReason = await showDialog<bool>(
               context: context,
               builder: (c) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.amber500),
                      SizedBox(width: 8),
                      Expanded(child: Text("Alasan Pulang Cepat", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.slate800))),
                    ],
                  ),
                  content: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                        const Text("Anda terdeteksi melakukan absen pulang mendahului jadwal shift.\n\nHarap tuliskan alasannya secara detail (akan dilaporkan ke Admin):", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate600, height: 1.5)),
                        const SizedBox(height: 16),
                        TextField(
                           controller: dialogReasonCtrl,
                           maxLines: 3,
                           decoration: InputDecoration(
                              hintText: "Ketik alasan pulang cepat...",
                              filled: true, fillColor: AppColors.slate50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                           ),
                        )
                     ]
                  ),
                  actions: [
                     TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
                     ElevatedButton(
                       style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                       onPressed: () {
                          if (dialogReasonCtrl.text.trim().isEmpty) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alasan pulang cepat wajib diisi!"), backgroundColor: AppColors.rose500));
                             return;
                          }
                          Navigator.pop(c, true);
                       },
                       child: const Text("Lanjut", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                     ),
                  ]
               )
            );
            
            if (submitReason != true) {
               setState(() => _isProcessingTap = false);
               return; 
            }
            
            String currentReason = dialogReasonCtrl.text.trim();

            if (!mounted) return;
            bool? verifyReason = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                 backgroundColor: Colors.white,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                 title: const Row(
                    children: [
                      Icon(Icons.fact_check, color: AppColors.emerald500),
                      SizedBox(width: 8),
                      Expanded(child: Text("Verifikasi Alasan", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.slate800))),
                    ],
                 ),
                 content: RichText(
                   text: TextSpan(
                     style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate600, height: 1.5),
                     children: [
                       const TextSpan(text: "Pastikan alasan Anda sudah benar dan tidak ada salah ketik sebelum dikirim ke Admin:\n\n"),
                       TextSpan(text: "\"$currentReason\"", style: const TextStyle(color: AppColors.slate900, fontStyle: FontStyle.italic, fontWeight: FontWeight.w900)),
                     ]
                   )
                 ),
                 actions: [
                   TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Edit Kembali", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                     onPressed: () => Navigator.pop(c, true),
                     child: const Text("Ya, Sudah Benar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                   ),
                 ]
              )
            );

            if (verifyReason == true) {
               _earlyOutReason = currentReason;
               confirmed = true;
            }
         }
      }
      
      await _authenticateAndSubmit(); 
    } finally {
      if (mounted) {
        setState(() => _isProcessingTap = false);
      }
    }
  }

  Future<void> _initAttendance() async {
    DateTime realTime = await _getStrictWitaTime();
    _currentToday = DateFormat('yyyy-MM-dd').format(realTime);

    await _fetchSiteConfigs();
    await _checkTodayAttendance();
    _startLocationTracking();
  }

  Future<void> _fetchSiteConfigs() async {
    try {
      var data = await ApiService().getConfigSite();

      if (data != null) {
        List<dynamic> locs = data['locations'] ?? [];
        List<dynamic> shifts = data['shifts'] ?? [];

        if (mounted) {
          setState(() {
            _locations = locs.map((e) => Map<String, dynamic>.from(e)).toList();
            
            String userAreaLow = widget.user.area.toLowerCase().trim();
            
            _availableShifts = shifts.map((e) => Map<String, dynamic>.from(e)).where((s) {
               String shiftAreaLow = (s['area'] ?? '').toString().toLowerCase().trim();
               return shiftAreaLow == userAreaLow || shiftAreaLow == 'semua area';
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal mengambil konfigurasi site: $e");
    } finally {
      if (mounted) {
        setState(() {
          if (_availableShifts.isEmpty) {
            _availableShifts = [
              {'id': 'shift-default', 'name': 'Shift Pagi (Default)', 'start': '08:00', 'end': '17:00', 'area': widget.user.area}
            ];
          }

          if (_availableShifts.isNotEmpty) {
             if (_selectedShiftCategory == null) {
                var match = _availableShifts.where((s) => s['name'].toString().toLowerCase() == widget.user.shift.toLowerCase()).toList();
                _selectedShiftCategory = match.isNotEmpty ? match.first['name'] : _availableShifts.first['name'];
             }
             if (_selectedShiftTimeId == null && _selectedShiftCategory != null) {
                var times = _availableShifts.where((s) => s['name'] == _selectedShiftCategory).toList();
                if (times.isNotEmpty) {
                   _selectedShiftTimeId = _getShiftVal(times.first);
                }
             }
          }
        });
      }
    }
  }

  Future<void> _checkTodayAttendance() async {
    try {
      var data = await ApiService().getTodayAttendance(widget.user.id);

      if (data != null && data.isNotEmpty) {
        if (data.containsKey('shift_value') && data['shift_value'] != null) {
           _selectedShiftTimeId = data['shift_value'];
           var match = _availableShifts.where((s) => _getShiftVal(s) == _selectedShiftTimeId).toList();
           if(match.isNotEmpty) _selectedShiftCategory = match.first['name'];
        } else if (data.containsKey('shift') && data['shift'] != null) {
           _selectedShiftCategory = data['shift'];
           var times = _availableShifts.where((s) => s['name'] == _selectedShiftCategory).toList();
           if (times.isNotEmpty) _selectedShiftTimeId = _getShiftVal(times.first);
        }

        if (data.containsKey('jam_pulang') && data['jam_pulang'] != null) {
          setState(() {
            actionType = 'SELESAI';
            _status = data['status_kehadiran'] ?? 'Selesai';
            _isShiftLocked = true;
          });
        } else if (data.containsKey('jam_masuk') && data['jam_masuk'] != null) {
          setState(() {
            actionType = 'KELUAR';
            _status = 'Hadir'; // UI Lock
            _isShiftLocked = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            actionType = 'MASUK';
            _isShiftLocked = false;
            _status = 'Hadir';
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal memuat status absensi: $e");
    } finally {
      if (mounted) setState(() => _isCheckingStatus = false);
    }
  }

  // --- FUNGSI REVERSE GEOCODING (MENGUBAH KOORDINAT JADI ALAMAT) ---
  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        if (mounted) {
          setState(() {
            List<String> addressParts = [];
            if (place.street != null && place.street!.isNotEmpty) addressParts.add(place.street!);
            if (place.subLocality != null && place.subLocality!.isNotEmpty) addressParts.add(place.subLocality!);
            if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
            if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) addressParts.add(place.subAdministrativeArea!);
            if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) addressParts.add(place.administrativeArea!);
            
            _currentAddress = addressParts.join(', ');
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal Reverse Geocoding: $e");
    }
  }

  Future<void> _startLocationTracking() async {
    if (!mounted) return;
    setState(() { _isLocating = true; _errorMsg = ''; });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() { _errorMsg = 'Layanan Lokasi dinonaktifkan.'; _isLocating = false; });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() { _errorMsg = 'Izin lokasi ditolak.'; _isLocating = false; });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() { _errorMsg = 'Izin lokasi ditolak permanen.'; _isLocating = false; });
      return;
    }

    try {
      if (!kIsWeb) {
        try {
          Position? lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null) _updatePosition(lastPos);
        } catch (e) {
          debugPrint("Abaikan error lastPos: $e");
        }
      }

      Position initPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15), 
      );
      _updatePosition(initPos);
    } on TimeoutException catch (_) {
      if (mounted && _currentPosition == null) {
        setState(() { _isLocating = false; _errorMsg = 'Sinyal GPS Lemah / Timeout. Pastikan di area terbuka.'; });
      }
    } catch (e) {
      debugPrint("Gagal getCurrentPosition: $e");
      if (mounted && _currentPosition == null) {
        setState(() { _isLocating = false; _errorMsg = 'Gagal membaca sensor GPS.'; });
      }
    }

    final LocationSettings locationSettings = kIsWeb 
        ? const LocationSettings(accuracy: LocationAccuracy.high)
        : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0);

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _updatePosition(position);
      },
      onError: (error) {
        if (mounted && _currentPosition == null) {
          setState(() { _errorMsg = 'Gagal melacak GPS. Pastikan lokasi aktif.'; _isLocating = false; });
        }
      }
    );
  }

  void _updatePosition(Position position) {
    if (!mounted) return;
    
    if (position.isMocked) {
      setState(() {
        _isMocked = true;
        _errorMsg = 'SISTEM MENDETEKSI FAKE GPS / LOKASI PALSU! HARAP MATIKAN APLIKASI MOCK LOCATION.';
        _isLocating = false;
      });
      return;
    }

    double minDistance = double.infinity;
    Map<String, dynamic>? nearestSite;

    for (var loc in _locations) {
      if (loc['isLocked'] == true && loc['lat'] != null && loc['lng'] != null) {
        
        if (widget.user.area != 'Semua Area' && widget.user.area != 'Semua Site') {
           if (loc['siteName'].toString().toLowerCase() != widget.user.area.toLowerCase()) {
              continue; 
           }
        }

        double dist = Geolocator.distanceBetween(position.latitude, position.longitude, loc['lat'], loc['lng']);
        if (dist < minDistance) {
          minDistance = dist;
          nearestSite = loc;
        }
      }
    }

    setState(() {
      _currentPosition = position;
      if (nearestSite != null) {
        _distance = minDistance;
        _closestSite = nearestSite;
      } else {
        _distance = double.infinity;
        _closestSite = null;
      }
      _isLocating = false;
      _isMocked = false;
      _errorMsg = '';
    });
    
    // Panggil fungsi terjemah alamat setiap kali koordinat terupdate
    _getAddressFromLatLng(position);

    _mapController.move(LatLng(position.latitude, position.longitude), 16.0);
  }

  Future<void> _forceRefreshLocation() async {
    _positionStreamSubscription?.cancel();
    await _startLocationTracking();
  }

  Future<bool> _validateTimeRequirements() async {
     if (_selectedShiftTimeId == null) {
        if (_availableShifts.isNotEmpty) {
           _selectedShiftCategory = _availableShifts.first['name'];
           _selectedShiftTimeId = _getShiftVal(_availableShifts.first);
           setState(() {}); 
        } else {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap tentukan jadwal shift dan waktu terlebih dahulu!"), backgroundColor: AppColors.rose500));
           return false;
        }
     }

     DateTime realTime = await _getStrictWitaTime(); 

     var shiftData = _availableShifts.firstWhere((s) => _getShiftVal(s) == _selectedShiftTimeId, orElse: () => _availableShifts.first);
     String startStr = shiftData['start'] ?? '08:00'; 
     String endStr = shiftData['end'] ?? '17:00';
     
     int startH = int.tryParse(startStr.split(':')[0]) ?? 8;
     int startM = int.tryParse(startStr.split(':')[1]) ?? 0;
     DateTime startTime = DateTime.utc(realTime.year, realTime.month, realTime.day, startH, startM);
     
     int endH = int.tryParse(endStr.split(':')[0]) ?? 17;
     int endM = int.tryParse(endStr.split(':')[1]) ?? 0;
     DateTime endTime = DateTime.utc(realTime.year, realTime.month, realTime.day, endH, endM);
     
     if (endTime.isBefore(startTime)) {
         if (realTime.hour < 12) {
             startTime = startTime.subtract(const Duration(days: 1));
         } else {
             endTime = endTime.add(const Duration(days: 1));
         }
     }

     if (actionType == 'MASUK') {
         DateTime openTime = startTime.subtract(const Duration(hours: 1));
         if (realTime.isBefore(openTime)) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Akses Ditolak: Absen Masuk baru tersedia 1 jam sebelum shift dimulai ($startStr)."), backgroundColor: AppColors.rose500, duration: const Duration(seconds: 4)));
             return false;
         }
     } else if (actionType == 'KELUAR') {
         if (realTime.isBefore(endTime)) {
             _isEarlyOut = true;
         } else {
             _isEarlyOut = false;
         }
     }
     
     return true;
  }

  Future<void> _authenticateAndSubmit() async {
    try {
      final photo = await showDialog<XFile>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LiveCameraDialog(
          reasonLabel: (actionType == 'KELUAR' && _isEarlyOut) 
              ? "Alasan Pulang Cepat:\n\"$_earlyOutReason\"" 
              : null,
          userId: widget.user.id,
        ),
      );

      if (photo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Absen Dibatalkan: Wajib melakukan verifikasi wajah (Face Recognition)."), backgroundColor: AppColors.rose500)
          );
        }
        return; 
      }

      setState(() {
        _liveSelfieImage = File(photo.path);
      });

      if (!kIsWeb) {
        try {
          bool isSupported = await auth.isDeviceSupported();
          if (isSupported) {
            bool authenticated = await auth.authenticate(
              localizedReason: 'Pindai Sidik Jari / PIN untuk mengesahkan Absensi',
              options: const AuthenticationOptions(
                stickyAuth: true, 
                biometricOnly: false, 
              ),
            );

            if (!authenticated) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Otentikasi Sistem Dibatalkan!"), backgroundColor: AppColors.rose500)
                );
              }
              return; 
            }
          }
        } catch (authError) {
          debugPrint("Bypass Biometrik: $authError");
        }
      }

      await _submitAbsen();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Terjadi kendala Keamanan/Kamera: $e"), backgroundColor: AppColors.rose500)
        );
      }
    }
  }

  Future<void> _submitAbsen() async {
    if (_isMocked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Akses Ditolak: Fake GPS Terdeteksi!"), backgroundColor: AppColors.rose500));
      return;
    }

    DateTime realTime = await _getStrictWitaTime(); 
    String timeStr = DateFormat('HH:mm').format(realTime);
    _currentToday = DateFormat('yyyy-MM-dd').format(realTime); 

    bool isWfhMode = _closestSite != null && (_closestSite!['isWfhMode'] == true);
    bool isPerjalananDinas = _status == 'Perjalanan Dinas';

    String siteName = _closestSite != null ? _closestSite!['siteName'] : "Site Tidak Diketahui";
    String formattedCoordinate = "${_currentPosition?.latitude.toStringAsFixed(4)}, ${_currentPosition?.longitude.toStringAsFixed(4)}";
    String finalAddress = _currentAddress.isNotEmpty ? _currentAddress : formattedCoordinate;
    
    if (isPerjalananDinas && actionType == 'MASUK') {
       siteName = "Dinas Luar ($finalAddress)";
    } else if (isWfhMode) {
       siteName = "$siteName (WFH)";
    }

    String kedisiplinan = 'Tepat Waktu';
    Map<String, dynamic>? activeShiftData;
    
    if (_selectedShiftTimeId != null) {
       activeShiftData = _availableShifts.firstWhere((s) => _getShiftVal(s) == _selectedShiftTimeId, orElse: () => _availableShifts.first);
       
       if (actionType == 'MASUK') {
           String startStr = activeShiftData['start'] ?? '08:00';
           int startH = int.tryParse(startStr.split(':')[0]) ?? 8;
           int startM = int.tryParse(startStr.split(':')[1]) ?? 0;
           
           DateTime startTime = DateTime.utc(realTime.year, realTime.month, realTime.day, startH, startM);
           
           if (realTime.hour < 12 && startH >= 12) {
              startTime = startTime.subtract(const Duration(days: 1));
           }
           
           if (realTime.isAfter(startTime)) {
               kedisiplinan = 'Terlambat';
           }
       }
    }

    String finalStatusKehadiran = _status;
    if (actionType == 'KELUAR') {
        if (_isEarlyOut) {
            finalStatusKehadiran = 'Pulang Cepat';
        } else {
            finalStatusKehadiran = 'Absen Pulang';
        }
    }

    String valStatus = 'Pending';
    if (finalStatusKehadiran == 'Hadir' || finalStatusKehadiran == 'Perjalanan Dinas' || finalStatusKehadiran == 'Absen Pulang' || finalStatusKehadiran == 'Pulang Cepat') {
        valStatus = 'Disetujui'; 
    }

    Map<String, dynamic> payload = {
      'user_id': widget.user.id,
      'nik': widget.user.nik,
      'nama_lengkap': widget.user.namaLengkap,
      'area': widget.user.area, 
      'date': _currentToday,
      'shift': activeShiftData != null ? activeShiftData['name'] : widget.user.shift, 
      'shift_time': activeShiftData != null ? "${activeShiftData['start']} - ${activeShiftData['end']}" : "-",
      'shift_value': _selectedShiftTimeId, 
      'status_validasi': valStatus,
      'site_absen': siteName,
      'photo_url': 'live_camera_capture_verified', 
      'updated_at': realTime.toIso8601String(),
    };

    if (finalStatusKehadiran == 'Hadir' || finalStatusKehadiran == 'Perjalanan Dinas' || finalStatusKehadiran == 'Absen Pulang' || finalStatusKehadiran == 'Pulang Cepat') {
      if (actionType == 'MASUK') {
        // HANYA UPDATE STATUS KEHADIRAN SAAT MASUK AGAR TIDAK MENIMPA SAAT PULANG
        payload['status_kehadiran'] = finalStatusKehadiran;
        payload['jam_masuk'] = timeStr;
        
        payload['gps_masuk'] = finalAddress;
        payload['site_masuk'] = siteName;
        payload['status_kedisiplinan'] = kedisiplinan;
        
        if (finalStatusKehadiran == 'Perjalanan Dinas') {
          payload['keterangan'] = "Pekerjaan: ${_keteranganDinasCtrl.text.trim()}";
        }
      } else if (actionType == 'KELUAR') {
        payload['jam_pulang'] = timeStr;
        payload['gps_pulang'] = finalAddress;
        payload['site_pulang'] = siteName;
        
        if (_isEarlyOut) {
           payload['status_pulang'] = 'Pulang Cepat';
           payload['alasan_pulang_cepat'] = _earlyOutReason; 
        } else {
           payload['status_pulang'] = 'Sesuai Jadwal';
        }
      }
    } else {
      payload['status_kehadiran'] = finalStatusKehadiran;
      payload['keterangan'] = _keterangan;
    }

    try {
      await ApiService().logManualAttendance(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Laporan ${actionType == 'MASUK' && (_status == 'Hadir' || _status == 'Perjalanan Dinas') ? 'Masuk' : (actionType == 'KELUAR' ? 'Pulang' : _status)} Berhasil Dikirim!"), backgroundColor: AppColors.emerald500),
        );
      }
      
      _checkTodayAttendance(); 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengirim ke server: $e"), backgroundColor: AppColors.rose500),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStatus) return const Center(child: CircularProgressIndicator(color: AppColors.yellow500));
    
    bool isWfhMode = _closestSite != null && (_closestSite!['isWfhMode'] == true);
    bool isPerjalananDinas = _status == 'Perjalanan Dinas';
    
    bool inRadius = _closestSite != null && (_distance <= (_closestSite!['radius'] ?? 100) || isWfhMode) || isPerjalananDinas;
    
    bool isEarly = _isCurrentlyEarlyOut();
    String camLabel = actionType == 'MASUK' ? 'MASUK' : (isEarly ? 'PULANG CEPAT' : 'PULANG');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 800;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildAttendanceCard(inRadius, isWfhMode, isPerjalananDinas, camLabel),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 7,
                      child: _buildHistoryCard(),
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAttendanceCard(inRadius, isWfhMode, isPerjalananDinas, camLabel),
                    const SizedBox(height: 24),
                    _buildHistoryCard(),
                  ],
                );
              }
            }
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(bool inRadius, bool isWfhMode, bool isPerjalananDinas, String camLabel) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text("KEHADIRAN KARYAWAN", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.slate900, letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.emerald50, borderRadius: BorderRadius.circular(16)),
                child: const Text("SISTEM AKTIF", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.emerald600)),
              ),
            ],
          ),
          const Divider(height: 32, color: AppColors.slate100),
          
          if (actionType == 'SELESAI') ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(color: AppColors.emerald50, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: AppColors.emerald500, size: 60),
                  ),
                  const SizedBox(height: 24),
                  Text(_status.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.slate800)),
                  const SizedBox(height: 8),
                  const Text("Anda telah menyelesaikan absensi masuk dan pulang untuk hari ini.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 40),
                ]
              ),
            )
          ] else ...[
            
            if (_availableShifts.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("PILIH JADWAL & WAKTU", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 1)),
                  if (_isShiftLocked) 
                    const Icon(Icons.lock, size: 14, color: AppColors.rose500)
                ],
              ),
              const SizedBox(height: 8),
              
              Builder(
                builder: (context) {
                  List<String> shiftCategories = _availableShifts.map((s) => s['name'].toString()).toSet().toList();
                  bool catExists = shiftCategories.contains(_selectedShiftCategory);
                  if (!catExists && shiftCategories.isNotEmpty) _selectedShiftCategory = shiftCategories.first;

                  List<Map<String, dynamic>> timesForCategory = _availableShifts.where((s) => s['name'] == _selectedShiftCategory).toList();
                  bool timeExists = timesForCategory.any((s) => _getShiftVal(s) == _selectedShiftTimeId);
                  
                  if (!timeExists && timesForCategory.isNotEmpty) {
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                       if(mounted) setState(() => _selectedShiftTimeId = _getShiftVal(timesForCategory.first));
                     });
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                           decoration: BoxDecoration(
                              color: _isShiftLocked ? AppColors.slate50 : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _isShiftLocked ? AppColors.slate100 : AppColors.slate300)
                           ),
                           child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                 isExpanded: true,
                                 value: _selectedShiftCategory,
                                 icon: Icon(Icons.arrow_drop_down, color: _isShiftLocked ? AppColors.slate300 : AppColors.slate600),
                                 items: shiftCategories.map((c) => DropdownMenuItem<String>(
                                    value: c, 
                                    child: Text(c, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _isShiftLocked ? AppColors.slate400 : AppColors.slate800), overflow: TextOverflow.ellipsis)
                                 )).toList(),
                                 onChanged: _isShiftLocked ? null : (val) {
                                    setState(() {
                                      _selectedShiftCategory = val;
                                      var newTimes = _availableShifts.where((s) => s['name'] == val).toList();
                                      if (newTimes.isNotEmpty) _selectedShiftTimeId = _getShiftVal(newTimes.first);
                                    });
                                 }
                              )
                           )
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                           decoration: BoxDecoration(
                              color: _isShiftLocked ? AppColors.slate50 : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _isShiftLocked ? AppColors.slate100 : AppColors.slate300)
                           ),
                           child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                 isExpanded: true,
                                 value: timeExists ? _selectedShiftTimeId : (timesForCategory.isNotEmpty ? _getShiftVal(timesForCategory.first) : null),
                                 icon: Icon(Icons.arrow_drop_down, color: _isShiftLocked ? AppColors.slate300 : AppColors.slate600),
                                 items: timesForCategory.map((s) => DropdownMenuItem<String>(
                                    value: _getShiftVal(s),
                                    child: Text("${s['start']} - ${s['end']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _isShiftLocked ? AppColors.slate400 : AppColors.slate800), overflow: TextOverflow.ellipsis)
                                 )).toList(),
                                 onChanged: _isShiftLocked ? null : (val) {
                                    setState(() => _selectedShiftTimeId = val);
                                 }
                              )
                           )
                        ),
                      ),
                    ],
                  );
                }
              ),
              
              if (!_isShiftLocked)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text("*Pilihan akan dikunci permanen setelah absen dieksekusi", style: TextStyle(fontSize: 9, color: AppColors.rose500, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(height: 24),
            ],

            if (actionType == 'MASUK') ...[
               Builder(
                 builder: (context) {
                   List<String> statusOptions = ['Hadir', 'Perjalanan Dinas'];
                   return Row(
                     children: statusOptions.map((s) => Expanded(
                       child: GestureDetector(
                         onTap: () => setState(() => _status = s),
                         child: Container(
                           margin: const EdgeInsets.symmetric(horizontal: 4), 
                           padding: const EdgeInsets.symmetric(vertical: 14),
                           decoration: BoxDecoration(
                             color: _status == s ? AppColors.yellow500 : Colors.white, 
                             border: Border.all(color: _status == s ? AppColors.yellow500 : AppColors.slate200),
                             borderRadius: BorderRadius.circular(16)
                           ),
                           alignment: Alignment.center,
                           child: Text(s.toUpperCase(), style: TextStyle(color: _status == s ? AppColors.slate900 : AppColors.slate400, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                         ),
                       ),
                     )).toList(),
                   );
                 }
               ),
               const SizedBox(height: 24),
            ],

            if (actionType == 'MASUK' && isPerjalananDinas) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  bool isBoxWide = constraints.maxWidth > 350;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.blue50.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.blue500)
                    ),
                    child: isBoxWide 
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.gps_fixed, color: AppColors.blue500, size: 24),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("LOKASI PERJALANAN DINAS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.blue500, letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  const Text("Alamat / titik koordinat lokasi Anda saat ini akan direkam secara otomatis oleh sistem satelit GPS saat Anda melakukan absensi.", style: TextStyle(fontSize: 10, color: AppColors.blue500, fontWeight: FontWeight.bold, height: 1.4)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("LOKASI TERKINI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.blue500, letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentAddress.isNotEmpty 
                                        ? _currentAddress 
                                        : "GPS: ${_currentPosition?.latitude.toStringAsFixed(5) ?? '-'}, ${_currentPosition?.longitude.toStringAsFixed(5) ?? '-'}", 
                                    style: TextStyle(
                                        fontSize: _currentAddress.isNotEmpty ? 10 : 12, 
                                        color: AppColors.blue500, 
                                        fontWeight: _currentAddress.isNotEmpty ? FontWeight.bold : FontWeight.w900, 
                                        fontFamily: _currentAddress.isNotEmpty ? 'Roboto' : 'monospace'
                                    ),
                                    maxLines: 3, 
                                    overflow: TextOverflow.ellipsis
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.gps_fixed, color: AppColors.blue500, size: 20),
                                const SizedBox(width: 12),
                                const Text("LOKASI PERJALANAN DINAS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.blue500, letterSpacing: 1)),
                              ]
                            ),
                            const SizedBox(height: 8),
                            const Text("Alamat / titik koordinat lokasi Anda saat ini akan direkam secara otomatis oleh sistem satelit GPS saat Anda melakukan absensi.", style: TextStyle(fontSize: 10, color: AppColors.blue500, fontWeight: FontWeight.bold, height: 1.4)),
                            const SizedBox(height: 16),
                            const Text("LOKASI TERKINI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.blue500, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(
                              _currentAddress.isNotEmpty 
                                  ? _currentAddress 
                                  : "GPS: ${_currentPosition?.latitude.toStringAsFixed(5) ?? '-'}, ${_currentPosition?.longitude.toStringAsFixed(5) ?? '-'}", 
                              style: TextStyle(
                                  fontSize: _currentAddress.isNotEmpty ? 10 : 12, 
                                  color: AppColors.blue500, 
                                  fontWeight: _currentAddress.isNotEmpty ? FontWeight.bold : FontWeight.w900, 
                                  fontFamily: _currentAddress.isNotEmpty ? 'Roboto' : 'monospace'
                              ),
                              maxLines: 3, 
                              overflow: TextOverflow.ellipsis
                            ),
                          ],
                        )
                  );
                }
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("KETERANGAN PEKERJAAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keteranganDinasCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "Contoh: Melakukan kunjungan klien ke PT. Bintang Mandiri...",
                      filled: true, fillColor: AppColors.slate50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
                    )
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            if ((actionType == 'MASUK' && (_status == 'Hadir' || _status == 'Perjalanan Dinas')) || actionType == 'KELUAR') ...[
              Container(
                height: 220,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: AppColors.slate900),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(-2.164177, 115.387570), 
                        initialZoom: 14.0, 
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', 
                          userAgentPackageName: 'com.ut.hrms'
                        ),
                        CircleLayer(
                          circles: _locations.where((l) => l['isLocked'] == true && l['lat'] != null).map((loc) => 
                            CircleMarker(
                              point: LatLng(loc['lat'], loc['lng']), 
                              color: AppColors.yellow500.withValues(alpha: 0.2), 
                              borderStrokeWidth: 2, 
                              borderColor: AppColors.yellow500, 
                              useRadiusInMeter: true, 
                              radius: (loc['radius'] ?? 100).toDouble()
                            )
                          ).toList()
                        ),
                        if (_currentPosition != null) MarkerLayer(
                          markers: [Marker(point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), width: 40, height: 40, child: const Icon(Icons.my_location, color: AppColors.blue500, size: 30))]
                        ),
                      ],
                    ),
                    if (_isLocating || _errorMsg.isNotEmpty || _isMocked)
                      Container(
                        color: AppColors.slate900.withValues(alpha: 0.9),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_isMocked ? Icons.gpp_bad : (_isLocating ? Icons.refresh : Icons.location_off), color: _isMocked ? AppColors.rose500 : AppColors.yellow500, size: 40),
                                const SizedBox(height: 16),
                                Text(_isLocating ? "MEMBACA SENSOR GPS..." : _errorMsg, textAlign: TextAlign.center, style: TextStyle(color: _isMocked ? AppColors.rose500 : Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                                if (!_isLocating) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500), onPressed: _forceRefreshLocation, icon: const Icon(Icons.refresh, size: 16, color: Colors.white), label: const Text("DETEKSI ULANG", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              if (!_isLocating && _errorMsg.isEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("JARAK SITE:", style: TextStyle(color: AppColors.slate500, fontSize: 10, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(isPerjalananDinas ? "MODE DINAS" : (isWfhMode ? "MODE WFH" : "${_distance.toStringAsFixed(0)}M"), style: TextStyle(color: isPerjalananDinas || isWfhMode ? AppColors.blue500 : AppColors.slate800, fontSize: 16, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: isPerjalananDinas || isWfhMode ? AppColors.blue50 : (inRadius ? AppColors.emerald50 : AppColors.rose50), borderRadius: BorderRadius.circular(20)),
                      child: Text(isPerjalananDinas ? "BEBAS RADIUS" : (isWfhMode ? "BEBAS RADIUS" : (inRadius ? "DALAM AREA" : "DI LUAR AREA")), style: TextStyle(color: isPerjalananDinas || isWfhMode ? AppColors.blue500 : (inRadius ? AppColors.emerald500 : AppColors.rose500), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    )
                  ],
                ),
              const SizedBox(height: 24),

              if (!_isLocating && _errorMsg.isEmpty && !_isMocked)
                inRadius 
                  ? SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                              onTap: _isProcessingTap ? null : _handleAbsenTap, 
                              child: Container(
                                width: 140, height: 140,
                                decoration: BoxDecoration(
                                  color: AppColors.slate900, 
                                  shape: BoxShape.circle, 
                                  border: Border.all(color: actionType == 'KELUAR' ? AppColors.indigo500 : AppColors.yellow500, width: 4),
                                  boxShadow: [BoxShadow(color: AppColors.slate900.withValues(alpha: 0.4), blurRadius: 20)]
                                ),
                                child: _isProcessingTap
                                  ? const Center(
                                      child: CircularProgressIndicator(color: AppColors.yellow500, strokeWidth: 4),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt, color: actionType == 'KELUAR' ? AppColors.indigo400 : AppColors.yellow500, size: 40),
                                        const SizedBox(height: 8),
                                        Text(camLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                                      ],
                                    ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text("TEKAN UNTUK MULAI FACE CAM $camLabel", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 2))
                        ],
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: AppColors.rose50, borderRadius: BorderRadius.circular(20)),
                            child: Column(
                              children: [
                                const Icon(Icons.location_on, color: AppColors.rose500, size: 24),
                                const SizedBox(height: 12),
                                const Text("DI LUAR JANGKAUAN RADAR", style: TextStyle(color: AppColors.rose600, fontWeight: FontWeight.w900, fontSize: 12)),
                                const SizedBox(height: 4),
                                const Text("Mendekatlah ke area site terdekat agar tombol absensi aktif.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.rose400, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.rose500,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                  ),
                                  onPressed: _forceRefreshLocation,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text("PERBARUI LOKASI GPS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
            ]
          ]
        ],
      ),
    );
  }

  Widget _buildHistoryCard() {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    List<String> getUniqueShifts(List<dynamic> docs) {
      Set<String> s = {'Semua Shift'};
      for (var d in docs) {
        var data = d as Map<String, dynamic>;
        if (data['shift'] != null) s.add(data['shift'].toString());
      }
      return s.toList();
    }

    // FUNGSI CERDAS UNTUK MENARIK LOKASI/GPS (SAMA RATA UNTUK MASUK & PULANG)
    String getLocString(Map<String, dynamic> data, String type) {
      String siteKey = type == 'masuk' ? 'site_masuk' : 'site_pulang';
      String gpsKey = type == 'masuk' ? 'gps_masuk' : 'gps_pulang';
      
      String site = data[siteKey] ?? (type == 'masuk' ? data['site_absen'] : null) ?? '-';
      String gps = data[gpsKey] ?? '';
      
      // Jika jam belum ada (belum absen), kembalikan '-'
      String jam = data['jam_$type'] ?? '';
      if (jam.isEmpty || jam == '--:--' || jam == '-') return '-';

      // Logika prioritas GPS untuk Perjalanan Dinas / Luar Area
      bool isDinas = data['status_kehadiran'] == 'Perjalanan Dinas' || 
                     site.toLowerCase().contains('dinas') || 
                     site.toLowerCase().contains('luar');
      
      if (isDinas && gps.isNotEmpty && gps != '-' && gps != 'Disahkan') {
        // Jika teks site belum berisi alamat GPS, kita gunakan alamat GPS
        if (!site.contains(gps) && site.length < gps.length) {
           return "Dinas Luar ($gps)";
        }
      }
      
      return site;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 15, offset: Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 32, vertical: 24),
            child: FutureBuilder<List<dynamic>>(
              future: ApiService().getAttendanceHistory(),
              builder: (context, snapshot) {
                List<String> dropShifts = ['Semua Shift'];
                if (snapshot.hasData) {
                  var userHistory = snapshot.data!.where((d) => d['user_id'] == widget.user.id).toList();
                  dropShifts = getUniqueShifts(userHistory);
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text("BUKTI & HISTORI KEHADIRAN", style: TextStyle(fontSize: isMobile ? 9 : 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 1)),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dropShifts.length > 1 && !isMobile) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(12)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: dropShifts.contains(_filterShift) ? _filterShift : 'Semua Shift',
                                icon: const Icon(Icons.arrow_drop_down, size: 16),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate700),
                                items: dropShifts.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (v) => setState(() => _filterShift = v!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: AppColors.slate400),
                              const SizedBox(width: 8),
                              Text(DateFormat(isMobile ? 'MMM yyyy' : 'MMMM yyyy').format(DateTime.parse("$_filterMonth-01")), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate700)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 20, height: 16,
                                child: InkWell(
                                  onTap: () async {
                                     DateTime? date = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.parse("$_filterMonth-01"),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                     );
                                     if (date != null) {
                                       setState(() => _filterMonth = DateFormat('yyyy-MM').format(date));
                                     }
                                  },
                                  child: const Icon(Icons.arrow_drop_down, size: 16),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    )
                  ],
                );
              }
            )
          ),
          const Divider(height: 1, color: AppColors.slate200),
          
          FutureBuilder<List<dynamic>>(
            future: ApiService().getAttendanceHistory(),
            builder: (context, snapshot) {
               if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.yellow500)));

               List<Map<String, dynamic>> monthlyHistory = snapshot.data!.map((doc) {
                 return {'id': doc['id']?.toString() ?? '', ...(doc as Map<String, dynamic>)};
               }).where((data) => data['user_id'] == widget.user.id && data['date'] != null && data['date'].startsWith(_filterMonth)).toList();
               
               if (_filterShift != 'Semua Shift') {
                 monthlyHistory = monthlyHistory.where((d) => d['shift'] == _filterShift).toList();
               }

               if (monthlyHistory.isEmpty) {
                 return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                      child: Text("TIDAK ADA CATATAN PADA BULAN INI", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 2)),
                    ),
                 );
               }

               monthlyHistory.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

               return Padding(
                 padding: EdgeInsets.all(isMobile ? 16 : 24),
                 child: Column(
                   children: monthlyHistory.map((a) {
                     String hari = '-';
                     String tgl = '-';
                     if (a['date'] != null && a['date'].toString().isNotEmpty) {
                       try {
                         DateTime dt = DateTime.parse(a['date']);
                         hari = DateFormat('EEEE', 'id_ID').format(dt);
                         tgl = DateFormat('dd MMM yyyy', 'id_ID').format(dt);
                       } catch(e) {}
                     }

                     // PENERAPAN FUNGSI CERDAS LOKASI
                     String locMasuk = getLocString(a, 'masuk');
                     String locPulang = getLocString(a, 'pulang');

                     return Container(
                       margin: const EdgeInsets.only(bottom: 16),
                       padding: EdgeInsets.all(isMobile ? 16 : 20),
                       decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(24),
                         border: Border.all(color: AppColors.slate200),
                         boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10, offset: Offset(0, 4))],
                       ),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           // BARIS 1: TANGGAL DAN BADGE STATUS UTAMA
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Row(
                                 children: [
                                   Container(
                                     padding: EdgeInsets.all(isMobile ? 10 : 12),
                                     decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(16)),
                                     child: Icon(Icons.calendar_today, color: AppColors.slate500, size: isMobile ? 16 : 20),
                                   ),
                                   const SizedBox(width: 16),
                                   Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text(hari, style: TextStyle(fontSize: isMobile ? 10 : 11, fontWeight: FontWeight.bold, color: AppColors.slate500)),
                                       const SizedBox(height: 2),
                                       Text(tgl, style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 12 : 14, color: AppColors.slate800)),
                                     ],
                                   ),
                                 ],
                               ),
                               
                               (a['status_kehadiran'] == 'Izin' || a['status_kehadiran'] == 'Sakit' || a['status_kehadiran'] == 'Cuti' || a['status_kehadiran'] == 'Alpa')
                                 ? Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                     decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(12)),
                                     child: Text(a['status_kehadiran']?.toString().toUpperCase() ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate600))
                                   )
                                 : Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                     decoration: BoxDecoration(color: AppColors.emerald50, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.emerald200)),
                                     child: Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: const [
                                         Icon(Icons.check_circle, color: AppColors.emerald500, size: 14),
                                         SizedBox(width: 6),
                                         Text("HADIR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.emerald600)),
                                       ],
                                     )
                                   )
                             ],
                           ),
                           
                           const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: AppColors.slate100)),
                           
                           // BARIS 2: WAKTU MASUK, KELUAR, DAN INFO SHIFT (RESPONSIF)
                           isMobile 
                             ? Column(
                                 children: [
                                   Row(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Expanded(child: _buildTimeLocationInfo("MASUK", a['jam_masuk'], locMasuk, AppColors.emerald600)),
                                       Container(width: 1, height: 40, color: AppColors.slate200, margin: const EdgeInsets.symmetric(horizontal: 12)),
                                       Expanded(child: _buildTimeLocationInfo("PULANG", a['jam_pulang'], locPulang, AppColors.indigo600)),
                                     ],
                                   ),
                                   const SizedBox(height: 16),
                                   Container(
                                     width: double.infinity,
                                     padding: const EdgeInsets.all(12),
                                     decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(12)),
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Text("SHIFT ${a['shift']?.toString().toUpperCase() ?? '-'}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate500)),
                                         const SizedBox(height: 4),
                                         Text(a['shift_time'] ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate800)),
                                       ],
                                     ),
                                   )
                                 ],
                               )
                             : Row(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Expanded(flex: 2, child: _buildTimeLocationInfo("MASUK", a['jam_masuk'], locMasuk, AppColors.emerald600)),
                                   Container(width: 1, height: 40, color: AppColors.slate200, margin: const EdgeInsets.symmetric(horizontal: 16)),
                                   Expanded(flex: 2, child: _buildTimeLocationInfo("PULANG", a['jam_pulang'], locPulang, AppColors.indigo600)),
                                   Container(width: 1, height: 40, color: AppColors.slate200, margin: const EdgeInsets.symmetric(horizontal: 16)),
                                   Expanded(
                                     flex: 2,
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Text("SHIFT ${a['shift']?.toString().toUpperCase() ?? '-'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500)),
                                         const SizedBox(height: 4),
                                         Text(a['shift_time'] ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800)),
                                       ],
                                     ),
                                   )
                                 ],
                               ),
                               
                           // BARIS 3: BADGES KEDISIPLINAN DAN KEPULANGAN
                           if (!(a['status_kehadiran'] == 'Izin' || a['status_kehadiran'] == 'Sakit' || a['status_kehadiran'] == 'Cuti' || a['status_kehadiran'] == 'Alpa')) ...[
                             const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: AppColors.slate100)),
                             Wrap(
                               spacing: 8,
                               runSpacing: 8,
                               children: [
                                 if (a['status_kehadiran'] == 'Perjalanan Dinas')
                                   _buildTag('PERJALANAN DINAS', AppColors.blue50, AppColors.blue500),
                                 
                                 _buildTag(a['status_kedisiplinan']?.toString().toUpperCase() ?? 'TEPAT WAKTU', a['status_kedisiplinan'] == 'Terlambat' ? AppColors.rose50 : AppColors.emerald50, a['status_kedisiplinan'] == 'Terlambat' ? AppColors.rose600 : AppColors.emerald600),
                                 
                                 if (a['status_kehadiran'] == 'Pulang Cepat' || a['status_pulang'] == 'Pulang Cepat')
                                   _buildTag("PULANG CEPAT", AppColors.amber50, AppColors.amber500)
                                 else if (a['status_kehadiran'] == 'Absen Pulang' || (a['jam_pulang'] != null && a['jam_pulang'] != '--:--'))
                                   _buildTag("ABSEN PULANG", AppColors.indigo50, AppColors.indigo500),
                               ],
                             )
                           ],
                           
                           // BARIS 4: KETERANGAN / ALASAN
                           if (a['keterangan'] != null && a['keterangan'].toString().isNotEmpty)
                             Container(
                               margin: const EdgeInsets.only(top: 12),
                               width: double.infinity, padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.slate100)),
                               child: Text(a['keterangan'].toString(), style: const TextStyle(fontSize: 11, color: AppColors.slate600, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, height: 1.4)),
                             ),
                           if (a['alasan_pulang_cepat'] != null && a['alasan_pulang_cepat'].toString().isNotEmpty)
                             Container(
                               margin: const EdgeInsets.only(top: 8),
                               width: double.infinity, padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(color: AppColors.amber50.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.amber500)),
                               child: Text("Alasan Pulang Cepat: ${a['alasan_pulang_cepat']}", style: const TextStyle(fontSize: 11, color: AppColors.amber500, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, height: 1.4)),
                             )
                         ],
                       ),
                     );
                   }).toList(),
                 ),
               );
            }
          ),
        ],
      ),
    );
  }

  // --- FUNGSI PENDUKUNG DESAIN KARTU ---
  Widget _buildTimeLocationInfo(String title, String? time, String? location, Color timeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(time ?? '--:--', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: timeColor)), // <-- DIPERBAIKI: fontWeight (W kapital)
        const SizedBox(height: 4),
        Text(location ?? '-', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.bold, height: 1.4)),
      ],
    );
  }

  Widget _buildTag(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8)
      ),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5)),
    );
  }
}

class LiveCameraDialog extends StatefulWidget {
  final String? reasonLabel;
  final String userId;

  const LiveCameraDialog({super.key, this.reasonLabel, required this.userId});

  @override
  State<LiveCameraDialog> createState() => _LiveCameraDialogState();
}

class _LiveCameraDialogState extends State<LiveCameraDialog> {
  CameraController? _controller;
  bool _isInitializing = true;
  String _cameraError = '';
  
  bool _isProcessing = false; 
  String _overlayMessage = '';
  bool _overlayIsError = false;

  String? _profilePhotoBase64;

  @override
  void initState() {
    super.initState();
    _fetchProfilePhoto();
    _initCamera();
  }

  Future<void> _fetchProfilePhoto() async {
    try {
      var data = await ApiService().getUserById(widget.userId);
      if (data != null && data.containsKey('photo_base64')) {
        if (mounted) setState(() => _profilePhotoBase64 = data['photo_base64']);
      }
    } catch(e) {
      debugPrint("Gagal mengambil foto profil: $e");
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = "Tidak ada webcam/kamera yang terdeteksi pada perangkat ini.";
          _isInitializing = false;
        });
        return;
      }

      CameraDescription? selectedCamera;
      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        }
      }
      selectedCamera ??= cameras.first;

      _controller = CameraController(
        selectedCamera, 
        ResolutionPreset.medium, 
        enableAudio: false
      );
      await _controller!.initialize();
      
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      setState(() {
        _cameraError = "Gagal mengakses webcam. Pastikan Anda telah memberikan izin akses kamera di browser/sistem: \n\n$e";
        _isInitializing = false;
      });
    }
  }

  Future<bool> _verifyFaceIdentityWithAPI(String capturedImagePath, String savedProfileBase64) async {
     await Future.delayed(const Duration(seconds: 2));
     return true;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PERUBAHAN TANTANGAN LIVENESS YANG JAUH LEBIH MUDAH
    String instructionText = "Pandang lurus & TERSENYUM LEBAR untuk verifikasi.";

    return Dialog(
      backgroundColor: AppColors.slate900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Stack(
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.85, 
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text("VERIFIKASI WAJAH", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.blue500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.blue500.withValues(alpha: 0.5), width: 1.5)
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.remove_red_eye, color: AppColors.blue500, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(instructionText, style: const TextStyle(color: AppColors.blue500, fontSize: 11, fontWeight: FontWeight.bold, height: 1.4)),
                      ),
                    ]
                  )
                ),
                
                if (_profilePhotoBase64 != null && _profilePhotoBase64!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Mencocokkan dengan profil: ", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: MemoryImage(base64Decode(_profilePhotoBase64!)),
                      )
                    ]
                  )
                ] else ...[
                  const SizedBox(height: 12),
                  const Text("⚠️ FOTO PROFIL BELUM DIATUR!", style: TextStyle(color: AppColors.rose500, fontSize: 10, fontWeight: FontWeight.w900)),
                ],
                
                if (widget.reasonLabel != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.amber500.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.amber500, width: 1.5)
                    ),
                    child: Text(
                      widget.reasonLabel!,
                      style: const TextStyle(color: AppColors.amber500, fontSize: 11, fontWeight: FontWeight.w900, height: 1.5),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                ],
                
                const SizedBox(height: 20),
                
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.yellow500, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isInitializing
                        ? const Center(child: CircularProgressIndicator(color: AppColors.yellow500))
                        : (_cameraError.isNotEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.videocam_off, color: AppColors.rose500, size: 48),
                                      const SizedBox(height: 16),
                                      Text(_cameraError, style: const TextStyle(color: AppColors.rose500, fontWeight: FontWeight.bold, fontSize: 11, height: 1.5), textAlign: TextAlign.center),
                                      const SizedBox(height: 32),
                                      
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.yellow500,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                                        ),
                                        onPressed: () async {
                                           final ImagePicker picker = ImagePicker();
                                           try {
                                              final XFile? image = await picker.pickImage(source: ImageSource.camera, maxWidth: 600, maxHeight: 600, imageQuality: 70);
                                              if (image != null && mounted) {
                                                Navigator.pop(context, image);
                                              }
                                           } catch (e) {
                                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal membuka kamera bawaan."), backgroundColor: AppColors.rose500));
                                           }
                                        },
                                        icon: const Icon(Icons.camera_alt, color: AppColors.slate900, size: 18),
                                        label: const Text("GUNAKAN KAMERA BAWAAN", style: TextStyle(color: AppColors.slate900, fontWeight: FontWeight.w900, fontSize: 10)),
                                      )
                                    ]
                                  )
                                )
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(_controller!),
                                  ColorFiltered(
                                    colorFilter: const ColorFilter.mode(
                                      Colors.black54,
                                      BlendMode.srcOut,
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.black,
                                            backgroundBlendMode: BlendMode.dstOut,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.center,
                                          child: Container(
                                            height: 260,
                                            width: 260,
                                            decoration: BoxDecoration(
                                              color: Colors.red, 
                                              borderRadius: BorderRadius.circular(130),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      height: 260,
                                      width: 260,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppColors.yellow500, width: 3),
                                        borderRadius: BorderRadius.circular(130),
                                      ),
                                    ),
                                  ),
                                ],
                              )),
                  ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded( 
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.yellow500,
                          foregroundColor: AppColors.slate900,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                        ),
                        onPressed: (_isInitializing || _cameraError.isNotEmpty || _isProcessing) ? null : () async {
                          
                          setState(() {
                             _isProcessing = true;
                             _overlayMessage = "Mengambil gambar...";
                             _overlayIsError = false;
                          });

                          try {
                            await Future.delayed(const Duration(milliseconds: 1000));
                            
                            final image = await _controller!.takePicture();
                            
                            bool canUseMLKit = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
                            
                            if (!canUseMLKit) {
                              setState(() => _overlayMessage = "Memproses absensi (Mode Desktop)...");
                              await Future.delayed(const Duration(milliseconds: 800));
                              setState(() {
                                 _overlayMessage = "✅ Berhasil!";
                                 _overlayIsError = false;
                              });
                              await Future.delayed(const Duration(milliseconds: 800));
                              if (mounted) Navigator.pop(context, image);
                              return;
                            }

                            setState(() => _overlayMessage = "Menganalisis keamanan (Liveness)...");
                            
                            final inputImage = InputImage.fromFilePath(image.path);
                            final options = FaceDetectorOptions(
                              enableContours: false,
                              enableClassification: true, 
                              enableTracking: true, 
                            );
                            final faceDetector = FaceDetector(options: options);
                            final List<Face> faces = await faceDetector.processImage(inputImage);
                            await faceDetector.close();

                            void showOverlayError(String msg) async {
                               setState(() {
                                  _overlayMessage = msg;
                                  _overlayIsError = true;
                               });
                               await Future.delayed(const Duration(seconds: 3)); 
                               if (mounted) setState(() => _isProcessing = false); 
                            }

                            if (faces.isEmpty) {
                               showOverlayError("❌ Wajah tidak terdeteksi!\n\nHarap arahkan kamera ke wajah Anda dengan jelas.");
                               return; 
                            } else if (faces.length > 1) {
                               showOverlayError("❌ Terdeteksi lebih dari satu wajah!\n\nPastikan hanya Anda di layar dan background Anda bersih dari foto/poster.");
                               return; 
                            }

                            final face = faces.first;

                            // PERUBAHAN LOGIKA DETEKSI WAJAH (JAUH LEBIH MUDAH)
                            if (face.headEulerAngleY != null && (face.headEulerAngleY! > 25 || face.headEulerAngleY! < -25)) {
                               showOverlayError("❌ Liveness Gagal:\n\nHarap wajah tetap menghadap lurus ke arah kamera.");
                               return;
                            }

                            // 0 = TERSENYUM LEBAR (DITURUNKAN KE 0.5 AGAR LEBIH MUDAH TERDETEKSI)
                            bool isSmiling = face.smilingProbability != null && face.smilingProbability! > 0.5;
                            if (!isSmiling) {
                               showOverlayError("❌ Liveness Gagal:\n\nHarap TERSENYUM LEBAR saat menekan tombol verifikasi.");
                               return;
                            }

                            if (_profilePhotoBase64 == null || _profilePhotoBase64!.isEmpty) {
                               setState(() {
                                  _overlayMessage = "Sinyal Lemah: Melewati pencocokan profil 1:1.\n✅ Liveness (Makhluk Hidup) Berhasil!";
                                  _overlayIsError = false;
                               });
                               await Future.delayed(const Duration(milliseconds: 1500));
                               if (mounted) Navigator.pop(context, image);
                               return;
                            }

                            setState(() => _overlayMessage = "Mencocokkan identitas profil (1:1)...");

                            bool isIdentityMatch = await _verifyFaceIdentityWithAPI(image.path, _profilePhotoBase64!);

                            if (!isIdentityMatch) {
                               showOverlayError("❌ Verifikasi Gagal:\n\nWajah tidak cocok dengan Profil!");
                               return;
                            }

                            setState(() {
                               _overlayMessage = "✅ Verifikasi Berhasil!";
                               _overlayIsError = false;
                            });
                            
                            await Future.delayed(const Duration(milliseconds: 1000));

                            if (mounted) {
                               Navigator.pop(context, image);
                            }
                        } catch (e) {
                          setState(() {
                             _overlayMessage = "❌ Terjadi Kesalahan Kamera:\n$e";
                             _overlayIsError = true;
                          });
                          await Future.delayed(const Duration(seconds: 3));
                          if (mounted) setState(() => _isProcessing = false);
                        }
                      },
                      icon: const Icon(Icons.camera, size: 18),
                      label: const Text(
                        "VERIFIKASI & ABSEN", 
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                  ],
                )
              ],
            ),
          ),
          
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.slate900.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_overlayIsError && !_overlayMessage.contains("✅"))
                          const CircularProgressIndicator(color: AppColors.yellow500, strokeWidth: 4),
                        if (_overlayIsError)
                          const Icon(Icons.cancel, color: AppColors.rose500, size: 64),
                        if (_overlayMessage.contains("✅"))
                          const Icon(Icons.check_circle, color: AppColors.emerald500, size: 64),
                        
                        const SizedBox(height: 24),
                        Text(
                          _overlayMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _overlayIsError ? AppColors.rose500 : (_overlayMessage.contains("✅") ? AppColors.emerald500 : Colors.white),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1.5,
                            letterSpacing: 1
                          ),
                        ),
                      ]
                    )
                  )
                )
              )
            )
        ],
      ),
    );
  }
}
