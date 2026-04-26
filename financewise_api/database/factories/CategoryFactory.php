<?php

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;

class CategoryFactory extends Factory
{
    protected $model = \App\Models\Category::class;

    public function definition(): array
    {
        return [
            'name' => fake()->word(),
            'icon' => fake()->randomElement(['food', 'transport', 'wifi', 'money', 'school', 'shopping']),
            'color' => fake()->hexColor(),
            'type' => fake()->randomElement(['income', 'expense']),
            'is_system' => false,
            'user_id' => null,
        ];
    }

    public function system(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_system' => true,
            'user_id' => null,
        ]);
    }
}
