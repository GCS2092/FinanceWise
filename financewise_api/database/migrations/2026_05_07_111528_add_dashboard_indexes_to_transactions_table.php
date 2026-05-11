<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            // Index composite pour les requêtes dashboard par date
            $table->index(['user_id', 'transaction_date'], 'idx_user_date');
            // Index pour filtrer par type et date
            $table->index(['user_id', 'type', 'transaction_date'], 'idx_user_type_date');
            // Index pour les requêtes de catégories
            $table->index(['user_id', 'category_id'], 'idx_user_category');
        });

        Schema::table('budgets', function (Blueprint $table) {
            // Index pour les requêtes de budgets actifs
            $table->index(['user_id', 'is_active', 'start_date', 'end_date'], 'idx_user_active_dates');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->dropIndex('idx_user_date');
            $table->dropIndex('idx_user_type_date');
            $table->dropIndex('idx_user_category');
        });

        Schema::table('budgets', function (Blueprint $table) {
            $table->dropIndex('idx_user_active_dates');
        });
    }
};
