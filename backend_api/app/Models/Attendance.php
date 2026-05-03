<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Attendance extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id', 'user_nik', 'date', 'shift',
        'jam_masuk', 'jam_pulang', 'status_kehadiran', 'keterangan',
        'photo_base64', 'latitude', 'longitude',
        'latitude_pulang', 'longitude_pulang',
    ];

    public function user() { return $this->belongsTo(User::class); }
}
