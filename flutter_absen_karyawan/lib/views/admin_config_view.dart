import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import '../core/app_constants.dart';

class AdminConfigView extends StatefulWidget {
  final List<dynamic>? initialLocations;
  const AdminConfigView({super.key, this.initialLocations});

  @override
  State<AdminConfigView> createState() => _AdminConfigViewState();
}

class _AdminConfigViewState extends State<AdminConfigView> {
  final MapController _mapController = MapController();
  final TextEditingController _siteNameCtrl = TextEditingController();
  final TextEditingController _latCtrl = TextEditingController();
  final TextEditingController _lngCtrl = TextEditingController();

  List<Map<String, dynamic>> _locations = [];
  String? _activeLocationId;

  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = '';

  void _syncControllers() {
    if (_activeLocation != null) {
      if (_siteNameCtrl.text != _activeLocation!['siteName']) {
        _siteNameCtrl.text = _activeLocation!['siteName'] ?? '';
      }
      if (_latCtrl.text != _activeLocation!['lat']?.toString()) {
        _latCtrl.text = _activeLocation!['lat']?.toString() ?? '';
      }
      if (_lngCtrl.text != _activeLocation!['lng']?.toString()) {
        _lngCtrl.text = _activeLocation!['lng']?.toString() ?? '';
      }
    }
  }

