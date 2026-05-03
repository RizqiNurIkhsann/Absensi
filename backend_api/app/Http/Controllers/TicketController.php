<?php

namespace App\Http\Controllers;

use App\Models\Ticket;
use Illuminate\Http\Request;

class TicketController extends Controller
{
    public function index(Request $request)
    {
        $query = Ticket::query();
        if ($request->has('user_id')) $query->where('user_id', $request->user_id);
        if ($request->has('status')) $query->where('status', $request->status);
        if ($request->has('area')) $query->where('area', $request->area);
        return response()->json(['data' => $query->orderBy('created_at', 'desc')->get()]);
    }

    public function store(Request $request)
    {
        $user = $request->user();
        $ticket = Ticket::create([
            'user_id' => $user->id,
            'user_name' => $user->nama_lengkap,
            'user_nik' => $user->nik,
            'subject' => $request->subject,
            'message' => $request->message,
            'category' => $request->category,
            'status' => 'Open',
            'area' => $request->area ?? $user->area,
        ]);
        return response()->json(['message' => 'Tiket dibuat', 'data' => $ticket], 201);
    }

    public function update(Request $request, $id)
    {
        $ticket = Ticket::findOrFail($id);
        $ticket->update($request->only(['status', 'reply', 'message', 'subject', 'category']));
        return response()->json(['message' => 'Tiket diperbarui', 'data' => $ticket->fresh()]);
    }

    public function destroy($id)
    {
        Ticket::findOrFail($id)->delete();
        return response()->json(['message' => 'Tiket dihapus']);
    }
}
