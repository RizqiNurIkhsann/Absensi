import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../core/app_constants.dart';
import '../models/user_model.dart';

class DashboardView extends StatefulWidget {
  final UserModel user;

  const DashboardView({super.key, required this.user});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  String _refreshId = UniqueKey().toString();

  @override
  void initState() {
    super.initState();
    // Timer untuk update waktu secara berkala
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getFormattedBadgeSite() {
    String area = widget.user.area;
    if (area.toLowerCase().contains("united tractors")) {
      return area; 
    } else if (area.toLowerCase().startsWith("site ")) {
      return "United Tractors Tbk. $area";
    }
    return "United Tractors Tbk. Site $area";
  }

  // --- FUNGSI ADMIN: TAMBAH PENGUMUMAN ---
  Future<void> _showAddAnnouncementDialog() async {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController subCtrl = TextEditingController();
    TextEditingController descCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.campaign, color: AppColors.yellow500),
            SizedBox(width: 8),
            Text("Tambah Informasi", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.slate800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("JUDUL PENGUMUMAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
            const SizedBox(height: 8),
            TextField(
              controller: titleCtrl, 
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              decoration: InputDecoration(hintText: "Contoh: Pembaruan Sistem", filled: true, fillColor: AppColors.slate50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))
            ),
            const SizedBox(height: 16),
            
            const Text("SUB-JUDUL / PENULIS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
            const SizedBox(height: 8),
            TextField(
              controller: subCtrl, 
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              decoration: InputDecoration(hintText: "Contoh: Tim IT Support", filled: true, fillColor: AppColors.slate50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))
            ),
            const SizedBox(height: 16),

            const Text("ISI PENGUMUMAN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl, maxLines: 4, 
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              decoration: InputDecoration(hintText: "Ketik isi pengumuman di sini...", filled: true, fillColor: AppColors.slate50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              if (titleCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
              var items = await ApiService().getAnnouncements();
              items.add({
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'title': titleCtrl.text.trim(),
                  'subtitle': subCtrl.text.trim(),
                  'desc': descCtrl.text.trim(),
              });
              await ApiService().updateAnnouncements(items);
              if (mounted) {
                 setState(() => _refreshId = UniqueKey().toString());
                 Navigator.pop(c);
              }
            },
            child: const Text("Posting", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  // --- FUNGSI ADMIN: HAPUS PENGUMUMAN ---
  Future<void> _deleteAnnouncement(dynamic item) async {
    var items = await ApiService().getAnnouncements();
    items.removeWhere((e) => e['id'] == item['id']);
    await ApiService().updateAnnouncements(items);
    if (mounted) setState(() => _refreshId = UniqueKey().toString());
  }

  @override
  Widget build(BuildContext context) {
    String todayStr = DateFormat('yyyy-MM-dd').format(_currentTime);
    bool isSuperAdmin = widget.user.role == 'admin';
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Latar belakang abu-abu sangat muda
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 24 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- FUTURE DATA ABSENSI ---
            FutureBuilder<dynamic>(
              key: ValueKey('attendance_$_refreshId'),
              future: isSuperAdmin ? ApiService().getAttendanceHistory() : ApiService().getTodayAttendance(widget.user.id),
              builder: (context, snapshot) {
                
                // Variabel Karyawan Default
                String jamMasuk = '--:--';
                String jamKeluar = '--:--';
                String statusKedisiplinan = '-';

                // Variabel Admin Default
                int adminHadirHariIni = 0;

                if (snapshot.hasData) {
                  if (isSuperAdmin) {
                     // Logika Penghitungan Untuk Admin
                     var todayDocs = (snapshot.data as List<dynamic>).where((d) => d['date'] == todayStr).toList();
                     adminHadirHariIni = todayDocs.where((doc) {
                        String status = doc['status_kehadiran'] ?? '';
                        return status == 'Hadir' || status == 'Absen Pulang' || status == 'Pulang Cepat' || status == 'Perjalanan Dinas';
                     }).length;
                  } else {
                     // Cari data absensi khusus hari ini untuk Karyawan
                     var todayData = snapshot.data as Map<String, dynamic>?;
                     if (todayData != null && todayData.isNotEmpty) {
                       jamMasuk = todayData['jam_masuk'] ?? '--:--';
                       jamKeluar = todayData['jam_pulang'] ?? '--:--';
                       statusKedisiplinan = todayData['status_kedisiplinan'] ?? '-';
                     }
                  }
                }

                // --- LOGIKA STATUS KEDISIPLINAN (Hanya Terlambat yang muncul) ---
                bool isTerlambat = statusKedisiplinan.toLowerCase() == 'terlambat';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- KARTU GREETING ---
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isMobile ? 24 : 32),
                      decoration: BoxDecoration(
                        color: isSuperAdmin ? AppColors.slate900 : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: isSuperAdmin ? null : Border.all(color: AppColors.slate200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_currentTime).toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isSuperAdmin ? AppColors.slate400 : AppColors.slate400, letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isSuperAdmin ? "RINGKASAN SISTEM" : "HALO, ${widget.user.namaLengkap.split(' ').first.toUpperCase()}",
                            style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w900, color: isSuperAdmin ? Colors.white : AppColors.slate800, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 16),
                          if (!isSuperAdmin)
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.yellow500,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _getFormattedBadgeSite(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate900),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.slate900,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(widget.user.shift.toLowerCase().contains('malam') ? Icons.nightlight_round : Icons.wb_sunny, color: Colors.white, size: 14),
                                      const SizedBox(width: 8),
                                      Text(
                                        "SHIFT ${widget.user.shift.toUpperCase()}",
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              "Pantau aktivitas kehadiran dan status karyawan secara real-time.",
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- BAGIAN STATISTIK / DASHBOARD KARYAWAN ---
                    if (isSuperAdmin) 
                      // TAMPILAN KHUSUS ADMIN (TETAP MENGGUNAKAN ROW/WRAP)
                      FutureBuilder<List<dynamic>>(
                        key: ValueKey('users_$_refreshId'),
                        future: ApiService().getUsers(),
                        builder: (context, userSnap) {
                          int totalKaryawan = 0;
                          if (userSnap.hasData) {
                            totalKaryawan = userSnap.data!.where((doc) {
                              return doc['role'] != 'admin'; 
                            }).length;
                          }
                          return Row(
                            children: [
                              Expanded(child: _buildAdminStatCard(title: "HADIR HARI INI", value: adminHadirHariIni.toString(), icon: Icons.check_circle, iconColor: AppColors.emerald500, bgColor: const Color(0xFFF0FDF4))),
                              const SizedBox(width: 16),
                              Expanded(child: _buildAdminStatCard(title: "JUMLAH KARYAWAN", value: totalKaryawan.toString(), icon: Icons.people, iconColor: AppColors.blue500, bgColor: const Color(0xFFEFF6FF))),
                            ]
                          );
                        }
                      )
                    else 
                      // TAMPILAN BARU KHUSUS KARYAWAN (KOMPAK & KOMPLEKS)
                      Container(
                        padding: EdgeInsets.all(isMobile ? 20 : 32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.slate200),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildCompactStatItem("WAKTU MASUK", jamMasuk, Icons.login, AppColors.emerald500, AppColors.emerald50)),
                                Container(width: 1, height: 60, color: AppColors.slate100),
                                Expanded(child: _buildCompactStatItem("WAKTU KELUAR", jamKeluar, Icons.logout, AppColors.indigo500, AppColors.indigo50)),
                              ],
                            ),
                            // Hanya tampilkan peringatan merah bila statusnya terlambat
                            if (isTerlambat) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Divider(height: 1, color: AppColors.slate100),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2), // Light Rose
                                  border: Border.all(color: AppColors.rose200),
                                  borderRadius: BorderRadius.circular(16)
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.warning_rounded, color: AppColors.rose500, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      "STATUS: TERLAMBAT", 
                                      style: TextStyle(color: AppColors.rose500, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)
                                    ),
                                  ],
                                ),
                              )
                            ]
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // --- PAPAN INFORMASI & STATUS PERLINDUNGAN SISTEM ---
                    if (isSuperAdmin) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.shield, size: 48, color: AppColors.slate200),
                            const SizedBox(height: 16),
                            const Text(
                              "SISTEM AKTIF & TERLINDUNGI",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Semua layanan dan sensor GPS beroperasi secara normal.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Papan informasi tampil untuk semua (Admin punya tombol edit)
                    _buildPapanInformasi(isMobile, isSuperAdmin),
                  ],
                );
              }
            )
          ],
        ),
      ),
    );
  }

  // --- WIDGET STATISTIK ADMIN ---
  Widget _buildAdminStatCard({
    required String title, required String value, required IconData icon, required Color iconColor, required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: iconColor.withValues(alpha: 0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.slate800)),
        ],
      ),
    );
  }

  // --- WIDGET STATISTIK KOMPAK KARYAWAN ---
  Widget _buildCompactStatItem(String title, String value, IconData icon, Color color, Color bgColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(
          value, 
          style: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.w900, 
            color: value == '--:--' ? AppColors.slate300 : AppColors.slate800, 
            fontFamily: 'monospace'
          )
        ),
      ],
    );
  }

  // --- WIDGET PAPAN INFORMASI DINAMIS ---
  Widget _buildPapanInformasi(bool isMobile, bool isAdmin) {
    return FutureBuilder<List<dynamic>>(
      key: ValueKey('announcements_$_refreshId'),
      future: ApiService().getAnnouncements(),
      builder: (context, snapshot) {
        List<dynamic> items = [];
        
        if (snapshot.hasData) {
          items = snapshot.data!;
        } else if (snapshot.connectionState == ConnectionState.done && !snapshot.hasData) {
          // Fallback data awal jika kosong (Hanya untuk tampilan Karyawan, Admin tetap melihat kosong jika belum ada)
          if (!isAdmin) {
             items = [
               {
                 'id': 'default-1',
                 'title': 'Selamat Datang di Sistem Baru',
                 'subtitle': 'HR Department',
                 'desc': 'Gunakan menu Layanan Mandiri untuk mengajukan Izin, Cuti, Lembur, atau melaporkan kendala kepada tim Administrator.'
               },
               {
                 'id': 'default-2',
                 'title': 'Pengingat Keselamatan (HSE)',
                 'subtitle': 'HSE Dept - Otomatis',
                 'desc': 'Keselamatan adalah prioritas utama. Pastikan Anda selalu menggunakan APD (Alat Pelindung Diri) lengkap sebelum memasuki area.'
               }
             ];
          }
        }

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 20 : 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.slate200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.yellow50, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.campaign, color: AppColors.yellow500, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text("PAPAN INFORMASI", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1)),
                    ]
                  ),
                  if (isAdmin)
                    InkWell(
                      onTap: _showAddAnnouncementDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.blue50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.blue500)
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.add, size: 14, color: AppColors.blue500),
                            SizedBox(width: 4),
                            Text("TAMBAH", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.blue500)),
                          ],
                        ),
                      ),
                    )
                ],
              ),
              const SizedBox(height: 24),
              
              if (items.isEmpty)
                 const Center(
                   child: Padding(
                     padding: EdgeInsets.symmetric(vertical: 24),
                     child: Text("Belum ada informasi terbaru.", style: TextStyle(fontSize: 11, color: AppColors.slate400, fontWeight: FontWeight.bold)),
                   ),
                 )
              else
                 ...items.asMap().entries.map((entry) {
                   int idx = entry.key;
                   var item = entry.value;
                   return Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Expanded(child: _buildInfoItem(item['title'] ?? '', item['subtitle'] ?? '', item['desc'] ?? '')),
                           if (isAdmin)
                             IconButton(
                               icon: const Icon(Icons.delete_outline, color: AppColors.rose400, size: 18),
                               onPressed: () => _deleteAnnouncement(item),
                               tooltip: "Hapus Pengumuman",
                               padding: EdgeInsets.zero,
                               constraints: const BoxConstraints(),
                             )
                         ],
                       ),
                       if (idx < items.length - 1)
                         const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: AppColors.slate100)),
                     ],
                   );
                 }).toList(),
            ]
          )
        );
      }
    );
  }

  Widget _buildInfoItem(String title, String subtitle, String desc) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.slate800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.blue500, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.slate500, height: 1.5, fontWeight: FontWeight.bold)),
       ]
     );
  }
}
