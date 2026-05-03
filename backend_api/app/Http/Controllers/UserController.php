<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Device;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class UserController extends Controller
{
    public function index()
    {
        return response()->json(['data' => User::with('device')->get()]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'nik' => 'required|unique:users',
            'email' => 'required|email|unique:users',
        ]);

        $user = User::create($request->only([
            'nama_lengkap', 'email', 'role', 'nik', 'departemen_id', 'jabatan',
            'password', 'jenis_kelamin', 'area', 'shift', 'kontak', 'alamat', 'tanggal_lahir',
            'agama', 'photo_base64', 'device_id', 'face_encoding', 'face_image_path',
        ]));

        if ($request->mobileDeviceId || $request->desktopDeviceId) {
            $user->device()->create([
                 'id' => Str::uuid()->toString(),
                 'mobileDeviceId' => $request->mobileDeviceId,
                 'desktopDeviceId' => $request->desktopDeviceId
            ]);
        }
        return response()->json(['message' => 'User created', 'data' => $user->fresh()]);
    }

    public function show($id)
    {
        $user = User::with('device')->findOrFail($id);
        return response()->json(['data' => $user]);
    }

    public function update(Request $request, $id)
    {
        $user = User::findOrFail($id);
        $request->validate([
            'email' => 'required|email|unique:users,email,' . $user->id,
            'nik' => 'required|unique:users,nik,' . $user->id,
        ]);

        $user->update($request->only([
            'nama_lengkap', 'email', 'role', 'nik', 'departemen_id', 'jabatan',
            'jenis_kelamin', 'area', 'shift', 'kontak', 'alamat', 'tanggal_lahir',
            'agama', 'photo_base64', 'device_id', 'face_encoding', 'face_image_path',
        ]));

        if ($request->has('password') && !empty($request->password)) {
            $user->update(['password' => bcrypt($request->password)]);
        }

        if ($request->has('mobileDeviceId') || $request->has('desktopDeviceId')) {
            $user->device()->updateOrCreate([], [
                 'mobileDeviceId' => $request->mobileDeviceId ?? ($user->device->mobileDeviceId ?? null),
                 'desktopDeviceId' => $request->desktopDeviceId ?? ($user->device->desktopDeviceId ?? null)
            ]);
        }

        return response()->json(['message' => 'User updated', 'data' => $user->fresh()]);
    }

    public function destroy($id)
    {
        User::destroy($id);
        return response()->json(['message' => 'User deleted']);
    }

    public function resetDevice(Request $request, $id)
    {
        $user = User::findOrFail($id);
        
        if ($user->device) {
             if ($request->field == 'mobileDeviceId') {
                 $user->device()->update(['mobileDeviceId' => null]);
             } else if ($request->field == 'desktopDeviceId') {
                 $user->device()->update(['desktopDeviceId' => null]);
             } else {
                 $user->device()->delete();
             }
        }
        
        $user->update(['device_id' => null]);
        
        return response()->json(['message' => 'Device direset', 'data' => $user->fresh()]);
    }

    public function resetFace($id)
    {
        $user = User::findOrFail($id);
        $user->update([
            'face_encoding' => null, 
            'photo_base64' => null, 
            'face_image_path' => null,
            'photo_change_count' => 0
        ]);
        return response()->json(['message' => 'Face data direset', 'data' => $user->fresh()]);
    }

    public function checkNik(Request $request)
    {
        $exists = User::where('nik', $request->nik)->exists();
        return response()->json(['exists' => $exists]);
    }

    public function checkEmail(Request $request)
    {
        $exists = User::where('email', $request->email)->exists();
        return response()->json(['exists' => $exists]);
    }
}
