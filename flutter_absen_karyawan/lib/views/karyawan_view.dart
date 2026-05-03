import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../core/app_constants.dart';
import '../models/user_model.dart';
import 'dart:convert';
import 'dart:typed_data';

// TAMBAHAN UNTUK DOWNLOAD LANGSUNG & MLKIT FACE DETECTION
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:path_provider/path_provider.dart'; 
import 'dart:io' as io;
import 'package:share_plus/share_plus.dart'; 
import 'package:file_saver/file_saver.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class KaryawanView extends StatefulWidget {
  final UserModel user;

  const KaryawanView({super.key, required this.user});

  @override
  State<KaryawanView> createState() => _KaryawanViewState();
}

class _KaryawanViewState extends State<KaryawanView> {
  // STATE BARU: Indikator Loading Konfigurasi
  bool _isLoadingConfig = true;

  String _searchQuery = '';
  String _selectedArea = 'Semua Area';
  List<String> _areas = ['Semua Area'];

  String _selectedDepartemen = 'Semua Departemen';
  List<String> _departemens = ['Semua Departemen', 'Umum'];

  String _selectedGender = 'Semua Jenis Kelamin';
  List<String> _genders = ['Semua Jenis Kelamin', 'Laki-laki', 'Perempuan'];

  List<String> _jabatans = ['Semua Jabatan', 'Staff'];

  List<String> _shifts = ['Pagi', 'Malam', 'Siang', 'General'];
  List<Map<String, dynamic>> _strukturOrganisasi = [];

  bool _isExporting = false;
  final List<String> _selectedUserIds = [];

  // Variabel untuk Scrollbar Horizontal
  final ScrollController _tableScrollController = ScrollController();

