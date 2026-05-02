<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('goal_reminders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('financial_goal_id')->constrained('financial_goals')->onDelete('cascade');
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('type'); // deadline_7days, deadline_3days, deadline_today, overdue, weekly, monthly, general_review
            $table->timestamp('scheduled_at');
            $table->timestamp('sent_at')->nullable();
            $table->string('status')->default('pending'); // pending, sent, failed, cancelled
            $table->text('message')->nullable();
            $table->timestamps();

            $table->index(['financial_goal_id', 'scheduled_at']);
            $table->index(['user_id', 'scheduled_at']);
            $table->index(['status', 'scheduled_at']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('goal_reminders');
    }
};
