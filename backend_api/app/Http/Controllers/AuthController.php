<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $request->validate(['nik' => 'required', 'password' => 'required']);
        $user = User::where('nik', $request->nik)->first();

        $reqMobile = $request->mobileDeviceId;
        $reqDesktop = $request->desktopDeviceId;

        if ($user->role !== 'admin') {
             $device = $user->device;
             
             if ($device) {
                 if ($reqMobile) {
                      if ($device->mobileDeviceId && $device->mobileDeviceId !== $reqMobile) {
                          return response()->json(['message' => 'Perangkat Handphone Anda tidak dikenali. Silakan hubungi Admin melalui Pusat Bantuan untuk mereset perangkat.'], 403);
                      } else if (!$device->mobileDeviceId) {
                          $device->update(['mobileDeviceId' => $reqMobile]);
                      }
                 }
                 
                 if ($reqDesktop) {
                      if ($device->desktopDeviceId && $device->desktopDeviceId !== $reqDesktop) {
                          return response()->json(['message' => 'Perangkat Desktop (PC) Anda tidak dikenali. Silakan hubungi Admin melalui Pusat Bantuan untuk mereset perangkat.'], 403);
                      } else if (!$device->desktopDeviceId) {
                          $device->update(['desktopDeviceId' => $reqDesktop]);
                      }
                 }
             } else {
                 if ($reqMobile || $reqDesktop) {
                     $user->device()->create([
                         'id' => Str::uuid()->toString(),
                         'mobileDeviceId' => $reqMobile,
                         'desktopDeviceId' => $reqDesktop
                     ]);
                 }
             }
        }

        $token = $user->createToken('auth_token')->plainTextToken;
        return response()->json(['message' => 'Login berhasil', 'token' => $token, 'user' => $user->fresh()]);
    }

    public function register(Request $request)
    {
        $request->validate([
            'nik' => 'required|unique:users',
            'nama_lengkap' => 'required',
            'password' => 'required|min:6',
        ]);

        $user = User::create([
            'nik' => $request->nik,
            'nama_lengkap' => $request->nama_lengkap,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role' => $request->role ?? 'Karyawan',
            'area' => $request->area,
            'shift' => $request->shift ?? 'Pagi',
            'departemen_id' => $request->departemen_id,
            'jabatan' => $request->jabatan,
            'jenis_kelamin' => $request->jenis_kelamin,
            'tanggal_lahir' => $request->tanggal_lahir,
            'agama' => $request->agama,
            'alamat' => $request->alamat,
            'kontak' => $request->kontak,
        ]);

        if ($request->mobileDeviceId || $request->desktopDeviceId) {
             $user->device()->create([
                 'id' => Str::uuid()->toString(),
                 'mobileDeviceId' => $request->mobileDeviceId,
                 'desktopDeviceId' => $request->desktopDeviceId
             ]);
        }

        $token = $user->createToken('auth_token')->plainTextToken;
        return response()->json(['message' => 'Registrasi berhasil', 'token' => $token, 'user' => $user->fresh()], 201);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();
        return response()->json(['message' => 'Logout berhasil']);
    }

    public function profile(Request $request)
    {
        return response()->json(['user' => $request->user()]);
    }

    public function updateProfile(Request $request)
    {
        $user = $request->user();
        $user->update($request->only([
            'nama_lengkap', 'email', 'kontak', 'alamat', 'tanggal_lahir',
            'photo_base64', 'jenis_kelamin', 'area', 'shift', 'departemen_id', 'jabatan',
        ]));
        // If they update their device somehow? Assuming profile doesn't.
        return response()->json(['message' => 'Profil diperbarui', 'user' => $user->fresh()]);
    }

    public function changePassword(Request $request)
    {
        $request->validate([
            'current_password' => 'required',
            'new_password' => 'required|min:6',
        ]);

        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json(['message' => 'Password lama salah'], 422);
        }

        $user->update(['password' => Hash::make($request->new_password)]);
        return response()->json(['message' => 'Password berhasil diubah']);
    }

    public function requestOtp(Request $request)
    {
        $request->validate([
            'email' => 'required|email'
        ]);

        $user = User::where('email', $request->email)->first();
        if (!$user) {
            return response()->json(['message' => 'Email tidak terdaftar di sistem kami.'], 404);
        }

        $otp = (string) rand(100000, 999999);
        $user->update([
            'otp_code' => $otp,
            'otp_expires_at' => now()->addMinutes(15)
        ]);

        try {
            Mail::send('emails.otp', ['otp' => $otp], function($message) use($request) {
                $message->to($request->email);
                $message->subject('Kode OTP Reset Password');
            });
            return response()->json(['message' => 'Kode OTP telah dikirim ke email Anda.']);
        } catch (\Exception $e) {
            return response()->json(['message' => 'Gagal mengirim email OTP. Pastikan konfigurasi SMTP benar.'], 500);
        }
    }

    public function resetPassword(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'otp_code' => 'required|string|size:6',
            'new_password' => 'required|min:6'
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user) {
            return response()->json(['message' => 'Email tidak terdaftar.'], 404);
        }

        if ($user->otp_code !== $request->otp_code) {
            return response()->json(['message' => 'Kode OTP salah.'], 400);
        }

        if (now()->greaterThan($user->otp_expires_at)) {
            return response()->json(['message' => 'Kode OTP sudah kedaluwarsa. Silakan minta kode baru.'], 400);
        }

        $user->update([
            'password' => Hash::make($request->new_password),
            'otp_code' => null,
            'otp_expires_at' => null
        ]);

        return response()->json(['message' => 'Password berhasil diubah.']);
    }
}
