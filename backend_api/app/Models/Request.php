<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Request extends Model
{
    use HasFactory;
    protected $fillable = [
        'user_id', 'user_name', 'user_nik', 'type', 'reason',
        'date_from', 'date_to', 'status', 'approved_by', 'area',
        'attachment_base64',
    ];

    public function user() { return $this->belongsTo(User::class); }
}