  // Variabel untuk Form Tambah/Edit Karyawan
  bool _showForm = false;
  bool _isSubmitting = false;
  bool _isEditing = false;
  bool _isAnalyzingPhoto = false; 
  String? _editDocId;

  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); 
  final TextEditingController _kontakController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  String _formArea = '';
  String _formDepartemen = '';
  String _formJabatan = '';
  String _formShift = 'Pagi'; 
  String _formRole = 'Karyawan'; 
  String _formJenisKelamin = 'Laki-laki';
  DateTime? _formTanggalLahir;
  String _formAgama = 'Islam';
  String? _formPhotoBase64;

  // Variabel Filter Bulan
  String _filterMonth = DateFormat('yyyy-MM').format(DateTime.now());

  late Future<List<dynamic>> _usersFuture;
  late Future<List<dynamic>> _attendanceFuture;

  @override
  void initState() {
    super.initState();
    _fetchConfig();
    
    _loadData();
  }

  void _loadData() {
    setState(() {
      _usersFuture = ApiService().getUsers();
      _attendanceFuture = ApiService().getAttendanceHistory();
    });
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    _namaController.dispose();
    _nikController.dispose();
    _emailController.dispose(); 
    _kontakController.dispose();
    _alamatController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _closeForm() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _showForm = false;
      _isEditing = false;
      _editDocId = null;
      _namaController.clear();
      _nikController.clear();
      _emailController.clear(); 
      _kontakController.clear();
      _alamatController.clear();
      _passController.clear();
      _formTanggalLahir = null;
      _formJenisKelamin = 'Laki-laki';
      _formAgama = 'Islam';
      _formShift = 'Pagi';
      _formRole = 'Karyawan';
      _formPhotoBase64 = null;
      _isAnalyzingPhoto = false;
    });
  }

  Future<void> _fetchConfig() async {
    try {
      var data = await ApiService().getConfigSite();

      if (data != null) {
        List<dynamic> locs = data['locations'] ?? [];
        List<dynamic> shifts = data['shifts'] ?? [];

        if (mounted) {
          setState(() {
            // Area
            if (locs.isNotEmpty) {
              var areaList = locs.map((e) => e['siteName'].toString()).toList();
              areaList.sort(
                (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
              );
              
              if (widget.user.role == 'Head Area' && widget.user.area != 'Semua Area' && widget.user.area.isNotEmpty) {
                _areas = [widget.user.area];
                _selectedArea = widget.user.area;
              } else {
                _areas = ['Semua Area', ...areaList];
                if (!_areas.contains(_selectedArea)) {
                  _selectedArea = _areas.first;
                }
              }

              var assignableAreas = _areas.where((a) => a != 'Semua Area').toList();
              if (assignableAreas.isEmpty) assignableAreas = _areas;
              if (assignableAreas.isNotEmpty && !assignableAreas.contains(_formArea)) {
                _formArea = assignableAreas.first;
              }
            }

            // Shift
            if (shifts.isNotEmpty) {
              _shifts = shifts
                  .map((e) => e['name'].toString())
                  .toSet()
                  .toList();
              if (_shifts.isNotEmpty && !_shifts.contains(_formShift)) {
                _formShift = _shifts.first;
              }
            }

            // Departemen & Jabatan
            if (data.containsKey('struktur_organisasi')) {
              _strukturOrganisasi = List<Map<String, dynamic>>.from(
                data['struktur_organisasi'],
              );
              Set<String> depSet = _strukturOrganisasi
                  .map((e) => e['departemen'].toString())
                  .toSet();
              List<String> sortedDeps = depSet.toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

              _departemens = ['Semua Departemen', ...sortedDeps];
              if (sortedDeps.isNotEmpty) {
                if (!_departemens.contains(_formDepartemen)) {
                  _formDepartemen = sortedDeps.first;
                }
              }
              _updateJabatanList(_formDepartemen);
            } else {
              List<dynamic> depsData =
                  data['departemens'] ??
                  ['Umum', 'Manajemen Site', 'Maintenance'];
              List<dynamic> jabsData =
                  data['jabatans'] ?? ['Staff', 'Supervisor', 'Manajer'];

              List<String> sortedDeps =
                  depsData.map((e) => e.toString()).toList()..sort(
                    (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                  );
              _departemens = ['Semua Departemen', ...sortedDeps];
              if (sortedDeps.isNotEmpty &&
                  !_departemens.contains(_formDepartemen)) {
                _formDepartemen = sortedDeps.first;
              }

              List<String> sortedJabs =
                  jabsData.map((e) => e.toString()).toList()..sort(
                    (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
                  );
              _jabatans = ['Semua Jabatan', ...sortedJabs];
              if (sortedJabs.isNotEmpty && !_jabatans.contains(_formJabatan)) {
                _formJabatan = sortedJabs.first;
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal load config: $e");
    } finally {
      // Mematikan loading ketika semua data selesai dimuat
      if (mounted) setState(() => _isLoadingConfig = false);
    }
  }

  void _updateJabatanList(String departemen, {String? preserveJabatan}) {
    if (_strukturOrganisasi.isEmpty) return;

    var relatedJabs = _strukturOrganisasi
        .where((e) => e['departemen'] == departemen)
        .map((e) => e['jabatan'].toString())
        .toSet()
        .toList();

    relatedJabs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    setState(() {
      _jabatans = ['Semua Jabatan', ...relatedJabs];

      if (preserveJabatan != null && relatedJabs.contains(preserveJabatan)) {
        _formJabatan = preserveJabatan;
      } else if (relatedJabs.isNotEmpty) {
        if (!relatedJabs.contains(_formJabatan)) {
          _formJabatan = relatedJabs.first;
        }
      } else {
        _formJabatan = '';
      }
    });
  }

  // FUNGSI UTAMA DOWNLOAD FILE DIRECT MENDUKUNG SEMUA PERANGKAT
  Future<void> _downloadFileDirectly(Uint8List bytes, String fileName) async {
    try {
      if (kIsWeb) {
        String nameOnly = fileName;
        if (fileName.endsWith('.csv')) {
           nameOnly = fileName.substring(0, fileName.length - 4);
        }
        
        await FileSaver.instance.saveFile(
          name: nameOnly,
          bytes: bytes,
          fileExtension: 'csv',
          mimeType: MimeType.csv,
        );

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("File Excel berhasil diunduh."),
              backgroundColor: AppColors.emerald500,
              duration: Duration(seconds: 3),
           ));
        }
      } else {
        if (io.Platform.isIOS) {
          final xFile = XFile.fromData(bytes, mimeType: 'text/csv', name: fileName);
          await Share.shareXFiles([xFile]);
          return;
        }

        io.Directory? directory;
        if (io.Platform.isAndroid) {
          directory = io.Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        } else if (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux) {
          directory = await getDownloadsDirectory();
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        final filePath = '${directory?.path ?? ''}/$fileName';
        final file = io.File(filePath);
        await file.writeAsBytes(bytes);
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("File Excel berhasil diunduh ke: $filePath"),
              backgroundColor: AppColors.emerald500,
              duration: const Duration(seconds: 5),
           ));
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Gagal menyimpan file ke perangkat. Pastikan izin penyimpanan aktif."),
            backgroundColor: AppColors.rose500,
         ));
      }
    }
  }

  // EXPORT EXCEL (Data Kehadiran / Laporan Absensi) DENGAN FORMAT HP/PC
  Future<void> _exportAttendanceData({required bool isMobileFormat}) async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pilih minimal 1 karyawan (centang kotak) untuk mengunduh absensinya."),
          backgroundColor: AppColors.rose500,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      String currentMonth = _filterMonth; 
      var allHistory = await ApiService().getAttendanceHistory();

      List<Map<String, dynamic>> allAtts = allHistory
          .map((e) => e as Map<String, dynamic>)
          .where((d) => _selectedUserIds.contains(d['user_id'].toString()) && d['date'] != null && d['date'].toString().startsWith(currentMonth))
          .toList();

      if (allAtts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tidak ada data kehadiran di bulan ini untuk karyawan yang dipilih."), backgroundColor: AppColors.amber500),
          );
        }
        setState(() => _isExporting = false);
        return;
      }

      // FORMAT CSV (Koma untuk HP, Titik Koma untuk PC)
      String delimiter = isMobileFormat ? ',' : ';';
      String csvData = isMobileFormat ? "" : "sep=;\n";
      csvData += "Tanggal${delimiter}Hari${delimiter}Nama Karyawan${delimiter}NRP${delimiter}Jam Masuk${delimiter}Jam Pulang${delimiter}Scan Masuk${delimiter}Scan Pulang${delimiter}Status Masuk${delimiter}Status Pulang${delimiter}Keterangan (Pulang Cepat/Kegiatan Dinas)${delimiter}GPS Lokasi ( Perjalanan Dinas )\n";

      String escapeCsv(String val) {
        String escaped = val.replaceAll('"', '""');
        return '"$escaped"';
      }

      for (var a in allAtts) {
        String dateStr = a['date'] ?? '';
        String hari = '-';
        if (dateStr.isNotEmpty) {
          try {
            hari = DateFormat('EEEE', 'id_ID').format(DateTime.parse(dateStr));
          } catch(e) {}
        }

        String shiftTime = a['shift_time'] ?? '-';
        String jamMasukJadwal = '-';
        String jamPulangJadwal = '-';
        if (shiftTime.contains('-')) {
           var parts = shiftTime.split('-');
           jamMasukJadwal = parts[0].trim();
           jamPulangJadwal = parts.length > 1 ? parts[1].trim() : '-';
        }

        String scanMasuk = a['jam_masuk'] ?? '-';
        String scanKeluar = a['jam_pulang'] ?? '-';
        String statusKedis = a['status_kedisiplinan'] ?? '-';
        String statusPulang = a['status_pulang'] ?? '-';
        
        String ket = a['keterangan'] ?? '-';
        String gpsMasuk = a['gps_masuk'] ?? '-';
        
        String statusKehadiran = a['status_kehadiran'] ?? 'Hadir';

        // Logika pemisahan keterangan menjadi 2 kolom
        bool isPerjalananDinas = statusKehadiran == 'Perjalanan Dinas' || ket.contains('Pekerjaan:') || ket.contains('Dinas di:');

        String ketPulangCepat = '-';
        String ketDinas = '-';
        List<String> gabunganKet = [];

        if (ket.contains('Pekerjaan:')) {
            String pekerjaan = ket.split('|')[0].replaceAll('Pekerjaan:', '').trim();
            if (pekerjaan.isNotEmpty) gabunganKet.add(pekerjaan);
        } else if (isPerjalananDinas && !ket.contains('Pulang Cepat:')) {
            if (ket != '-' && ket.isNotEmpty) gabunganKet.add(ket);
        }

        String alasanPC = a['alasan_pulang_cepat'] ?? '';
        if (alasanPC.isNotEmpty) {
            gabunganKet.add("Pulang Cepat: $alasanPC");
        } else if (statusPulang == 'Pulang Cepat' || ket.contains('Pulang Cepat:') || statusKehadiran == 'Pulang Cepat') {
            String pc = ket;
            if (ket.contains('Pulang Cepat:')) {
                pc = ket.substring(ket.indexOf('Pulang Cepat:') + 13).split('|')[0].trim();
            }
            if (pc.isNotEmpty && pc != '-' && !pc.contains('Pekerjaan:')) {
                gabunganKet.add("Pulang Cepat: $pc");
            } else if ((statusPulang == 'Pulang Cepat' || statusKehadiran == 'Pulang Cepat') && ket == '-') {
                gabunganKet.add("Pulang Cepat");
            }
        }

        if (statusKehadiran == 'Izin' || statusKehadiran == 'Sakit' || statusKehadiran == 'Cuti' || statusKehadiran == 'Alpa') {
            gabunganKet.clear();
            gabunganKet.add("[$statusKehadiran] $ket");
            statusKedis = '-';
            statusPulang = '-';
        }

        if (gabunganKet.isEmpty && ket != '-' && !ket.contains('Diinput manual')) {
            ketPulangCepat = ket;
        } else if (gabunganKet.isNotEmpty) {
            ketPulangCepat = gabunganKet.join(' / ');
        }

        if (isPerjalananDinas) {
            if (gpsMasuk != '-' && gpsMasuk != 'Disahkan' && gpsMasuk.isNotEmpty) {
                ketDinas = gpsMasuk;
            } else if (a['gps_pulang'] != null && a['gps_pulang'] != '-' && a['gps_pulang'] != 'Disahkan') {
                ketDinas = a['gps_pulang'];
            } else if (ket.contains('Lokasi:')) {
                var parts = ket.split('|');
                if (parts.length > 1) ketDinas = parts[1].replaceAll('Lokasi:', '').trim();
            } else {
                ketDinas = a['site_masuk'] ?? a['site_absen'] ?? '-';
                ketDinas = ketDinas.replaceAll('Dinas otomatis di:', '').replaceAll('Dinas di:', '').replaceAll('(Manual)', '').trim();
            }
        } else {
            ketDinas = '-';
        }

        csvData += "${escapeCsv(dateStr)}$delimiter${escapeCsv(hari)}$delimiter${escapeCsv(a['nama_lengkap'] ?? '-')}$delimiter${escapeCsv(a['nik'] ?? '-')}$delimiter${escapeCsv(jamMasukJadwal)}$delimiter${escapeCsv(jamPulangJadwal)}$delimiter${escapeCsv(scanMasuk)}$delimiter${escapeCsv(scanKeluar)}$delimiter${escapeCsv(statusKedis)}$delimiter${escapeCsv(statusPulang)}$delimiter${escapeCsv(ketPulangCepat)}$delimiter${escapeCsv(ketDinas)}\n";
      }

      final bytes = utf8.encode(csvData);
      final Uint8List uint8List = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...bytes]); 
      
      String employeeName = "Kolektif";
      if (_selectedUserIds.length == 1 && allAtts.isNotEmpty) {
          employeeName = (allAtts.first['nama_lengkap'] ?? 'Karyawan').toString().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      }
      
      String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileName = "Laporan_Absensi_${employeeName}_${currentMonth}_$timeStamp.csv";

      await _downloadFileDirectly(uint8List, fileName);

      if (mounted) {
        setState(() => _selectedUserIds.clear());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menarik data untuk export."), backgroundColor: AppColors.rose500));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // WIDGET TOMBOL EKSPOR HANYA UNTUK LAPORAN ABSENSI (Sesuai Permintaan)
  Widget _buildExportButton() {
    return PopupMenuButton<String>(
      tooltip: "Pilih jenis unduhan",
      enabled: !_isExporting,
      onSelected: (value) {
        if (value == 'absen_pc') _exportAttendanceData(isMobileFormat: false);
        if (value == 'absen_hp') _exportAttendanceData(isMobileFormat: true);
      },
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        const PopupMenuItem(
          enabled: false,
          child: Text("💻 FORMAT EXCEL (Dekstop & Mobile)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400)),
        ),
        PopupMenuItem(
          value: 'absen_pc',
          child: Row(
            children: [
              const Icon(Icons.event_available, color: AppColors.emerald500, size: 16),
              const SizedBox(width: 8),
              Text("Laporan Absen (${_selectedUserIds.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.slate800)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          enabled: false,
          child: Text("📱 FORMAT SPREADSHEET (Mobile & Tablet)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400)),
        ),
        PopupMenuItem(
          value: 'absen_hp',
          child: Row(
            children: [
              const Icon(Icons.event_available, color: AppColors.emerald500, size: 16),
              const SizedBox(width: 8),
              Text("Laporan Absen (${_selectedUserIds.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.slate800)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.emerald500,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.emerald500.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isExporting 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            const Text("UNDUH EXCEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  // HAPUS KARYAWAN
  Future<void> _deleteEmployee(String docId, String nama) async {
    bool confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.rose500),
            SizedBox(width: 8),
            Text(
              "Hapus Karyawan?",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Text(
          "Apakah Anda yakin ingin menghapus data $nama secara permanen?",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.slate600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text(
              "Batal",
              style: TextStyle(
                color: AppColors.slate400,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose500,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              "Hapus Permanen",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().deleteUser(docId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Data berhasil dihapus."),
              backgroundColor: AppColors.emerald500,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Gagal menghapus data."),
              backgroundColor: AppColors.rose500,
            ),
          );
        }
      }
    }
  }

  // FUNGSI BARU: RESET (HAPUS) ABSEN HARI INI UNTUK SIMULASI
  Future<void> _resetAttendance(String docId, String nama) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: const [
            Icon(Icons.history_toggle_off, color: AppColors.amber500),
            SizedBox(width: 8),
            Text("Reset Absen Hari Ini?", style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(
          "Yakin ingin menghapus data absen hari ini untuk $nama? Aksi ini sangat berguna untuk mengulang simulasi absensi.",
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber500,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Reset Absen", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );

    if (confirm == true) {
      try {
        await ApiService().deleteAttendance(docId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Data absen hari ini berhasil direset."),
              backgroundColor: AppColors.emerald500,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Gagal mereset data."),
              backgroundColor: AppColors.rose500,
            ),
          );
        }
      }
    }
  }

  // POPUP FILTER BULAN KHUSUS (Hanya Bulan & Tahun)
  Future<void> _showMonthYearPicker() async {
    DateTime currentDate = DateTime.parse("$_filterMonth-01");
    int selectedYear = currentDate.year;
    int selectedMonth = currentDate.month;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text("Pilih Bulan", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.slate800), textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: AppColors.slate600),
                        onPressed: () => setStateDialog(() => selectedYear--),
                      ),
                      Text(selectedYear.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate800)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: AppColors.slate600),
                        onPressed: () => setStateDialog(() => selectedYear++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: List.generate(12, (index) {
                      int month = index + 1;
                      bool isSelected = month == selectedMonth;
                      return InkWell(
                        onTap: () => setStateDialog(() => selectedMonth = month),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 60,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.yellow500 : AppColors.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? AppColors.yellow500 : AppColors.slate200)
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            DateFormat('MMM', 'id_ID').format(DateTime(2020, month)).toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isSelected ? AppColors.slate900 : AppColors.slate500,
                              fontSize: 10
                            )
                          )
                        )
                      );
                    }),
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("Batal", style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.bold))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    setState(() {
                      _filterMonth = "$selectedYear-${selectedMonth.toString().padLeft(2, '0')}";
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Pilih", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          }
        );
      }
    );
  }

  // EDIT KARYAWAN
  void _editEmployee(String docId, Map<String, dynamic> d) {
    setState(() {
      _isEditing = true;
      _editDocId = docId;
      _namaController.text = d['nama_lengkap'] ?? '';
      _nikController.text = d['nik'] ?? '';
      _emailController.text = d['email'] ?? ''; 
      _kontakController.text = d['kontak'] ?? '';
      _alamatController.text = d['alamat'] ?? '';
      _passController.text = d['password'] ?? '';
      _formRole = d['role'] ?? 'Karyawan';

      _formJenisKelamin = d['jenis_kelamin'] ?? 'Laki-laki';
      if (!_genders.contains(_formJenisKelamin)) {
        _formJenisKelamin = 'Laki-laki';
      }

      _formAgama = d['agama'] ?? 'Islam';

      if (d['tanggal_lahir'] != null) {
        try {
          _formTanggalLahir = DateTime.parse(d['tanggal_lahir']);
        } catch (e) {
          _formTanggalLahir = null;
        }
      }

      _formArea = d['area'] ?? '';
      if (!_areas.contains(_formArea) && _areas.length > 1) {
        _formArea = _areas[1]; 
      }

      _formDepartemen = d['departemen_id'] ?? '';
      if (!_departemens.contains(_formDepartemen) && _departemens.length > 1) {
        _formDepartemen = _departemens[1]; 
      }

      String existJabatan = d['jabatan'] ?? '';
      _updateJabatanList(_formDepartemen, preserveJabatan: existJabatan);

      _formShift = d['shift'] ?? 'Pagi';
      if (!_shifts.contains(_formShift) && _shifts.isNotEmpty) {
        _formShift = _shifts.first;
      }

      _formPhotoBase64 = d['photo_base64'];

      _showForm = true;
    });
  }

  // --- LOGIKA BARU: VALIDASI WAJAH MENGGUNAKAN MLKIT ---
  Future<void> _pickPhoto() async {
    // 1. BLOKIR TOTAL AKSES DARI WEB / DESKTOP (PC/MAC/LAPTOP)
    bool isDesktopOrWeb = kIsWeb || 
                          defaultTargetPlatform == TargetPlatform.windows || 
                          defaultTargetPlatform == TargetPlatform.macOS || 
                          defaultTargetPlatform == TargetPlatform.linux;

    if (isDesktopOrWeb) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.phonelink_erase, color: AppColors.rose500, size: 28),
                SizedBox(width: 12),
                Expanded(child: Text("AKSES DIBLOKIR", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.slate800))),
              ],
            ),
            content: const Text(
              "Mohon maaf, pengunggahan foto profil wajib menggunakan sensor deteksi wajah (AI).\n\nKarena perangkat Desktop/Web tidak mendukung sensor ini, silakan gunakan perangkat Handphone (Android/iOS) untuk mengubah foto profil.",
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600, height: 1.5),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () => Navigator.pop(c),
                  child: const Text("Mengerti", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              )
            ],
          )
        );
      }
      return; // Hentikan eksekusi, galeri file tidak akan terbuka sama sekali
    }

    // 2. JIKA MOBILE (HP), LANJUT BUKA GALERI DAN VALIDASI WAJAH
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery, 
        maxWidth: 600, 
        maxHeight: 600, 
        imageQuality: 80
      );
      
      if (image != null) {
        setState(() => _isAnalyzingPhoto = true); // Munculkan indikator loading
        
        final inputImage = InputImage.fromFilePath(image.path);
        final options = FaceDetectorOptions(
          enableContours: false,
          enableClassification: false,
          enableTracking: false,
        );
        final faceDetector = FaceDetector(options: options);
        final List<Face> faces = await faceDetector.processImage(inputImage);
        await faceDetector.close();
        
        if (mounted) setState(() => _isAnalyzingPhoto = false);

        if (faces.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("❌ Foto ditolak: Tidak ada wajah yang terdeteksi di dalam foto! Harap pilih foto wajah yang jelas."),
              backgroundColor: AppColors.rose500,
              duration: Duration(seconds: 4),
            ));
          }
          return; // Berhenti di sini, jangan set fotonya
        } else if (faces.length > 1) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("❌ Foto ditolak: Terdeteksi lebih dari 1 wajah di dalam foto. Pastikan hanya ada 1 wajah (Foto Karyawan tunggal)."),
              backgroundColor: AppColors.rose500,
              duration: Duration(seconds: 4),
            ));
          }
          return; // Berhenti di sini
        }

        // Jika lolos validasi wajah (1 wajah terdeteksi), ubah ke base64
        final bytes = await image.readAsBytes();
        setState(() {
          _formPhotoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Gagal memilih atau memproses gambar."), 
          backgroundColor: AppColors.rose500
        ));
      }
    }
  }

  // SUBMIT FORM KARYAWAN
  Future<void> _submitKaryawan() async {
    FocusManager.instance.primaryFocus?.unfocus();

    String formNama = _namaController.text.trim();
    String formNik = _nikController.text.trim();
    String formEmail = _emailController.text.trim(); 
    String formKontak = _kontakController.text.trim();
    String formAlamat = _alamatController.text.trim();
    String formPass = _passController.text.trim();

    if (formNama.isEmpty ||
        formNik.isEmpty ||
        formEmail.isEmpty || 
        _formDepartemen.isEmpty ||
        _formJabatan.isEmpty ||
        _formTanggalLahir == null ||
        (_formPhotoBase64 == null || _formPhotoBase64!.isEmpty) || // WAJIB FOTO
        (!_isEditing && formPass.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Harap lengkapi semua field wajib termasuk unggah Foto Profil Wajah!",
          ),
          backgroundColor: AppColors.rose500,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      var existingUser = await ApiService().getUserByNik(formNik);
      bool nikExists = existingUser != null && existingUser['id'].toString() != _editDocId;

      if (nikExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "NRP tersebut sudah terdaftar untuk pengguna lain.",
              ),
              backgroundColor: AppColors.rose500,
            ),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      Map<String, dynamic> payload = {
        'nama_lengkap': formNama,
        'nik': formNik,
        'email': formEmail, 
        'jenis_kelamin': _formJenisKelamin,
        'tanggal_lahir': DateFormat('yyyy-MM-dd').format(_formTanggalLahir!),
        'agama': _formAgama,
        'alamat': formAlamat.isNotEmpty ? formAlamat : '-',
        'kontak': formKontak.isNotEmpty ? formKontak : '-',
        'departemen_id': _formDepartemen,
        'jabatan': _formJabatan,
        'area': _formArea,
      'shift': _formShift,
      'role': _formRole,
    };

    if (_formPhotoBase64 != null && _formPhotoBase64!.isNotEmpty) {
      payload['photo_base64'] = _formPhotoBase64;
    } else if (_isEditing) {
      payload['photo_base64'] = null;
    }

    if (!_isEditing) {
       payload['password'] = formPass;
    }

    if (_isEditing && _editDocId != null) {
        payload['updated_at'] = DateTime.now().toIso8601String();
        await ApiService().updateUser(_editDocId!, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Data Karyawan Berhasil Diperbarui!"),
              backgroundColor: AppColors.emerald500,
            ),
          );
        }
      } else {
        payload['status_karyawan'] = 'Aktif';
        payload['deviceId'] = '';
        payload['created_at'] = DateTime.now().toIso8601String();
        await ApiService().registerUser(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Karyawan Baru Berhasil Ditambahkan!"),
              backgroundColor: AppColors.emerald500,
            ),
          );
        }
      }
      
      _loadData();
      _closeForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal menyimpan data Karyawan."),
            backgroundColor: AppColors.rose500,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdminOrHead =
        widget.user.role == 'admin' || widget.user.role == 'Head Area';
    bool isMobile = MediaQuery.of(context).size.width < 600; 

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Stack(
          children: [
            FutureBuilder<List<dynamic>>(
              future: _attendanceFuture,
              builder: (context, attSnapshot) {
                // Kumpulkan data absen hari ini berdasarkan user_id
                Map<String, Map<String, dynamic>> todayAttMap = {};
                String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                if (attSnapshot.hasData) {
                  for (var data in attSnapshot.data!) {
                    if (data['user_id'] != null && data['date'] == today) {
                      todayAttMap[data['user_id'].toString()] = data as Map<String, dynamic>;
                    }
                  }
                }

                return FutureBuilder<List<dynamic>>(
                  future: _usersFuture,
                  builder: (context, snapshot) {
                    // MENGGUNAKAN _isLoadingConfig UNTUK MENCEGAH LAYAR BERKEDIP KOSONG SAAT LOAD AWAL
                    if (snapshot.connectionState == ConnectionState.waiting || _isLoadingConfig) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(60.0),
                          child: CircularProgressIndicator(
                            color: AppColors.yellow500,
                          ),
                        ),
                      );
                    }

                    // Kumpulkan Dept Head per Area
                    Map<String, String> deptHeadMap = {};
                    if (snapshot.hasData) {
                      for (var data in snapshot.data!) {
                        var d = data as Map<String, dynamic>;
                        if (d['role'] == 'Head Area' && d['area'] != null) {
                          deptHeadMap[d['area'].toString()] = d['nama_lengkap'] ?? 'Tanpa Nama';
                        }
                      }
                    }

                    List<Map<String, dynamic>> employees = [];
                    if (snapshot.hasData) {
                      employees = snapshot.data!.where((data) {
                        var d = data as Map<String, dynamic>;
                        return d['role'] != 'admin';
                      }).map((e) => e as Map<String, dynamic>).toList();
                    }

                    // Filter Area
                    if (_selectedArea.isNotEmpty && _selectedArea != 'Semua Area') {
                      employees = employees
                          .where(
                            (u) =>
                                (u['area'] ?? '') ==
                                _selectedArea,
                          )
                          .toList();
                    }

                    // Filter Departemen
                    if (_selectedDepartemen != 'Semua Departemen') {
                      employees = employees
                          .where(
                            (u) =>
                                (u['departemen_id'] ??
                                    'Umum') ==
                                _selectedDepartemen,
                          )
                          .toList();
                    }

                    // Filter Jenis Kelamin
                    if (_selectedGender != 'Semua Jenis Kelamin') {
                      employees = employees
                          .where(
                            (u) =>
                                (u['jenis_kelamin'] ??
                                    '') ==
                                _selectedGender,
                          )
                          .toList();
                    }

                    // Filter Search
                    if (_searchQuery.isNotEmpty) {
                      employees = employees.where((u) {
                        var d = u;
                        String nm = (d['nama_lengkap'] ?? '')
                            .toString()
                            .toLowerCase();
                        String nk = (d['nik'] ?? '')
                            .toString()
                            .toLowerCase();
                        String q = _searchQuery.toLowerCase();
                        return nm.contains(q) || nk.contains(q);
                      }).toList();
                    }

                    employees.sort((a, b) {
                      var dataA = a;
                      var dataB = b;

                      String jabA = (dataA['jabatan'] ?? '').toString().toLowerCase();
                      String jabB = (dataB['jabatan'] ?? '').toString().toLowerCase();

                      bool isHeadA = dataA['role'] == 'Head Area' || jabA.contains('head');
                      bool isHeadB = dataB['role'] == 'Head Area' || jabB.contains('head');

                      if (isHeadA && !isHeadB) return -1;
                      if (!isHeadA && isHeadB) return 1;

                      String namaA = (dataA['nama_lengkap'] ?? '').toString().toLowerCase();
                      String namaB = (dataB['nama_lengkap'] ?? '').toString().toLowerCase();
                      return namaA.compareTo(namaB);
                    });

                    // Menghitung Statistik Ringkasan
                    int totalLaki = employees
                        .where(
                          (u) =>
                              (u['jenis_kelamin'] ?? '') ==
                              'Laki-laki',
                        )
                        .length;
                    int totalPerempuan = employees
                        .where(
                          (u) =>
                              (u['jenis_kelamin'] ?? '') ==
                              'Perempuan',
                        )
                        .length;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              bool isWide = constraints.maxWidth > 800;
                              return Flex(
                                direction: isWide ? Axis.horizontal : Axis.vertical,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: isWide
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "DATA KARYAWAN",
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.slate900,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          // Filter Bulan (Dipindahkan ke kiri bawah judul)
                                          InkWell(
                                            onTap: _showMonthYearPicker,
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(color: AppColors.slate200),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.calendar_month, size: 14, color: AppColors.slate500),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    DateFormat('MMM yyyy', 'id_ID').format(DateTime.parse("$_filterMonth-01")).toUpperCase(),
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate700, letterSpacing: 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  
                                  if (!isWide) const SizedBox(height: 16),

                                  // Search Bar
                                  Container(
                                    width: isWide ? 250 : constraints.maxWidth,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: AppColors.slate100),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: AppColors.black12,
                                          blurRadius: 10,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      onChanged: (v) =>
                                          setState(() => _searchQuery = v),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.slate800,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: "Cari Nama / NRP...",
                                        hintStyle: TextStyle(
                                          color: AppColors.slate400,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search,
                                          color: AppColors.slate400,
                                          size: 18,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 32),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(color: AppColors.slate100),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 24,
                                  ),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: AppColors.slate100),
                                    ),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      bool isDesktopTab = constraints.maxWidth > 900;

                                      if (isDesktopTab) {
                                        // --- TAMPILAN DESKTOP HEADER DENGAN EXPANDED/WRAP (Mengatasi Overflow) ---
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start, 
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 12.0, bottom: 12.0),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.sort,
                                                    color: AppColors.slate400,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    "DAFTAR KARYAWAN (${employees.length})",
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w900,
                                                      color: AppColors.slate600,
                                                      letterSpacing: 2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 24),
                                            Expanded(
                                              child: Wrap(
                                                alignment: WrapAlignment.end,
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                spacing: 12,
                                                runSpacing: 12,
                                                children: [
                                                  // Dropdown Area
                                                  Container(
                                                    width: 200,
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      border: Border.all(color: AppColors.slate200),
                                                      borderRadius: BorderRadius.circular(24),
                                                      boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4)],
                                                    ),
                                                    child: DropdownButtonHideUnderline(
                                                      child: DropdownButton<String>(
                                                        isExpanded: true,
                                                        value: _areas.contains(_selectedArea) ? _selectedArea : (_areas.isNotEmpty ? _areas.first : null),
                                                        icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate500),
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                                        onChanged: (String? newValue) => setState(() => _selectedArea = newValue!),
                                                        items: _areas.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                                                      ),
                                                    ),
                                                  ),
                                                  // Dropdown Jenis Kelamin
                                                  Container(
                                                    width: 200,
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      border: Border.all(color: AppColors.slate200),
                                                      borderRadius: BorderRadius.circular(24),
                                                      boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4)],
                                                    ),
                                                    child: DropdownButtonHideUnderline(
                                                      child: DropdownButton<String>(
                                                        isExpanded: true,
                                                        value: _genders.contains(_selectedGender) ? _selectedGender : _genders.first,
                                                        icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate500),
                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                                        onChanged: (String? newValue) => setState(() => _selectedGender = newValue!),
                                                        items: _genders.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                                                      ),
                                                    ),
                                                  ),
                                                  // Dropdown Departemen selalu tampil
                                                  Container(
                                                    width: 200,
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      border: Border.all(color: AppColors.slate200),
                                                      borderRadius: BorderRadius.circular(24),
                                                      boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4)],
                                                    ),
                                                    child: DropdownButtonHideUnderline(
                                                      child: DropdownButton<String>(
                                                        isExpanded: true,
                                                        value: _departemens.contains(_selectedDepartemen) ? _selectedDepartemen : _departemens.first,
                                                        icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate500),
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                                        onChanged: (String? newValue) => setState(() => _selectedDepartemen = newValue!),
                                                        items: _departemens.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                                                      ),
                                                    ),
                                                  ),
                                                  
                                                  if (isAdminOrHead) ...[
                                                    _buildExportButton(), // HANYA OPSI UNDUH LAPORAN ABSEN
                                                    ElevatedButton.icon(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: AppColors.yellow500,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                      ),
                                                      onPressed: () {
                                                        _closeForm();
                                                        setState(() => _showForm = true);
                                                      },
                                                      icon: const Icon(Icons.person_add, size: 16, color: AppColors.slate900),
                                                      label: const Text(
                                                        "TAMBAH",
                                                        style: TextStyle(color: AppColors.slate900, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      } else {
                                        // --- TAMPILAN MOBILE HEADER ---
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.sort, color: AppColors.slate400, size: 16),
                                                const SizedBox(width: 12),
                                                Text(
                                                  "DAFTAR KARYAWAN (${employees.length})",
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 2),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(color: AppColors.slate200),
                                                borderRadius: BorderRadius.circular(24),
                                                boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4)],
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  isExpanded: true,
                                                  value: _areas.contains(_selectedArea) ? _selectedArea : (_areas.isNotEmpty ? _areas.first : null),
                                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate500),
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                                  onChanged: (String? newValue) => setState(() => _selectedArea = newValue!),
                                                  items: _areas.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(color: AppColors.slate200),
                                                borderRadius: BorderRadius.circular(24),
                                                boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4)],
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  isExpanded: true,
                                                  value: _genders.contains(_selectedGender) ? _selectedGender : _genders.first,
                                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate500),
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                                  onChanged: (String? newValue) => setState(() => _selectedGender = newValue!),
                                                  items: _genders.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(color: AppColors.slate200),
                                                borderRadius: BorderRadius.circular(24),
                                                boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4)],
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  isExpanded: true,
                                                  value: _departemens.contains(_selectedDepartemen) ? _selectedDepartemen : _departemens.first,
                                                  icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate500),
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                                  onChanged: (String? newValue) => setState(() => _selectedDepartemen = newValue!),
                                                  items: _departemens.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                                                ),
                                              ),
                                            ),

                                            if (isAdminOrHead) ...[
                                              const SizedBox(height: 16),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 12,
                                                children: [
                                                  _buildExportButton(), // HANYA OPSI UNDUH LAPORAN ABSEN
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.yellow500,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                    ),
                                                    onPressed: () {
                                                      _closeForm();
                                                      setState(() => _showForm = true);
                                                    },
                                                    icon: const Icon(Icons.person_add, size: 16, color: AppColors.slate900),
                                                    label: const Text(
                                                      "TAMBAH KARYAWAN",
                                                      style: TextStyle(color: AppColors.slate900, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        );
                                      }
                                    },
                                  ),
                                ),

                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return RawScrollbar(
                                      controller: _tableScrollController,
                                      thumbVisibility: true,
                                      trackVisibility: false, // Melayang
                                      thickness: 6, // Tipis elegan
                                      radius: const Radius.circular(20), // Sangat bulat (pill)
                                      thumbColor: AppColors.slate500.withValues(alpha: 0.6), // Warna abu-abu seperti gambar
                                      child: SingleChildScrollView(
                                        controller: _tableScrollController,
                                        scrollDirection: Axis.horizontal,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minWidth: constraints.maxWidth > 1000
                                                ? constraints.maxWidth
                                                : 1000,
                                          ),
                                          child: DataTable(
                                            headingRowColor: WidgetStateProperty.all(
                                              Colors.white,
                                            ),
                                            headingTextStyle: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.slate400,
                                              letterSpacing: 2,
                                            ),
                                            dividerThickness: 1,
                                            dataRowMaxHeight: 90,
                                            columns: [
                                              const DataColumn(
                                                label: Text('PROFIL KARYAWAN'),
                                              ),
                                              const DataColumn(
                                                label: Text('INFO PERSONAL'),
                                              ),
                                              const DataColumn(
                                                label: Text('POSISI & JABATAN'),
                                              ),
                                              const DataColumn(
                                                label: Text('LOKASI / AREA'),
                                              ),
                                              const DataColumn(
                                                label: Text('KONTAK & EMAIL'),
                                              ),
                                              const DataColumn(
                                                label: Text('ABSEN HARI INI'),
                                              ),
                                              const DataColumn(
                                                label: Text('STATUS'),
                                              ),
                                              if (isAdminOrHead)
                                                const DataColumn(
                                                  label: Text('AKSI'),
                                                ),
                                            ],
                                            rows: employees.map((doc) {
                                              var d = doc;

                                              // Logika Cek Status Absen Hari Ini (dari _todayAttendanceStream)
                                              var attDoc = todayAttMap[doc['id'].toString()];
                                              bool hasAttended = attDoc != null;
                                              var attData = hasAttended ? attDoc : null;
                                              String jamMasuk = hasAttended ? (attData!['jam_masuk'] ?? '--:--') : '--:--';
                                              String jamPulang = hasAttended ? (attData!['jam_pulang'] ?? '--:--') : '--:--';

                                              String tglLahir = '-';
                                              if (d['tanggal_lahir'] != null &&
                                                  d['tanggal_lahir']
                                                      .toString()
                                                      .isNotEmpty) {
                                                try {
                                                  tglLahir =
                                                      DateFormat(
                                                        'dd MMM yyyy',
                                                        'id_ID',
                                                      ).format(
                                                        DateTime.parse(
                                                          d['tanggal_lahir'],
                                                        ),
                                                      );
                                                } catch (e) {
                                                  tglLahir = d['tanggal_lahir'];
                                                }
                                              }

                                              return DataRow(
                                                selected: _selectedUserIds.contains(
                                                  doc['id'].toString(),
                                                ),
                                                onSelectChanged: isAdminOrHead
                                                    ? (val) {
                                                        setState(() {
                                                          if (val == true) {
                                                            _selectedUserIds.add(
                                                              doc['id'].toString(),
                                                            );
                                                          } else {
                                                            _selectedUserIds.remove(
                                                              doc['id'].toString(),
                                                            );
                                                          }
                                                        });
                                                      }
                                                    : null,
                                                cells: [
                                                  DataCell(
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          (d['nama_lengkap'] ??
                                                                  'Tanpa Nama')
                                                              .toString()
                                                              .toUpperCase(),
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            fontSize: 13,
                                                            color: AppColors.slate800,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          d['nik'] ?? '-',
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                AppColors.indigo500,
                                                            fontFamily: 'monospace',
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          (d['jenis_kelamin'] ?? '-')
                                                              .toString()
                                                              .toUpperCase(),
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            color: AppColors.slate800,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          tglLahir,
                                                          style: const TextStyle(
                                                            fontSize: 10,
                                                            color: AppColors.slate500,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          (d['departemen_id'] ??
                                                                  'UMUM')
                                                              .toString()
                                                              .toUpperCase(),
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            color: AppColors.slate800,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          (d['jabatan'] ?? 'STAFF')
                                                              .toString()
                                                              .toUpperCase(),
                                                          style: const TextStyle(
                                                            fontSize: 10,
                                                            color: AppColors.slate500,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 10,
                                                                vertical: 6,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.slate100,
                                                            border: Border.all(
                                                              color: AppColors.slate200,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(12),
                                                          ),
                                                          child: Text(
                                                            (d['area'] ?? 'Belum Diatur')
                                                                .toString()
                                                                .toUpperCase(),
                                                            style: const TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w900,
                                                              color: AppColors.slate600,
                                                              letterSpacing: 1,
                                                            ),
                                                          ),
                                                        ),
                                                      ]
                                                    )
                                                  ),
                                                  DataCell(
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          d['kontak'] ?? '-',
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.slate800,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          d['email'] ?? '-',
                                                          style: const TextStyle(
                                                            fontSize: 10,
                                                            color: AppColors.slate500,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(hasAttended ? Icons.check_circle : Icons.cancel, size: 14, color: hasAttended ? AppColors.emerald500 : AppColors.rose500),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              hasAttended ? (attData!['status_kehadiran']?.toString().toUpperCase() ?? 'HADIR') : "BELUM ABSEN", 
                                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: hasAttended ? AppColors.emerald600 : AppColors.rose600)
                                                            ),
                                                          ]
                                                        ),
                                                        if (hasAttended) ...[
                                                          const SizedBox(height: 4),
                                                          Text("IN: $jamMasuk | OUT: $jamPulang", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate500)),
                                                          if (attData!['keterangan'] != null && attData['keterangan'].toString().contains("Pulang Cepat"))
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 2),
                                                              child: Text(attData['keterangan'].toString().replaceAll("Pulang Cepat: ", ""), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: AppColors.slate400, fontStyle: FontStyle.italic)),
                                                            )
                                                        ]
                                                      ]
                                                    )
                                                  ),
                                                  DataCell(
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.emerald50,
                                                        border: Border.all(
                                                          color: AppColors.emerald200,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        (d['status_karyawan'] ??
                                                                "AKTIF")
                                                            .toString()
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w900,
                                                          color: AppColors.emerald600,
                                                          letterSpacing: 1,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (isAdminOrHead)
                                                    DataCell(
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          if (hasAttended)
                                                            IconButton(
                                                              icon: const Icon(
                                                                Icons.history_toggle_off,
                                                                size: 20,
                                                                color: AppColors.amber500,
                                                              ),
                                                              tooltip: "Reset Absen Hari Ini (Simulasi)",
                                                              style: IconButton.styleFrom(
                                                                backgroundColor: AppColors.amber50,
                                                              ),
                                                              onPressed: () => _resetAttendance(
                                                                attDoc!['id'].toString(),
                                                                d['nama_lengkap'] ?? 'User',
                                                              ),
                                                            ),
                                                          if (hasAttended) const SizedBox(width: 8),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.edit,
                                                              size: 20,
                                                              color:
                                                                  AppColors.blue500,
                                                            ),
                                                            tooltip: "Edit Karyawan",
                                                            style:
                                                                IconButton.styleFrom(
                                                                  backgroundColor:
                                                                      AppColors
                                                                          .blue50,
                                                                ),
                                                            onPressed: () =>
                                                                _editEmployee(
                                                                  doc['id'].toString(),
                                                                  d,
                                                                ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.delete,
                                                              size: 20,
                                                              color:
                                                                  AppColors.rose500,
                                                            ),
                                                            tooltip: "Hapus Karyawan",
                                                            style:
                                                                IconButton.styleFrom(
                                                                  backgroundColor:
                                                                      AppColors
                                                                          .rose50,
                                                                ),
                                                            onPressed: () =>
                                                                _deleteEmployee(
                                                                  doc['id'].toString(),
                                                                  d['nama_lengkap'] ??
                                                                      'User',
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // STATISTIK RINGKASAN BAWAH (PANAH DIHAPUS)
                                if (employees.isNotEmpty) ...[
                                  const Divider(
                                    height: 1,
                                    color: AppColors.slate100,
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 16 : 32,
                                      vertical: 16,
                                    ),
                                    color: AppColors.slate50,
                                    width: double.infinity,
                                    child: Wrap(
                                      alignment: isMobile
                                          ? WrapAlignment.center
                                          : WrapAlignment.end,
                                      spacing: 24,
                                      runSpacing: 12,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.people,
                                              size: 14,
                                              color: AppColors.slate500,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              "TOTAL KARYAWAN: ${employees.length}",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.slate700,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.male,
                                              size: 14,
                                              color: AppColors.blue500,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              "LAKI-LAKI: $totalLaki",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.blue500,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.female,
                                              size: 14,
                                              color: AppColors.rose500,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              "PEREMPUAN: $totalPerempuan",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.rose600,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            // FORM MODAL TAMBAH/EDIT KARYAWAN
            if (_showForm) _buildFormModal(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildFormModal(bool isMobile) {
    List<String> assignableAreas = _areas.where((a) => a != 'Semua Area').toList();
    if (assignableAreas.isEmpty) assignableAreas = _areas;
    String? dropdownAreaValue = assignableAreas.contains(_formArea)
        ? _formArea
        : (assignableAreas.isNotEmpty ? assignableAreas.first : null);

    List<String> assignableDeps = _departemens.where((d) => d != 'Semua Departemen').toList();
    String? dropdownDepValue = assignableDeps.contains(_formDepartemen)
        ? _formDepartemen
        : (assignableDeps.isNotEmpty ? assignableDeps.first : null);

    List<String> assignableJabs = _jabatans.where((j) => j != 'Semua Jabatan').toList();
    String? dropdownJabValue = assignableJabs.contains(_formJabatan)
        ? _formJabatan
        : (assignableJabs.isNotEmpty ? assignableJabs.first : null);

    return Container(
      color: AppColors.slate900.withValues(alpha: 0.8),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: EdgeInsets.all(isMobile ? 24 : 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isMobile ? 32 : 48),
              boxShadow: const [
                BoxShadow(color: AppColors.black12, blurRadius: 20),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? "EDIT KARYAWAN" : "TAMBAH KARYAWAN",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _closeForm(),
                      icon: const Icon(Icons.close, color: AppColors.slate400),
                      tooltip: "Tutup",
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                Center(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.slate100,
                            backgroundImage: _formPhotoBase64 != null && _formPhotoBase64!.isNotEmpty && !_isAnalyzingPhoto
                                ? MemoryImage(base64Decode(_formPhotoBase64!))
                                : null,
                            child: _isAnalyzingPhoto 
                                ? const CircularProgressIndicator(color: AppColors.yellow500)
                                : (_formPhotoBase64 == null || _formPhotoBase64!.isEmpty
                                    ? const Icon(Icons.person, size: 50, color: AppColors.slate400)
                                    : null),
                          ),
                          InkWell(
                            onTap: _isAnalyzingPhoto ? null : _pickPhoto,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.yellow500,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 16, color: AppColors.slate900),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text("FOTO PROFIL WAJAH", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 1)),
                      if (_formPhotoBase64 != null && _formPhotoBase64!.isNotEmpty)
                        TextButton(
                          onPressed: () => setState(() => _formPhotoBase64 = null),
                          child: const Text("Hapus Foto", style: TextStyle(color: AppColors.rose500, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // BARIS 1: NAMA & NRP
                isMobile
                    ? Column(
                        children: [
                          _buildInputCol(
                            "NAMA LENGKAP",
                            TextField(
                              textInputAction: TextInputAction.next,
                              controller: _namaController,
                              decoration: _inputDeco("Nama Lengkap"),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInputCol(
                            "NRP (NIK)",
                            TextField(
                              textInputAction: TextInputAction.next,
                              controller: _nikController,
                              decoration: _inputDeco("NRP-XXX"),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _buildInputCol(
                              "NAMA LENGKAP",
                              TextField(
                                textInputAction: TextInputAction.next,
                                controller: _namaController,
                                decoration: _inputDeco("Nama Lengkap"),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInputCol(
                              "NRP (NIK)",
                              TextField(
                                textInputAction: TextInputAction.next,
                                controller: _nikController,
                                decoration: _inputDeco("NRP-XXX"),
                              ),
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 16),
                
                // BARIS 2: JENIS KELAMIN & TANGGAL LAHIR
                isMobile 
                  ? Column(
                      children: [
                        _buildInputCol("JENIS KELAMIN", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _formJenisKelamin, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Laki-laki', 'Perempuan'].map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formJenisKelamin = v!),
                        )),
                        const SizedBox(height: 16),
                        _buildInputCol("TANGGAL LAHIR", InkWell(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context, initialDate: _formTanggalLahir ?? DateTime(1980), firstDate: DateTime(1950), lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _formTanggalLahir = picked);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formTanggalLahir != null ? DateFormat('dd MMMM yyyy', 'id_ID').format(_formTanggalLahir!) : "Pilih Tanggal", style: TextStyle(fontWeight: FontWeight.bold, color: _formTanggalLahir != null ? AppColors.slate800 : AppColors.slate400)),
                                const Icon(Icons.calendar_today, size: 16, color: AppColors.slate400),
                              ],
                            ),
                          ),
                        )),
                      ]
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildInputCol("JENIS KELAMIN", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _formJenisKelamin, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Laki-laki', 'Perempuan'].map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formJenisKelamin = v!),
                        ))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInputCol("TANGGAL LAHIR", InkWell(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context, initialDate: _formTanggalLahir ?? DateTime(1980), firstDate: DateTime(1950), lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _formTanggalLahir = picked);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formTanggalLahir != null ? DateFormat('dd MMMM yyyy', 'id_ID').format(_formTanggalLahir!) : "Pilih Tanggal", style: TextStyle(fontWeight: FontWeight.bold, color: _formTanggalLahir != null ? AppColors.slate800 : AppColors.slate400)),
                                const Icon(Icons.calendar_today, size: 16, color: AppColors.slate400),
                              ],
                            ),
                          ),
                        ))),
                      ],
                    ),
                const SizedBox(height: 16),

                // BARIS 3: AGAMA & NO. TELP
                isMobile 
                  ? Column(
                      children: [
                        _buildInputCol("AGAMA", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _formAgama, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'].map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formAgama = v!),
                        )),
                        const SizedBox(height: 16),
                        _buildInputCol("NO. TELEPON", TextField(textInputAction: TextInputAction.next, keyboardType: TextInputType.phone, controller: _kontakController, decoration: _inputDeco("No. HP Aktif"))),
                      ]
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildInputCol("AGAMA", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _formAgama, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'].map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formAgama = v!),
                        ))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInputCol("NO. TELEPON", TextField(textInputAction: TextInputAction.next, keyboardType: TextInputType.phone, controller: _kontakController, decoration: _inputDeco("No. HP Aktif")))),
                      ],
                    ),
                const SizedBox(height: 16),

                // BARIS 4: EMAIL & ALAMAT LENGKAP
                isMobile 
                  ? Column(
                      children: [
                        _buildInputCol("ALAMAT EMAIL", TextField(textInputAction: TextInputAction.next, keyboardType: TextInputType.emailAddress, controller: _emailController, decoration: _inputDeco("email@karyawan.com"))),
                        const SizedBox(height: 16),
                        _buildInputCol("ALAMAT LENGKAP", TextField(textInputAction: TextInputAction.next, maxLines: 2, controller: _alamatController, decoration: _inputDeco("Alamat Lengkap Karyawan"))),
                      ]
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildInputCol("ALAMAT EMAIL", TextField(textInputAction: TextInputAction.next, keyboardType: TextInputType.emailAddress, controller: _emailController, decoration: _inputDeco("email@karyawan.com")))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInputCol("ALAMAT LENGKAP", TextField(textInputAction: TextInputAction.next, maxLines: 2, controller: _alamatController, decoration: _inputDeco("Alamat Lengkap Karyawan")))),
                      ],
                    ),
                const SizedBox(height: 16),
                
                // BARIS 5: DEPARTEMEN & JABATAN
                isMobile 
                  ? Column(
                      children: [
                        _buildInputCol("DEPARTEMEN / DIVISI", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownDepValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: assignableDeps.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _formDepartemen = v!;
                              _updateJabatanList(v); // Auto filter jabatan
                            });
                          },
                        )),
                        const SizedBox(height: 16),
                        _buildInputCol("JABATAN / POSISI", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownJabValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: assignableJabs.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formJabatan = v!),
                        )),
                      ]
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildInputCol("DEPARTEMEN / DIVISI", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownDepValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: assignableDeps.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _formDepartemen = v!;
                              _updateJabatanList(v); // Auto filter jabatan
                            });
                          },
                        ))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInputCol("JABATAN / POSISI", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownJabValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: assignableJabs.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formJabatan = v!),
                        ))),
                      ],
                    ),
                const SizedBox(height: 16),

                // BARIS 6: AREA PENUGASAN & KATA SANDI (KATA SANDI HANYA MUNCUL JIKA TAMBAH BARU / !_isEditing)
                isMobile
                  ? Column(
                      children: [
                        _buildInputCol("AREA PENUGASAN (SITE)", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownAreaValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: assignableAreas.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _formArea = v!;
                            });
                          },
                        )),
                        if (!_isEditing) ...[
                           const SizedBox(height: 16),
                           _buildInputCol("KATA SANDI BARU", TextField(textInputAction: TextInputAction.done, onSubmitted: (_) => _submitKaryawan(), controller: _passController, obscureText: true, decoration: _inputDeco("Kata Sandi Rahasia (Diperlukan untuk login)"))),
                        ]
                      ]
                    )
                  : (!_isEditing) 
                      ? Row(
                          children: [
                            Expanded(child: _buildInputCol("AREA PENUGASAN (SITE)", DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: dropdownAreaValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                              items: assignableAreas.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _formArea = v!;
                                });
                              },
                            ))),
                            const SizedBox(width: 16),
                            Expanded(child: _buildInputCol("KATA SANDI BARU", TextField(textInputAction: TextInputAction.done, onSubmitted: (_) => _submitKaryawan(), controller: _passController, obscureText: true, decoration: _inputDeco("Kata Sandi Rahasia (Diperlukan untuk login)")))),
                          ],
                        )
                      : _buildInputCol("AREA PENUGASAN (SITE)", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownAreaValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: assignableAreas.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _formArea = v!;
                            });
                          },
                        )),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.slate900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 10,
                      shadowColor: AppColors.slate900.withValues(alpha: 0.3),
                    ),
                    onPressed: _isSubmitting ? null : _submitKaryawan,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            _isEditing
                                ? "SIMPAN PERUBAHAN DATA"
                                : "SIMPAN DATA KARYAWAN",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputCol(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: AppColors.slate500,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.yellow500, width: 2),
      ),
    );
  }
}
