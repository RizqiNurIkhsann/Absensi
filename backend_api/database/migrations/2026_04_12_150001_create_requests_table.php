<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('user_name')->nullable();
            $table->string('user_nik')->nullable();
            $table->string('type'); // 'Izin', 'Sakit', 'Cuti', 'WFH'
            $table->string('reason')->nullable();
            $table->string('date_from');
            $table->string('date_to')->nullable();
            $table->string('status')->default('Pending'); // 'Pending', 'Disetujui', 'Ditolak'
            $table->unsignedBigInteger('approved_by')->nullable();
            $table->string('area')->nullable();
            $table->longText('attachment_base64')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('requests');
    }
};
