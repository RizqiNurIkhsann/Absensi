import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../core/app_constants.dart';
import '../models/user_model.dart';

class HelpView extends StatefulWidget {
  final UserModel user;
  final VoidCallback onBack;

  const HelpView({super.key, required this.user, required this.onBack});

  @override
  State<HelpView> createState() => _HelpViewState();
}

class _HelpViewState extends State<HelpView> {
  Key _refreshKey = UniqueKey();

  // --- STATE ADMIN ---
  String _adminTab = 'Open'; // 'Open' atau 'Selesai'
  Map<String, dynamic>? _replyingTo;
  String _replyMsg = '';
  bool _isReplying = false;

  String _selectedAreaFilter = 'Semua Area';
  List<String> _availableAreas = ['Semua Area'];
  
  // State untuk Fitur Hapus
  final List<String> _selectedTicketIds = [];
  bool _isDeleting = false;

  // Scroll Controller untuk Tabel Admin
  final ScrollController _tableScrollController = ScrollController();

  // --- STATE KARYAWAN ---
  String _subject = '';
  String _message = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchConfigs(); // Mengambil daftar area
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  // Mengambil daftar area/site
  Future<void> _fetchConfigs() async {
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
      debugPrint("Gagal fetch config area: $e");
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(isoString));
    } catch (e) {
      return '-';
    }
  }

  // --- FUNGSI ADMIN: BALAS TIKET ---
  Future<void> _submitReply() async {
    if (_replyingTo == null || _replyMsg.trim().isEmpty) return;

    setState(() => _isReplying = true);
    try {
      await ApiService().updateTicket(_replyingTo!['id'], {
        'status': 'Selesai',
        'balasan': _replyMsg,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tiket berhasil dibalas & diselesaikan!"), backgroundColor: AppColors.emerald500));
        setState(() {
          _replyingTo = null;
          _replyMsg = '';
          _selectedTicketIds.clear(); // Reset pilihan
          _refreshKey = UniqueKey();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengirim balasan."), backgroundColor: AppColors.rose500));
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  // --- FUNGSI ADMIN: HAPUS TIKET YANG DIPILIH ---
  Future<void> _deleteSelectedTickets() async {
    if (_selectedTicketIds.isEmpty) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.rose500),
            SizedBox(width: 8),
            Text("Hapus Tiket?", style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text("Apakah Anda yakin ingin menghapus ${_selectedTicketIds.length} tiket keluhan yang dipilih? Aksi ini tidak dapat dibatalkan.", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Hapus Permanen", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        for (String id in _selectedTicketIds) {
          await ApiService().deleteTicket(id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tiket berhasil dihapus."), backgroundColor: AppColors.emerald500));
          setState(() {
            _selectedTicketIds.clear();
            _refreshKey = UniqueKey();
          });
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menghapus tiket."), backgroundColor: AppColors.rose500));
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  // --- FUNGSI KARYAWAN / DEPT HEAD: BUAT TIKET ---
  Future<void> _submitTicket() async {
    if (_subject.isEmpty || _message.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap lengkapi Subjek dan Pesan!"), backgroundColor: AppColors.rose500));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService().createTicket({
        'user_id': widget.user.id,
        'nik': widget.user.nik,
        'nama_lengkap': widget.user.namaLengkap,
        'role': widget.user.role, 
        'area': widget.user.area,
        'subject': _subject,
        'message': _message,
        'status': 'Open',
        'balasan': '',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tiket berhasil dikirim. Admin akan segera merespons."), backgroundColor: AppColors.emerald500));
        setState(() {
          _subject = '';
          _message = '';
          _refreshKey = UniqueKey();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengirim tiket."), backgroundColor: AppColors.rose500));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: FutureBuilder<List<dynamic>>(
          key: _refreshKey,
          future: ApiService().getTickets(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.yellow500));
            }

            List<Map<String, dynamic>> allTickets = [];
            if (snapshot.hasData) {
              allTickets = snapshot.data!.map((doc) => {'id': doc['id']?.toString() ?? '', ...(doc as Map<String, dynamic>)}).toList();
            }

            if (widget.user.role == 'admin') {
              return _buildAdminView(allTickets);
            } else {
              return _buildEmployeeView(allTickets);
            }
          },
        ),
      ),
    );
  }

  // ==========================================
  // TAMPILAN KHUSUS ADMIN
  // ==========================================
  Widget _buildAdminView(List<Map<String, dynamic>> allTickets) {
    // Logika Pemfilteran berdasarkan Area
    if (_selectedAreaFilter != 'Semua Area') {
      allTickets = allTickets.where((t) => (t['area'] ?? '') == _selectedAreaFilter).toList();
    }

    List<Map<String, dynamic>> openTickets = allTickets.where((t) => t['status'] == 'Open').toList();
    List<Map<String, dynamic>> closedTickets = allTickets.where((t) => t['status'] == 'Selesai').toList();

    openTickets.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    closedTickets.sort((a, b) => (b['updated_at'] ?? '').compareTo(a['updated_at'] ?? ''));

    List<Map<String, dynamic>> displayedTickets = _adminTab == 'Open' ? openTickets : closedTickets;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER ADMIN
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.slate600, size: 24),
                        onPressed: widget.onBack,
                        tooltip: 'Kembali',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white, 
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.slate200))
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text("PUSAT BANTUAN", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.slate900, letterSpacing: -0.5)),
                    ],
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // DROPDOWN FILTER AREA
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.slate200), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4, offset: Offset(0, 2))]),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _availableAreas.contains(_selectedAreaFilter) ? _selectedAreaFilter : (_availableAreas.isNotEmpty ? _availableAreas.first : null),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.slate500),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedAreaFilter = newValue!;
                                _selectedTicketIds.clear(); // Bersihkan centang saat ganti area
                              });
                            },
                            items: _availableAreas.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                          ),
                        ),
                      ),
                      // TABS TIKET
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.slate200), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 8, offset: Offset(0, 4))]),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildAdminTabBtn("MENUNGGU (${openTickets.length})", 'Open'),
                            _buildAdminTabBtn("SELESAI (${closedTickets.length})", 'Selesai'),
                          ],
                        ),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 40),

              // TABEL DATA TIKET ADMIN
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: AppColors.slate200)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.slate200, width: 2))
                      ),
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_adminTab == 'Open' ? "DAFTAR KELUHAN MASUK" : "RIWAYAT KELUHAN SELESAI", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 2)),
                          
                          // TOMBOL HAPUS AKAN MUNCUL JIKA ADA TIKET DIPILIH
                          if (_selectedTicketIds.isNotEmpty)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.rose500,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                              ),
                              onPressed: _isDeleting ? null : _deleteSelectedTickets,
                              icon: _isDeleting ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.delete, size: 16),
                              label: Text("HAPUS (${_selectedTicketIds.length})", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                            )
                        ],
                      ),
                    ),
                    
                    RawScrollbar(
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
                          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width > 800 ? 800 : MediaQuery.of(context).size.width - 48),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.white),
                            headingTextStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 2),
                            dataRowMaxHeight: 90,
                            dividerThickness: 1,
                            // FITUR SELECT ALL
                            onSelectAll: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedTicketIds.addAll(
                                    displayedTickets
                                      .map((t) => t['id'].toString())
                                      .where((id) => !_selectedTicketIds.contains(id))
                                  );
                                } else {
                                  _selectedTicketIds.clear();
                                }
                              });
                            },
                            columns: const [
                              DataColumn(label: Text('TANGGAL')),
                              DataColumn(label: Text('KARYAWAN & JABATAN')),
                              DataColumn(label: Text('LOKASI / AREA')), 
                              DataColumn(label: Text('SUBJEK KELUHAN')),
                              DataColumn(label: Text('PESAN & DETAIL')),
                              DataColumn(label: Text('TINDAKAN')),
                            ],
                            rows: displayedTickets.map((t) {
                              bool isDeptHead = t['role'] == 'Head Area';

                              return DataRow(
                                // FITUR SELECT PER BARIS
                                selected: _selectedTicketIds.contains(t['id']),
                                onSelectChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedTicketIds.add(t['id']);
                                    } else {
                                      _selectedTicketIds.remove(t['id']);
                                    }
                                  });
                                },
                                cells: [
                                  DataCell(Text(_formatDate(t['created_at']), style: const TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                                  DataCell(Column(
                                    mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text((t['nama_lengkap'] ?? 'Tanpa Nama').toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.slate800)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(t['nik'] ?? '-', style: const TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDeptHead ? AppColors.indigo50 : AppColors.slate100, 
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: isDeptHead ? AppColors.indigo500 : AppColors.slate200)
                                            ),
                                            child: Text(isDeptHead ? 'DEPT HEAD' : 'KARYAWAN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: isDeptHead ? AppColors.indigo600 : AppColors.slate600, letterSpacing: 1)),
                                          )
                                        ],
                                      ),
                                    ],
                                  )),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(color: AppColors.slate50, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(12)),
                                      child: Text((t['area'] ?? 'Belum Diatur').toString().toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 1)),
                                    )
                                  ),
                                  DataCell(Text((t['subject'] ?? '-').toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate800))),
                                  DataCell(SizedBox(
                                    width: 250,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t['message'] ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.slate600, fontWeight: FontWeight.bold)),
                                        if (_adminTab == 'Selesai' && t['balasan'] != null && t['balasan'].toString().isNotEmpty)
                                           Padding(
                                             padding: const EdgeInsets.only(top: 6.0),
                                             child: Text("Balasan: ${t['balasan']}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: AppColors.emerald500, fontWeight: FontWeight.bold)),
                                           ),
                                      ],
                                    ),
                                  )),
                                  DataCell(
                                    _adminTab == 'Open'
                                      ? ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                                          onPressed: () => setState(() => _replyingTo = t),
                                          icon: const Icon(Icons.reply, color: Colors.white, size: 14),
                                          label: const Text("BALAS & TUTUP", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(color: AppColors.emerald50, border: Border.all(color: AppColors.emerald200), borderRadius: BorderRadius.circular(12)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.check, size: 14, color: AppColors.emerald600),
                                              SizedBox(width: 4),
                                              Text("SELESAI", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.emerald600, letterSpacing: 1)),
                                            ],
                                          ),
                                        )
                                  )
                                ]
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    if (displayedTickets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 80),
                        child: Center(
                          child: Text(_adminTab == 'Open' ? "TIDAK ADA TIKET YANG MENUNGGU SAAT INI." : "BELUM ADA RIWAYAT TIKET SELESAI.", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
                        ),
                      )
                  ],
                ),
              ),
            ],
          ),
        ),

        // MODAL BALAS TIKET (ADMIN)
        if (_replyingTo != null) _buildAdminReplyModal()
      ],
    );
  }

  Widget _buildAdminTabBtn(String label, String tabValue) {
    bool isActive = _adminTab == tabValue;
    return GestureDetector(
      onTap: () {
        if (_adminTab != tabValue) {
          setState(() {
            _adminTab = tabValue;
            _selectedTicketIds.clear(); // Bersihkan centang saat pindah tab
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.yellow500 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isActive ? AppColors.slate900 : AppColors.slate500, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildAdminReplyModal() {
    return Container(
      color: AppColors.slate900.withValues(alpha: 0.8),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(48), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 20)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("BALAS TIKET KELUHAN", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: -0.5)),
                    IconButton(onPressed: () => setState(() { _replyingTo = null; _replyMsg = ''; }), icon: const Icon(Icons.close, color: AppColors.slate400), tooltip: 'Tutup')
                  ],
                ),
                const SizedBox(height: 24),
                
                // Ringkasan Keluhan
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.slate100)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text((_replyingTo!['nama_lengkap'] ?? 'User').toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 1)),
                          Text(_formatDate(_replyingTo!['created_at']), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, fontFamily: 'monospace')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text((_replyingTo!['subject'] ?? '-').toString().toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800)),
                      const SizedBox(height: 4),
                      Text('"${_replyingTo!['message']}"', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate600, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Form Balasan
                const Text("PESAN BALASAN & SOLUSI", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 2)),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 4,
                  onChanged: (v) => _replyMsg = v,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate700),
                  decoration: InputDecoration(
                    hintText: "Ketik balasan Anda di sini...",
                    filled: true, fillColor: AppColors.slate50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.slate200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.slate200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.emerald500, width: 2)),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 10, shadowColor: AppColors.emerald500.withValues(alpha: 0.3)),
                    onPressed: _isReplying ? null : _submitReply,
                    icon: _isReplying ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    label: Text(_isReplying ? "MENGIRIM..." : "KIRIM & SELESAIKAN TIKET", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAMPILAN KHUSUS KARYAWAN
  // ==========================================
  Widget _buildEmployeeView(List<Map<String, dynamic>> allTickets) {
    List<Map<String, dynamic>> myTickets = allTickets.where((t) => t['user_id'] == widget.user.id).toList();
    myTickets.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.slate600, size: 24),
                onPressed: widget.onBack,
                tooltip: 'Kembali',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white, 
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.slate200))
                ),
              ),
              const SizedBox(width: 16),
              const Text("PUSAT BANTUAN", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.slate900, letterSpacing: -0.5)),
            ],
          ),
          const SizedBox(height: 32),

          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 800;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- KOLOM KIRI (INFO KONTAK CS & FAQ) ---
                  Expanded(
                    flex: isWide ? 4 : 0,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(color: AppColors.slate900, borderRadius: BorderRadius.circular(32)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: AppColors.yellow500, borderRadius: BorderRadius.circular(16)),
                                child: const Icon(Icons.phone_in_talk, color: AppColors.slate900, size: 24),
                              ),
                              const SizedBox(height: 24),
                              const Text("LAYANAN CS", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                              const SizedBox(height: 8),
                              const Text("Hubungi administrator jika Anda mengalami kendala mendesak terkait sistem.", style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold, height: 1.5)),
                              const SizedBox(height: 24),
                              
                              Container(
                                padding: const EdgeInsets.all(20),
                                width: double.infinity,
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("WHATSAPP ADMIN", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 1)),
                                    SizedBox(height: 8),
                                    Text("+62 812-3456-7890 dan +62 851-9165-1651", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.emerald500)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(20),
                                width: double.infinity,
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("EMAIL SUPPORT", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white54, letterSpacing: 1)),
                                    SizedBox(height: 8),
                                    Text("hr.support@ut.co.id", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.blue500)),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // --- KETERANGAN SISTEM ---
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline, size: 18, color: AppColors.blue500),
                                  SizedBox(width: 8),
                                  Text("KETERANGAN SISTEM", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate900, letterSpacing: 1)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _buildFaqItem("GAGAL ABSEN LOKASI / GPS?", "Pastikan izin lokasi GPS di browser atau HP Anda aktif. Jika peta tidak muncul, klik tombol \"Deteksi Ulang\".", AppColors.yellow500),
                              const SizedBox(height: 16),
                              _buildFaqItem("ABSEN PERJALANAN DINAS", "Gunakan status \"Perjalanan Dinas\" pada menu Kehadiran. Sistem akan melacak alamat lokasi Anda secara otomatis tanpa dibatasi radius jarak.", AppColors.indigo500),
                              const SizedBox(height: 16),
                              _buildFaqItem("JAM KERJA TERLAMBAT", "Sistem secara otomatis menandai \"Terlambat\" jika Anda absen melebihi batas masuk pada shift kerja Anda.", AppColors.emerald500),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  if (isWide) const SizedBox(width: 24),
                  if (!isWide) const SizedBox(height: 24),

                  // --- KOLOM KANAN (FORM & RIWAYAT) ---
                  Expanded(
                    flex: isWide ? 6 : 0,
                    child: Column(
                      children: [
                        // FORM KELUHAN BARU
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.send, size: 18, color: AppColors.yellow500),
                                  SizedBox(width: 8),
                                  Text("BUAT TIKET KELUHAN BARU", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate900, letterSpacing: 1)),
                                ],
                              ),
                              const SizedBox(height: 32),
                              
                              const Text("SUBJEK KELUHAN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 2)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _subject.isEmpty ? null : _subject,
                                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500),
                                decoration: InputDecoration(
                                  filled: true, fillColor: AppColors.slate50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
                                ),
                                hint: const Text("Pilih Kategori Masalah...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                items: ['Aplikasi / GPS Error', 'Perubahan Data Profil', 'Perubahan Shift / Jadwal', 'Lainnya']
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))).toList(),
                                onChanged: (v) => setState(() => _subject = v!),
                              ),
                              
                              const SizedBox(height: 24),
                              const Text("DETAIL PESAN / ALASAN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 2)),
                              const SizedBox(height: 8),
                              TextField(
                                maxLines: 4,
                                onChanged: (v) => _message = v,
                                controller: TextEditingController(text: _message)..selection = TextSelection.collapsed(offset: _message.length),
                                decoration: InputDecoration(
                                  hintText: "Jelaskan masalah Anda secara detail...",
                                  hintStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black38),
                                  filled: true, fillColor: AppColors.slate50,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
                                ),
                              ),
                              
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity, height: 60,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                  onPressed: _isSubmitting ? null : _submitTicket,
                                  icon: _isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.yellow500, strokeWidth: 2)) : const Icon(Icons.send, color: Colors.white, size: 16),
                                  label: Text(_isSubmitting ? "MENGIRIM..." : "KIRIM TIKET", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // RIWAYAT TIKET KARYAWAN
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("RIWAYAT TIKET ANDA", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 2)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                                    child: Text("${myTickets.length} TIKET", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate400)),
                                  )
                                ],
                              ),
                              const Divider(height: 32),
                              
                              if (myTickets.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.speaker_notes_off, size: 40, color: AppColors.slate200),
                                        SizedBox(height: 16),
                                        Text("BELUM ADA RIWAYAT TIKET KELUHAN.", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 1)),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Column(
                                  children: myTickets.map((t) => Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.slate100)),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(_formatDate(t['created_at']), style: const TextStyle(fontSize: 9, color: AppColors.slate400, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                                  const SizedBox(height: 4),
                                                  Text((t['subject'] ?? '-').toString().toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800)),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(color: t['status'] == 'Selesai' ? AppColors.emerald50 : AppColors.yellow500, border: Border.all(color: t['status'] == 'Selesai' ? AppColors.emerald200 : AppColors.yellow500), borderRadius: BorderRadius.circular(12)),
                                              child: Text(t['status'] == 'Open' ? 'DIPROSES' : 'SELESAI', style: TextStyle(color: t['status'] == 'Selesai' ? AppColors.emerald600 : AppColors.yellow500, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                            )
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity, padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.slate100)),
                                          child: Text('"${t['message']}"', style: const TextStyle(fontSize: 11, color: AppColors.slate600, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                                        ),
                                        if (t['balasan'] != null && t['balasan'].toString().isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            width: double.infinity, padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(color: AppColors.emerald50.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: AppColors.emerald500, width: 4))),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text("BALASAN ADMIN", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.emerald600, letterSpacing: 1)),
                                                const SizedBox(height: 4),
                                                Text('"${t['balasan']}"', style: const TextStyle(fontSize: 11, color: AppColors.slate700, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          )
                                        ]
                                      ],
                                    ),
                                  )).toList(),
                                )
                            ],
                          ),
                        )
                      ],
                    ),
                  )
                ],
              );
            }
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String title, String desc, Color indicatorColor) {
    return Container(
      decoration: BoxDecoration(border: Border(left: BorderSide(color: indicatorColor, width: 4))),
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate900)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 10, color: AppColors.slate400, fontWeight: FontWeight.bold, height: 1.5)),
        ],
      ),
    );
  }
}
