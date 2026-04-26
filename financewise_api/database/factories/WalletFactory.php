<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class WalletFactory extends Factory
{
    protected $model = \App\Models\Wallet::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'name' => fake()->randomElement(['Principal', 'Wave', 'Orange Money', 'Cash']),
            'balance' => fake()->randomFloat(2, 0, 500000),
            'currency' => 'XOF',
            'type' => fake()->randomElement(['cash', 'mobile_money', 'bank']),
        ];
    }
}
