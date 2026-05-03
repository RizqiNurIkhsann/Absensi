import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../core/app_constants.dart';
import '../models/user_model.dart';

class ValidationView extends StatefulWidget {
  final UserModel currentUser;

  const ValidationView({super.key, required this.currentUser});

  @override
  State<ValidationView> createState() => _ValidationViewState();
}

class _ValidationViewState extends State<ValidationView> {
  String _tab = 'manual'; // Hanya 'manual' yang tersisa
  
  // State Manual Input
  final TextEditingController _manualNikCtrl = TextEditingController();
  final TextEditingController _manualNamaCtrl = TextEditingController();
  final TextEditingController _manualKeteranganCtrl = TextEditingController(); // Tambahan Keterangan
  final TextEditingController _manualLokasiDinasCtrl = TextEditingController(); // Tambahan Input Lokasi Dinas Luar
  
  DateTime? _manualTanggal;
  TimeOfDay? _manualMasuk;
  TimeOfDay? _manualKeluar;
  
  String _manualShift = 'Pagi'; // Default Shift
  String _manualKedisiplinan = 'Tepat Waktu'; // Status Kedisiplinan Masuk
  String _manualStatusPulang = 'Sesuai Jadwal'; // Status Kepulangan Keluar
  String _manualStatusKehadiran = 'Hadir'; // Status Kehadiran (Hadir/Perjalanan Dinas)
  
  String? _manualAreaMasuk; // Area 1
  String? _manualAreaPulang; // Area 2
  
  bool _isManualSubmitting = false;

  // --- TAMBAHAN UNTUK AUTOCOMPLETE ---
  final FocusNode _manualNamaFocus = FocusNode();
  List<Map<String, dynamic>> _employeeList = [];

  // Mengambil List Shift & Area dari Config Database
  List<Map<String, dynamic>> _availableShifts = [];
  List<String> _availableAreas = [];

  @override
  void initState() {
    super.initState();
    _fetchConfigs();
    _fetchEmployees(); // Memuat data karyawan saat pertama kali dibuka
  }

  @override
  void dispose() {
    _manualNikCtrl.dispose();
    _manualNamaCtrl.dispose();
    _manualKeteranganCtrl.dispose();
    _manualLokasiDinasCtrl.dispose();
    _manualNamaFocus.dispose();
    super.dispose();
  }

  // --- FUNGSI MENGAMBIL DATA KARYAWAN UNTUK AUTOCOMPLETE ---
  Future<void> _fetchEmployees() async {
    try {
      var users = await ApiService().getUsers();
      if (mounted) {
        setState(() {
          _employeeList = users.map((e) => e as Map<String, dynamic>).toList();
        });
      }
    } catch (e) {
      debugPrint("Gagal fetch employee: $e");
    }
  }

