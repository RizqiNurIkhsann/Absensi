import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../core/app_constants.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:path_provider/path_provider.dart'; 
import 'dart:io' as io;
import 'package:share_plus/share_plus.dart'; 
import 'package:file_saver/file_saver.dart'; 

class AdminDeptHeadView extends StatefulWidget {
  const AdminDeptHeadView({super.key});

  @override
  State<AdminDeptHeadView> createState() => _AdminDeptHeadViewState();
}

class _AdminDeptHeadViewState extends State<AdminDeptHeadView> {
  bool _showForm = false;
  bool _isSubmitting = false;
  
  bool _isEditing = false;
  String? _editDocId;
  Key _refreshKey = UniqueKey();

  final ScrollController _tableScrollController = ScrollController();

  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); 
  final TextEditingController _kontakController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();
  final TextEditingController _passController = TextEditingController(); 

  String _formDepartemen = 'Manajemen Site';
  String _formJabatan = 'Head Area';
  String _formArea = 'Semua Area'; 
  String _formJenisKelamin = 'Laki-laki';
  DateTime? _formTanggalLahir;
  String _formAgama = 'Islam';

  String _selectedAreaFilter = 'Semua Area';

  List<String> _availableAreas = ['Semua Area']; 
  List<String> _departemens = ['Manajemen Site', 'Umum'];
  List<String> _jabatans = ['Head Area', 'Manajer'];
  List<Map<String, dynamic>> _strukturOrganisasi = [];

  final List<String> _selectedUserIds = [];

  @override
  void initState() {
    super.initState();
    _fetchConfigs();
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
    });
  }

  Future<void> _fetchConfigs() async {
    try {
      var dataSite = await ApiService().getConfigSite();
      var dataGen = await ApiService().getConfigGeneral();
          
      if (dataSite != null || dataGen != null) {
        var data = {...(dataSite ?? {}), ...(dataGen ?? {})};
        List<dynamic> locs = data['locations'] ?? [];
        
        if (mounted) {
          setState(() {
            if (locs.isNotEmpty) {
              Set<String> areaSet = locs.map((e) => e['siteName'].toString()).toSet();
              areaSet.remove('Semua Area'); 
              List<String> sortedAreas = areaSet.toList();
              sortedAreas.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              
              _availableAreas = ['Semua Area', ...sortedAreas]; 
              if (sortedAreas.isNotEmpty && !_availableAreas.contains(_formArea)) _formArea = sortedAreas.first;
            } else {
              _availableAreas = ['Semua Area'];
              _formArea = 'Semua Area';
            }
            
            if (data.containsKey('struktur_organisasi')) {
               _strukturOrganisasi = List<Map<String, dynamic>>.from(data['struktur_organisasi']);
               Set<String> depSet = _strukturOrganisasi.map((e) => e['departemen'].toString()).toSet();
               List<String> sortedDeps = depSet.toList();
               sortedDeps.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
               
               _departemens = sortedDeps.isNotEmpty ? sortedDeps : ['Umum'];
               if (sortedDeps.isNotEmpty && !_departemens.contains(_formDepartemen)) {
                 _formDepartemen = sortedDeps.first;
               }
               _updateJabatanList(_formDepartemen);
            } else {
               List<dynamic> depsData = data['departemens'] ?? ['Umum', 'Manajemen Site', 'Maintenance'];
               List<dynamic> jabsData = data['jabatans'] ?? ['Staff', 'Supervisor', 'Manajer', 'Head Area'];
               
               List<String> sortedDeps = depsData.map((e) => e.toString()).toList();
               sortedDeps.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
               _departemens = sortedDeps.isNotEmpty ? sortedDeps : ['Umum'];
               if (sortedDeps.isNotEmpty && !_departemens.contains(_formDepartemen)) _formDepartemen = sortedDeps.first;
               
               List<String> sortedJabs = jabsData.map((e) => e.toString()).toList();
               sortedJabs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
               _jabatans = sortedJabs.isNotEmpty ? sortedJabs : ['Staff'];
               if (sortedJabs.isNotEmpty && !_jabatans.contains(_formJabatan)) _formJabatan = sortedJabs.first;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal fetch config: $e");
    }
  }

  void _updateJabatanList(String departemen, {String? preserveJabatan}) {
      if (_strukturOrganisasi.isEmpty) return;
      var relatedJabs = _strukturOrganisasi.where((e) => e['departemen'] == departemen).map((e) => e['jabatan'].toString()).toSet().toList();
      relatedJabs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
          _jabatans = relatedJabs.isNotEmpty ? relatedJabs : ['Staff'];
          if (preserveJabatan != null && _jabatans.contains(preserveJabatan)) {
             _formJabatan = preserveJabatan;
          } else if (_jabatans.isNotEmpty) {
             if (!relatedJabs.contains(_formJabatan)) _formJabatan = relatedJabs.first;
          } else {
             _formJabatan = '';
          }
      });
  }

  Future<void> _submitDeptHead() async {
    FocusManager.instance.primaryFocus?.unfocus();

    String formNamaLengkap = _namaController.text.trim();
    String formNik = _nikController.text.trim();
    String formEmail = _emailController.text.trim(); 
    String formKontak = _kontakController.text.trim();
    String formAlamat = _alamatController.text.trim();
    String formPass = _passController.text.trim();

    if (formNamaLengkap.isEmpty || formNik.isEmpty || formEmail.isEmpty || _formDepartemen.isEmpty || _formJabatan.isEmpty || _formTanggalLahir == null || (!_isEditing && formPass.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap lengkapi semua field wajib (termasuk kata sandi baru)!"), backgroundColor: AppColors.rose500));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      var userByNik = await ApiService().getUserByNik(formNik);
      bool nikExists = userByNik != null && userByNik['id'].toString() != _editDocId;
      if (nikExists) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("NRP tersebut sudah terdaftar untuk pengguna lain."), backgroundColor: AppColors.rose500));
        setState(() => _isSubmitting = false); return;
      }

      Map<String, dynamic> payload = {
        'nama_lengkap': formNamaLengkap, 'nik': formNik, 'email': formEmail, 'jenis_kelamin': _formJenisKelamin, 'tanggal_lahir': DateFormat('yyyy-MM-dd').format(_formTanggalLahir!),
        'agama': _formAgama, 'alamat': formAlamat.isNotEmpty ? formAlamat : '-', 'kontak': formKontak.isNotEmpty ? formKontak : '-', 'departemen_id': _formDepartemen,
        'jabatan': _formJabatan, 'area': _formArea.isNotEmpty ? _formArea : 'Semua Area', 'role': 'Head Area',
      };

      if (!_isEditing && formPass.isNotEmpty) {
         payload['password'] = formPass;
      }

      if (_isEditing && _editDocId != null) {
        payload['updated_at'] = DateTime.now().toIso8601String();
        await ApiService().updateUser(_editDocId!, payload);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Perubahan Berhasil Disimpan!"), backgroundColor: AppColors.emerald500));
      } else {
        payload['status_karyawan'] = 'Aktif'; payload['deviceId'] = ''; payload['created_at'] = DateTime.now().toIso8601String();
        await ApiService().registerUser(payload);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data Admin Area Berhasil Ditambahkan!"), backgroundColor: AppColors.emerald500));
      }
      _closeForm();
      setState(() => _refreshKey = UniqueKey());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menyimpan data Admin Area."), backgroundColor: AppColors.rose500));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteDeptHead(String docId, String nama) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), backgroundColor: Colors.white,
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: AppColors.rose500), SizedBox(width: 8), Text("Hapus Data?", style: TextStyle(fontWeight: FontWeight.w900))]),
        content: Text("Apakah Anda yakin ingin menghapus data $nama secara permanen?", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.pop(c, true), child: const Text("Hapus Permanen", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
        ],
      )
    );

    if (confirm == true) {
      try {
        await ApiService().deleteUser(docId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data berhasil dihapus."), backgroundColor: AppColors.emerald500));
          setState(() => _refreshKey = UniqueKey());
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menghapus data."), backgroundColor: AppColors.rose500));
      }
    }
  }

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Data absen hari ini berhasil direset."),
              backgroundColor: AppColors.emerald500,
            ),
          );
          setState(() => _refreshKey = UniqueKey());
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
              content: Text("✅ File Excel berhasil diunduh."),
              backgroundColor: AppColors.emerald500,
              duration: Duration(seconds: 3),
           ));
        }
        return;
      } 
      
      if (io.Platform.isAndroid) {
        final String downloadPath = '/storage/emulated/0/Download/$fileName';
        final file = io.File(downloadPath);
        await file.writeAsBytes(bytes);
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("✅ Berhasil! File langsung tersimpan di folder Download perangkat."),
              backgroundColor: AppColors.emerald500,
              duration: const Duration(seconds: 5),
           ));
        }
        return;
      }

      if (io.Platform.isIOS) {
        final xFile = XFile.fromData(bytes, mimeType: 'text/csv', name: fileName);
        await Share.shareXFiles([xFile]);
        return;
      }

      io.Directory? directory;
      if (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux) {
        directory = await getDownloadsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final filePath = '${directory?.path ?? ''}/$fileName';
      final file = io.File(filePath);
      await file.writeAsBytes(bytes);
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("✅ File Excel berhasil diunduh ke: $filePath"),
            backgroundColor: AppColors.emerald500,
            duration: const Duration(seconds: 5),
         ));
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Gagal menyimpan file. Pastikan izin penyimpanan aktif.\nError: $e"),
            backgroundColor: AppColors.rose500,
            duration: const Duration(seconds: 5),
         ));
      }
    }
  }

  Future<void> _exportAttendanceData({required bool isMobileFormat}) async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pilih minimal 1 Admin Area (centang kotak) untuk mengunduh absensinya."),
          backgroundColor: AppColors.rose500,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String currentMonth = DateFormat('yyyy-MM').format(DateTime.now()); 
      List<dynamic> attendanceHistory = await ApiService().getAttendanceHistory();
      List<Map<String, dynamic>> allAtts = attendanceHistory
          .map((e) => Map<String, dynamic>.from(e))
          .where((d) => _selectedUserIds.contains(d['user_id']?.toString()) && d['date'] != null && d['date'].toString().startsWith(currentMonth))
          .toList();

      if (allAtts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tidak ada data kehadiran di bulan ini untuk pengguna yang dipilih."), backgroundColor: AppColors.amber500),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

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

        // IDENTIFIKASI PERJALANAN DINAS WALAUPUN STATUS KETIMPA JADI PULANG CEPAT
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
          employeeName = (allAtts.first['nama_lengkap'] ?? 'Admin').toString().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildExportButton() {
    return PopupMenuButton<String>(
      tooltip: "Pilih jenis unduhan",
      enabled: !_isSubmitting,
      onSelected: (value) {
        if (value == 'absen_pc') _exportAttendanceData(isMobileFormat: false);
        if (value == 'absen_hp') _exportAttendanceData(isMobileFormat: true);
      },
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        const PopupMenuItem(
          enabled: false,
          child: Text("💻 FORMAT DESKTOP (EXCEL PC)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400)),
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
          child: Text("📱 FORMAT MOBILE (HP/TABLET)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400)),
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
            _isSubmitting 
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

  void _editDeptHead(String docId, Map<String, dynamic> d) {
    setState(() {
      _isEditing = true; _editDocId = docId; _namaController.text = d['nama_lengkap'] ?? ''; _nikController.text = d['nik'] ?? ''; _emailController.text = d['email'] ?? ''; _kontakController.text = d['kontak'] ?? ''; _alamatController.text = d['alamat'] ?? ''; _passController.text = d['password'] ?? '';
      
      _formJenisKelamin = d['jenis_kelamin'] ?? 'Laki-laki'; 
      if (!['Laki-laki', 'Perempuan'].contains(_formJenisKelamin)) _formJenisKelamin = 'Laki-laki';
      
      _formAgama = d['agama'] ?? 'Islam';
      if (d['tanggal_lahir'] != null) { try { _formTanggalLahir = DateTime.parse(d['tanggal_lahir']); } catch(e) { _formTanggalLahir = null; } }
      _formArea = d['area'] ?? ''; if (!_availableAreas.contains(_formArea) && _availableAreas.isNotEmpty) _formArea = _availableAreas.first;
      _formDepartemen = d['departemen_id'] ?? ''; if (!_departemens.contains(_formDepartemen) && _departemens.isNotEmpty) _formDepartemen = _departemens.first;
      String existJabatan = d['jabatan'] ?? ''; _updateJabatanList(_formDepartemen, preserveJabatan: existJabatan);
      _showForm = true;
    });
  }

  Widget _buildAddButton() {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(horizontal: 20)),
        onPressed: () { _closeForm(); setState(() => _showForm = true); },
        icon: const Icon(Icons.person_add, size: 16, color: AppColors.slate900), label: const Text("TAMBAH", style: TextStyle(color: AppColors.slate900, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("DATA ADMIN AREA", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: -0.5)),
              const SizedBox(height: 32),
              
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), border: Border.all(color: AppColors.slate100), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10)]),
                clipBehavior: Clip.antiAlias,
                child: FutureBuilder<List<dynamic>>(
                  key: _refreshKey,
                  future: Future.wait([
                    ApiService().getAttendanceHistory(),
                    ApiService().getUsers(),
                  ]),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(60.0), child: Center(child: CircularProgressIndicator(color: AppColors.emerald500)));

                    List<dynamic> allAttendance = snapshot.hasData ? snapshot.data![0] as List<dynamic> : [];
                    List<dynamic> allUsers = snapshot.hasData ? snapshot.data![1] as List<dynamic> : [];

                    Map<String, Map<String, dynamic>> attendedUserRecords = {};
                    for (var doc in allAttendance) {
                      var d = Map<String, dynamic>.from(doc);
                      if (d['date'] == todayStr && d['user_id'] != null) {
                        attendedUserRecords[d['user_id'].toString()] = {'id': d['id']?.toString() ?? '', ...d};
                      }
                    }

                    List<Map<String, dynamic>> users = allUsers.map((e) => Map<String, dynamic>.from(e)).where((u) => u['role'] == 'Head Area').toList();
                    users.sort((a, b) => (a['nama_lengkap'] ?? '').toString().toLowerCase().compareTo((b['nama_lengkap'] ?? '').toString().toLowerCase()));

                    List<Map<String, dynamic>> displayedUsers = users.where((d) {
                      bool matchArea = _selectedAreaFilter == 'Semua Area' || (d['area'] ?? '') == _selectedAreaFilter;
                      return matchArea;
                    }).toList();

                    int totalLaki = displayedUsers.where((u) => (u['jenis_kelamin'] ?? '') == 'Laki-laki').length;
                    int totalPerempuan = displayedUsers.where((u) => (u['jenis_kelamin'] ?? '') == 'Perempuan').length;

                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate100))),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  bool isDesktopTab = constraints.maxWidth > 800;

                                  if (isDesktopTab) {
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.sort, color: AppColors.slate400, size: 20),
                                            const SizedBox(width: 12),
                                            Text("DAFTAR ADMIN AREA (${displayedUsers.length})", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 2)),
                                          ]
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                               width: 250, height: 46, padding: const EdgeInsets.symmetric(horizontal: 16),
                                               decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4)]),
                                               child: DropdownButtonHideUnderline(
                                                 child: DropdownButton<String>(
                                                   isExpanded: true, value: _availableAreas.contains(_selectedAreaFilter) ? _selectedAreaFilter : (_availableAreas.isNotEmpty ? _availableAreas.first : null),
                                                   icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate500), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                                   onChanged: (String? newValue) => setState(() => _selectedAreaFilter = newValue!),
                                                   items: _availableAreas.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                                                 ),
                                               ),
                                            ),
                                            const SizedBox(width: 16),
                                            _buildExportButton(), 
                                            const SizedBox(width: 12),
                                            _buildAddButton(),
                                          ],
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.sort, color: AppColors.slate400, size: 16),
                                            const SizedBox(width: 12),
                                            Text("DAFTAR ADMIN AREA (${displayedUsers.length})", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 2)),
                                          ]
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                 height: 46, padding: const EdgeInsets.symmetric(horizontal: 16),
                                                 decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4)]),
                                                 child: DropdownButtonHideUnderline(
                                                   child: DropdownButton<String>(
                                                     isExpanded: true, value: _availableAreas.contains(_selectedAreaFilter) ? _selectedAreaFilter : (_availableAreas.isNotEmpty ? _availableAreas.first : null),
                                                     icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate500), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                                     onChanged: (String? newValue) => setState(() => _selectedAreaFilter = newValue!),
                                                     items: _availableAreas.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                                                   ),
                                                  ),
                                              ),
                                            ),
                                          ]
                                        ),
                                        const SizedBox(height: 16),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: [
                                            _buildExportButton(), 
                                            _buildAddButton(),
                                          ],
                                        )
                                      ]
                                    );
                                  }
                                }
                              )
                            ),
                            
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return RawScrollbar(
                                  controller: _tableScrollController,
                                  thumbVisibility: true,
                                  trackVisibility: false,
                                  thickness: 6,
                                  radius: const Radius.circular(20),
                                  thumbColor: AppColors.slate500.withValues(alpha: 0.6),
                                  child: SingleChildScrollView(
                                    controller: _tableScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth > 1000 ? constraints.maxWidth : 1000),
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(Colors.white),
                                        headingTextStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 2),
                                        dividerThickness: 1,
                                        dataRowMaxHeight: 90,
                                        columns: const [
                                          DataColumn(label: Text('PROFIL ADMIN AREA')),
                                          DataColumn(label: Text('INFO PERSONAL')),
                                          DataColumn(label: Text('POSISI & JABATAN')),
                                          DataColumn(label: Text('LOKASI / AREA')),
                                          DataColumn(label: Text('KONTAK & EMAIL')),
                                          DataColumn(label: Text('STATUS')),
                                          DataColumn(label: Text('ABSEN HARI INI')),
                                          DataColumn(label: Text('AKSI')),
                                        ],
                                        rows: displayedUsers.map((doc) {
                                          var d = doc.data() as Map<String, dynamic>;
                                          String docId = doc.id;

                                          String tglLahir = '-';
                                          if (d['tanggal_lahir'] != null && d['tanggal_lahir'].toString().isNotEmpty) {
                                            try { tglLahir = DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(d['tanggal_lahir'])); } catch (e) { tglLahir = d['tanggal_lahir']; }
                                          }

                                          bool hasAttended = attendedUserRecords.containsKey(docId);
                                          String? attDocId = hasAttended ? attendedUserRecords[docId]!['id'] : null;

                                          return DataRow(
                                            selected: _selectedUserIds.contains(docId),
                                            onSelectChanged: (val) {
                                              setState(() { if (val == true) { _selectedUserIds.add(docId); } else { _selectedUserIds.remove(docId); } });
                                            },
                                            cells: [
                                              DataCell(Column(
                                                crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text((d['nama_lengkap'] ?? 'Tanpa Nama').toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.slate800)),
                                                  const SizedBox(height: 4), Text(d['nik'] ?? '-', style: const TextStyle(fontSize: 11, color: AppColors.indigo500, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                                ],
                                              )),
                                              DataCell(Column(
                                                crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text((d['jenis_kelamin'] ?? '-').toString().toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.slate800, fontWeight: FontWeight.w900)),
                                                  const SizedBox(height: 2), Text(tglLahir, style: const TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.bold)),
                                                ],
                                              )),
                                              DataCell(Column(
                                                crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text((d['departemen_id'] ?? 'MANAJEMEN SITE').toString().toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.slate800, fontWeight: FontWeight.w900)),
                                                  const SizedBox(height: 2), Text((d['jabatan'] ?? 'HEAD AREA').toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.indigo50, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.indigo500)),
                                                    child: const Text('ADMIN AREA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.indigo600, letterSpacing: 1)),
                                                  )
                                                ],
                                              )),
                                              DataCell(Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.slate100, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(12)),
                                                child: Text((d['area'] ?? 'Belum Diatur').toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 1)),
                                              )),
                                              DataCell(Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(d['kontak'] ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                                                  const SizedBox(height: 2),
                                                  Text(d['email'] ?? '-', style: const TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.bold)),
                                                ],
                                              )),
                                              DataCell(Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: AppColors.emerald50, border: Border.all(color: AppColors.emerald200), borderRadius: BorderRadius.circular(12)),
                                                child: Text((d['status_karyawan'] ?? "AKTIF").toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.emerald600, letterSpacing: 1)),
                                              )),
                                              DataCell(
                                                Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Builder(
                                                      builder: (context) {
                                                        String badgeText = "BELUM ABSEN";
                                                        Color badgeColor = AppColors.rose600;
                                                        Color badgeBg = AppColors.rose50;
                                                        Color badgeBorder = AppColors.rose200;
                                                        IconData badgeIcon = Icons.cancel;

                                                        if (hasAttended) {
                                                           var attData = attendedUserRecords[docId]!;
                                                           
                                                           if (attData['status_kehadiran'] != 'Hadir') {
                                                               badgeText = attData['status_kehadiran'].toString().toUpperCase();
                                                               badgeColor = AppColors.blue500;
                                                               badgeBg = AppColors.blue50;
                                                               badgeBorder = AppColors.blue500;
                                                               badgeIcon = Icons.info;
                                                           } else if (attData['jam_pulang'] != null) {
                                                               if (attData['status_pulang'] == 'Pulang Cepat') {
                                                                   badgeText = "PULANG CEPAT";
                                                                   badgeColor = AppColors.amber500;
                                                                   badgeBg = AppColors.amber50;
                                                                   badgeBorder = AppColors.amber500;
                                                                   badgeIcon = Icons.exit_to_app;
                                                               } else {
                                                                   badgeText = "SUDAH PULANG";
                                                                   badgeColor = AppColors.emerald600;
                                                                   badgeBg = AppColors.emerald50;
                                                                   badgeBorder = AppColors.emerald200;
                                                                   badgeIcon = Icons.check_circle;
                                                               }
                                                           } else if (attData['jam_masuk'] != null) {
                                                               badgeText = "SUDAH MASUK";
                                                               badgeColor = AppColors.indigo600;
                                                               badgeBg = AppColors.indigo50;
                                                               badgeBorder = AppColors.indigo400;
                                                               badgeIcon = Icons.login;
                                                           }
                                                        }

                                                        return Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                              decoration: BoxDecoration(
                                                                color: badgeBg,
                                                                border: Border.all(color: badgeBorder),
                                                                borderRadius: BorderRadius.circular(12)
                                                              ),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(badgeIcon, color: badgeColor, size: 12),
                                                                  const SizedBox(width: 4),
                                                                  Text(badgeText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: badgeColor, letterSpacing: 1)),
                                                                ]
                                                              )
                                                            ),
                                                            if (hasAttended) ...[
                                                              const SizedBox(width: 4),
                                                              IconButton(
                                                                icon: const Icon(Icons.refresh, size: 16, color: AppColors.slate400),
                                                                tooltip: "Reset Absen Hari Ini (Simulasi)",
                                                                constraints: const BoxConstraints(),
                                                                padding: EdgeInsets.zero,
                                                                onPressed: () => _resetAttendance(
                                                                  attDocId!,
                                                                  d['nama_lengkap'] ?? 'User',
                                                                ),
                                                              )
                                                            ]
                                                          ],
                                                        );
                                                      }
                                                    ),
                                                    if (hasAttended) ...[
                                                      const SizedBox(height: 4),
                                                      Text("IN: ${attendedUserRecords[docId]!['jam_masuk'] ?? '--:--'} | OUT: ${attendedUserRecords[docId]!['jam_pulang'] ?? '--:--'}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate500)),
                                                      if (attendedUserRecords[docId]!['alasan_pulang_cepat'] != null && attendedUserRecords[docId]!['alasan_pulang_cepat'].toString().isNotEmpty)
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 2),
                                                          child: Text(attendedUserRecords[docId]!['alasan_pulang_cepat'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: AppColors.slate400, fontStyle: FontStyle.italic)),
                                                        )
                                                      else if (attendedUserRecords[docId]!['keterangan'] != null && attendedUserRecords[docId]!['keterangan'].toString().contains("Pulang Cepat"))
                                                        Padding(
                                                          padding: const EdgeInsets.only(top: 2),
                                                          child: Text(attendedUserRecords[docId]!['keterangan'].toString().replaceAll("Pulang Cepat: ", ""), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: AppColors.slate400, fontStyle: FontStyle.italic)),
                                                        )
                                                    ]
                                                  ]
                                                )
                                              ),
                                              DataCell(
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(icon: const Icon(Icons.edit, size: 20, color: AppColors.blue500), tooltip: "Edit Data", style: IconButton.styleFrom(backgroundColor: AppColors.blue50), onPressed: () => _editDeptHead(docId, d)),
                                                    const SizedBox(width: 8),
                                                    IconButton(icon: const Icon(Icons.delete, size: 20, color: AppColors.rose500), tooltip: "Hapus Data", style: IconButton.styleFrom(backgroundColor: AppColors.rose50), onPressed: () => _deleteDeptHead(docId, d['nama_lengkap'] ?? 'User')),
                                                  ],
                                                )
                                              ),
                                            ]
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                );
                              }
                            ),
                            
                            if (displayedUsers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(80),
                                child: Text("BELUM ADA DATA ADMIN AREA YANG TERDAFTAR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1), textAlign: TextAlign.center),
                              ),
                              
                            if (displayedUsers.isNotEmpty) ...[
                              const Divider(height: 1, color: AppColors.slate100),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                color: AppColors.slate50, width: double.infinity,
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 24, runSpacing: 12,
                                  children: [
                                    Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.people, size: 14, color: AppColors.slate500), const SizedBox(width: 6), Text("TOTAL ADMIN AREA: ${displayedUsers.length}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate700, letterSpacing: 1))
                                    ]),
                                    Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.male, size: 14, color: AppColors.blue500), const SizedBox(width: 6), Text("LAKI-LAKI: $totalLaki", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.blue500, letterSpacing: 1))]),
                                    Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.female, size: 14, color: AppColors.rose500), const SizedBox(width: 6), Text("PEREMPUAN: $totalPerempuan", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.rose600, letterSpacing: 1))]),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ); 
                  }, 
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),

        // MODAL TAMBAH / EDIT DEPT HEAD
        if (_showForm) _buildAddDeptHeadModal(MediaQuery.of(context).size.width < 800),
      ],
    );
  }

  Widget _buildAddDeptHeadModal(bool isMobile) {
    String? dropdownAreaValue = _availableAreas.contains(_formArea) ? _formArea : (_availableAreas.isNotEmpty ? _availableAreas.first : null);
    String? dropdownDepValue = _departemens.contains(_formDepartemen) ? _formDepartemen : (_departemens.isNotEmpty ? _departemens.first : null);
    String? dropdownJabValue = _jabatans.contains(_formJabatan) ? _formJabatan : (_jabatans.isNotEmpty ? _jabatans.first : null);

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
              boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 20)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(_isEditing ? "EDIT ADMIN AREA" : "TAMBAH ADMIN AREA", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: -0.5)),
                    ),
                    IconButton(
                      onPressed: () => _closeForm(),
                      icon: const Icon(Icons.close, color: AppColors.slate400),
                      tooltip: "Tutup"
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                isMobile 
                  ? Column(
                      children: [
                        _buildInputCol("NAMA LENGKAP", TextField(textInputAction: TextInputAction.next, controller: _namaController, decoration: _inputDeco("Nama Lengkap"))),
                        const SizedBox(height: 16),
                        _buildInputCol("NRP (NIK)", TextField(textInputAction: TextInputAction.next, controller: _nikController, decoration: _inputDeco("NRP-XXX"))),
                      ]
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildInputCol("NAMA LENGKAP", TextField(textInputAction: TextInputAction.next, controller: _namaController, decoration: _inputDeco("Nama Lengkap")))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInputCol("NRP (NIK)", TextField(textInputAction: TextInputAction.next, controller: _nikController, decoration: _inputDeco("NRP-XXX")))),
                      ],
                    ),
                const SizedBox(height: 16),

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

                isMobile 
                  ? Column(
                      children: [
                        _buildInputCol("ALAMAT EMAIL", TextField(textInputAction: TextInputAction.next, keyboardType: TextInputType.emailAddress, controller: _emailController, decoration: _inputDeco("email@adminarea.com"))),
                        const SizedBox(height: 16),
                        _buildInputCol("ALAMAT LENGKAP", TextField(textInputAction: TextInputAction.next, maxLines: 2, controller: _alamatController, decoration: _inputDeco("Alamat Lengkap Admin Area"))),
                      ]
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildInputCol("ALAMAT EMAIL", TextField(textInputAction: TextInputAction.next, keyboardType: TextInputType.emailAddress, controller: _emailController, decoration: _inputDeco("email@adminarea.com")))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInputCol("ALAMAT LENGKAP", TextField(textInputAction: TextInputAction.next, maxLines: 2, controller: _alamatController, decoration: _inputDeco("Alamat Lengkap Admin Area")))),
                      ],
                    ),
                const SizedBox(height: 16),
                
                isMobile 
                  ? Column(
                      children: [
                        _buildInputCol("DEPARTEMEN / DIVISI", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownDepValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: _departemens.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _formDepartemen = v!;
                              _updateJabatanList(v);
                            });
                          },
                        )),
                        const SizedBox(height: 16),
                        _buildInputCol("JABATAN / POSISI", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownJabValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: _jabatans.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formJabatan = v!),
                        )),
                      ]
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildInputCol("DEPARTEMEN / DIVISI", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownDepValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: _departemens.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _formDepartemen = v!;
                              _updateJabatanList(v);
                            });
                          },
                        ))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInputCol("JABATAN / POSISI", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownJabValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: _jabatans.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formJabatan = v!),
                        ))),
                      ],
                    ),
                const SizedBox(height: 16),

                isMobile
                  ? Column(
                      children: [
                        _buildInputCol("AREA PENUGASAN (SITE YANG DIKELOLA)", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownAreaValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: _availableAreas.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _formArea = v!;
                            });
                          },
                        )),
                        if (!_isEditing) ...[
                           const SizedBox(height: 16),
                           _buildInputCol("KATA SANDI BARU", TextField(textInputAction: TextInputAction.done, onSubmitted: (_) => _submitDeptHead(), controller: _passController, obscureText: true, decoration: _inputDeco("Kata Sandi Rahasia"))),
                        ]
                      ]
                    )
                  : (!_isEditing)
                      ? Row(
                          children: [
                            Expanded(child: _buildInputCol("AREA PENUGASAN (SITE YANG DIKELOLA)", DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: dropdownAreaValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                              items: _availableAreas.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _formArea = v!;
                                });
                              },
                            ))),
                            const SizedBox(width: 16),
                            Expanded(child: _buildInputCol("KATA SANDI BARU", TextField(textInputAction: TextInputAction.done, onSubmitted: (_) => _submitDeptHead(), controller: _passController, obscureText: true, decoration: _inputDeco("Kata Sandi Rahasia")))),
                          ],
                        )
                      : _buildInputCol("AREA PENUGASAN (SITE YANG DIKELOLA)", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownAreaValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: _availableAreas.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _formArea = v!;
                            });
                          },
                        )),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 10, shadowColor: AppColors.emerald500.withValues(alpha: 0.3)),
                    onPressed: _isSubmitting ? null : _submitDeptHead,
                    child: _isSubmitting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : Text(_isEditing ? "SIMPAN PERUBAHAN" : "SIMPAN DATA ADMIN AREA", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                  ),
                )

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
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 1)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
    );
  }
}
