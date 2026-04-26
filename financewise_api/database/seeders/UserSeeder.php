<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        // User 1 — Demo avec beaucoup de données
        $user1 = User::factory()->create([
            'name' => 'Demo User',
            'email' => 'demo@financewise.com',
            'password' => 'password123',
        ]);

        // User 2 — Second user pour tests d'autorisation
        $user2 = User::factory()->create([
            'name' => 'Test User',
            'email' => 'test@financewise.com',
            'password' => 'password123',
        ]);

        // Wallets pour user1
        \App\Models\Wallet::factory()->create([
            'user_id' => $user1->id,
            'name' => 'Principal',
            'type' => 'mobile_money',
            'currency' => 'XOF',
            'balance' => 150000,
        ]);

        \App\Models\Wallet::factory()->create([
            'user_id' => $user1->id,
            'name' => 'Épargne',
            'type' => 'bank',
            'currency' => 'XOF',
            'balance' => 500000,
        ]);

        // Wallet pour user2
        \App\Models\Wallet::factory()->create([
            'user_id' => $user2->id,
            'name' => 'Principal',
            'type' => 'mobile_money',
            'currency' => 'XOF',
            'balance' => 75000,
        ]);
    }
}
