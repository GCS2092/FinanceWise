<?php

namespace Database\Factories;

use App\Models\Category;
use App\Models\User;
use App\Models\Wallet;
use Illuminate\Database\Eloquent\Factories\Factory;

class TransactionFactory extends Factory
{
    protected $model = \App\Models\Transaction::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'category_id' => Category::factory(),
            'wallet_id' => Wallet::factory(),
            'type' => fake()->randomElement(['income', 'expense', 'transfer']),
            'amount' => fake()->randomFloat(2, 100, 50000),
            'description' => fake()->sentence(),
            'transaction_date' => fake()->dateTimeBetween('-30 days', 'now'),
            'source' => fake()->randomElement(['manual', 'sms_wave', 'sms_orange_money']),
            'external_id' => fake()->optional()->uuid(),
            'status' => 'completed',
        ];
    }
}
