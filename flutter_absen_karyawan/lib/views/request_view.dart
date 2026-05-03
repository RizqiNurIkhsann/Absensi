import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../core/app_constants.dart';
import '../models/user_model.dart';

class RequestView extends StatefulWidget {
  final UserModel user;

  const RequestView({super.key, required this.user});

  @override
  State<RequestView> createState() => _RequestViewState();
}

class _RequestViewState extends State<RequestView> {
  bool _showForm = false;
  String _tab = 'saya'; // 'saya' atau 'tim'
  bool _isSubmitting = false;
  Key _refreshKey = UniqueKey();

  // --- FILTER STATE ---
  String _filterType = 'Semua Jenis';
  final List<String> _availableTypes = ['Semua Jenis', 'Cuti', 'Izin', 'Lembur', 'Sakit'];
  String _filterYear = 'Semua Tahun';

  // --- FORM STATE ---
  String _formType = 'Cuti';
  String _formStart = '';
  String _formEnd = '';
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // Fungsi Menutup Form
  void _closeForm() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _showForm = false;
      _formType = 'Cuti';
      _formStart = '';
      _formEnd = '';
      _reasonController.clear();
    });
  }

  // Fungsi untuk Update Status (Persetujuan Admin) ke API
  Future<void> _updateStatus(String docId, String newStatus) async {
    try {
      bool ok = await ApiService().updateRequestStatus(docId, newStatus);
      if (!ok) throw Exception("Gagal update status");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Borang berhasil $newStatus"),
            backgroundColor: newStatus == 'Disetujui'
                ? AppColors.emerald500
                : AppColors.rose500,
          ),
        );
        setState(() => _refreshKey = UniqueKey());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal memperbarui status ke server"),
            backgroundColor: AppColors.rose500,
          ),
        );
      }
    }
  }

  // Fungsi untuk Mengirim Form Baru ke Firebase
  Future<void> _submitRequest() async {
    String formReason = _reasonController.text.trim();

    if (_formStart.isEmpty || _formEnd.isEmpty || formReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Harap lengkapi semua data, termasuk tanggal & alasan!",
          ),
          backgroundColor: AppColors.rose500,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    Map<String, dynamic> payload = {
      'user_id': widget.user.id,
      'nik': widget.user.nik,
      'shift': widget.user.shift,
      'area': widget.user.area,
      'nama_lengkap': widget.user.namaLengkap,
      'type': _formType == 'Izin' ? 'Izin' : _formType, 
      'reason': formReason,
      'start': _formStart,
      'end': _formEnd,
      'status': 'Pending',
      'submittedAt': DateFormat('dd/MM/yyyy').format(DateTime.now()),
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      bool ok = await ApiService().createRequest(payload);
      if (!ok) throw Exception("Gagal membuat request");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Permohonan Berhasil Terkirim!"),
            backgroundColor: AppColors.emerald500,
          ),
        );
        setState(() => _refreshKey = UniqueKey());
        _closeForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal mengirim permohonan."),
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
    // HANYA ADMIN (IT SUPPORT) YANG MEMILIKI TAB GANDA DI SINI
    bool isAdmin = widget.user.role == 'admin';
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: FutureBuilder<List<dynamic>>(
          key: _refreshKey,
          future: ApiService().getRequests(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: AppColors.yellow500),
                ),
              );
            }

            List<Map<String, dynamic>> requests = snapshot.data!.map((doc) {
              var data = doc as Map<String, dynamic>;
              data['id'] = doc['id']?.toString() ?? '';
              return data;
            }).toList();

            // ----------------------------------------------------
            // 1. EKSTRAK TAHUN UNTUK DROPDOWN FILTER (Dinamis)
            // ----------------------------------------------------
            Set<String> yearSet = {'Semua Tahun'};
            for (var r in requests) {
              if (r['start'] != null && r['start'].toString().length >= 4) {
                yearSet.add(r['start'].toString().substring(0, 4));
              }
            }
            List<String> availableYears = yearSet.toList();
            availableYears.sort((a, b) => b.compareTo(a)); 
            
            if (!availableYears.contains(_filterYear)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _filterYear = 'Semua Tahun');
              });
            }

            // ----------------------------------------------------
            // 2. PEMFILTERAN DATA (TAB, JENIS, TAHUN, AREA)
            // ----------------------------------------------------
            List myReq = [];
            List teamReq = [];
            List historyTeamReq = [];

            for (var r in requests) {
              // Filter Jenis & Tahun
              bool passType = _filterType == 'Semua Jenis' || r['type'] == _filterType;
              bool passYear = _filterYear == 'Semua Tahun' || (r['start'] ?? '').toString().startsWith(_filterYear);
              
              if (!passType || !passYear) continue; 

              // Pisahkan berdasarkan Tab (Saya vs Tim)
              if (r['user_id'] == widget.user.id) {
                myReq.add(r);
              } else if (isAdmin) {
                // Admin (IT Support) melihat semua request sebagai pantauan
                if (r['status'] == 'Pending') {
                  teamReq.add(r);
                } else {
                  historyTeamReq.add(r);
                }
              }
            }

            // Sort descending (terbaru di atas)
            myReq.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
            historyTeamReq.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));

            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // HEADER & TOMBOL BUAT BARU
                    Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "LAYANAN MANDIRI",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slate800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (isMobile) const SizedBox(height: 16),
                        if (_tab == 'saya') 
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.yellow500,
                              elevation: 10,
                              shadowColor: AppColors.yellow500.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () => setState(() => _showForm = true),
                            icon: const Icon(Icons.add, color: AppColors.slate900, size: 18),
                            label: const Text(
                              "Buat Baru",
                              style: TextStyle(color: AppColors.slate900, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // TAB SAYA / TIM (HANYA MUNCUL UNTUK SUPER ADMIN / IT SUPPORT)
                    if (isAdmin) ...[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.slate100),
                          boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4)],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTabBtn('PERMOHONAN SAYA', 'saya', 0),
                              _buildTabBtn('SEMUA KARYAWAN', 'tim', teamReq.length),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // FILTER DROPDOWNS (Jenis & Tahun)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildFilterDropdown(
                          label: "Jenis Layanan:",
                          value: _filterType,
                          items: _availableTypes,
                          onChanged: (val) => setState(() => _filterType = val!),
                        ),
                        _buildFilterDropdown(
                          label: "Tahun:",
                          value: _filterYear,
                          items: availableYears,
                          onChanged: (val) => setState(() => _filterYear = val!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // CONTENT: PERMOHONAN SAYA
                    if (_tab == 'saya') ...[
                      if (myReq.isEmpty)
                        _buildEmptyState("TIDAK ADA DATA ${_filterType.toUpperCase()} PADA TAHUN ${_filterYear.toUpperCase()}")
                      else
                        ...myReq.map((r) => _buildMyReqCard(Map<String, dynamic>.from(r))),
                    ],

                    // CONTENT: SEMUA KARYAWAN (KHUSUS SUPER ADMIN)
                    if (_tab == 'tim' && isAdmin) ...[
                      _buildTeamReqSection("Menunggu Persetujuan (${teamReq.length})", teamReq, true),
                      const SizedBox(height: 24),
                      _buildTeamReqSection("Riwayat Validasi", historyTeamReq, false),
                    ],
                    
                    const SizedBox(height: 100),
                  ],
                ),

                // MODAL FORMULIR
                if (_showForm) _buildFormModal(),
              ],
            );
          },
        ),
      ),
    );
  }

  // Komponen Tab Button
  Widget _buildTabBtn(String label, String tabValue, int badge) {
    bool isActive = _tab == tabValue;
    return GestureDetector(
      onTap: () => setState(() {
        _tab = tabValue;
        _filterType = 'Semua Jenis';
        _filterYear = 'Semua Tahun';
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.yellow500 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive ? [BoxShadow(color: AppColors.yellow500.withValues(alpha: 0.3), blurRadius: 8)] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isActive ? AppColors.slate900 : AppColors.slate400,
                letterSpacing: 1,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.rose500,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Komponen Dropdown Filter
  Widget _buildFilterDropdown({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate200),
        boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4, offset: Offset(0, 2))]
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.slate500),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate800),
              onChanged: onChanged,
              items: items.map<DropdownMenuItem<String>>((String val) => DropdownMenuItem<String>(value: val, child: Text(val))).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Tampilan Kosong
  Widget _buildEmptyState(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        children: [
          const Icon(Icons.description_outlined, size: 48, color: AppColors.slate200),
          const SizedBox(height: 16),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.slate400, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Komponen Card Permohonan Saya
  Widget _buildMyReqCard(Map<String, dynamic> r) {
    String type = r['type'] ?? 'Lainnya';
    
    Color iconBg = AppColors.slate100;
    Color iconColor = AppColors.slate500;
    if (type == 'Cuti') {
      iconBg = AppColors.blue500;
      iconColor = Colors.white;
    } else if (type == 'Izin') {
      iconBg = AppColors.emerald500;
      iconColor = Colors.white;
    } else if (type == 'Lembur' || type == 'Lembur/Kerja') {
      iconBg = AppColors.amber500;
      iconColor = Colors.white;
    }

    Color statusCol = r['status'] == 'Disetujui' ? AppColors.emerald500 : (r['status'] == 'Ditolak' ? AppColors.rose500 : AppColors.slate400);
    Color statusBg = r['status'] == 'Disetujui' ? AppColors.emerald50 : (r['status'] == 'Ditolak' ? AppColors.rose50 : AppColors.slate50);

    String displayType = type;
    if (type == 'Izin') displayType = "IZIN / LIBUR UMUM";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColors.slate100),
        boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: iconBg.withValues(alpha: 0.3), blurRadius: 10)],
                ),
                child: Icon(Icons.description, color: iconColor, size: 28),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBg,
                  border: Border.all(color: statusCol.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  r['status']?.toString().toUpperCase() ?? 'PENDING',
                  style: TextStyle(color: statusCol, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            displayType.toUpperCase(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.slate800),
          ),
          const SizedBox(height: 4),
          Text(
            "${r['start']} s/d ${r['end']}",
            style: const TextStyle(fontSize: 10, color: AppColors.slate400, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.only(left: 16),
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.yellow500, width: 4))),
            child: Text(
              '"${r['reason']}"',
              style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // Komponen Bagian Persetujuan Tim (Hanya untuk Admin/IT Support)
  Widget _buildTeamReqSection(String title, List reqs, bool showActions) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColors.slate100),
        boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 5)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: AppColors.slate50.withValues(alpha: 0.5),
            width: double.infinity,
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 2),
            ),
          ),
          const Divider(height: 1, color: AppColors.slate100),
          if (reqs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text("TIDAK ADA DATA PADA FILTER INI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 2)),
              ),
            ),

          ...reqs.map(
            (r) {
               String displayType = r['type'] ?? 'FORM';
               if (displayType == 'Izin') displayType = 'LIBUR UMUM / IZIN';

               return Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.slate50)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['nama_lengkap']?.toString().toUpperCase() ?? 'TANPA NAMA',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.slate800, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r['submittedAt'] ?? '-',
                            style: const TextStyle(fontSize: 9, color: AppColors.slate400, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayType.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.indigo600, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '"${r['reason']}" (${r['start']} - ${r['end']})',
                            style: const TextStyle(fontSize: 9, color: AppColors.slate500, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (showActions)
                      Row(
                        children: [
                          _actionBtn(Icons.check, AppColors.emerald500, () => _updateStatus(r['id'], 'Disetujui')),
                          const SizedBox(width: 8),
                          _actionBtn(Icons.close, AppColors.rose500, () => _updateStatus(r['id'], 'Ditolak')),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: r['status'] == 'Disetujui' ? AppColors.emerald50 : AppColors.rose50,
                          border: Border.all(color: r['status'] == 'Disetujui' ? AppColors.emerald200 : AppColors.rose200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          r['status']?.toString().toUpperCase() ?? '-',
                          style: TextStyle(
                            color: r['status'] == 'Disetujui' ? AppColors.emerald600 : AppColors.rose600,
                            fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)],
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  // Modal Buat Permohonan Baru
  Widget _buildFormModal() {
    return Container(
      color: AppColors.slate900.withValues(alpha: 0.8),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(40),
            constraints: const BoxConstraints(maxWidth: 600),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(48),
              boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 20)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text(
                        "FORMULIR UT",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: -0.5),
                      ),
                    ),
                    IconButton(
                      onPressed: _closeForm,
                      icon: const Icon(Icons.close, color: AppColors.slate400),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                _inputLabel("Jenis Layanan"),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    border: Border.all(color: AppColors.slate200),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _formType,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 16),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate700),
                      onChanged: (String? newValue) => setState(() => _formType = newValue!),
                      items: <String>['Cuti', 'Izin', 'Lembur/Kerja']
                          .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value.toUpperCase()),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _inputLabel("Tanggal Mulai"),
                          _buildDateInput(_formStart, (v) {
                            setState(() {
                              _formStart = v;
                            });
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _inputLabel("Tanggal Selesai"),
                          _buildDateInput(_formEnd, (v) {
                            setState(() {
                              _formEnd = v;
                            });
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _inputLabel("Alasan / Keterangan"),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700),
                  decoration: InputDecoration(
                    hintText: "Tuliskan alasan...",
                    filled: true,
                    fillColor: AppColors.slate50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.slate200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.slate200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.slate900,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 10,
                      shadowColor: AppColors.slate900.withValues(alpha: 0.3),
                    ),
                    onPressed: _isSubmitting ? null : _submitRequest,
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.yellow500, strokeWidth: 3))
                        : const Text(
                            "KIRIM PERMOHONAN",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2),
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

  Widget _inputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: AppColors.slate400,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildDateInput(String currentValue, Function(String) onDateSelected) {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onDateSelected(DateFormat('yyyy-MM-dd').format(picked));
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.slate200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentValue.isEmpty ? "Pilih Tanggal" : DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(currentValue)),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: currentValue.isEmpty ? AppColors.slate400 : AppColors.slate700,
              ),
            ),
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: AppColors.slate400,
            ),
          ],
        ),
      ),
    );
  }
}
