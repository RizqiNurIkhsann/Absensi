import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/app_constants.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import 'admin_config_view.dart';

class SettingsView extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;
  final Function(String) onChangeView;

  const SettingsView({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onChangeView,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _activeSetting = 'menu'; // 'menu', 'shift', 'departemen', 'devices', 'profile', 'notifikasi'
  
  // PERUBAHAN: Dibuat nullable agar kosong secara default
  String? _selectedShiftArea; 
  
  String _deviceFilterArea = 'Semua Area'; 

  late Future<Map<String, dynamic>?> _configFuture;
  late Future<List<dynamic>> _usersFuture;
  
  Map<String, dynamic>? _cachedConfigData;
  List<dynamic>? _cachedUsersData;
  DateTime? _lastOptimisticUpdate;
  
  bool _isEditMode = false;
  bool _isSaving = false;
  
  // Controller untuk Profil
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _kontakController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  String? _photoBase64;
  
  // Controller untuk Shift
  final TextEditingController _shiftNameController = TextEditingController();
  TimeOfDay? _shiftStart;
  TimeOfDay? _shiftEnd;

  // Controller untuk Departemen & Jabatan
  final TextEditingController _deptController = TextEditingController();
  final TextEditingController _jabatanController = TextEditingController();

  List<String> _availableAreas = ['Semua Area'];

  // --- STATE NOTIFIKASI ---
  bool _notifEnabled = true;
  int _notifSound = 1;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    
    _loadData();
        
    _fetchProfileData();
    _fetchConfigAreas();
    _loadNotifSettings(); // Memuat pengaturan notifikasi
  }

  void _loadData() {
    setState(() {
      _configFuture = ApiService().getConfigSite();
      _usersFuture = ApiService().getUsers();
    });
    
    _configFuture.then((data) {
      if (mounted && data != null) {
        setState(() {
          _cachedConfigData = data;
        });
      }
    });
    
    _usersFuture.then((data) {
      if (mounted) {
        setState(() {
          _cachedUsersData = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _kontakController.dispose();
    _alamatController.dispose();
    _passController.dispose();
    _shiftNameController.dispose();
    _deptController.dispose();
    _jabatanController.dispose();
    _audioPlayer.dispose(); // Bebaskan memori audio player
    super.dispose();
  }

  // ==========================================
  // LOGIKA PENGATURAN NOTIFIKASI & PREVIEW AUDIO
  // ==========================================
  
  Future<void> _loadNotifSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifEnabled = prefs.getBool('notif_enabled_${widget.user.id}') ?? true;
      _notifSound = prefs.getInt('notif_sound_${widget.user.id}') ?? 1;
    });
  }

  Future<void> _saveNotifSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled_${widget.user.id}', _notifEnabled);
    await prefs.setInt('notif_sound_${widget.user.id}', _notifSound);
  }

  // Fungsi untuk memutar preview suara notifikasi
  void _previewSound(int soundNum) async {
    String fileName = soundNum == 1 ? 'notif_1.mp3' : 'notif_2.mp3';
    
    try {
      await _audioPlayer.stop(); 
      await _audioPlayer.setVolume(1.0); 
      
      // PERBAIKAN: Penanganan khusus path audio untuk platform Web (localhost Chrome)
      if (kIsWeb) {
        // Di Flutter Web, file asset dibungkus di dalam path URL /assets/
        // Jika folder Anda bernama "Assets" (huruf besar), gunakan baris ini:
        await _audioPlayer.play(UrlSource('assets/Assets/audio/$fileName'));
        
        // Catatan: Jika nama folder Anda "assets" (huruf kecil), jadikan komentar baris di atas
        // dan gunakan baris di bawah ini:
        // await _audioPlayer.play(UrlSource('assets/audio/$fileName'));
      } else {
        // Untuk platform Mobile (Android / iOS)
        await _audioPlayer.play(AssetSource('audio/$fileName'));
      }
    } catch (e) {
      debugPrint("Gagal memutar audio preview: $e");
    }
  }

  // ==========================================

  Future<void> _forceFetchConfig() async {
    try {
      var data = await ApiService().getConfigSite();
      if (data != null && mounted) {
        setState(() {
          _cachedConfigData = data;
        });
      }
    } catch (e) {
      debugPrint("Gagal force fetch config: $e");
    }
  }

  Future<void> _fetchConfigAreas() async {
    try {
      var data = await ApiService().getConfigSite();
          
      if (data != null) {
        List<dynamic> locs = data['locations'] ?? [];
        if (mounted) {
          setState(() {
            if (locs.isNotEmpty) {
              List<String> sortedAreas = locs.map((e) => e['siteName'].toString()).toList();
              sortedAreas.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              _availableAreas = ['Semua Area', ...sortedAreas];
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal load area config: $e");
    }
  }

  Future<void> _fetchProfileData() async {
    if (widget.user.role == 'admin') return;
    
    try {
      var data = await ApiService().getUserById(widget.user.id);
          
      if (data != null && mounted) {
        setState(() {
          _namaController.text = data['nama_lengkap'] ?? widget.user.namaLengkap;
          _emailController.text = data['email'] ?? '';
          _kontakController.text = data['kontak'] ?? '';
          _alamatController.text = data['alamat'] ?? '';
          _passController.text = data['password'] ?? '';
          _photoBase64 = data['photo_base64'];
        });
      }
    } catch(e) {
      debugPrint("Gagal fetch profile: $e");
    }
  }

  // --- ADMIN SETTINGS FUNCTIONS ---
  Future<void> _addShift() async {
    if (_shiftNameController.text.trim().isEmpty || _shiftStart == null || _shiftEnd == null || _selectedShiftArea == null) return;

    String startStr = '${_shiftStart!.hour.toString().padLeft(2, '0')}:${_shiftStart!.minute.toString().padLeft(2, '0')}';
    String endStr = '${_shiftEnd!.hour.toString().padLeft(2, '0')}:${_shiftEnd!.minute.toString().padLeft(2, '0')}';

    try {
      var currentShifts = List<dynamic>.from(_cachedConfigData?['shifts'] ?? []);
      currentShifts.add({
          'id': 'shift-${DateTime.now().millisecondsSinceEpoch}',
          'name': _shiftNameController.text.trim(),
          'start': startStr,
          'end': endStr,
          'area': _selectedShiftArea,
      });
      
      await ApiService().updateConfigSite({'shifts': currentShifts});
      
      _shiftNameController.clear();
      setState(() { _shiftStart = null; _shiftEnd = null; });
      _forceFetchConfig();
    } catch (e) {
      debugPrint("Gagal tambah shift: $e");
    }
  }

  Future<void> _removeShift(Map<String, dynamic> shift) async {
    try {
      var currentShifts = List<dynamic>.from(_cachedConfigData?['shifts'] ?? []);
      currentShifts.removeWhere((s) => s['id'] == shift['id']);
      await ApiService().updateConfigSite({'shifts': currentShifts});
      _forceFetchConfig();
    } catch (e) {
      debugPrint("Gagal hapus shift: $e");
    }
  }

  Future<void> _addStruktur() async {
    if (_deptController.text.trim().isEmpty || _jabatanController.text.trim().isEmpty) return;

    try {
      var currentStruktur = List<dynamic>.from(_cachedConfigData?['struktur_organisasi'] ?? []);
      currentStruktur.add({
          'departemen': _deptController.text.trim(),
          'jabatan': _jabatanController.text.trim(),
      });
      await ApiService().updateConfigSite({'struktur_organisasi': currentStruktur});
      
      _jabatanController.clear(); 
      _forceFetchConfig();
    } catch (e) {
      debugPrint("Gagal tambah struktur: $e");
    }
  }

  Future<void> _removeStruktur(Map<String, dynamic> struktur) async {
    try {
      var currentStruktur = List<dynamic>.from(_cachedConfigData?['struktur_organisasi'] ?? []);
      currentStruktur.removeWhere((s) => s['departemen'] == struktur['departemen'] && s['jabatan'] == struktur['jabatan']);
      await ApiService().updateConfigSite({'struktur_organisasi': currentStruktur});
      _forceFetchConfig();
    } catch (e) {
      debugPrint("Gagal hapus struktur: $e");
    }
  }

  Future<void> _resetDeviceUser(String userId, String deviceType) async {
    try {
      String updateField = deviceType == 'mobile' ? 'mobileDeviceId' : 'desktopDeviceId';
      await ApiService().updateUser(userId, {updateField: ''});
      _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Perangkat $deviceType berhasil di-reset untuk pengguna ini."), backgroundColor: AppColors.emerald500));
    } catch (e) {
      debugPrint("Gagal reset device: $e");
    }
  }

  void _showDevDialog(String title) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.construction, color: AppColors.yellow500),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.slate800))),
          ],
        ),
        content: const Text(
          "Fitur ini masih dalam tahap pengembangan dan akan segera tersedia pada pembaruan sistem mendatang.",
          style: TextStyle(color: AppColors.slate600, fontWeight: FontWeight.bold, height: 1.5)
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.slate900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: () => Navigator.pop(c),
            child: const Text("Mengerti", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: _buildCurrentView(),
      ),
    );
  }

  Widget _buildCurrentView() {
    if (_activeSetting == 'profile') return _buildProfileView();
    if (_activeSetting == 'notifikasi') return _buildNotificationView(); // Tampilan Pengaturan Notifikasi
    
    if (widget.user.role != 'admin') {
      return _buildRegularProfile();
    }

    if (_activeSetting == 'menu') return _buildMainMenu();
    if (_activeSetting == 'shift') return _buildShiftView();
    if (_activeSetting == 'departemen') return _buildDepartemenView();
    if (_activeSetting == 'devices') return _buildManageDevicesView();
    
    return _buildMainMenu();
  }

  Widget _buildRegularProfile() {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return FutureBuilder<Map<String, dynamic>?>(
      future: ApiService().getUserById(widget.user.id),
      builder: (context, snapshot) {
        String name = widget.user.namaLengkap;
        String nik = widget.user.nik;
        String role = widget.user.role;
        String? photoBase64;
        bool isProfileComplete = true;

        if (snapshot.hasData && snapshot.data != null) {
          var data = snapshot.data!;
          name = data['nama_lengkap'] ?? name;
          nik = data['nik'] ?? nik;
          role = data['role'] ?? role;
          photoBase64 = data['photo_base64'];

          String kontak = data['kontak'] ?? '-';
          String alamat = data['alamat'] ?? '-';
          String tglLahir = data['tanggal_lahir'] ?? '';
          String photo = data['photo_base64'] ?? '';
          String email = data['email'] ?? '';
          
          if (kontak == '-' || kontak.isEmpty || alamat == '-' || alamat.isEmpty || tglLahir.isEmpty || photo.isEmpty || email.isEmpty) {
              isProfileComplete = false;
          }
        } else {
          isProfileComplete = false;
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("PENGATURAN AKUN", style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: -0.5)),
              SizedBox(height: isMobile ? 24 : 32),

              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: AppColors.slate100)),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.yellow500, 
                      radius: isMobile ? 24 : 32, 
                      backgroundImage: photoBase64 != null && photoBase64.isNotEmpty ? MemoryImage(base64Decode(photoBase64)) : null,
                      child: photoBase64 == null || photoBase64.isEmpty 
                        ? Text(name.isNotEmpty ? name[0] : 'U', style: TextStyle(color: AppColors.slate900, fontWeight: FontWeight.w900, fontSize: isMobile ? 20 : 24))
                        : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.toUpperCase(), style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w900, color: AppColors.slate800)),
                          const SizedBox(height: 4),
                          Text(nik, style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.yellow500, borderRadius: BorderRadius.circular(8)),
                            child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.slate900)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildMenuItem(
                icon: Icons.person, 
                title: "Profil Saya", 
                subtitle: "Lihat dan edit informasi profil Anda", 
                showBadge: !isProfileComplete, 
                onTap: () => setState(() => _activeSetting = 'profile')
              ),
              
              // --- MENU NOTIFIKASI BARU ---
              _buildMenuItem(
                icon: Icons.notifications, 
                title: "Notifikasi", 
                subtitle: "Atur preferensi notifikasi dan nada dering", 
                onTap: () => setState(() => _activeSetting = 'notifikasi')
              ),
              
              _buildMenuItem(icon: Icons.lock_outline, title: "Ganti Password", subtitle: "Perbarui kata sandi akun Anda", onTap: () => _showChangePasswordDialog()),
              
              _buildMenuItem(icon: Icons.help, title: "Bantuan & Support", subtitle: "Pusat bantuan dan kontak CS", onTap: () => widget.onChangeView('help')),
              _buildMenuItem(
                icon: Icons.logout, title: "Keluar", subtitle: "Keluar dari aplikasi", isDestructive: true,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: const Text("Konfirmasi Keluar", style: TextStyle(fontWeight: FontWeight.w900)), 
                      content: const Text("Apakah Anda yakin ingin keluar dari aplikasi?", style: TextStyle(fontWeight: FontWeight.bold)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal", style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.bold))), 
                        ElevatedButton(
                          onPressed: () { Navigator.pop(context); widget.onLogout(); }, 
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
                          child: const Text("Keluar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        )
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }
    );
  }

  // ==========================================
  // TAMPILAN PENGATURAN NOTIFIKASI
  // ==========================================
  Widget _buildNotificationView() {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBack("PENGATURAN NOTIFIKASI"),
          SizedBox(height: isMobile ? 24 : 32),

          Container(
            padding: EdgeInsets.all(isMobile ? 24 : 40),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(32), 
              border: Border.all(color: AppColors.slate100)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Notifikasi Jam Pulang", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate800)),
                          SizedBox(height: 4),
                          Text("Tampilkan pop-up dan mainkan suara pengingat saat waktu shift kerja Anda telah habis.", style: TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.bold, height: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Switch(
                      value: _notifEnabled,
                      activeThumbColor: AppColors.yellow500,
                      activeTrackColor: AppColors.slate900,
                      inactiveThumbColor: AppColors.slate400,
                      onChanged: (val) {
                        setState(() => _notifEnabled = val);
                        _saveNotifSettings();
                      },
                    )
                  ],
                ),
                
                if (_notifEnabled) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(height: 1, color: AppColors.slate100),
                  ),
                  const Text("PILIH NADA DERING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
                  const SizedBox(height: 16),
                  
                  _buildSoundOption(1, "Nada Dering 1 (Standar)"),
                  const SizedBox(height: 12),
                  _buildSoundOption(2, "Nada Dering 2 (Singkat)"),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }

  // Komponen Pilihan Suara
  Widget _buildSoundOption(int value, String title) {
    bool isSelected = _notifSound == value;
    return InkWell(
      onTap: () {
        setState(() => _notifSound = value);
        _previewSound(value); // Memutar preview suara saat dipilih
        _saveNotifSettings();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.yellow50 : Colors.white,
          border: Border.all(color: isSelected ? AppColors.yellow500 : AppColors.slate200),
          borderRadius: BorderRadius.circular(16)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.music_note, color: isSelected ? AppColors.yellow500 : AppColors.slate400, size: 20),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: isSelected ? AppColors.slate800 : AppColors.slate600, fontSize: 13)),
              ],
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.yellow500, size: 20)
            else
              const Icon(Icons.circle_outlined, color: AppColors.slate300, size: 20)
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    String currentPass = '';
    String newPass = '';
    String confirmPass = '';
    bool isSubmitting = false;
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submitPassword() async {
              if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Semua kolom password harus diisi!"), backgroundColor: AppColors.rose500));
                return;
              }

              if (newPass != confirmPass) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password Baru dan Konfirmasi Password tidak cocok!"), backgroundColor: AppColors.rose500));
                return;
              }

              // Validasi Kekuatan Password
              bool hasMinLength = newPass.length >= 8;
              bool hasUppercase = newPass.contains(RegExp(r'[A-Z]'));
              bool hasLowercase = newPass.contains(RegExp(r'[a-z]'));
              bool hasDigits = newPass.contains(RegExp(r'[0-9]'));
              bool hasSpecialCharacters = newPass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

              if (!hasMinLength || !hasUppercase || !hasLowercase || !hasDigits || !hasSpecialCharacters) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Password tidak memenuhi syarat keamanan!"), 
                  backgroundColor: AppColors.rose500
                ));
                return;
              }

              setDialogState(() => isSubmitting = true);
              try {
                await ApiService().updateUser(widget.user.id, {
                  'password': newPass,
                });
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password berhasil diperbarui!"), backgroundColor: AppColors.emerald500));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal memperbarui password."), backgroundColor: AppColors.rose500));
                }
              } finally {
                 if (mounted) setDialogState(() => isSubmitting = false);
              }
            }

            Widget _buildRowInput(String label, ValueChanged<String> onChanged, {bool isObscure = false}) {
               return Padding(
                 padding: const EdgeInsets.only(bottom: 16),
                 child: Row(
                   crossAxisAlignment: CrossAxisAlignment.center,
                   children: [
                     Expanded(
                       flex: 2,
                       child: Text(label, style: const TextStyle(color: AppColors.slate700, fontSize: 11, fontWeight: FontWeight.w900))
                     ),
                     const SizedBox(width: 12),
                     Expanded(
                       flex: 4,
                       child: SizedBox(
                         height: 44,
                         child: TextField(
                           obscureText: isObscure ? !showPassword : false,
                           onChanged: onChanged,
                           style: const TextStyle(fontSize: 13, color: AppColors.slate900, fontWeight: FontWeight.bold),
                           decoration: InputDecoration(
                             filled: true,
                             fillColor: AppColors.slate50,
                             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slate200)),
                             enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slate200)),
                             focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
                           ),
                         ),
                       )
                     )
                   ]
                 ),
               );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                width: 450,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.slate200)
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Dialog (UT Theme)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      color: AppColors.slate900,
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.lock_reset, color: AppColors.yellow500, size: 24),
                          SizedBox(width: 12),
                          Text("GANTI PASSWORD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                        ],
                      ),
                    ),
                    
                    // Body Dialog
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRowInput("Password Lama", (v) => currentPass = v, isObscure: true),
                          _buildRowInput("Password Baru", (v) => newPass = v, isObscure: true),
                          _buildRowInput("Konfirmasi Password", (v) => confirmPass = v, isObscure: true),
                          
                          const SizedBox(height: 8),
                          const Text(
                            "*catatan : Password minimal harus 8 Karakter dan mengandung Huruf Besar, Huruf Kecil, Karakter Khusus dan Angka!",
                            style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.slate500, height: 1.5, fontWeight: FontWeight.bold),
                          ),
                          
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              SizedBox(
                                width: 20, height: 20,
                                child: Checkbox(
                                  value: showPassword,
                                  activeColor: AppColors.yellow500,
                                  checkColor: AppColors.slate900,
                                  side: const BorderSide(color: AppColors.slate300),
                                  onChanged: (val) {
                                    setDialogState(() => showPassword = val ?? false);
                                  }
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text("Show Password", style: TextStyle(color: AppColors.slate700, fontSize: 11, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.slate100,
                                    foregroundColor: AppColors.slate700,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("BATAL", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                                )
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.yellow500,
                                    foregroundColor: AppColors.slate900,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                  ),
                                  onPressed: isSubmitting ? null : submitPassword,
                                  child: isSubmitting 
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.slate900, strokeWidth: 2))
                                    : const Text("SIMPAN", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                                )
                              )
                            ]
                          )
                        ],
                      )
                    )
                  ],
                ),
              )
            );
          },
        );
      }
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool isDestructive = false, bool showBadge = false}) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(border: Border.all(color: AppColors.slate100), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDestructive ? AppColors.rose50 : AppColors.slate50, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: isDestructive ? AppColors.rose500 : AppColors.slate600, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title, style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.w900, color: isDestructive ? AppColors.rose500 : AppColors.slate800)),
                          // INDIKATOR MERAH DI SAMPING TULISAN
                          if (showBadge) ...[
                            const SizedBox(width: 8),
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.rose500, shape: BoxShape.circle)),
                          ]
                        ],
                      ), 
                      const SizedBox(height: 2), 
                      Text(subtitle, style: TextStyle(fontSize: isMobile ? 10 : 11, color: AppColors.slate400, fontWeight: FontWeight.bold))
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.slate300, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainMenu() {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PENGATURAN SISTEM", style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.w900, color: AppColors.slate900, letterSpacing: -0.5)),
          SizedBox(height: isMobile ? 24 : 32),
          _buildMenuCard(title: "Radar & Lokasi Site", subtitle: "Konfigurasi titik pusat GPS, radius absensi, dan area.", icon: Icons.location_on, onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => AdminConfigView(initialLocations: _cachedConfigData?['locations']))).then((_) => _forceFetchConfig()); }),
          const SizedBox(height: 16),
          _buildMenuCard(title: "Pengaturan Shift (Waktu)", subtitle: "Kelola aturan jam masuk dan jam pulang untuk setiap site.", icon: Icons.timer, onTap: () => setState(() => _activeSetting = 'shift')),
          const SizedBox(height: 16),
          _buildMenuCard(title: "Departemen & Jabatan", subtitle: "Kelola daftar divisi dan posisi untuk data karyawan.", icon: Icons.work, onTap: () => setState(() => _activeSetting = 'departemen')),
          const SizedBox(height: 16),
          _buildMenuCard(title: "Kelola Perangkat", subtitle: "Reset pengikatan perangkat (Device Lock) karyawan.", icon: Icons.devices, onTap: () => setState(() => _activeSetting = 'devices')),
          const SizedBox(height: 16),
          
          // MENGGUNAKAN STREAMBUILDER UNTUK MENDETEKSI TIKET OPEN
          FutureBuilder<List<dynamic>>(
            future: ApiService().getTickets(),
            builder: (context, snapshot) {
              int pendingTicketsCount = 0;
              if (snapshot.hasData) {
                var docs = snapshot.data!.where((t) => t['status'] == 'Open').toList();
                if (widget.user.role == 'Head Area') {
                  docs = docs.where((d) => d['area'] == widget.user.area).toList();
                }
                pendingTicketsCount = docs.length;
              }
              return _buildMenuCard(
                title: "Pusat Bantuan", 
                subtitle: "Kelola tiket keluhan dan permintaan bantuan.", 
                icon: Icons.chat, 
                showBadge: pendingTicketsCount > 0,
                badgeCount: pendingTicketsCount,
                onTap: () { widget.onChangeView('admin_tickets'); }
              );
            }
          ),
          
          const SizedBox(height: 16),
          _buildMenuCard(title: "Ganti Password", subtitle: "Perbarui kata sandi akun Admin", icon: Icons.lock_outline, onTap: () => _showChangePasswordDialog()),
          
          const SizedBox(height: 32),
          InkWell(
            onTap: widget.onLogout, borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24), decoration: BoxDecoration(color: AppColors.rose50, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.rose100)),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.rose200)), child: const Icon(Icons.logout, color: AppColors.rose500, size: 24)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text("KELUAR PORTAL", style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 12 : 14, color: AppColors.rose600)), const SizedBox(height: 4), Text("Akhiri sesi Anda dan keluar dari sistem secara aman.", style: TextStyle(fontSize: isMobile ? 10 : 11, color: AppColors.slate500, fontWeight: FontWeight.bold))],
                    ),
                  ),
                  if (!isMobile) const Icon(Icons.close, color: AppColors.rose400, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMenuCard({required String title, required String subtitle, required IconData icon, required VoidCallback onTap, bool showBadge = false, int badgeCount = 0}) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.slate200), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4)]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.yellow50, borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: AppColors.slate800, size: isMobile ? 24 : 28)),
            SizedBox(width: isMobile ? 16 : 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Row(
                    children: [
                      Text(title.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 13 : 15, color: AppColors.slate800)),
                      // INDIKATOR MERAH / ANGKA DI PUSAT BANTUAN ADMIN
                      if (showBadge || badgeCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: badgeCount > 0 ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : null,
                          width: badgeCount > 0 ? null : 8,
                          height: badgeCount > 0 ? null : 8,
                          decoration: BoxDecoration(color: AppColors.rose500, borderRadius: BorderRadius.circular(8)),
                          child: badgeCount > 0 ? Text(badgeCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)) : null,
                        ),
                      ]
                    ],
                  ), 
                  const SizedBox(height: 6), 
                  Text(subtitle, style: TextStyle(fontSize: isMobile ? 10 : 12, color: AppColors.slate500, fontWeight: FontWeight.bold))
                ]
              )
            ),
            if (!isMobile) Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.chevron_right, color: AppColors.slate400, size: 16)),
          ],
        ),
      ),
    );
  }

  // --- WIDGET PROFILE VIEW ---
  Widget _buildProfileView() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ApiService().getUserById(widget.user.id),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.yellow500));
        
        var userData = userSnap.data ?? <String, dynamic>{};

        userData['nama_lengkap'] = userData['nama_lengkap'] ?? widget.user.namaLengkap;
        userData['nik'] = userData['nik'] ?? widget.user.nik;
        userData['role'] = userData['role'] ?? widget.user.role;
        userData['area'] = userData['area'] ?? widget.user.area;

        return FutureBuilder<Map<String, dynamic>?>(
          future: _configFuture,
          builder: (context, configSnap) {
            if (!configSnap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.yellow500));
            var configData = configSnap.data ?? {};

            return _ProfileForm(
              userData: userData,
              configData: configData,
              userId: widget.user.id,
              userRole: widget.user.role, 
              onBack: () => setState(() => _activeSetting = 'menu'),
            );
          }
        );
      }
    );
  }

  // WIDGET MANAGE DEVICES
  Widget _buildManageDevicesView() {
    bool isMobile = MediaQuery.of(context).size.width < 800;
    double padding = isMobile ? 16 : 32;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _configFuture,
      builder: (context, configSnap) {
        List<String> availableAreas = ['Semua Area'];
        if (configSnap.hasData && configSnap.data != null) {
          var data = configSnap.data!;
          List<dynamic> locs = data['locations'] ?? [];
          if (locs.isNotEmpty) {
            var areaList = locs.map((e) => e['siteName'].toString()).toList();
            areaList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            availableAreas.addAll(areaList);
          }
        }

        if (!availableAreas.contains(_deviceFilterArea)) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) setState(() => _deviceFilterArea = 'Semua Area');
           });
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBack("Kelola Perangkat"),
              SizedBox(height: padding),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(isMobile ? 24 : 40), 
                  border: Border.all(color: AppColors.slate200), 
                  boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10)]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isMobile 
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("DAFTAR PERANGKAT KARYAWAN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 2)),
                            const SizedBox(height: 16),
                            _buildAreaDropdown(availableAreas, isMobile),
                          ]
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("DAFTAR PERANGKAT KARYAWAN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 2)),
                            _buildAreaDropdown(availableAreas, isMobile),
                          ]
                        ),
                    const SizedBox(height: 24),
                    
                    FutureBuilder<List<dynamic>>(
                      future: _usersFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.yellow500));
                        if (snapshot.hasError) return const Text("Terjadi kesalahan memuat data", style: TextStyle(color: AppColors.rose500));
                        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("Tidak ada data karyawan.", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold));

                        var users = snapshot.data!.where((doc) {
                          var data = doc as Map<String, dynamic>;
                          bool isNotAdmin = data['role'] != 'admin'; 
                          bool isAreaMatch = _deviceFilterArea == 'Semua Area' || (data['area'] ?? '') == _deviceFilterArea;
                          return isNotAdmin && isAreaMatch;
                        }).toList();

                        users.sort((a, b) => ((a as Map<String, dynamic>)['nama_lengkap'] ?? '').toString().compareTo(((b as Map<String, dynamic>)['nama_lengkap'] ?? '').toString()));

                        if (users.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text("Tidak ada data karyawan di area yang dipilih.", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: users.length,
                          separatorBuilder: (_, __) => const Divider(height: 32, color: AppColors.slate100),
                          itemBuilder: (context, index) {
                            var userData = users[index] as Map<String, dynamic>;
                            String userId = userData['id'].toString();
                            String name = userData['nama_lengkap'] ?? 'Tanpa Nama';
                            String nik = userData['nik'] ?? '-';
                            String area = userData['area'] ?? 'Belum Diatur';
                            
                            var deviceObj = userData['device'] as Map<String, dynamic>? ?? {};
                            
                            String mobileId = deviceObj['mobileDeviceId']?.toString() ?? '';
                            String desktopId = deviceObj['desktopDeviceId']?.toString() ?? '';
                            
                            if (mobileId.isEmpty && desktopId.isEmpty && userData.containsKey('deviceId') && userData['deviceId'] != null) {
                               mobileId = userData['deviceId'].toString(); 
                            }

                            bool isMobileBound = mobileId.isNotEmpty;
                            bool isDesktopBound = desktopId.isNotEmpty;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.slate800)),
                                const SizedBox(height: 4),
                                Text("$nik • Area: ${area.toUpperCase()}", style: const TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                const SizedBox(height: 16),
                                Flex(
                                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                                  children: [
                                    Expanded(
                                      flex: isMobile ? 0 : 1,
                                      child: _buildDeviceCard(
                                        title: "Handphone (Mobile)",
                                        isBound: isMobileBound,
                                        deviceId: mobileId,
                                        onReset: () => _resetDevice(userId, name, 'mobileDeviceId', 'Handphone'),
                                      ),
                                    ),
                                    if (isMobile) const SizedBox(height: 12) else const SizedBox(width: 16),
                                    Expanded(
                                      flex: isMobile ? 0 : 1,
                                      child: _buildDeviceCard(
                                        title: "Desktop (PC/Laptop)",
                                        isBound: isDesktopBound,
                                        deviceId: desktopId,
                                        onReset: () => _resetDevice(userId, name, 'desktopDeviceId', 'Desktop'),
                                      ),
                                    ),
                                  ]
                                )
                              ],
                            );
                          }
                        );
                      }
                    )
                  ]
                )
              ),
              const SizedBox(height: 100),
            ],
          )
        );
      }
    );
  }

  Widget _buildAreaDropdown(List<String> availableAreas, bool isMobile) {
    return Container(
      width: isMobile ? double.infinity : 250,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.slate200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: availableAreas.contains(_deviceFilterArea) ? _deviceFilterArea : 'Semua Area',
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.slate500),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
          onChanged: (String? newValue) => setState(() => _deviceFilterArea = newValue!),
          items: availableAreas.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
        ),
      ),
    );
  }

  Widget _buildDeviceCard({required String title, required bool isBound, required String deviceId, required VoidCallback onReset}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBound ? AppColors.slate50 : Colors.white,
        border: Border.all(color: isBound ? AppColors.slate200 : AppColors.slate100),
        borderRadius: BorderRadius.circular(16)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(title.contains("Handphone") ? Icons.smartphone : Icons.computer, size: 16, color: AppColors.slate500),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate700)),
                ]
              ),
              Icon(isBound ? Icons.lock : Icons.lock_open, size: 16, color: isBound ? AppColors.rose500 : AppColors.emerald500),
            ]
          ),
          const SizedBox(height: 12),
          Text(isBound ? "Terikat (ID: ${deviceId.length > 8 ? deviceId.substring(0,8) : deviceId}...)" : "Belum Terikat", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isBound ? AppColors.rose600 : AppColors.emerald600)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isBound ? AppColors.slate900 : AppColors.slate100,
                foregroundColor: isBound ? Colors.white : AppColors.slate400,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12)
              ),
              onPressed: isBound ? onReset : null,
              icon: const Icon(Icons.refresh, size: 14),
              label: Text(isBound ? "Reset" : "Aman", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
            )
          )
        ]
      )
    );
  }

  void _resetDevice(String docId, String userName, String fieldName, String deviceType) async {
     bool confirm = await showDialog(
       context: context,
       builder: (c) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text("Reset $deviceType?", style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Text("Aksi ini akan menghapus pengikatan $deviceType dan mengizinkan '$userName' untuk login di perangkat $deviceType baru. Lanjutkan?", style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
             TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.bold))),
             ElevatedButton(
                onPressed: () => Navigator.pop(c, true), 
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
                child: const Text("Reset", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
             ),
          ]
       )
     );

     if (confirm == true) {
         try {
           // Mengirimkan pembaruan field kosong ke backend
           await ApiService().updateUser(docId, {
             fieldName: '',
           });
           
           // Panggil endpoint reset device
           final client = ApiClient().dio;
           await client.post('/users/$docId/reset-device', data: {'field': fieldName});

           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Perangkat $deviceType berhasil di-reset!"), backgroundColor: AppColors.emerald500));
        } catch (e) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal reset perangkat."), backgroundColor: AppColors.rose500));
        }
     }
  }

  Widget _buildShiftView() {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    double padding = isMobile ? 16 : 32;

    if (_cachedConfigData == null) {
      return Center(
        child: Padding(padding: EdgeInsets.all(padding), child: const CircularProgressIndicator(color: AppColors.yellow500)),
      );
    }

    List<dynamic> shiftsData = _cachedConfigData!['shifts'] ?? [];
    List<String> availableAreas = [];
    List<dynamic> locsData = _cachedConfigData!['locations'] ?? [];
    if (locsData.isNotEmpty) {
      availableAreas.addAll(locsData.map((e) => e['siteName'].toString()));
    }

        if (availableAreas.isEmpty) {
           availableAreas = ['Belum ada area'];
        }

        List<Map<String, dynamic>> shifts = shiftsData.map((e) => Map<String, dynamic>.from(e)).toList();
        
        List<Map<String, dynamic>> filteredShifts = [];
        if (_selectedShiftArea != null) {
          filteredShifts = shifts.where((s) {
            String sArea = s['area'] ?? 'Semua Area';
            return sArea == _selectedShiftArea; 
          }).toList();
        }

        var pagiShifts = filteredShifts.where((s) => !s['name'].toString().toLowerCase().contains('malam')).toList();
        var malamShifts = filteredShifts.where((s) => s['name'].toString().toLowerCase().contains('malam')).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBack("Pengaturan Shift Kerja"),
              SizedBox(height: padding),

              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(isMobile ? 24 : 40), border: Border.all(color: AppColors.slate200), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(padding),
                      child: isMobile 
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.slate200)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: _selectedShiftArea != null && availableAreas.contains(_selectedShiftArea) ? _selectedShiftArea : null, 
                                    hint: const Text("PILIH AREA...", style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.w900)),
                                    icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate400), 
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                    decoration: const InputDecoration(border: InputBorder.none),
                                    onChanged: (String? newValue) => setState(() => _selectedShiftArea = newValue),
                                    items: availableAreas.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: () {
                                    if (_selectedShiftArea == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap pilih Area terlebih dahulu!"), backgroundColor: AppColors.rose500));
                                      return;
                                    }
                                    _showShiftDialog(null, shifts, availableAreas);
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: AppColors.yellow500, shape: BoxShape.circle), child: const Icon(Icons.add, size: 24, color: AppColors.slate900)),
                                ),
                              )
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 20, color: AppColors.slate400),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 250,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.slate200)),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue: _selectedShiftArea != null && availableAreas.contains(_selectedShiftArea) ? _selectedShiftArea : null, 
                                        hint: const Text("PILIH AREA...", style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.w900)),
                                        icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate400), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                        decoration: const InputDecoration(border: InputBorder.none),
                                        onChanged: (String? newValue) => setState(() => _selectedShiftArea = newValue),
                                        items: availableAreas.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                            onTap: () {
                              if (_selectedShiftArea == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap pilih Area terlebih dahulu!"), backgroundColor: AppColors.rose500));
                                return;
                              }
                              _showShiftDialog(null, shifts, availableAreas);
                            }, 
                            borderRadius: BorderRadius.circular(24),
                            child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: AppColors.yellow500, shape: BoxShape.circle), child: const Icon(Icons.add, size: 24, color: AppColors.slate900)),
                          ),
                        ],
                      ),
                    ),

                    if (_selectedShiftArea == null)
                       Padding(
                         padding: EdgeInsets.all(padding),
                         child: const Center(child: Text("Silakan pilih Area Penugasan pada menu di atas untuk mengatur Shift.", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
                       )
                    else if (pagiShifts.isEmpty && malamShifts.isEmpty)
                       Padding(
                         padding: EdgeInsets.all(padding),
                         child: Center(child: Text("Belum ada shift terdaftar di ${_selectedShiftArea!.toUpperCase()}.", style: const TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
                       )
                    else ...[
                       if (pagiShifts.isNotEmpty) ...[
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                           color: AppColors.slate50,
                           child: Row(children: const [Icon(Icons.wb_sunny, size: 18, color: AppColors.amber500), SizedBox(width: 8), Text("KELOMPOK PAGI", style: TextStyle(fontSize: 11, color: AppColors.amber500, fontWeight: FontWeight.w900))]),
                         ),
                         ListView.separated(
                           shrinkWrap: true,
                           physics: const NeverScrollableScrollPhysics(),
                           itemCount: pagiShifts.length,
                           separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.slate100),
                           itemBuilder: (context, index) => _buildShiftCard(pagiShifts[index], shifts, availableAreas),
                         ),
                       ],
                       if (malamShifts.isNotEmpty) ...[
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                           color: AppColors.slate50,
                           child: Row(children: const [Icon(Icons.nightlight_round, size: 18, color: AppColors.indigo500), SizedBox(width: 8), Text("KELOMPOK MALAM", style: TextStyle(fontSize: 11, color: AppColors.indigo500, fontWeight: FontWeight.w900))]),
                         ),
                         ListView.separated(
                           shrinkWrap: true,
                           physics: const NeverScrollableScrollPhysics(),
                           itemCount: malamShifts.length,
                           separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.slate100),
                           itemBuilder: (context, index) => _buildShiftCard(malamShifts[index], shifts, availableAreas),
                         ),
                       ]
                    ]

                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        );
  }

  Widget _buildShiftCard(Map<String, dynamic> s, List<Map<String, dynamic>> allShifts, List<String> availableAreas) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['name'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.slate800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.emerald50, borderRadius: BorderRadius.circular(8)),
                      child: Text("IN: ${s['start']}", style: const TextStyle(color: AppColors.emerald600, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace')),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.rose50, borderRadius: BorderRadius.circular(8)),
                      child: Text("OUT: ${s['end']}", style: const TextStyle(color: AppColors.rose600, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'monospace')),
                    ),
                  ],
                )
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: AppColors.slate400), 
                tooltip: "Edit Shift",
                onPressed: () => _showShiftDialog(s, allShifts, availableAreas)
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: AppColors.rose400),
                tooltip: "Hapus Shift",
                onPressed: () async {
                  bool confirm = await showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text("Hapus Shift?"), content: Text("Yakin ingin menghapus shift ${s['name']}?"),
                      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal")), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Hapus", style: TextStyle(color: Colors.red)))],
                    ),
                  );
                  if (confirm) {
                    List<Map<String, dynamic>> updated = List.from(allShifts)..removeWhere((item) => item['id'] == s['id']);
                    
                    try {
                      await ApiService().updateConfigSite({'shifts': updated});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data shift berhasil dihapus!"), backgroundColor: AppColors.emerald500));
                        _forceFetchConfig();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Koneksi gagal! Silakan periksa jaringan/server Anda."), backgroundColor: AppColors.rose500));
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showShiftDialog(Map<String, dynamic>? shiftToEdit, List<Map<String, dynamic>> currentShifts, List<String> availableAreas) {
    String name = shiftToEdit?['name'] ?? 'Pagi';
    String start = shiftToEdit?['start'] ?? '08:00';
    String end = shiftToEdit?['end'] ?? '17:00';
    String shiftArea = shiftToEdit?['area'] ?? _selectedShiftArea ?? availableAreas.first;
    bool isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder: (context) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submitShift() async {
              List<Map<String, dynamic>> updatedShifts = List.from(currentShifts);
              if (shiftToEdit == null) {
                // Menyimpan ke area yang dipilih di dalam dialog
                updatedShifts.add({'id': 'shift-${DateTime.now().millisecondsSinceEpoch}', 'name': name, 'start': start, 'end': end, 'area': shiftArea});
              } else {
                int idx = updatedShifts.indexWhere((e) => e['id'] == shiftToEdit['id']);
                if (idx != -1) { updatedShifts[idx] = {'id': shiftToEdit['id'], 'name': name, 'start': start, 'end': end, 'area': shiftArea}; }
              }
              
              bool isNew = shiftToEdit == null;
              
              setDialogState(() => isSubmitting = true);

              try {
                 await ApiService().updateConfigSite({'shifts': updatedShifts});
                 if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isNew ? "Data shift berhasil disimpan!" : "Data shift berhasil diupdate!"), backgroundColor: AppColors.emerald500));
                    _forceFetchConfig();
                 }
              } catch (e) {
                 if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Koneksi gagal! Silakan periksa jaringan/server Anda."), backgroundColor: AppColors.rose500));
                 }
              } finally {
                 if (mounted) setDialogState(() => isSubmitting = false);
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 24 : 40)),
              title: Row(
                children: [
                  Container(padding: EdgeInsets.all(isMobile ? 8 : 12), decoration: BoxDecoration(color: AppColors.amber500, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.timer, color: Colors.white, size: isMobile ? 20 : 24)),
                  const SizedBox(width: 16),
                  Expanded(child: Text(shiftToEdit == null ? "TAMBAH SHIFT" : "EDIT SHIFT", style: TextStyle(fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.w900))),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("KATEGORI SHIFT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: ['Pagi', 'Malam'].contains(name) ? name : 'Pagi',
                      decoration: InputDecoration(filled: true, fillColor: AppColors.slate50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
                      items: ['Pagi', 'Malam'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (v) => setDialogState(() => name = v!),
                    ),
                    const SizedBox(height: 24),
                    const Text("AREA SHIFT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: availableAreas.contains(shiftArea) ? shiftArea : availableAreas.first,
                      decoration: InputDecoration(filled: true, fillColor: AppColors.slate50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
                      items: availableAreas.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setDialogState(() => shiftArea = v!),
                    ),
                    const SizedBox(height: 24),
                    
                    if (isMobile) ...[
                      const Text("JAM MASUK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(start.split(':')[0]) ?? 8, minute: int.tryParse(start.split(':')[1]) ?? 0));
                          if (picked != null) setDialogState(() => start = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}");
                        },
                        child: Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(20)), child: Text(start, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'))),
                      ),
                      const SizedBox(height: 24),
                      const Text("JAM PULANG", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(end.split(':')[0]) ?? 17, minute: int.tryParse(end.split(':')[1]) ?? 0));
                          if (picked != null) setDialogState(() => end = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}");
                        },
                        child: Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(20)), child: Text(end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'))),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("JAM MASUK", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(start.split(':')[0]) ?? 8, minute: int.tryParse(start.split(':')[1]) ?? 0));
                                    if (picked != null) setDialogState(() => start = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}");
                                  },
                                  child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(20)), child: Text(start, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'))),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("JAM PULANG", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(end.split(':')[0]) ?? 17, minute: int.tryParse(end.split(':')[1]) ?? 0));
                                    if (picked != null) setDialogState(() => end = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}");
                                  },
                                  child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(20)), child: Text(end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'))),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: isSubmitting ? null : submitShift,
                  child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Simpan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDepartemenView() {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    double padding = isMobile ? 16 : 32;

    if (_cachedConfigData == null) {
      return Center(
        child: Padding(padding: EdgeInsets.all(padding), child: const CircularProgressIndicator(color: AppColors.emerald500)),
      );
    }

    List<Map<String, dynamic>> strukturOrganisasi = [];
    var data = _cachedConfigData!;
    
    if (data.containsKey('struktur_organisasi')) {
      strukturOrganisasi = List<Map<String, dynamic>>.from(
        (data['struktur_organisasi'] as List).map((e) => Map<String, dynamic>.from(e))
      );
    } else {
      // Migrasi otomatis jika data struktur_organisasi belum ada di database
      List<dynamic> oldDeps = data['departemens'] ?? ['Umum'];
      List<dynamic> oldJabs = data['jabatans'] ?? ['Staff'];
      
      strukturOrganisasi = [
        {'departemen': oldDeps.isNotEmpty ? oldDeps.first : 'Umum', 'jabatan': oldJabs.isNotEmpty ? oldJabs.first : 'Staff'}
      ];
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBack("Struktur Organisasi"),
          SizedBox(height: padding),
          _buildStrukturGrouped(strukturOrganisasi),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStrukturGrouped(List<Map<String, dynamic>> strukturList) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    // Kelompokkan data berdasarkan Departemen
    Map<String, List<Map<String, dynamic>>> groupedData = {};
    for (int i = 0; i < strukturList.length; i++) {
      String dep = strukturList[i]['departemen'].toString();
      if (!groupedData.containsKey(dep)) {
        groupedData[dep] = [];
      }
      groupedData[dep]!.add({
        'originalIndex': i,
        'jabatan': strukturList[i]['jabatan'].toString(),
      });
    }

    // URUTKAN DAFTAR DEPARTEMEN DARI A - Z
    var sortedEntries = groupedData.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(isMobile ? 24 : 40), 
        border: Border.all(color: AppColors.slate200), 
        boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("STRUKTUR ORGANISASI PERUSAHAAN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 1)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald500, 
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    onPressed: () => _showStrukturDialog(null, null, strukturList),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text("Departemen Baru", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                  )
                ]
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "STRUKTUR ORGANISASI PERUSAHAAN",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 2)
                    )
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald500, 
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    onPressed: () => _showStrukturDialog(null, null, strukturList),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text("Departemen Baru", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                  )
                ],
              ),
          const SizedBox(height: 32),

          if (sortedEntries.isEmpty)
             const Center(
               child: Padding(
                 padding: EdgeInsets.all(40), 
                 child: Text("Belum ada data struktur organisasi", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))
               )
             ),

          ...sortedEntries.map((entry) {
            String depName = entry.key;
            List<Map<String, dynamic>> jabs = entry.value;

            // URUTKAN DAFTAR JABATAN DI DALAM DEPARTEMEN DARI A - Z
            jabs.sort((a, b) => a['jabatan'].toString().toLowerCase().compareTo(b['jabatan'].toString().toLowerCase()));

            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER DEPARTEMEN ---
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      border: const Border(bottom: BorderSide(color: AppColors.slate200))
                    ),
                    child: isMobile 
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.domain, color: AppColors.slate500, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("DEPARTEMEN", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
                                      Text(depName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.slate800)),
                                    ],
                                  ),
                                ),
                              ]
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 16, color: AppColors.slate400),
                                      tooltip: 'Edit Departemen',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showEditDepartemenDialog(depName, strukturList)
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 16, color: AppColors.rose400),
                                      tooltip: 'Hapus Departemen',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        bool confirm = await showDialog(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text("Hapus Departemen?"),
                                            content: Text("Yakin ingin menghapus departemen '$depName' beserta seluruh jabatan di dalamnya?"),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.bold))),
                                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
                                            ],
                                          )
                                        );
                                        if (confirm == true) {
                                          List<Map<String, dynamic>> updated = List.from(strukturList);
                                          updated.removeWhere((item) => item['departemen'] == depName);
                                          await _saveStrukturToFirestore(updated);
                                        }
                                      }
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () => _showStrukturDialog(null, {'departemen': depName, 'jabatan': ''}, strukturList, lockDepartemen: true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.add, size: 12, color: AppColors.slate600),
                                        SizedBox(width: 4),
                                        Text("JABATAN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 1))
                                      ],
                                    )
                                  )
                                )
                              ],
                            )
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.domain, color: AppColors.slate500, size: 24),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("DEPARTEMEN", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
                                    Text(depName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.slate800)),
                                  ],
                                ),
                              ]
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: AppColors.slate400),
                                  tooltip: 'Edit Departemen',
                                  onPressed: () => _showEditDepartemenDialog(depName, strukturList)
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: AppColors.rose400),
                                  tooltip: 'Hapus Departemen',
                                  onPressed: () async {
                                    bool confirm = await showDialog(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text("Hapus Departemen?"),
                                        content: Text("Yakin ingin menghapus departemen '$depName' beserta seluruh jabatan di dalamnya?"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.bold))),
                                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
                                        ],
                                      )
                                    );
                                    if (confirm == true) {
                                      List<Map<String, dynamic>> updated = List.from(strukturList);
                                      updated.removeWhere((item) => item['departemen'] == depName);
                                      await _saveStrukturToFirestore(updated);
                                    }
                                  }
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _showStrukturDialog(null, {'departemen': depName, 'jabatan': ''}, strukturList, lockDepartemen: true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.add, size: 14, color: AppColors.slate600),
                                        SizedBox(width: 4),
                                        Text("JABATAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 1))
                                      ],
                                    )
                                  )
                                )
                              ],
                            )
                          ],
                        ),
                  ),

                  // --- LIST JABATAN DI BAWAH DEPARTEMEN ---
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: jabs.length,
                    separatorBuilder: (c, i) => const Divider(height: 1, color: AppColors.slate100),
                    itemBuilder: (context, index) {
                      var jabData = jabs[index];
                      int origIdx = jabData['originalIndex'];
                      String jabName = jabData['jabatan'];

                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.badge, size: 16, color: AppColors.slate400),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(jabName.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 13, color: AppColors.slate700))),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: AppColors.slate400),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showStrukturDialog(origIdx, {'departemen': depName, 'jabatan': jabName}, strukturList)
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: AppColors.rose400),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    bool confirm = await showDialog(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text("Hapus Jabatan?"),
                                        content: Text("Yakin ingin menghapus posisi '$jabName' dari departemen '$depName'?"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal")),
                                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Hapus", style: TextStyle(color: Colors.red)))
                                        ],
                                      )
                                    );
                                    if (confirm) {
                                      List<Map<String, dynamic>> updated = List.from(strukturList);
                                      updated.removeAt(origIdx);
                                      await _saveStrukturToFirestore(updated);
                                    }
                                  }
                                )
                              ]
                            )
                          ],
                        )
                      );
                    }
                  )
                ],
              )
            );
          }).toList(),
        ],
      )
    );
  }

  void _showStrukturDialog(int? indexToEdit, Map<String, dynamic>? itemToEdit, List<Map<String, dynamic>> currentList, {bool lockDepartemen = false}) {
    String departemen = itemToEdit != null ? itemToEdit['departemen'] : '';
    String jabatan = itemToEdit != null ? itemToEdit['jabatan'] : '';
    bool isEdit = indexToEdit != null;
    bool isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder: (context) {
        void submitStruktur() async {
          if (departemen.trim().isEmpty || jabatan.trim().isEmpty) return;
          FocusManager.instance.primaryFocus?.unfocus(); 
          
          List<Map<String, dynamic>> updatedList = List.from(currentList);

          if (isEdit) {
            updatedList[indexToEdit!] = {
              'departemen': departemen.trim(),
              'jabatan': jabatan.trim()
            };
          } else {
            updatedList.add({
              'departemen': departemen.trim(),
              'jabatan': jabatan.trim()
            });
          }

          await _saveStrukturToFirestore(updatedList);
          if (mounted) Navigator.pop(context);
        }

        return AlertDialog(
          backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 24 : 40)),
          title: Row(
            children: [
              Container(padding: EdgeInsets.all(isMobile ? 8 : 12), decoration: BoxDecoration(color: AppColors.emerald500, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.work, color: Colors.white, size: isMobile ? 20 : 24)),
              const SizedBox(width: 16),
              Expanded(child: Text(isEdit ? "EDIT POSISI" : "TAMBAH POSISI BARU", style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w900))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("NAMA DEPARTEMEN / DIVISI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), 
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => departemen = v,
                  controller: TextEditingController(text: departemen)..selection = TextSelection.collapsed(offset: departemen.length),
                  enabled: !lockDepartemen,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(), 
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: lockDepartemen ? AppColors.slate500 : AppColors.slate800),
                  decoration: InputDecoration(
                    hintText: "Contoh: IT, Umum, Finance...", 
                    filled: true, fillColor: lockDepartemen ? AppColors.slate100 : AppColors.slate50, 
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)
                  ),
                ),
                const SizedBox(height: 24),
                const Text("NAMA JABATAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), 
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => jabatan = v, 
                  controller: TextEditingController(text: jabatan)..selection = TextSelection.collapsed(offset: jabatan.length),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    submitStruktur();
                  },
                  decoration: InputDecoration(
                    hintText: "Contoh: IT Support, Manager...", 
                    filled: true, fillColor: AppColors.slate50, 
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(context);
              }, 
              child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: submitStruktur,
              child: const Text("Simpan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showEditDepartemenDialog(String oldDepName, List<Map<String, dynamic>> currentList) {
    String newDepName = oldDepName;
    bool isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder: (context) {
        void submitEdit() async {
          if (newDepName.trim().isEmpty || newDepName.trim() == oldDepName) return;
          FocusManager.instance.primaryFocus?.unfocus();
          
          List<Map<String, dynamic>> updatedList = List.from(currentList);
          for (int i = 0; i < updatedList.length; i++) {
            if (updatedList[i]['departemen'] == oldDepName) {
              updatedList[i]['departemen'] = newDepName.trim();
            }
          }

          await _saveStrukturToFirestore(updatedList);
          if (mounted) Navigator.pop(context);
        }

        return AlertDialog(
          backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 24 : 40)),
          title: Row(
            children: [
              Container(padding: EdgeInsets.all(isMobile ? 8 : 12), decoration: BoxDecoration(color: AppColors.blue500, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.domain, color: Colors.white, size: isMobile ? 20 : 24)),
              const SizedBox(width: 16),
              Expanded(child: Text("EDIT DEPARTEMEN", style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w900))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("NAMA DEPARTEMEN / DIVISI BARU", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)), 
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => newDepName = v, 
                  controller: TextEditingController(text: newDepName)..selection = TextSelection.collapsed(offset: newDepName.length),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.slate800),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    submitEdit();
                  },
                  decoration: InputDecoration(
                    hintText: "Contoh: IT, Umum, Finance...", 
                    filled: true, fillColor: AppColors.slate50, 
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(context);
              }, 
              child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: submitEdit,
              child: const Text("Simpan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveStrukturToFirestore(List<Map<String, dynamic>> strukturList) async {
    Set<String> deps = {};
    Set<String> jabs = {};
    
    for(var item in strukturList) {
      if (item['departemen'].toString().trim().isNotEmpty) deps.add(item['departemen']);
      if (item['jabatan'].toString().trim().isNotEmpty) jabs.add(item['jabatan']);
    }

    // Optimistic UI Update
    setState(() {
      _cachedConfigData!['struktur_organisasi'] = strukturList;
      _cachedConfigData!['departemens'] = deps.toList();
      _cachedConfigData!['jabatans'] = jabs.toList();
      _lastOptimisticUpdate = DateTime.now();
    });

    try {
      await ApiService().updateConfigSite({
        'struktur_organisasi': strukturList,
        'departemens': deps.toList(),
        'jabatans': jabs.toList()
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil menyimpan data organisasi!"), backgroundColor: AppColors.emerald500));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menyimpan data: $e"), backgroundColor: AppColors.rose500));
      }
    }
  }

  Widget _buildHeaderBack(String title) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.slate500, size: isMobile ? 20 : 28),
          onPressed: () => setState(() => _activeSetting = 'menu'),
          style: IconButton.styleFrom(backgroundColor: Colors.white, padding: EdgeInsets.all(isMobile ? 8 : 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.slate200))),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(title.toUpperCase(), style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: -0.5), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

