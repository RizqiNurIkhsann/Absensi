import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../core/app_constants.dart';
import '../models/user_model.dart';

class AnnouncementView extends StatefulWidget {
  final UserModel user;

  const AnnouncementView({super.key, required this.user});

  @override
  State<AnnouncementView> createState() => _AnnouncementViewState();
}

class _AnnouncementViewState extends State<AnnouncementView> {
  Key _refreshKey = UniqueKey();
  
  Future<void> _showAddAnnouncementDialog() async {
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController subCtrl = TextEditingController();
    TextEditingController descCtrl = TextEditingController();
    bool isMobile = MediaQuery.of(context).size.width < 600;

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.campaign, color: AppColors.yellow500),
            const SizedBox(width: 8),
            Expanded(child: Text("Tambah Informasi", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.slate800, fontSize: isMobile ? 16 : 18))),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
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
                  'date': DateFormat('dd MMM yyyy').format(DateTime.now())
              });
              await ApiService().updateAnnouncements(items);
              if (mounted) {
                 setState(() => _refreshKey = UniqueKey());
                 Navigator.pop(c);
              }
            },
            child: const Text("Posting", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  Future<void> _deleteAnnouncement(dynamic item) async {
    bool confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Hapus Pengumuman?"),
        content: const Text("Informasi ini akan dihapus dari dashboard seluruh karyawan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(c, true), 
            child: const Text("Hapus", style: TextStyle(color: Colors.white))
          )
        ],
      )
    );

    if (confirm == true) {
      var items = await ApiService().getAnnouncements();
      items.removeWhere((e) => e['id'] == item['id']);
      await ApiService().updateAnnouncements(items);
      if (mounted) setState(() => _refreshKey = UniqueKey());
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              const Text("PAPAN INFORMASI", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.slate900, letterSpacing: -0.5)),
              if (isMobile) const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.yellow500,
                  foregroundColor: AppColors.slate900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: _showAddAnnouncementDialog,
                icon: const Icon(Icons.add_alert, size: 18),
                label: const Text("BUAT PENGUMUMAN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
              )
            ],
          ),
          const SizedBox(height: 32),

          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.slate200),
              boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10, offset: Offset(0, 4))]
            ),
            child: FutureBuilder<List<dynamic>>(
              key: _refreshKey,
              future: ApiService().getAnnouncements(),
              builder: (context, snapshot) {
                List<dynamic> items = [];
                
                if (snapshot.hasData) {
                  items = snapshot.data!;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate100, width: 2))),
                      child: Row(
                        children: [
                          const Icon(Icons.sort, color: AppColors.slate400, size: 20),
                          const SizedBox(width: 12),
                          Text("DAFTAR PENGUMUMAN (${items.length})", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 2)),
                        ],
                      ),
                    ),
                    
                    if (items.isEmpty)
                       const Padding(
                         padding: EdgeInsets.symmetric(vertical: 80),
                         child: Center(child: Text("BELUM ADA PENGUMUMAN YANG DIBUAT.", style: TextStyle(fontSize: 11, color: AppColors.slate400, fontWeight: FontWeight.w900, letterSpacing: 1))),
                       )
                    else
                       Padding(
                         padding: const EdgeInsets.all(32),
                         child: Column(
                           children: items.reversed.toList().asMap().entries.map((entry) {
                             int idx = entry.key;
                             var item = entry.value;
                             return Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Row(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Container(
                                       padding: const EdgeInsets.all(12),
                                       decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(16)),
                                       child: const Icon(Icons.campaign, color: AppColors.blue500, size: 24),
                                     ),
                                     const SizedBox(width: 20),
                                     Expanded(
                                       child: Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                            Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.slate800)),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.person, size: 12, color: AppColors.slate400),
                                                const SizedBox(width: 4),
                                                Text(item['subtitle'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.5)),
                                                const SizedBox(width: 12),
                                                const Icon(Icons.access_time, size: 12, color: AppColors.slate400),
                                                const SizedBox(width: 4),
                                                Text(item['date'] ?? 'Baru', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate400)),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(item['desc'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.5, fontWeight: FontWeight.bold)),
                                         ]
                                       ),
                                     ),
                                     const SizedBox(width: 16),
                                     IconButton(
                                       icon: const Icon(Icons.delete_outline, color: AppColors.rose500),
                                       onPressed: () => _deleteAnnouncement(item),
                                       tooltip: "Hapus Pengumuman",
                                       style: IconButton.styleFrom(backgroundColor: AppColors.rose50),
                                     )
                                   ],
                                 ),
                                 if (idx < items.length - 1)
                                   const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(height: 1, color: AppColors.slate200)),
                               ],
                             );
                           }).toList(),
                         ),
                       )
                  ],
                );
              }
            )
          )
        ],
      ),
    );
  }
}
