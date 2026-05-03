import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import '../core/app_constants.dart';
import '../views/login_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isLoading = false;

  Future<void> _requestAllPermissions() async {
    setState(() => _isLoading = true);

    // Meminta 3 Izin Sekaligus (Lokasi, Kamera, Penyimpanan/Galeri)
    Map<perm.Permission, perm.PermissionStatus> statuses = await [
      perm.Permission.location,
      perm.Permission.camera,
      perm.Permission.photos,
    ].request();

    setState(() => _isLoading = false);

    // Cek apakah ada izin yang ditolak secara permanen (Ditolak & Jangan Tanya Lagi)
    bool isAnyPermanentlyDenied = statuses.values.any(
      (status) => status.isPermanentlyDenied,
    );

    if (isAnyPermanentlyDenied) {
      _showSettingsDialog();
      return;
    }

    // Jika Lokasi dan Kamera sudah diizinkan, lanjutkan ke halaman berikutnya
    if (statuses[perm.Permission.location]!.isGranted &&
        statuses[perm.Permission.camera]!.isGranted) {
      _goToMainMenu();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Aplikasi butuh akses Lokasi dan Kamera untuk Absensi.",
            ),
            backgroundColor: AppColors.rose500,
          ),
        );
      }
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Izin Diblokir",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "Anda telah menolak izin secara permanen. Aplikasi absensi tidak dapat berjalan tanpa akses Lokasi dan Kamera. Silakan buka Pengaturan HP Anda untuk mengizinkan secara manual.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Batal",
              style: TextStyle(color: AppColors.slate500),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald500,
            ),
            onPressed: () {
              Navigator.pop(context);
              perm.openAppSettings();
            },
            child: const Text(
              "Buka Pengaturan",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _goToMainMenu() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen(onLogin: (user) {})),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.security_rounded,
                  size: 80,
                  color: AppColors.blue500,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                "Izin Akses Aplikasi",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              const Text(
                "Untuk menggunakan sistem absensi digital, kami memerlukan beberapa izin akses pada perangkat Anda agar data kehadiran terekam valid.",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.slate500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              _buildPermissionItem(
                Icons.location_on,
                "Lokasi (GPS)",
                "Untuk memastikan Anda berada di area kerja (Site) saat melakukan absen.",
              ),
              const SizedBox(height: 16),
              _buildPermissionItem(
                Icons.camera_alt,
                "Kamera",
                "Untuk melakukan verifikasi wajah (Selfie) saat jam masuk dan pulang.",
              ),
              const SizedBox(height: 16),
              _buildPermissionItem(
                Icons.photo_library,
                "Galeri & Penyimpanan",
                "Untuk mengunggah Surat Keterangan Dokter saat mengajukan Izin Sakit.",
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.slate900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isLoading ? null : _requestAllPermissions,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "BERIKAN IZIN AKSES",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.slate700, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppColors.slate800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.slate500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