  Map<String, dynamic>? get _activeLocation {
    if (_activeLocationId == null || _locations.isEmpty) return null;
    try {
      return _locations.firstWhere((l) => l['id'] == _activeLocationId);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _siteNameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLocations != null) {
      _locations = widget.initialLocations!.map((e) => Map<String, dynamic>.from(e)).toList();
      if (_locations.isNotEmpty) {
        _activeLocationId = _locations.first['id'];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _moveToActiveLocation();
        });
      }
      _isLoading = false;
      _syncControllers();
    }
    _fetchConfig();
  }

  Future<void> _fetchConfig() async {
    try {
      var data = await ApiService().getConfigSite();
      if (!mounted) return;

      if (data != null) {
        setState(() {
          List<dynamic> locs = data['locations'] ?? [];
          _locations = locs.map((e) => Map<String, dynamic>.from(e)).toList();

          bool activeExists = _locations.any((l) => l['id'] == _activeLocationId);
          if (!activeExists && _locations.isNotEmpty) {
            _activeLocationId = _locations.first['id'];
          } else if (_locations.isEmpty) {
            _activeLocationId = null;
          }
          _syncControllers();
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _moveToActiveLocation();
        });
      }
    } catch (e) {
      debugPrint("Gagal mengambil config: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _moveToActiveLocation() {
    if (_activeLocation != null && _activeLocation!['lat'] != null) {
      _mapController.move(
        LatLng(_activeLocation!['lat'], _activeLocation!['lng']),
        15.0,
      );
    }
  }

  Future<void> _addLocation() async {
    String newId = 'site-${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _locations.add({
        'id': newId,
        'siteName': 'Site Baru',
        'lat': -2.1703, // Default koordinat baru
        'lng': 115.4218,
        'radius': 100,
        'isLocked': false,
        'isWfhMode': false, // Mode WFH default mati
        'isNew': true,
      });
      _activeLocationId = newId;
      _syncControllers();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _moveToActiveLocation();
    });
    
    // Auto-save ke backend agar data tidak hilang saat menekan tombol back
    await _saveConfig(autoSave: true);
  }

  Future<void> _saveConfig({bool autoSave = false, bool isDelete = false}) async {
    int activeIdx = _locations.indexWhere((l) => l['id'] == _activeLocationId);
    bool isNew = false;
    
    if (activeIdx != -1) {
      isNew = _locations[activeIdx]['isNew'] == true;
      if (!autoSave) {
        setState(() {
          _locations[activeIdx].remove('isNew');
        });
      }
      if (!isDelete && !autoSave) {
        setState(() {
          _locations[activeIdx]['isLocked'] = true;
        });
      }
    }

    String successMsg = "Data lokasi berhasil disimpan!";
    if (isDelete) {
      successMsg = "Data lokasi berhasil dihapus!";
    } else if (!isNew) {
      successMsg = "Data lokasi berhasil diupdate!";
    }

    setState(() => _isSaving = true);
    
    try {
      dynamic result = await ApiService().updateConfigSite({
        'locations': _locations,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
          
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: AppColors.emerald500,
          ),
        );
        if (!autoSave && !isDelete) {
           await _fetchConfig(); // Auto refresh data dari server
        }
      } else {
        throw Exception(result.toString());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menyimpan: ${e.toString()}"),
            backgroundColor: AppColors.rose500,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // FUNGSI BARU: Hapus Lokasi
  Future<void> _deleteLocation() async {
    if (_activeLocationId == null) return;
    
    int activeIdx = _locations.indexWhere((l) => l['id'] == _activeLocationId);
    if (activeIdx == -1) return;
    bool isNew = _locations[activeIdx]['isNew'] == true;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Hapus Lokasi?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text("Apakah Anda yakin ingin menghapus '${_activeLocation!['siteName']}'? Aksi ini tidak dapat dibatalkan.", style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          )
        ]
      )
    );

    if (!mounted) return;

    if (confirm == true) {
      setState(() {
        _locations.removeWhere((l) => l['id'] == _activeLocationId);
        if (_locations.isNotEmpty) {
          _activeLocationId = _locations.first['id'];
        } else {
          _activeLocationId = null;
        }
        _syncControllers();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moveToActiveLocation();
      });
      
      await _saveConfig(isDelete: true);
      if (!mounted) return;
      await _fetchConfig();
    }
  }

  Future<void> _resetConfig() async {
    int activeIdx = _locations.indexWhere((l) => l['id'] == _activeLocationId);
    if (activeIdx != -1) {
      setState(() {
        _locations[activeIdx]['isLocked'] = false;
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "🔓 Kunci Terbuka. Silakan atur ulang lokasi pada peta.",
          ),
          backgroundColor: AppColors.blue500,
        ),
      );
    }
  }

  Future<void> _getMyGPS() async {
    setState(() => _isSaving = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception("GPS Mati");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Izin Ditolak");
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      int activeIdx = _locations.indexWhere(
        (l) => l['id'] == _activeLocationId,
      );
      if (activeIdx != -1) {
        setState(() {
          _locations[activeIdx]['lat'] = position.latitude;
          _locations[activeIdx]['lng'] = position.longitude;
          _syncControllers();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _moveToActiveLocation();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal melacak GPS perangkat."),
            backgroundColor: AppColors.rose500,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _updateActiveLocation(String key, dynamic value) {
    int activeIdx = _locations.indexWhere((l) => l['id'] == _activeLocationId);
    if (activeIdx != -1) {
      setState(() {
        _locations[activeIdx][key] = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800; 

    List<Map<String, dynamic>> filteredLocations = _locations.where((loc) {
      return (loc['siteName'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Tombol Back & Judul
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.all(isMobile ? 8 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Icon(Icons.arrow_back, color: AppColors.slate600, size: isMobile ? 18 : 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "PENGATURAN RADAR & LOKASI",
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slate800,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            if (_isLoading)
               const SizedBox(height: 400, child: Center(child: CircularProgressIndicator(color: AppColors.yellow500)))
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  if (!isMobile) {
                    // --- TAMPILAN DESKTOP (Menyamping) ---
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildLeftColumn(filteredLocations, false),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 7,
                          child: _activeLocation == null 
                            ? _buildEmptyState()
                            : _buildDetailPanel(false),
                        ),
                      ],
                    );
                  } else {
                    // --- TAMPILAN MOBILE (Menurun ke Bawah) ---
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLeftColumn(filteredLocations, true),
                        const SizedBox(height: 24),
                        if (_activeLocation == null) 
                          _buildEmptyState()
                        else 
                          _buildDetailPanel(true),
                      ],
                    );
                  }
                }
              )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 400,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.slate200),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "Pilih atau Tambah Site untuk melihat pengaturan.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftColumn(List<Map<String, dynamic>> filteredLocations, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "DAFTAR SITE (${_locations.length})",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppColors.slate800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: _addLocation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.yellow500,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, size: 16, color: AppColors.slate900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Search Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate200),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                icon: Icon(Icons.search, size: 18, color: AppColors.slate400),
                hintText: "Cari lokasi site...",
                hintStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate400),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // List of Sites
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: isMobile ? 300 : 600),
            child: SingleChildScrollView(
              child: Column(
                children: filteredLocations.map((loc) {
                  bool isActive = loc['id'] == _activeLocationId;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _activeLocationId = loc['id'];
                        _syncControllers();
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _moveToActiveLocation();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.yellow50 : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isActive ? AppColors.yellow500 : AppColors.slate200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc['siteName'],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isActive ? AppColors.slate900 : AppColors.slate700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                loc['isLocked'] ? Icons.check_circle_outline : Icons.error_outline,
                                size: 14,
                                color: loc['isLocked'] ? AppColors.emerald500 : AppColors.amber500,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  loc['lat'] != null ? "${loc['lat'].toStringAsFixed(4)}, ${loc['lng'].toStringAsFixed(4)}" : "Belum diatur",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: loc['lat'] != null ? AppColors.slate500 : AppColors.rose500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          )
        ],
      ),
    );
  }

  // Widget untuk panel sebelah kanan / bawah (Peta dan Form)
  Widget _buildDetailPanel(bool isMobile) {
    bool isLocked = _activeLocation!['isLocked'] ?? false;
    bool isWfh = _activeLocation!['isWfhMode'] == true;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "RADAR: ${_activeLocation!['siteName'].toString().toUpperCase()}",
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slate800,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  if (isLocked)
                    InkWell(
                      onTap: _resetConfig,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.rose50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.rose500),
                            if (!isMobile) ...[
                              const SizedBox(width: 6),
                              const Text("RESET LOKASI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.rose600, letterSpacing: 1)),
                            ]
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // TOMBOL HAPUS LOKASI
                  InkWell(
                    onTap: isLocked ? null : _deleteLocation, // Tidak bisa hapus jika sedang dikunci
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isLocked ? AppColors.slate100 : AppColors.rose500,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, size: 14, color: isLocked ? AppColors.slate400 : Colors.white),
                          if (!isMobile) ...[
                            const SizedBox(width: 6),
                            Text("HAPUS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isLocked ? AppColors.slate400 : Colors.white, letterSpacing: 1)),
                          ]
                        ],
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),

          // PETA
          Container(
            height: isMobile ? 220 : 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: AppColors.slate900, // Warna gelap untuk tema peta
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _activeLocation!['lat'] != null
                        ? LatLng(_activeLocation!['lat'], _activeLocation!['lng'])
                        : const LatLng(-2.164177, 115.387570), // Default
                    initialZoom: 15.0,
                    interactionOptions: InteractionOptions(
                      flags: isLocked ? InteractiveFlag.none : InteractiveFlag.all,
                    ),
                    onTap: (tapPosition, point) {
                      if (!isLocked) {
                        _updateActiveLocation('lat', point.latitude);
                        _updateActiveLocation('lng', point.longitude);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      userAgentPackageName: 'com.ut.hrms',
                    ),
                    if (_activeLocation!['lat'] != null) ...[
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(_activeLocation!['lat'], _activeLocation!['lng']),
                            color: AppColors.yellow500.withValues(alpha: 0.15),
                            borderColor: AppColors.yellow500,
                            borderStrokeWidth: 2,
                            useRadiusInMeter: true,
                            radius: (_activeLocation!['radius'] ?? 100).toDouble(),
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_activeLocation!['lat'], _activeLocation!['lng']),
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on, color: AppColors.rose500, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                
                // Gunakan GPS Button (Floating di atas peta jika tidak dikunci)
                if (!isLocked)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.extended(
                      onPressed: _getMyGPS,
                      backgroundColor: AppColors.slate900,
                      icon: const Icon(Icons.my_location, color: Colors.white, size: 18),
                      label: const Text("Gunakan GPS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                    )
                  )
              ],
            ),
          ),
          const SizedBox(height: 32),

          // FORM INPUT BAWAH
          const Text("NAMA LOKASI SITE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
          const SizedBox(height: 8),
          TextField(
            controller: _siteNameCtrl,
            onChanged: (val) => _updateActiveLocation('siteName', val),
            enabled: !isLocked,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: isLocked ? AppColors.slate50 : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
            ),
          ),
          const SizedBox(height: 24),

          // KOLOM KOORDINAT YANG BISA DIEDIT (TextField)
          isMobile
            ? Column(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("LATITUD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _latCtrl,
                        onChanged: (val) {
                          double? parsed = double.tryParse(val);
                          if (parsed != null) {
                            _updateActiveLocation('lat', parsed);
                          }
                        },
                        enabled: !isLocked,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: "Contoh: -2.1774",
                          filled: true,
                          fillColor: isLocked ? AppColors.slate50 : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("LONGITUD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _lngCtrl,
                        onChanged: (val) {
                          double? parsed = double.tryParse(val);
                          if (parsed != null) {
                            _updateActiveLocation('lng', parsed);
                          }
                        },
                        enabled: !isLocked,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: "Contoh: 115.4225",
                          filled: true,
                          fillColor: isLocked ? AppColors.slate50 : Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
                        ),
                      ),
                    ],
                  ),
                ]
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("LATITUD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _latCtrl,
                          onChanged: (val) {
                            double? parsed = double.tryParse(val);
                            if (parsed != null) {
                              _updateActiveLocation('lat', parsed);
                            }
                          },
                          enabled: !isLocked,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: "Contoh: -2.1774",
                            filled: true,
                            fillColor: isLocked ? AppColors.slate50 : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("LONGITUD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _lngCtrl,
                          onChanged: (val) {
                            double? parsed = double.tryParse(val);
                            if (parsed != null) {
                              _updateActiveLocation('lng', parsed);
                            }
                          },
                          enabled: !isLocked,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: "Contoh: 115.4225",
                            filled: true,
                            fillColor: isLocked ? AppColors.slate50 : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 24),

          // FITUR BARU: TOMBOL WFH (TOGGLE BEBAS RADIUS)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "JARI-JARI (RADIUS): ${_activeLocation!['radius']?.toInt() ?? 100}M",
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1),
              ),
              Row(
                children: [
                  Icon(Icons.home_work, size: 14, color: isWfh ? AppColors.blue500 : AppColors.slate400),
                  const SizedBox(width: 6),
                  Text("MODE WFH", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isWfh ? AppColors.blue500 : AppColors.slate400, letterSpacing: 1)),
                  const SizedBox(width: 4),
                  Switch(
                    value: isWfh,
                    onChanged: isLocked ? null : (val) => _updateActiveLocation('isWfhMode', val),
                    activeThumbColor: AppColors.blue500,
                  ),
                ],
              ),
            ],
          ),
          Slider(
            value: (_activeLocation!['radius'] ?? 100).toDouble(),
            min: 30, max: 500, divisions: 470,
            activeColor: AppColors.yellow500,
            inactiveColor: AppColors.slate200,
            thumbColor: AppColors.slate800,
            onChanged: isLocked ? null : (val) => _updateActiveLocation('radius', val.toInt()),
          ),
          const SizedBox(height: 32),

          // TOMBOL SIMPAN / KETERANGAN KUNCI
          SizedBox(
            width: double.infinity,
            height: 60,
            child: isLocked
                ? Container(
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.slate200, style: BorderStyle.solid, width: 2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.shield, color: AppColors.slate400, size: 18),
                        SizedBox(width: 8),
                        Text("KOORDINAT SITE DIKUNCI", style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ],
                    ),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.yellow500,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _isSaving ? null : _saveConfig,
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.slate900, strokeWidth: 2))
                        : const Icon(Icons.lock_outline, color: AppColors.slate900, size: 20),
                    label: Text(
                      _isSaving ? "MENYIMPAN..." : "KUNCI & SIMPAN",
                      style: const TextStyle(color: AppColors.slate900, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
