<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use App\Models\User;
use Illuminate\Support\Facades\Storage;

class FaceAuthController extends Controller
{
    // Configure Python AI Service URL
    private $aiServiceUrl = 'http://127.0.0.1:5000';

    public function registerFace(Request $request)
    {
        $request->validate([
            'image' => 'required|file|max:10240', // Max 10MB
            'user_id' => 'required|exists:users,id'
        ]);

        $user = User::find($request->user_id);

        if (!$request->hasFile('image')) {
            return response()->json(['success' => false, 'message' => 'Image missing.']);
        }

        $imageFile = $request->file('image');

        // Forward multipart to Python AI Service
        try {
            $response = Http::attach(
                'image', 
                file_get_contents($imageFile->getRealPath()), 
                $imageFile->getClientOriginalName()
            )->post("{$this->aiServiceUrl}/encode-face");

            if ($response->successful()) {
                $data = $response->json();
                
                if (isset($data['success']) && $data['success'] == true) {
                    // Save image physically
                    $path = $imageFile->store('faces', 'public');

                    // Save encoding locally
                    $user->face_encoding = json_encode($data['encoding']);
                    $user->face_image_path = $path;
                    $user->photo_base64 = base64_encode(file_get_contents($imageFile->getRealPath()));
                    $user->photo_change_count = $user->photo_change_count + 1;
                    $user->save();

                    return response()->json([
                        'success' => true,
                        'message' => 'Wajah berhasil didaftarkan.'
                    ]);
                } else {
                    return response()->json(['success' => false, 'message' => $data['detail'] ?? 'Verifikasi AI gagal']);
                }
            } else {
                $errorData = $response->json();
                return response()->json([
                    'success' => false, 
                    'message' => $errorData['detail'] ?? 'Terjadi kesalahan pada AI Service.'
                ], 400);
            }
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => 'Tidak dapat terhubung ke AI Service.'], 500);
        }
    }

    public function verifyFace(Request $request)
    {
        $request->validate([
            'image' => 'required|file|max:10240',
            'user_id' => 'required|exists:users,id'
        ]);

        $user = User::find($request->user_id);

        if (!$user->face_encoding) {
            return response()->json(['success' => false, 'message' => 'Akun belum melakukan registrasi wajah.']);
        }

        $imageFile = $request->file('image');

        try {
            $response = Http::attach(
                'image', 
                file_get_contents($imageFile->getRealPath()), 
                $imageFile->getClientOriginalName()
            )->post("{$this->aiServiceUrl}/compare-face", [
                'db_encoding' => $user->face_encoding
            ]);

            if ($response->successful()) {
                $data = $response->json();

                if (isset($data['success']) && $data['success'] == true) {
                    if ($data['match'] == true) {
                        return response()->json([
                            'success' => true,
                            'message' => 'Wajah terverifikasi',
                            'confidence' => $data['confidence']
                        ]);
                    } else {
                        return response()->json([
                            'success' => false,
                            'message' => 'Wajah tidak cocok dengan profil terdaftar',
                            'confidence' => $data['confidence']
                        ]);
                    }
                } else {
                    return response()->json(['success' => false, 'message' => $data['detail'] ?? 'Pengenalan wajah gagal']);
                }
            } else {
                $errorData = $response->json();
                return response()->json([
                    'success' => false, 
                    'message' => $errorData['detail'] ?? 'Wajah tidak terdeteksi atau error AI Service'
                ], 400);
            }
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => 'Tidak dapat terhubung ke AI Service.'], 500);
        }
    }
}