// --- CLASS _ProfileForm (UI Form Edit Profil) ---
class _ProfileForm extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> configData;
  final String userId;
  final String userRole; 
  final VoidCallback onBack;

  const _ProfileForm({
    required this.userData,
    required this.configData,
    required this.userId,
    required this.userRole,
    required this.onBack,
  });

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  final TextEditingController _namaCtrl = TextEditingController();
  final TextEditingController _kontakCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController(); 
  final TextEditingController _alamatCtrl = TextEditingController();
  final TextEditingController _nikCtrl = TextEditingController();

  String _agama = 'Islam';
  String _area = '';
  String _departemen = '';
  String _jabatan = '';
  String? _photoBase64;
  
  DateTime? _tanggalLahir;
  String _jenisKelamin = 'Laki-laki';
  
  bool _isSaving = false;
  bool _isEditMode = false; // Status mode edit aktif/tidak

  List<String> _availableAreas = [];
  List<String> _departemens = [];
  List<String> _jabatans = [];
  List<Map<String, dynamic>> _strukturOrganisasi = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    List<dynamic> locs = widget.configData['locations'] ?? [];
    if (locs.isNotEmpty) {
      _availableAreas = locs.map((e) => e['siteName'].toString()).toList();
      _availableAreas.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      _availableAreas = ['Semua Area'];
    }

    if (widget.configData.containsKey('struktur_organisasi')) {
      _strukturOrganisasi = List<Map<String, dynamic>>.from(widget.configData['struktur_organisasi']);
      Set<String> deps = _strukturOrganisasi.map((e) => e['departemen'].toString()).toSet();
      _departemens = deps.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      _departemens = List<String>.from(widget.configData['departemens'] ?? ['Umum'])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }

    _namaCtrl.text = widget.userData['nama_lengkap'] ?? '';
    _nikCtrl.text = widget.userData['nik'] ?? '';
    _kontakCtrl.text = widget.userData['kontak'] ?? '';
    _emailCtrl.text = widget.userData['email'] ?? ''; 
    _alamatCtrl.text = widget.userData['alamat'] ?? '';
    _agama = widget.userData['agama'] ?? 'Islam';
    
    _jenisKelamin = widget.userData['jenis_kelamin'] ?? 'Laki-laki';
    if (!['Laki-laki', 'Perempuan'].contains(_jenisKelamin)) _jenisKelamin = 'Laki-laki';
    
    if (widget.userData['tanggal_lahir'] != null && widget.userData['tanggal_lahir'].toString().isNotEmpty) {
      try {
         _tanggalLahir = DateTime.parse(widget.userData['tanggal_lahir']);
      } catch (e) {
         _tanggalLahir = null;
      }
    }
    
    _area = widget.userData['area'] ?? '';
    if (!_availableAreas.contains(_area)) _area = _availableAreas.isNotEmpty ? _availableAreas.first : '';

    _departemen = widget.userData['departemen_id'] ?? '';
    if (!_departemens.contains(_departemen)) _departemen = _departemens.isNotEmpty ? _departemens.first : '';

    _updateJabatanList(_departemen);
    _jabatan = widget.userData['jabatan'] ?? '';
    if (!_jabatans.contains(_jabatan)) _jabatan = _jabatans.isNotEmpty ? _jabatans.first : '';

    _photoBase64 = widget.userData['photo_base64'];
  }

  void _updateJabatanList(String departemen) {
    if (_strukturOrganisasi.isEmpty) {
       _jabatans = List<String>.from(widget.configData['jabatans'] ?? ['Staff'])..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
       return;
    }
    var relatedJabs = _strukturOrganisasi
        .where((e) => e['departemen'] == departemen)
        .map((e) => e['jabatan'].toString())
        .toSet()
        .toList();
        
    relatedJabs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    setState(() {
      _jabatans = relatedJabs.isNotEmpty ? relatedJabs : ['Staff'];
      if (!_jabatans.contains(_jabatan)) {
        _jabatan = _jabatans.first;
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
        imageQuality: 50,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();

        // JIKA DI WEBATAU PLATFORM LAIN SELAIN ANDROID/IOS: Langsung simpan foto tanpa proses ML Kit
        bool canUseMLKit = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
        
        if (!canUseMLKit) {
          setState(() {
            _photoBase64 = base64Encode(bytes);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("✅ Foto profil berhasil diunggah (Mode Desktop/Web)."), 
              backgroundColor: AppColors.emerald500
            ));
          }
          return; // Hentikan fungsi di sini agar tidak menjalankan ML Kit di bawah
        }

        // JIKA DI HP (ANDROID/IOS): Jalankan simulasi & deteksi wajah ML Kit
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Row(
                children: const [
                  SizedBox(
                    width: 24, height: 24, 
                    child: CircularProgressIndicator(color: AppColors.blue500, strokeWidth: 3)
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Text("Memindai wajah dengan AI...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate800))
                  ),
                ],
              ),
            )
          );
        }

        // --- LOGIKA GOOGLE ML KIT (ON-DEVICE) ---
        final inputImage = InputImage.fromFilePath(image.path);
        final options = FaceDetectorOptions(
          enableContours: false,
          enableClassification: false,
        );
        final faceDetector = FaceDetector(options: options);
        
        final List<Face> faces = await faceDetector.processImage(inputImage);
        await faceDetector.close();

        if (mounted) Navigator.pop(context); // Tutup dialog loading

        if (faces.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("❌ Wajah tidak ditemukan! Harap gunakan foto yang jelas."), 
              backgroundColor: AppColors.rose500
            ));
          }
        } else if (faces.length > 1) {
          // MENCEGAH LEBIH DARI 1 WAJAH
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("❌ Terdeteksi lebih dari 1 wajah! Harap pastikan hanya ada wajah Anda di foto."), 
              backgroundColor: AppColors.rose500
            ));
          }
        } else {
          // WAJAH TEPAT 1 (VALID)
          setState(() {
            _photoBase64 = base64Encode(bytes);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("✅ Wajah terdeteksi dan valid!"), 
              backgroundColor: AppColors.emerald500
            ));
          }
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memproses foto: $e"), backgroundColor: AppColors.rose500));
    }
  }

  Future<void> _saveProfile() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_namaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama lengkap wajib diisi!"), backgroundColor: AppColors.rose500));
      return;
    }
    if (_nikCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("NRP / NIK wajib diisi!"), backgroundColor: AppColors.rose500));
      return;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alamat Email wajib diisi!"), backgroundColor: AppColors.rose500));
      return;
    }

    // --- TAMBAHAN VALIDASI WAJIB FOTO PROFIL UNTUK FACECAM ---
    if (_photoBase64 == null || _photoBase64!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Akses Ditolak: Foto Profil wajib diunggah! Wajah Anda diperlukan untuk validasi Face Recognition saat absensi."), 
        backgroundColor: AppColors.rose500,
        duration: Duration(seconds: 5),
      ));
      return; // Hentikan proses simpan jika foto tidak ada
    }
    // ---------------------------------------------------------

    setState(() => _isSaving = true);
    try {
      await ApiService().updateUser(widget.userId, {
        'nama_lengkap': _namaCtrl.text.trim(),
        'nik': _nikCtrl.text.trim(), 
        'email': _emailCtrl.text.trim(), 
        'kontak': _kontakCtrl.text.trim(),
        'alamat': _alamatCtrl.text.trim(),
        'agama': _agama,
        'jenis_kelamin': _jenisKelamin,
        if (_tanggalLahir != null) 'tanggal_lahir': DateFormat('yyyy-MM-dd').format(_tanggalLahir!),
        'departemen_id': _departemen,
        'jabatan': _jabatan,
        'area': _area,
        if (_photoBase64 != null) 'photo_base64': _photoBase64,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil Berhasil Diperbarui!"), backgroundColor: AppColors.emerald500));
        setState(() => _isEditMode = false); // Mengunci form kembali
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menyimpan profil."), backgroundColor: AppColors.rose500));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    bool isComplete = (_photoBase64 != null && _photoBase64!.isNotEmpty) &&
                      (_tanggalLahir != null) &&
                      (_emailCtrl.text.isNotEmpty) &&
                      (_kontakCtrl.text.isNotEmpty && _kontakCtrl.text != '-') &&
                      (_alamatCtrl.text.isNotEmpty && _alamatCtrl.text != '-');

    // LOGIKA KUNCI DATA UNTUK KARYAWAN BIASA
    bool isKaryawan = widget.userRole == 'Karyawan';
    
    // PERBAIKAN: Kunci foto profil dibuka agar Karyawan bebas ganti foto kapan saja.
    // Aturan keamanan tetap terjaga oleh AI Face Detection di fungsi _pickPhoto()
    bool isPhotoLocked = false; 

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.slate500, size: isMobile ? 20 : 24),
                onPressed: widget.onBack,
                style: IconButton.styleFrom(backgroundColor: Colors.white, padding: EdgeInsets.all(isMobile ? 8 : 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.slate200))),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text("PROFIL SAYA", style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: -0.5), overflow: TextOverflow.ellipsis)),
              
              if (!_isEditMode)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.yellow500,
                    foregroundColor: AppColors.slate900,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12)
                  ),
                  onPressed: () => setState(() => _isEditMode = true),
                  icon: Icon(Icons.edit, size: isMobile ? 14 : 16),
                  label: Text("Edit Profil", style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 10 : 12, letterSpacing: 1)),
                )
              else
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.slate500),
                  onPressed: () {
                    setState(() {
                      _isEditMode = false;
                      _initData(); 
                    });
                  },
                  icon: Icon(Icons.close, size: isMobile ? 14 : 16),
                  label: Text("Batal", style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 10 : 12)),
                )
            ],
          ),
          SizedBox(height: isMobile ? 24 : 32),
          
          if (!isComplete)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.rose50, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.rose200)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.rose500),
                  const SizedBox(width: 12),
                  const Expanded(child: Text("Profil Anda belum lengkap! Harap lengkapi semua data diri termasuk Alamat Email dan Foto Profil (Wajah).", style: TextStyle(color: AppColors.rose600, fontWeight: FontWeight.bold, fontSize: 11))),
                ],
              )
            ),

          if (_isEditMode && isKaryawan)
             Container(
               margin: const EdgeInsets.only(bottom: 24),
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.blue500)),
               child: Row(
                 children: [
                   const Icon(Icons.lock_outline, color: AppColors.blue500),
                   const SizedBox(width: 12),
                   // PERBAIKAN: Tulisan 'Foto Profil' dihapus dari keterangan data yang dikunci
                   const Expanded(child: Text("INFO: Departemen dan Jabatan telah dikunci oleh sistem. Hubungi HR / Admin jika Anda ingin melakukan perubahan pada data tersebut.", style: TextStyle(color: AppColors.blue500, fontWeight: FontWeight.bold, fontSize: 11))),
                 ],
               )
             ),

          Container(
            padding: EdgeInsets.all(isMobile ? 24 : 40),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(isMobile ? 24 : 40), border: Border.all(color: AppColors.slate100), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.slate200, width: 2)),
                        child: CircleAvatar(
                          radius: isMobile ? 40 : 56,
                          backgroundColor: AppColors.slate100,
                          backgroundImage: _photoBase64 != null && _photoBase64!.isNotEmpty ? MemoryImage(base64Decode(_photoBase64!)) : null,
                          child: _photoBase64 == null || _photoBase64!.isEmpty
                            ? Text(_namaCtrl.text.isNotEmpty ? _namaCtrl.text[0].toUpperCase() : 'U', style: TextStyle(fontSize: isMobile ? 32 : 48, fontWeight: FontWeight.w900, color: AppColors.slate400))
                            : null,
                        ),
                      ),
                      if (_isEditMode && !isPhotoLocked) 
                        InkWell(
                          onTap: _pickImage,
                          child: Container(
                            padding: EdgeInsets.all(isMobile ? 8 : 10),
                            decoration: BoxDecoration(color: AppColors.yellow500, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            child: Icon(Icons.camera_alt, size: isMobile ? 16 : 20, color: AppColors.slate900),
                          ),
                        )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: Text(
                  _isEditMode && !isPhotoLocked ? "Unggah Foto Wajah" : "Foto Profil (Wajah) Terkunci", 
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)
                )),
                const SizedBox(height: 40),

                isMobile
                 ? Column(
                     children: [
                       _buildInputCol("NAMA LENGKAP", TextField(controller: _namaCtrl, enabled: _isEditMode, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("Nama Lengkap"))),
                       const SizedBox(height: 16),
                       _buildInputCol("NRP / NIK", TextField(controller: _nikCtrl, enabled: _isEditMode, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("NRP-XXX"))),
                     ]
                   )
                 : Row(
                     children: [
                       Expanded(child: _buildInputCol("NAMA LENGKAP", TextField(controller: _namaCtrl, enabled: _isEditMode, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("Nama Lengkap")))),
                       const SizedBox(width: 16),
                       Expanded(child: _buildInputCol("NRP / NIK", TextField(controller: _nikCtrl, enabled: _isEditMode, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("NRP-XXX")))),
                     ],
                   ),
                const SizedBox(height: 16),
                
                isMobile
                 ? Column(
                     children: [
                       _buildInputCol("JENIS KELAMIN", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _jenisKelamin, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Laki-laki', 'Perempuan'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: _isEditMode ? (v) => setState(() => _jenisKelamin = v!) : null,
                       )),
                       const SizedBox(height: 16),
                       _buildInputCol("TANGGAL LAHIR", InkWell(
                          onTap: _isEditMode ? () async {
                            DateTime? picked = await showDatePicker(
                              context: context, initialDate: _tanggalLahir ?? DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _tanggalLahir = picked);
                          } : null,
                          child: Container(
                            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(color: _isEditMode ? AppColors.slate50 : AppColors.slate100, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_tanggalLahir != null ? DateFormat('dd MMMM yyyy', 'id_ID').format(_tanggalLahir!) : "Pilih Tanggal", style: TextStyle(fontWeight: FontWeight.bold, color: _tanggalLahir != null ? (_isEditMode ? AppColors.slate800 : AppColors.slate500) : AppColors.slate400)),
                                const Icon(Icons.calendar_today, size: 16, color: AppColors.slate400),
                              ],
                            ),
                          ),
                       )),
                     ]
                   )
                 : Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Expanded(child: _buildInputCol("JENIS KELAMIN", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _jenisKelamin, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Laki-laki', 'Perempuan'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: _isEditMode ? (v) => setState(() => _jenisKelamin = v!) : null,
                       ))),
                       const SizedBox(width: 16),
                       Expanded(child: _buildInputCol("TANGGAL LAHIR", InkWell(
                          onTap: _isEditMode ? () async {
                            DateTime? picked = await showDatePicker(
                              context: context, initialDate: _tanggalLahir ?? DateTime(2000), firstDate: DateTime(1950), lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _tanggalLahir = picked);
                          } : null,
                          child: Container(
                            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(color: _isEditMode ? AppColors.slate50 : AppColors.slate100, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_tanggalLahir != null ? DateFormat('dd MMMM yyyy', 'id_ID').format(_tanggalLahir!) : "Pilih Tanggal", style: TextStyle(fontWeight: FontWeight.bold, color: _tanggalLahir != null ? (_isEditMode ? AppColors.slate800 : AppColors.slate500) : AppColors.slate400)),
                                const Icon(Icons.calendar_today, size: 16, color: AppColors.slate400),
                              ],
                            ),
                          ),
                       ))),
                     ],
                   ),
                const SizedBox(height: 16),
                
                isMobile
                 ? Column(
                     children: [
                       _buildInputCol("AGAMA", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _agama, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: _isEditMode ? (v) => setState(() => _agama = v!) : null,
                       )),
                       const SizedBox(height: 16),
                       _buildInputCol("NO. TELEPON", TextField(controller: _kontakCtrl, enabled: _isEditMode, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("No. HP Aktif"))),
                     ]
                   )
                 : Row(
                     children: [
                       Expanded(child: _buildInputCol("AGAMA", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _agama, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: _isEditMode ? (v) => setState(() => _agama = v!) : null,
                       ))),
                       const SizedBox(width: 16),
                       Expanded(child: _buildInputCol("NO. TELEPON", TextField(controller: _kontakCtrl, enabled: _isEditMode, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("No. HP Aktif")))),
                     ],
                   ),
                const SizedBox(height: 16),

                isMobile
                 ? Column(
                     children: [
                       _buildInputCol("ALAMAT EMAIL", TextField(controller: _emailCtrl, enabled: _isEditMode, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("email@karyawan.com"))),
                       const SizedBox(height: 16),
                       _buildInputCol("ALAMAT LENGKAP", TextField(controller: _alamatCtrl, enabled: _isEditMode, maxLines: 2, textInputAction: TextInputAction.done, style: _textStyle(), decoration: _inputDeco("Alamat Lengkap Karyawan"))),
                     ]
                   )
                 : Row(
                     children: [
                       Expanded(child: _buildInputCol("ALAMAT EMAIL", TextField(controller: _emailCtrl, enabled: _isEditMode, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, style: _textStyle(), decoration: _inputDeco("email@karyawan.com")))),
                       const SizedBox(width: 16),
                       Expanded(child: _buildInputCol("ALAMAT LENGKAP", TextField(controller: _alamatCtrl, enabled: _isEditMode, maxLines: 2, textInputAction: TextInputAction.done, style: _textStyle(), decoration: _inputDeco("Alamat Lengkap Karyawan")))),
                     ],
                   ),
                const SizedBox(height: 16),

                isMobile
                 ? Column(
                     children: [
                       _buildInputCol("DEPARTEMEN / DIVISI", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _departemen, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco("", isLocked: isKaryawan),
                          items: _departemens.map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(isLocked: isKaryawan), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (_isEditMode && !isKaryawan) ? (v) { setState(() { _departemen = v!; _updateJabatanList(v); }); } : null,
                       )),
                       const SizedBox(height: 16),
                       _buildInputCol("JABATAN / POSISI", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _jabatan, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco("", isLocked: isKaryawan),
                          items: _jabatans.map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(isLocked: isKaryawan), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (_isEditMode && !isKaryawan) ? (v) => setState(() => _jabatan = v!) : null,
                       )),
                     ]
                   )
                 : Row(
                     children: [
                       Expanded(child: _buildInputCol("DEPARTEMEN / DIVISI", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _departemen, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco("", isLocked: isKaryawan),
                          items: _departemens.map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(isLocked: isKaryawan), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (_isEditMode && !isKaryawan) ? (v) { setState(() { _departemen = v!; _updateJabatanList(v); }); } : null,
                       ))),
                       const SizedBox(width: 16),
                       Expanded(child: _buildInputCol("JABATAN / POSISI", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _jabatan, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco("", isLocked: isKaryawan),
                          items: _jabatans.map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(isLocked: isKaryawan), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (_isEditMode && !isKaryawan) ? (v) => setState(() => _jabatan = v!) : null,
                       ))),
                     ],
                   ),
                const SizedBox(height: 16),
                
                isMobile
                 ? _buildInputCol("AREA PENUGASAN", DropdownButtonFormField<String>(
                      isExpanded: true, initialValue: _area, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco("", isLocked: isKaryawan),
                      items: _availableAreas.map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(isLocked: isKaryawan), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (_isEditMode && !isKaryawan) ? (v) => setState(() => _area = v!) : null,
                   ))
                 : Row(
                     children: [
                       Expanded(child: _buildInputCol("AREA PENUGASAN", DropdownButtonFormField<String>(
                          isExpanded: true, initialValue: _area, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco("", isLocked: isKaryawan),
                          items: _availableAreas.map((e) => DropdownMenuItem(value: e, child: Text(e, style: _textStyle(isLocked: isKaryawan), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (_isEditMode && !isKaryawan) ? (v) => setState(() => _area = v!) : null,
                       ))),
                       const SizedBox(width: 16),
                       const Expanded(child: SizedBox()), 
                     ],
                   ),

                if (_isEditMode) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity, height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 10, shadowColor: AppColors.slate900.withValues(alpha: 0.3)),
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text("SIMPAN PERUBAHAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                    ),
                  )
                ]
              ],
            ),
          )
        ]
      )
    );
  }

  Widget _buildInputCol(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  TextStyle _textStyle({bool isLocked = false}) {
    return TextStyle(fontWeight: FontWeight.bold, color: (_isEditMode && !isLocked) ? AppColors.slate800 : AppColors.slate500);
  }

  InputDecoration _inputDeco(String hint, {bool isLocked = false}) {
    return InputDecoration(
      hintText: hint, 
      filled: true, 
      fillColor: (_isEditMode && !isLocked) ? AppColors.slate50 : AppColors.slate100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.slate200.withValues(alpha: 0.5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
    );
  }
}
