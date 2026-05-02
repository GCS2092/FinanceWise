<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::table('financial_goals', function (Blueprint $table) {
            $table->foreignId('category_id')->nullable()->after('color')->constrained('categories')->onDelete('set null');
            $table->string('reminder_frequency')->nullable()->after('status'); // weekly, biweekly, monthly
            $table->timestamp('last_reminder_sent_at')->nullable()->after('reminder_frequency');
        });
    }

    public function down()
    {
        Schema::table('financial_goals', function (Blueprint $table) {
            $table->dropForeign(['category_id']);
            $table->dropColumn(['category_id', 'reminder_frequency', 'last_reminder_sent_at']);
        });
    }
};
