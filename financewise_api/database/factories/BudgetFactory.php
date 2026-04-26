<?php

namespace Database\Factories;

use App\Models\Category;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class BudgetFactory extends Factory
{
    protected $model = \App\Models\Budget::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'category_id' => Category::factory(),
            'amount' => fake()->randomFloat(2, 10000, 200000),
            'period' => fake()->randomElement(['daily', 'weekly', 'monthly', 'yearly']),
            'start_date' => now()->startOfMonth(),
            'end_date' => now()->endOfMonth(),
            'spent' => fake()->randomFloat(2, 0, 150000),
            'is_active' => true,
        ];
    }
}
