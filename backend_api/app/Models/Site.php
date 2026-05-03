<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Site extends Model
{
    public $incrementing = false;
    protected $keyType = 'string';
    protected $fillable = ['id', 'nama_site', 'lat', 'lng', 'radius', 'is_locked', 'is_wfh_mode'];
}
