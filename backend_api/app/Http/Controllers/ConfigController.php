<?php

namespace App\Http\Controllers;

use App\Models\Config;
use App\Models\Site;
use App\Models\Shift;
use App\Models\Departemen;
use App\Models\Jabatan;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class ConfigController extends Controller
{
    public function show($key)
    {
        if ($key === 'site') {
            $locations = Site::all()->map(function($s) {
                return ['id' => $s->id, 'siteName' => $s->nama_site, 'lat' => $s->lat, 'lng' => $s->lng, 'radius' => $s->radius, 'isLocked' => (bool)$s->is_locked, 'isWfhMode' => (bool)$s->is_wfh_mode];
            });
            
            $shifts = Shift::all()->map(function($s) {
                return ['id' => $s->id, 'name' => $s->nama_shift, 'start' => $s->start_time, 'end' => $s->end_time, 'area' => $s->site_id];
            });
            
            $jabatans = Jabatan::all();
            $departemens = Departemen::all();
            
            $struktur = [];
            $deps = [];
            $jabatansList = [];
            
            foreach($departemens as $d) {
                $deps[] = $d->nama_departemen;
            }
            
            foreach($jabatans as $j) {
                $depName = $departemens->firstWhere('id', $j->departemen_id)?->nama_departemen ?? 'Unknown';
                $struktur[] = ['departemen' => $depName, 'jabatan' => $j->nama_jabatan];
                $jabatansList[] = $j->nama_jabatan;
            }
            
            return response()->json(['data' => [
                'locations' => $locations,
                'shifts' => $shifts,
                'struktur_organisasi' => $struktur,
                'departemens' => $deps,
                'jabatans' => array_values(array_unique($jabatansList)),
            ]]);
        }

        $config = Config::where('key', $key)->first();
        if (!$config) {
            return response()->json(['data' => null]);
        }
        return response()->json(['data' => $config->value]);
    }

    public function update(Request $request, $key)
    {
        try {
            $value = $request->input('value');
            if (!$value) {
                $value = $request->all();
            } else if (is_string($value)) {
                $value = json_decode($value, true);
            }

            // Reverse bridging: if 'site' json is uploaded, extract it to tables
            if ($key === 'site' && is_array($value)) {
                
                // 1. Sync Locations
                if (isset($value['locations'])) {
                    $submittedLocationIds = [];
                    foreach($value['locations'] as $loc) {
                        $id = $loc['id'] ?? Str::uuid()->toString();
                        $submittedLocationIds[] = $id;
                        Site::updateOrCreate(
                            ['id' => $id],
                            [
                                'nama_site' => $loc['siteName'],
                                'lat' => $loc['lat'],
                                'lng' => $loc['lng'],
                                'radius' => (int)$loc['radius'],
                                'is_locked' => $loc['isLocked'] ?? true,
                                'is_wfh_mode' => $loc['isWfhMode'] ?? false,
                            ]
                        );
                    }
                    // Delete removed locations
                    if (count($submittedLocationIds) > 0) {
                        $deletedSites = Site::whereNotIn('id', $submittedLocationIds)->get();
                        foreach($deletedSites as $ds) {
                            Shift::where('site_id', $ds->nama_site)->delete();
                            $ds->delete();
                        }
                    } else {
                        Shift::truncate();
                        Site::truncate();
                    }
                }
                
                // 2. Sync Shifts
                if (isset($value['shifts'])) {
                    $submittedShiftIds = [];
                    $activeSites = Site::pluck('nama_site')->toArray();
                    foreach($value['shifts'] as $s) {
                        if (!in_array($s['area'], $activeSites)) {
                            continue; // Prevent recreating orphan shifts from stale payloads
                        }
                        $id = $s['id'] ?? Str::uuid()->toString();
                        $submittedShiftIds[] = $id;
                        Shift::updateOrCreate(
                            ['id' => $id],
                            [
                                'nama_shift' => $s['name'],
                                'start_time' => $s['start'],
                                'end_time' => $s['end'],
                                'site_id' => $s['area'],
                            ]
                        );
                    }
                    // Delete removed shifts
                    if (count($submittedShiftIds) > 0) {
                        Shift::whereNotIn('id', $submittedShiftIds)->delete();
                    } else {
                        Shift::truncate();
                    }
                }

                // 3. Sync Departemens & Jabatans
                if (isset($value['departemens'])) {
                     $submittedDeps = [];
                     foreach($value['departemens'] as $dep) {
                          $submittedDeps[] = $dep;
                          $d = Departemen::firstOrCreate(['nama_departemen' => $dep]);
                          
                          $validJabatans = [];
                          if (isset($value['struktur_organisasi'])) {
                              foreach($value['struktur_organisasi'] as $struktur) {
                                  if ($struktur['departemen'] === $dep) {
                                      if (!empty($struktur['jabatan'])) {
                                          $validJabatans[] = $struktur['jabatan'];
                                          Jabatan::firstOrCreate([
                                              'departemen_id' => $d->id,
                                              'nama_jabatan' => $struktur['jabatan']
                                          ]);
                                      }
                                  }
                              }
                          }
                          // Delete removed jabatans for this departemen
                          if (count($validJabatans) > 0) {
                              Jabatan::where('departemen_id', $d->id)->whereNotIn('nama_jabatan', $validJabatans)->delete();
                          } else {
                              Jabatan::where('departemen_id', $d->id)->delete();
                          }
                     }
                     // Delete removed departemens
                     if (count($submittedDeps) > 0) {
                         Departemen::whereNotIn('nama_departemen', $submittedDeps)->delete();
                     } else {
                         Departemen::truncate();
                     }
                }


                // We don't save to Config JSON anymore for 'site' to prevent double truth source.
                return response()->json([
                    'message' => 'Site data synced to relational tables',
                    'data' => $value
                ]);
            }

            // Normal JSON config update for purely generic structures (e.g., attendance_limits)
            $config = Config::updateOrCreate(
                ['key' => $key],
                ['value' => is_string($value) ? $value : json_encode($value)]
            );

            return response()->json([
                'message' => 'Config berhasil disimpan',
                'data' => $config->value
            ]);
        } catch (\Exception $e) {
            \Log::error("Config Controller Error: " . $e->getMessage() . " at " . $e->getLine());
            return response()->json([
                'message' => 'Gagal menyimpan config',
                'error' => $e->getMessage()
            ], 500);
        }
    }
}

