<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // === 1. SETUP DEFAULT CONFIGS ===
        \DB::table('configs')->insert([
            [
                'key' => 'site',
                'value' => json_encode([
                    'locations' => [
                        [
                            'id' => 'site-1',
                            'siteName' => 'Kantor Pusat',
                            'lat' => -6.2088,
                            'lng' => 106.8456,
                            'radius' => 50,
                            'isLocked' => true,
                            'isWfhMode' => false,
                        ],
                        [
                            'id' => 'site-2',
                            'siteName' => 'Cabang Surabaya',
                            'lat' => -7.2575,
                            'lng' => 112.7521,
                            'radius' => 50,
                            'isLocked' => true,
                            'isWfhMode' => false,
                        ],
                    ],
                    'shifts' => [
                        ['id' => '1', 'name' => 'General', 'start' => '08:00', 'end' => '17:00', 'area' => 'Kantor Pusat'],
                        ['id' => '2', 'name' => 'Pagi', 'start' => '07:00', 'end' => '15:00', 'area' => 'Kantor Pusat'],
                        ['id' => '3', 'name' => 'Siang', 'start' => '15:00', 'end' => '23:00', 'area' => 'Kantor Pusat'],
                    ],
                    'struktur_organisasi' => [
                        ['departemen' => 'Manajemen', 'jabatan' => 'Direktur'],
                        ['departemen' => 'IT', 'jabatan' => 'Developer'],
                        ['departemen' => 'IT', 'jabatan' => 'Support'],
                        ['departemen' => 'Engineering', 'jabatan' => 'Staff'],
                        ['departemen' => 'HRD', 'jabatan' => 'Admin'],
                    ]
                ]),
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'key' => 'attendance_limits',
                'value' => json_encode([
                    'maxLateMinutes' => 15,
                    'maxEarlyLeaveMinutes' => 0,
                    'requireFaceMatch' => true,
                    'requireLiveSelfie' => true
                ]),
                'created_at' => now(),
                'updated_at' => now(),
            ]
        ]);

        // === 2. CREATE ADMIN & IT USERS (using create so 'hashed' cast works) ===
        User::create([
            'nik' => 'admin',
            'nama_lengkap' => 'Administrator Sistem',
            'email' => 'admin@komatsu.com',
            'password' => 'admin123',
            'role' => 'admin',
            'departemen_id' => 'Manajemen',
            'jabatan' => 'Direktur',
            'jenis_kelamin' => 'Laki-laki',
            'area' => 'Kantor Pusat',
            'shift' => 'General',
        ]);

        User::create([
            'nik' => 'it',
            'nama_lengkap' => 'IT Support',
            'email' => 'it@komatsu.com',
            'password' => 'it123',
            'role' => 'IT',
            'departemen_id' => 'IT',
            'jabatan' => 'Support',
            'jenis_kelamin' => 'Laki-laki',
            'area' => 'Kantor Pusat',
            'shift' => 'General',
        ]);

        // === 3. CREATE REGULAR EMPLOYEES ===
        User::create([
            'nik' => '7001',
            'nama_lengkap' => 'Budi Santoso',
            'email' => 'budi@komatsu.com',
            'password' => 'budi123',
            'role' => 'Karyawan',
            'departemen_id' => 'Engineering',
            'jabatan' => 'Staff',
            'jenis_kelamin' => 'Laki-laki',
            'area' => 'Kantor Pusat',
            'shift' => 'Pagi',
        ]);

        User::create([
            'nik' => '7002',
            'nama_lengkap' => 'Siti Aminah',
            'email' => 'siti@komatsu.com',
            'password' => 'siti123',
            'role' => 'Karyawan',
            'departemen_id' => 'HRD',
            'jabatan' => 'Admin',
            'jenis_kelamin' => 'Perempuan',
            'area' => 'Cabang Surabaya',
            'shift' => 'General',
        ]);
    }
}
