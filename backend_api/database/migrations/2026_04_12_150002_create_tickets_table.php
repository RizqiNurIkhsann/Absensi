<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tickets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('user_name')->nullable();
            $table->string('user_nik')->nullable();
            $table->string('subject');
            $table->text('message')->nullable();
            $table->string('category')->nullable();
            $table->string('status')->default('Open'); // 'Open', 'In Progress', 'Closed'
            $table->string('area')->nullable();
            $table->text('reply')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tickets');
    }
};
