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
        // Supprimer l'enum et le remplacer par une string avec check constraint
        DB::statement("ALTER TABLE categories ALTER COLUMN type TYPE VARCHAR(50)");
        DB::statement("ALTER TABLE categories DROP CONSTRAINT IF EXISTS categories_type_check");
        DB::statement("ALTER TABLE categories ADD CONSTRAINT categories_type_check CHECK (type IN ('income', 'expense', 'financial_goal'))");
    }

    public function down(): void
    {
        // Recréer l'enum original
        DB::statement("ALTER TABLE categories DROP CONSTRAINT categories_type_check");
        DB::statement("ALTER TABLE categories ADD CONSTRAINT categories_type_check CHECK (type IN ('income', 'expense'))");
    }
};