  Future<void> _fetchConfigs() async {
    try {
      var data = await ApiService().getConfigSite();

      if (data != null) {
        List<dynamic> shifts = data['shifts'] ?? [];
        List<dynamic> locs = data['locations'] ?? [];
        
        if (mounted) {
          setState(() {
            _availableShifts = shifts.map((e) => Map<String, dynamic>.from(e)).toList();
            
            if (locs.isNotEmpty) {
              var areaList = locs.map((e) => e['siteName'].toString()).toList();
              areaList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              
              // Jika user adalah Head Area, batasi pilihan hanya ke areanya sendiri
              if (widget.currentUser.role == 'Head Area' && widget.currentUser.area != 'Semua Area') {
                 if (areaList.contains(widget.currentUser.area)) {
                    _availableAreas = [widget.currentUser.area];
                 } else {
                    _availableAreas = areaList;
                 }
              } else {
                 _availableAreas = areaList;
              }
            }
            
            if (_availableAreas.isNotEmpty) {
              _manualAreaMasuk = _availableAreas.first;
              _manualAreaPulang = _availableAreas.first;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal load config: $e");
    }
  }

  // --- FUNGSI SUBMIT MANUAL ---
  Future<void> _submitManualData() async {
    FocusManager.instance.primaryFocus?.unfocus();

    String manualNik = _manualNikCtrl.text.trim();
    String manualNama = _manualNamaCtrl.text.trim();

    if (manualNik.isEmpty || manualNama.isEmpty || _manualTanggal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon lengkapi data dasar (NRP, Nama, Tanggal)!"), backgroundColor: AppColors.rose500));
      return;
    }

    if (_manualStatusKehadiran == 'Hadir') {
      if (_manualMasuk == null || _manualKeluar == null || _manualAreaMasuk == null || _manualAreaPulang == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Untuk status Hadir, Waktu & Lokasi harus diisi lengkap!"), backgroundColor: AppColors.rose500));
        return;
      }
    } else if (_manualStatusKehadiran == 'Perjalanan Dinas') {
      if (_manualMasuk == null || _manualKeluar == null || _manualLokasiDinasCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Untuk status Perjalanan Dinas, Waktu & Lokasi Perjalanan Dinas harus diisi lengkap!"), backgroundColor: AppColors.rose500));
        return;
      }
    }

    setState(() => _isManualSubmitting = true);

    try {
      var existingUser = await ApiService().getUserByNik(manualNik);

      String targetUserId = "manual_$manualNik";
      String targetUserName = manualNama;

      if (existingUser != null) {
        targetUserId = existingUser['id'].toString();
        targetUserName = existingUser['nama_lengkap'] ?? manualNama;
      }

      String dateStr = DateFormat('yyyy-MM-dd').format(_manualTanggal!);
      String docId = "${targetUserId}_$dateStr";

      // Payload Dasar
      Map<String, dynamic> payload = {
        'user_id': targetUserId,
        'nik': manualNik,
        'nama_lengkap': targetUserName,
        'date': dateStr,
        'shift': _manualShift,
        'shift_time': "-", 
        'status_kehadiran': _manualStatusKehadiran,
        'status_validasi': 'Disetujui',
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Tambahkan payload spesifik berdasarkan Status Kehadiran
      if (_manualStatusKehadiran == 'Hadir' || _manualStatusKehadiran == 'Perjalanan Dinas') {
        payload['jam_masuk'] = "${_manualMasuk!.hour.toString().padLeft(2, '0')}:${_manualMasuk!.minute.toString().padLeft(2, '0')}";
        payload['jam_pulang'] = "${_manualKeluar!.hour.toString().padLeft(2, '0')}:${_manualKeluar!.minute.toString().padLeft(2, '0')}";
        
        payload['site_absen'] = _manualStatusKehadiran == 'Perjalanan Dinas' ? _manualLokasiDinasCtrl.text.trim() : _manualAreaMasuk; 
        payload['site_masuk'] = _manualStatusKehadiran == 'Perjalanan Dinas' ? _manualLokasiDinasCtrl.text.trim() : _manualAreaMasuk;
        payload['site_pulang'] = _manualStatusKehadiran == 'Perjalanan Dinas' ? _manualLokasiDinasCtrl.text.trim() : _manualAreaPulang;
        
        payload['status_kedisiplinan'] = _manualKedisiplinan;
        payload['status_pulang'] = _manualStatusPulang;
        
        payload['keterangan'] = _manualStatusKehadiran == 'Perjalanan Dinas' ? 'Dinas di: ${_manualLokasiDinasCtrl.text.trim()} (Manual)' : 'Diinput manual oleh Admin';
      }

      await ApiService().logManualAttendance(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data absensi manual berhasil ditambahkan!"), backgroundColor: AppColors.emerald500));
        setState(() {
          _manualNikCtrl.clear();
          _manualNamaCtrl.clear();
          _manualKeteranganCtrl.clear();
          _manualLokasiDinasCtrl.clear();
          _manualTanggal = null;
          _manualMasuk = null;
          _manualKeluar = null;
          _manualShift = 'Pagi';
          _manualKedisiplinan = 'Tepat Waktu';
          _manualStatusPulang = 'Sesuai Jadwal';
          _manualStatusKehadiran = 'Hadir';
          // Area dipertahankan untuk memudahkan input berikutnya
        });
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menambahkan data manual."), backgroundColor: AppColors.rose500));
    } finally {
      if (mounted) setState(() => _isManualSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  const Text("PUSAT VALIDASI", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.slate900, letterSpacing: -0.5)),
                ],
              ),
              const SizedBox(height: 32),

              // Content based on tab (Only Manual Input remains)
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return _buildManualForm();
  }

  // --- BANTUAN RESPONSIVE LAYOUT UNTUK FORM MANUAL ---
  Widget _buildResponsiveRow(bool isMobile, Widget leftChild, Widget? rightChild) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leftChild,
          if (rightChild != null) ...[
             const SizedBox(height: 16),
             rightChild,
          ]
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: leftChild),
          if (rightChild != null) ...[
             const SizedBox(width: 16),
             Expanded(child: rightChild),
          ] else ...[
             const SizedBox(width: 16),
             const Expanded(child: SizedBox.shrink()),
          ]
        ],
      );
    }
  }

  // --- 3. TAB INPUT MANUAL ---
  Widget _buildManualForm() {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: EdgeInsets.all(isMobile ? 24 : 40),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), border: Border.all(color: AppColors.slate100), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("PENYIMPANAN ABSENSI (MANUAL)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            const Text("TAMBAH DATA KEHADIRAN KARYAWAN YANG LUPA MELAPOR MASUK / KELUAR.", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
            const SizedBox(height: 32),

            // Baris 1: NAMA (AUTOCOMPLETE) DI KIRI & NRP (TERKUNCI) DI KANAN
            _buildResponsiveRow(
              isMobile, 
              _buildInputCol("NAMA LENGKAP", LayoutBuilder(
                builder: (context, constraints) => RawAutocomplete<Map<String, dynamic>>(
                  textEditingController: _manualNamaCtrl,
                  focusNode: _manualNamaFocus,
                  optionsBuilder: (TextEditingValue v) {
                    if (v.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                    return _employeeList.where((u) {
                      String nama = (u['nama_lengkap'] ?? '').toString().toLowerCase();
                      String nik = (u['nik'] ?? '').toString().toLowerCase();
                      String q = v.text.toLowerCase();
                      return nama.contains(q) || nik.contains(q);
                    });
                  },
                  displayStringForOption: (option) => option['nama_lengkap'] ?? '',
                  onSelected: (selection) {
                    setState(() {
                      // Saat nama dipilih, otomatis isi NRP
                      _manualNikCtrl.text = selection['nik'] ?? '';
                    });
                  },
                  fieldViewBuilder: (c, t, f, o) {
                    return TextField(
                      controller: t, focusNode: f, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), 
                      decoration: _inputDeco("Ketik Nama / NRP Karyawan...").copyWith(
                        suffixIcon: const Icon(Icons.search, size: 18, color: AppColors.slate400),
                      ),
                    );
                  },
                  optionsViewBuilder: (c, o, opts) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: constraints.maxWidth, margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.slate200), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10, offset: Offset(0, 5))]),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 250),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8), shrinkWrap: true, itemCount: opts.length,
                              itemBuilder: (c, i) {
                                final option = opts.elementAt(i);
                                return InkWell(
                                  onTap: () => o(option), 
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text((option['nama_lengkap'] ?? 'TANPA NAMA').toString().toUpperCase(), style: const TextStyle(color: AppColors.slate800, fontWeight: FontWeight.w900, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                        const SizedBox(width: 8),
                                        Text(option['nik'] ?? '-', style: const TextStyle(color: AppColors.slate500, fontWeight: FontWeight.bold, fontSize: 10, fontFamily: 'monospace')),
                                      ],
                                    )
                                  )
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )),
              _buildInputCol("NRP KARYAWAN", TextField(
                controller: _manualNikCtrl, 
                enabled: false, // <-- Menghidupkan mode non-aktif
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate500), 
                decoration: _inputDeco("Terisi Otomatis...", isLocked: true)
              ))
            ),
            const SizedBox(height: 16),

            // Baris 2: TANGGAL & SHIFT
            _buildResponsiveRow(
              isMobile,
              _buildInputCol("TANGGAL", InkWell(
                onTap: () async {
                  DateTime? d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (d != null) setState(() => _manualTanggal = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_manualTanggal != null ? DateFormat('dd/MM/yyyy').format(_manualTanggal!) : "dd/mm/yyyy", style: TextStyle(fontWeight: FontWeight.bold, color: _manualTanggal != null ? AppColors.slate800 : AppColors.slate400, fontSize: 13)),
                      const Icon(Icons.calendar_today, size: 16, color: AppColors.slate400)
                    ],
                  ),
                ),
              )),
              _buildInputCol("SHIFT", DropdownButtonFormField<String>(
                initialValue: _manualShift,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate400),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800, fontSize: 13),
                decoration: _inputDeco(""),
                items: ['Pagi', 'Malam'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _manualShift = v!),
              ))
            ),
            const SizedBox(height: 16),

            // Baris 3: STATUS KEHADIRAN (Hadir / Perjalanan Dinas)
            _buildResponsiveRow(
              isMobile,
              _buildInputCol("STATUS KEHADIRAN", DropdownButtonFormField<String>(
                initialValue: _manualStatusKehadiran,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate400),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800, fontSize: 13),
                decoration: _inputDeco(""),
                items: ['Hadir', 'Perjalanan Dinas'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _manualStatusKehadiran = v!),
              )),
              null // Biarkan sebelah kanan kosong secara responsif
            ),
            const SizedBox(height: 16),

            // --- BARIS KONDISIONAL BERDASARKAN STATUS KEHADIRAN ---
            if (_manualStatusKehadiran == 'Hadir' || _manualStatusKehadiran == 'Perjalanan Dinas') ...[
              // Baris 4: WAKTU MASUK & AREA MASUK/LOKASI DINAS
              _buildResponsiveRow(
                isMobile,
                _buildInputCol("WAKTU MASUK", InkWell(
                  onTap: () async {
                    TimeOfDay? t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
                    if (t != null) setState(() => _manualMasuk = t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_manualMasuk != null ? "${_manualMasuk!.hour.toString().padLeft(2,'0')}:${_manualMasuk!.minute.toString().padLeft(2,'0')}" : "--:--", style: TextStyle(fontWeight: FontWeight.bold, color: _manualMasuk != null ? AppColors.emerald600 : AppColors.slate400, fontSize: 13)),
                        const Icon(Icons.access_time, size: 16, color: AppColors.slate400)
                      ],
                    ),
                  ),
                )),
                _buildInputCol("WAKTU KELUAR", InkWell(
                  onTap: () async {
                    TimeOfDay? t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 17, minute: 0));
                    if (t != null) setState(() => _manualKeluar = t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_manualKeluar != null ? "${_manualKeluar!.hour.toString().padLeft(2,'0')}:${_manualKeluar!.minute.toString().padLeft(2,'0')}" : "--:--", style: TextStyle(fontWeight: FontWeight.bold, color: _manualKeluar != null ? AppColors.rose600 : AppColors.slate400, fontSize: 13)),
                        const Icon(Icons.access_time, size: 16, color: AppColors.slate400)
                      ],
                    ),
                  ),
                ))
              ),
              const SizedBox(height: 16),

              if (_manualStatusKehadiran == 'Hadir') ...[
                 _buildResponsiveRow(
                   isMobile,
                   _buildInputCol("LOKASI MASUK (AREA 1)", DropdownButtonFormField<String>(
                     initialValue: _manualAreaMasuk,
                     isExpanded: true,
                     icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate400),
                     style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800, fontSize: 12),
                     decoration: _inputDeco("Pilih Area"),
                     items: _availableAreas.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                     onChanged: (v) => setState(() => _manualAreaMasuk = v),
                   )),
                   _buildInputCol("LOKASI PULANG (AREA 2)", DropdownButtonFormField<String>(
                     initialValue: _manualAreaPulang,
                     isExpanded: true,
                     icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate400),
                     style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800, fontSize: 12),
                     decoration: _inputDeco("Pilih Area"),
                     items: _availableAreas.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                     onChanged: (v) => setState(() => _manualAreaPulang = v),
                   ))
                 ),
                 const SizedBox(height: 16),
              ] else ...[
                 _buildInputCol("LOKASI PERJALANAN DINAS", TextField(
                   controller: _manualLokasiDinasCtrl,
                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                   decoration: _inputDeco("Contoh: Kantor Pusat, Dinas Luar Kota, dsb."),
                 )),
                 const SizedBox(height: 16),
              ],

              // Baris 6: KEDISIPLINAN & KEPULANGAN
              _buildResponsiveRow(
                isMobile,
                _buildInputCol("STATUS KEDISIPLINAN (MASUK)", DropdownButtonFormField<String>(
                  initialValue: _manualKedisiplinan,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate400),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800, fontSize: 13),
                  decoration: _inputDeco(""),
                  items: ['Tepat Waktu', 'Terlambat'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _manualKedisiplinan = v!),
                )),
                _buildInputCol("STATUS KEPULANGAN (KELUAR)", DropdownButtonFormField<String>(
                  initialValue: _manualStatusPulang,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate400),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800, fontSize: 13),
                  decoration: _inputDeco(""),
                  items: ['Sesuai Jadwal', 'Pulang Cepat'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _manualStatusPulang = v!),
                ))
              ),
            ],

            const SizedBox(height: 32),

            // Tombol Simpan
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _isManualSubmitting ? null : _submitManualData,
                child: _isManualSubmitting ? const CircularProgressIndicator(color: AppColors.yellow500) : const Text("SIMPAN DATA ABSENSI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            )
          ],
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

  InputDecoration _inputDeco(String hint, {bool isLocked = false}) {
    return InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: AppColors.slate300, fontSize: 12, fontWeight: FontWeight.bold),
      filled: true, fillColor: isLocked ? AppColors.slate50 : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppColors.slate200.withValues(alpha: 0.5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
    );
  }
}
