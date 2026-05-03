class UserModel {
  final String id;
  final String namaLengkap;
  final String role;
  final String nik;
  final String departemenId;
  final String area;
  final String shift;
  final String deviceId; // Parameter keamanan pengunci perangkat

  UserModel({
    required this.id,
    required this.namaLengkap,
    required this.role,
    required this.nik,
    this.departemenId = 'Umum',
    this.area = "Site Tabalong (Mabu'un)",
    this.shift = 'Pagi',
    this.deviceId = '', 
  });

  factory UserModel.fromJson(Map<String, dynamic> json, [String? id]) {
    return UserModel(
      id: id ?? json['id'] ?? '',
      namaLengkap: json['nama_lengkap'] ?? 'Pengguna',
      role: json['role'] ?? 'Karyawan',
      nik: json['nik'] ?? '-',
      departemenId: json['departemen_id'] ?? 'Umum',
      area: json['area'] ?? "Site Tabalong (Mabu'un)",
      shift: json['shift'] ?? 'Pagi',
      deviceId: json['device_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama_lengkap': namaLengkap,
      'role': role,
      'nik': nik,
      'departemen_id': departemenId,
      'area': area,
      'shift': shift,
      'device_id': deviceId,
    };
  }
}