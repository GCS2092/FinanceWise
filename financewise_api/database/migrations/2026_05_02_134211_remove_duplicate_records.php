<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Supprimer les doublons de wallets (garder le premier)
        DB::statement('
            DELETE FROM wallets w1
            USING wallets w2
            WHERE w1.id > w2.id
            AND w1.user_id = w2.user_id
            AND w1.name = w2.name
        ');

        // Supprimer les doublons de financial_goals (garder le premier)
        DB::statement('
            DELETE FROM financial_goals g1
            USING financial_goals g2
            WHERE g1.id > g2.id
            AND g1.user_id = g2.user_id
            AND g1.name = g2.name
        ');

        // Supprimer les doublons de categories (garder le premier)
        DB::statement('
            DELETE FROM categories c1
            USING categories c2
            WHERE c1.id > c2.id
            AND c1.user_id = c2.user_id
            AND c1.name = c2.name
        ');

        // Supprimer les doublons de payment_reminders (garder le premier)
        DB::statement('
            DELETE FROM payment_reminders p1
            USING payment_reminders p2
            WHERE p1.id > p2.id
            AND p1.user_id = p2.user_id
            AND p1.name = p2.name
        ');

        // Supprimer les doublons de budgets (garder le premier)
        DB::statement('
            DELETE FROM budgets b1
            USING budgets b2
            WHERE b1.id > b2.id
            AND b1.user_id = b2.user_id
            AND b1.category_id = b2.category_id
        ');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Rien à faire pour cette migration
    }
};
