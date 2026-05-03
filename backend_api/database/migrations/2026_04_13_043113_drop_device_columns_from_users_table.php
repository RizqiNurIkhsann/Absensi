<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['device_id', 'mobileDeviceId', 'desktopDeviceId']);
        });
    }
    public function down(): void {
        Schema::table('users', function (Blueprint $table) {
            $table->string('device_id')->nullable();
            $table->string('mobileDeviceId')->nullable();
            $table->string('desktopDeviceId')->nullable();
        });
    }
};
