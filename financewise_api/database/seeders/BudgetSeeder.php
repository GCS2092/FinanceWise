<?php

namespace Database\Seeders;

use App\Models\Budget;
use App\Models\Category;
use App\Models\User;
use Illuminate\Database\Seeder;

class BudgetSeeder extends Seeder
{
    public function run(): void
    {
        $user = User::where('email', 'demo@financewise.com')->first();
        if (!$user) {
            return;
        }

        $categories = Category::where('is_system', true)->pluck('id', 'name');

        $budgets = [
            [
                'category' => 'Nourriture',
                'amount' => 100000,
                'period' => 'monthly',
                'start_date' => now()->startOfMonth(),
                'end_date' => now()->endOfMonth(),
            ],
            [
                'category' => 'Transport',
                'amount' => 50000,
                'period' => 'monthly',
                'start_date' => now()->startOfMonth(),
                'end_date' => now()->endOfMonth(),
            ],
            [
                'category' => 'Internet / Data',
                'amount' => 30000,
                'period' => 'monthly',
                'start_date' => now()->startOfMonth(),
                'end_date' => now()->endOfMonth(),
            ],
            [
                'category' => 'Loisirs',
                'amount' => 40000,
                'period' => 'monthly',
                'start_date' => now()->startOfMonth(),
                'end_date' => now()->endOfMonth(),
            ],
            [
                'category' => 'Logement',
                'amount' => 100000,
                'period' => 'monthly',
                'start_date' => now()->startOfMonth(),
                'end_date' => now()->endOfMonth(),
            ],
        ];

        foreach ($budgets as $b) {
            $categoryId = $categories[$b['category']] ?? null;
            if (!$categoryId) {
                continue;
            }

            Budget::factory()->create([
                'user_id' => $user->id,
                'category_id' => $categoryId,
                'amount' => $b['amount'],
                'period' => $b['period'],
                'start_date' => $b['start_date'],
                'end_date' => $b['end_date'],
                'is_active' => true,
            ]);
        }
    }
}
