<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\UserController;
use App\Http\Controllers\AttendanceController;
use App\Http\Controllers\ConfigController;
use App\Http\Controllers\RequestController;
use App\Http\Controllers\TicketController;
use App\Http\Controllers\FaceAuthController;

// Public routes
Route::post('/login', [AuthController::class, 'login']);
Route::post('/register', [AuthController::class, 'register']);
Route::post('/request-otp', [AuthController::class, 'requestOtp']);
Route::post('/reset-password', [AuthController::class, 'resetPassword']);
Route::post('/check-nik', [UserController::class, 'checkNik']);
Route::post('/check-email', [UserController::class, 'checkEmail']);
Route::get('/config/{key}', [ConfigController::class, 'show']); // Public: login/register needs areas & dept

// Protected routes
Route::middleware('auth:sanctum')->group(function () {
    // Auth
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/profile', [AuthController::class, 'profile']);
    Route::put('/profile', [AuthController::class, 'updateProfile']);
    Route::post('/change-password', [AuthController::class, 'changePassword']);

    // Face API
    Route::post('/register-face', [FaceAuthController::class, 'registerFace']);
    Route::post('/verify-face', [FaceAuthController::class, 'verifyFace']);

    // Users
    Route::get('/users', [UserController::class, 'index']);
    Route::post('/users', [UserController::class, 'store']);
    Route::get('/users/{id}', [UserController::class, 'show']);
    Route::put('/users/{id}', [UserController::class, 'update']);
    Route::delete('/users/{id}', [UserController::class, 'destroy']);
    Route::post('/users/{id}/reset-device', [UserController::class, 'resetDevice']);
    Route::post('/users/{id}/reset-face', [UserController::class, 'resetFace']);

    // Attendance
    Route::post('/attendance/clock-in', [AttendanceController::class, 'clockIn']);
    Route::post('/attendance/clock-out', [AttendanceController::class, 'clockOut']);
    Route::get('/attendance/today', [AttendanceController::class, 'todayRecord']);
    Route::get('/attendance/history', [AttendanceController::class, 'history']);
    Route::get('/attendance/all', [AttendanceController::class, 'allRecords']);
    Route::post('/attendance/store', [AttendanceController::class, 'store']);

    Route::put('/config/{key}', [ConfigController::class, 'update']);

    // Requests (Izin/Sakit/Cuti)
    Route::get('/requests', [RequestController::class, 'index']);
    Route::post('/requests', [RequestController::class, 'store']);
    Route::put('/requests/{id}/status', [RequestController::class, 'updateStatus']);
    Route::delete('/requests/{id}', [RequestController::class, 'destroy']);

    // Tickets (Help Desk)
    Route::get('/tickets', [TicketController::class, 'index']);
    Route::post('/tickets', [TicketController::class, 'store']);
    Route::put('/tickets/{id}', [TicketController::class, 'update']);
    Route::delete('/tickets/{id}', [TicketController::class, 'destroy']);

    // Master Data
    Route::apiResource('departemens', \App\Http\Controllers\DepartemenController::class);
    Route::apiResource('jabatans', \App\Http\Controllers\JabatanController::class);
    Route::apiResource('sites', \App\Http\Controllers\SiteController::class);
    Route::apiResource('shifts', \App\Http\Controllers\ShiftController::class);
    Route::apiResource('devices', \App\Http\Controllers\DeviceController::class);
});
