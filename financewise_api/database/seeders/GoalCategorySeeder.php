<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;

class GoalCategorySeeder extends Seeder
{
    public function run()
    {
        $goalCategories = [
            [
                'name' => 'Voyage',
                'icon' => 'flight',
                'color' => '#2196F3',
                'type' => 'financial_goal',
                'is_system' => true,
            ],
            [
                'name' => 'Achat',
                'icon' => 'shopping_cart',
                'color' => '#FF9800',
                'type' => 'financial_goal',
                'is_system' => true,
            ],
            [
                'name' => 'Épargne',
                'icon' => 'savings',
                'color' => '#4CAF50',
                'type' => 'financial_goal',
                'is_system' => true,
            ],
            [
                'name' => 'Éducation',
                'icon' => 'school',
                'color' => '#9C27B0',
                'type' => 'financial_goal',
                'is_system' => true,
            ],
            [
                'name' => 'Santé',
                'icon' => 'local_hospital',
                'color' => '#F44336',
                'type' => 'financial_goal',
                'is_system' => true,
            ],
            [
                'name' => 'Logement',
                'icon' => 'home',
                'color' => '#795548',
                'type' => 'financial_goal',
                'is_system' => true,
            ],
            [
                'name' => 'Transport',
                'icon' => 'directions_car',
                'color' => '#607D8B',
                'type' => 'financial_goal',
                'is_system' => true,
            ],
            [
                'name' => 'Technologie',
                'icon' => 'devices',
                'color' => '#3F51B5',
                'type' => 'financial_goal',
                'is_system' => true,
            ],
            [
                'name' => 'Événement',
                'icon' => 'celebration',
                'color' => '#E91E63',
                'type' => 'financial_goal',
                'is_system' => true,
            ],
            [
                'name' => 'Autre',
                'icon' => 'flag',
                'color' => '#9E9E9E',
                'type' => 'financial_goal',
                'is_system' => true,
            ],
        ];

        foreach ($goalCategories as $category) {
            Category::firstOrCreate(
                ['name' => $category['name'], 'type' => 'financial_goal'],
                $category
            );
        }
    }
}
