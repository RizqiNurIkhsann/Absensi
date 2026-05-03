<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

class Jabatan extends Model
{
    use HasUuids;
    
    public $incrementing = false;
    protected $keyType = 'string';
    protected $fillable = ['id', 'departemen_id', 'nama_jabatan'];
}
