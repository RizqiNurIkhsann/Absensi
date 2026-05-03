<?php

namespace App\Http\Controllers;

use App\Models\Attendance;
use Illuminate\Http\Request;

class AttendanceController extends Controller
{
    public function clockIn(Request $request)
    {
        $user = $request->user();
        $date = $request->date ?? now()->addHours(8)->format('Y-m-d');

        $existing = Attendance::where('user_id', $user->id)->where('date', $date)->first();
        if ($existing) {
            $existing->update([
                'jam_masuk' => $request->jam_masuk,
                'status_kehadiran' => $request->status_kehadiran ?? 'Hadir',
                'shift' => $request->shift,
                'latitude' => $request->latitude,
                'longitude' => $request->longitude,
                'photo_base64' => $request->photo_base64,
                'keterangan' => $request->keterangan,
            ]);
            return response()->json(['message' => 'Absen Masuk diperbarui', 'data' => $existing->fresh()]);
        }

        $attendance = Attendance::create([
            'user_id' => $user->id,
            'user_nik' => $user->nik,
            'date' => $date,
            'shift' => $request->shift,
            'jam_masuk' => $request->jam_masuk,
            'status_kehadiran' => $request->status_kehadiran ?? 'Hadir',
            'latitude' => $request->latitude,
            'longitude' => $request->longitude,
            'photo_base64' => $request->photo_base64,
            'keterangan' => $request->keterangan,
        ]);

        return response()->json(['message' => 'Absen Masuk Berhasil', 'data' => $attendance]);
    }

    public function clockOut(Request $request)
    {
        $user = $request->user();
        $date = $request->date ?? now()->addHours(8)->format('Y-m-d');

        $attendance = Attendance::where('user_id', $user->id)->where('date', $date)->first();
        if (!$attendance) {
            return response()->json(['message' => 'Belum absen masuk hari ini'], 404);
        }

        $attendance->update([
            'jam_pulang' => $request->jam_pulang,
            'status_kehadiran' => $request->status_kehadiran ?? 'Absen Pulang',
            'latitude_pulang' => $request->latitude,
            'longitude_pulang' => $request->longitude,
            'keterangan' => $request->keterangan,
        ]);

        return response()->json(['message' => 'Absen Pulang Berhasil', 'data' => $attendance->fresh()]);
    }

    public function todayRecord(Request $request)
    {
        $date = $request->date ?? now()->addHours(8)->format('Y-m-d');
        $record = Attendance::where('user_id', $request->user()->id)->where('date', $date)->first();
        return response()->json(['data' => $record]);
    }

    public function history(Request $request)
    {
        $query = $request->user()->attendances()->orderBy('date', 'desc');
        if ($request->has('month')) {
            $query->where('date', 'like', $request->month . '%');
        }
        return response()->json(['data' => $query->get()]);
    }

    public function allRecords(Request $request)
    {
        $query = Attendance::with('user');
        if ($request->has('date')) $query->where('date', $request->date);
        if ($request->has('user_id')) $query->where('user_id', $request->user_id);
        return response()->json(['data' => $query->orderBy('date', 'desc')->get()]);
    }

    public function store(Request $request)
    {
        $attendance = Attendance::updateOrCreate(
            ['user_id' => $request->user_id, 'date' => $request->date],
            $request->only([
                'user_nik', 'shift', 'jam_masuk', 'jam_pulang',
                'status_kehadiran', 'keterangan', 'photo_base64',
                'latitude', 'longitude', 'latitude_pulang', 'longitude_pulang',
            ])
        );
        return response()->json(['message' => 'Data absensi disimpan', 'data' => $attendance]);
    }
}
