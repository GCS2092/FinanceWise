<?php

namespace Database\Seeders;

use App\Models\FinancialGoal;
use App\Models\User;
use Illuminate\Database\Seeder;

class GoalSeeder extends Seeder
{
    public function run(): void
    {
        $user = User::where('email', 'demo@financewise.com')->first();
        if (!$user) {
            return;
        }

        $goals = [
            [
                'name' => 'Fonds d\'urgence',
                'description' => 'Épargne de sécurité pour imprévus',
                'target_amount' => 1000000,
                'current_amount' => 350000,
                'target_date' => now()->addMonths(6),
                'icon' => 'savings',
                'color' => '#FF9800',
                'status' => 'pending',
            ],
            [
                'name' => 'Voiture',
                'description' => 'Achat d\'une voiture d\'occasion',
                'target_amount' => 3000000,
                'current_amount' => 750000,
                'target_date' => now()->addYears(1),
                'icon' => 'directions_car',
                'color' => '#2196F3',
                'status' => 'pending',
            ],
            [
                'name' => 'Voyage',
                'description' => 'Vacances à la fin de l\'année',
                'target_amount' => 500000,
                'current_amount' => 150000,
                'target_date' => now()->addMonths(8),
                'icon' => 'flight',
                'color' => '#9C27B0',
                'status' => 'pending',
            ],
            [
                'name' => 'Études des enfants',
                'description' => 'Fonds pour l\'éducation',
                'target_amount' => 2000000,
                'current_amount' => 200000,
                'target_date' => now()->addYears(2),
                'icon' => 'school',
                'color' => '#4CAF50',
                'status' => 'pending',
            ],
        ];

        foreach ($goals as $goal) {
            FinancialGoal::create([
                'user_id' => $user->id,
                'name' => $goal['name'],
                'description' => $goal['description'],
                'target_amount' => $goal['target_amount'],
                'current_amount' => $goal['current_amount'],
                'target_date' => $goal['target_date'],
                'icon' => $goal['icon'],
                'color' => $goal['color'],
                'status' => $goal['status'],
            ]);
        }
    }
}
