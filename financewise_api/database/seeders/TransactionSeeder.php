<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Transaction;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Database\Seeder;

class TransactionSeeder extends Seeder
{
    public function run(): void
    {
        $user = User::where('email', 'demo@financewise.com')->first();
        if (!$user) {
            return;
        }

        $wallet = Wallet::where('user_id', $user->id)->where('name', 'Principal')->first();
        $categories = Category::where('is_system', true)->pluck('id', 'name');

        if (!$wallet || $categories->isEmpty()) {
            return;
        }

        $transactions = [
            // Revenus
            ['type' => 'income', 'amount' => 300000, 'description' => 'Salaire mensuel', 'category' => 'Revenus', 'date' => now()->startOfMonth()],
            ['type' => 'income', 'amount' => 50000, 'description' => 'Bonus freelance', 'category' => 'Revenus', 'date' => now()->subDays(20)],

            // Dépenses
            ['type' => 'expense', 'amount' => 15000, 'description' => 'Courses alimentaires', 'category' => 'Nourriture', 'date' => now()->subDays(2)],
            ['type' => 'expense', 'amount' => 8500, 'description' => 'Déjeuner rapide', 'category' => 'Nourriture', 'date' => now()->subDays(5)],
            ['type' => 'expense', 'amount' => 12000, 'description' => 'Essence', 'category' => 'Transport', 'date' => now()->subDays(3)],
            ['type' => 'expense', 'amount' => 5000, 'description' => 'Taxi moto', 'category' => 'Transport', 'date' => now()->subDays(1)],
            ['type' => 'expense', 'amount' => 25000, 'description' => 'Forfait internet', 'category' => 'Internet / Data', 'date' => now()->subDays(10)],
            ['type' => 'expense', 'amount' => 10000, 'description' => 'Crédit mobile', 'category' => 'Mobile Money', 'date' => now()->subDays(4)],
            ['type' => 'expense', 'amount' => 45000, 'description' => 'Frais de scolarité', 'category' => 'École / Université', 'date' => now()->subDays(15)],
            ['type' => 'expense', 'amount' => 12000, 'description' => 'Consultation médicale', 'category' => 'Santé', 'date' => now()->subDays(7)],
            ['type' => 'expense', 'amount' => 20000, 'description' => 'Transfert à famille', 'category' => 'Transferts', 'date' => now()->subDays(6)],
            ['type' => 'expense', 'amount' => 80000, 'description' => 'Loyer mensuel', 'category' => 'Logement', 'date' => now()->startOfMonth()],
            ['type' => 'expense', 'amount' => 15000, 'description' => 'Cinéma et sorties', 'category' => 'Loisirs', 'date' => now()->subDays(8)],
        ];

        foreach ($transactions as $trx) {
            $categoryId = $categories[$trx['category']] ?? null;
            if (!$categoryId) {
                continue;
            }

            Transaction::factory()->create([
                'user_id' => $user->id,
                'wallet_id' => $wallet->id,
                'category_id' => $categoryId,
                'type' => $trx['type'],
                'amount' => $trx['amount'],
                'description' => $trx['description'],
                'transaction_date' => $trx['date'],
                'source' => 'manual',
                'status' => 'completed',
            ]);
        }
    }
}
