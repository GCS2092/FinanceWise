<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

class ParsedSmsFactory extends Factory
{
    protected $model = \App\Models\ParsedSms::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'provider' => fake()->randomElement(['wave', 'orange_money']),
            'raw_content' => fake()->sentence(10),
            'parsed_amount' => fake()->randomFloat(2, 100, 50000),
            'parsed_phone' => fake()->phoneNumber(),
            'parsed_type' => fake()->randomElement(['income', 'expense']),
            'transaction_id' => null,
            'status' => fake()->randomElement(['pending', 'processed', 'failed']),
            'error_message' => null,
            'parsed_at' => fake()->optional()->dateTime(),
        ];
    }
}
