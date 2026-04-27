<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // --- TRANSACTIONS ---
        Schema::table('transactions', function (Blueprint $table) {
            $table->index(['user_id', 'created_at'], 'idx_transactions_user_created');
            $table->index(['user_id', 'type'], 'idx_transactions_user_type');
            $table->index(['user_id', 'category_id'], 'idx_transactions_user_category');
            $table->index(['wallet_id', 'created_at'], 'idx_transactions_wallet_created');
            $table->index(['user_id', 'transaction_date'], 'idx_transactions_user_txdate');
        });

        // Index sur transactions récentes (tri par date desc pour queries dashboard/liste)
        DB::statement("
            CREATE INDEX IF NOT EXISTS idx_transactions_recent 
            ON transactions (user_id, transaction_date DESC)
        ");

        // Index sur expression DATE_TRUNC pour requêtes dashboard mensuelles
        DB::statement("
            CREATE INDEX IF NOT EXISTS idx_transactions_month_trunc 
            ON transactions (user_id, (DATE_TRUNC('month', transaction_date)))
        ");

        // --- BUDGETS ---
        Schema::table('budgets', function (Blueprint $table) {
            $table->index(['user_id', 'category_id'], 'idx_budgets_user_category');
            $table->index(['user_id', 'is_active', 'start_date', 'end_date'], 'idx_budgets_user_active_period');
        });

        // --- PARSED_SMS ---
        Schema::table('parsed_sms', function (Blueprint $table) {
            $table->index(['user_id', 'status'], 'idx_parsed_sms_user_status');
        });
    }

    public function down(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->dropIndex('idx_transactions_user_created');
            $table->dropIndex('idx_transactions_user_type');
            $table->dropIndex('idx_transactions_user_category');
            $table->dropIndex('idx_transactions_wallet_created');
            $table->dropIndex('idx_transactions_user_txdate');
        });

        DB::statement('DROP INDEX IF EXISTS idx_transactions_recent');
        DB::statement('DROP INDEX IF EXISTS idx_transactions_month_trunc');

        Schema::table('budgets', function (Blueprint $table) {
            $table->dropIndex('idx_budgets_user_category');
            $table->dropIndex('idx_budgets_user_active_period');
        });

        Schema::table('parsed_sms', function (Blueprint $table) {
            $table->dropIndex('idx_parsed_sms_user_status');
        });
    }
};
