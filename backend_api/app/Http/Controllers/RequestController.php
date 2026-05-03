<?php

namespace App\Http\Controllers;

use App\Models\Request as LeaveRequest;
use Illuminate\Http\Request;

class RequestController extends Controller
{
    public function index(Request $request)
    {
        $query = LeaveRequest::query();
        if ($request->has('user_id')) $query->where('user_id', $request->user_id);
        if ($request->has('status')) $query->where('status', $request->status);
        if ($request->has('area')) $query->where('area', $request->area);
        return response()->json(['data' => $query->orderBy('created_at', 'desc')->get()]);
    }

    public function store(Request $request)
    {
        $user = $request->user();
        $leave = LeaveRequest::create([
            'user_id' => $user->id,
            'user_name' => $user->nama_lengkap,
            'user_nik' => $user->nik,
            'type' => $request->type,
            'reason' => $request->reason,
            'date_from' => $request->date_from,
            'date_to' => $request->date_to,
            'status' => 'Pending',
            'area' => $request->area ?? $user->area,
            'attachment_base64' => $request->attachment_base64,
        ]);
        return response()->json(['message' => 'Pengajuan berhasil', 'data' => $leave], 201);
    }

    public function updateStatus(Request $request, $id)
    {
        $leave = LeaveRequest::findOrFail($id);
        $leave->update([
            'status' => $request->status,
            'approved_by' => $request->user()->id,
        ]);
        return response()->json(['message' => 'Status diperbarui', 'data' => $leave->fresh()]);
    }

    public function destroy($id)
    {
        LeaveRequest::findOrFail($id)->delete();
        return response()->json(['message' => 'Request dihapus']);
    }
}
