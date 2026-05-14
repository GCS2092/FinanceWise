<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('ai_conversation_summaries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('conversation_id')->constrained('ai_conversations')->cascadeOnDelete();
            $table->unsignedBigInteger('from_message_id')->nullable();
            $table->unsignedBigInteger('to_message_id')->nullable();
            $table->text('body');
            $table->json('meta')->nullable();
            $table->timestamps();
            $table->index(['conversation_id', 'to_message_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ai_conversation_summaries');
    }
};
