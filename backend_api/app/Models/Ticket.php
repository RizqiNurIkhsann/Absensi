<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Ticket extends Model
{
    use HasFactory;
    protected $fillable = [
        'user_id', 'user_name', 'user_nik', 'subject', 'message',
        'category', 'status', 'area', 'reply',
    ];

    public function user() { return $this->belongsTo(User::class); }
}
