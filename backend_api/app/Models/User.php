<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'nik', 'nama_lengkap', 'email', 'password', 'role',
        'departemen_id', 'jabatan', 'jenis_kelamin', 'area', 'shift',
        'kontak', 'alamat', 'tanggal_lahir', 'photo_base64', 'agama',
        
        'face_encoding', 'face_image_path', 'photo_change_count'
    ];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function attendances() { return $this->hasMany(Attendance::class); }
    public function requests() { return $this->hasMany(Request::class); }
    public function tickets() { return $this->hasMany(Ticket::class); }
    public function device() { return $this->hasOne(Device::class); }
}


