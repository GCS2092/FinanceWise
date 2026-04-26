<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;

class CategorySeeder extends Seeder
{
    public function run(): void
    {
        $categories = [
            // Catégories spécifiques au Sénégal
            ['name' => 'Nourriture', 'icon' => 'food', 'color' => '#EF4444', 'type' => 'expense'],
            ['name' => 'Transport', 'icon' => 'transport', 'color' => '#3B82F6', 'type' => 'expense'],
            ['name' => 'Internet / Data', 'icon' => 'wifi', 'color' => '#8B5CF6', 'type' => 'expense'],
            ['name' => 'Wave', 'icon' => 'money', 'color' => '#10B981', 'type' => 'expense'],
            ['name' => 'Orange Money', 'icon' => 'money', 'color' => '#F97316', 'type' => 'expense'],
            ['name' => 'Free Money', 'icon' => 'money', 'color' => '#06B6D4', 'type' => 'expense'],
            ['name' => 'Wari', 'icon' => 'money', 'color' => '#8B5CF6', 'type' => 'expense'],
            ['name' => 'Proximo', 'icon' => 'shopping', 'color' => '#F59E0B', 'type' => 'expense'],
            ['name' => 'Jumia', 'icon' => 'shopping', 'color' => '#EC4899', 'type' => 'expense'],
            ['name' => 'Carburant', 'icon' => 'local_gas_station', 'color' => '#DC2626', 'type' => 'expense'],
            ['name' => 'Électricité', 'icon' => 'bolt', 'color' => '#FBBF24', 'type' => 'expense'],
            ['name' => 'Eau', 'icon' => 'water_drop', 'color' => '#3B82F6', 'type' => 'expense'],
            ['name' => 'Sénélec', 'icon' => 'bolt', 'color' => '#FBBF24', 'type' => 'expense'],
            ['name' => 'SDE', 'icon' => 'water_drop', 'color' => '#3B82F6', 'type' => 'expense'],
            ['name' => 'Canal+', 'icon' => 'tv', 'color' => '#8B5CF6', 'type' => 'expense'],
            ['name' => 'Santé', 'icon' => 'health', 'color' => '#EC4899', 'type' => 'expense'],
            ['name' => 'Pharmacie', 'icon' => 'local_pharmacy', 'color' => '#10B981', 'type' => 'expense'],
            ['name' => 'École / Université', 'icon' => 'school', 'color' => '#6366F1', 'type' => 'expense'],
            ['name' => 'Logement', 'icon' => 'home', 'color' => '#F97316', 'type' => 'expense'],
            ['name' => 'Loyer', 'icon' => 'home', 'color' => '#DC2626', 'type' => 'expense'],
            ['name' => 'Loisirs', 'icon' => 'game', 'color' => '#06B6D4', 'type' => 'expense'],
            ['name' => 'Restaurant', 'icon' => 'restaurant', 'color' => '#F59E0B', 'type' => 'expense'],
            ['name' => 'Café', 'icon' => 'coffee', 'color' => '#78350F', 'type' => 'expense'],
            ['name' => 'Taxi', 'icon' => 'local_taxi', 'color' => '#FBBF24', 'type' => 'expense'],
            ['name' => 'Bus Rapide', 'icon' => 'directions_bus', 'color' => '#3B82F6', 'type' => 'expense'],
            ['name' => 'Clando', 'icon' => 'directions_car', 'color' => '#F97316', 'type' => 'expense'],
            ['name' => 'Transferts famille', 'icon' => 'family_restroom', 'color' => '#10B981', 'type' => 'expense'],
            // Catégories générales
            ['name' => 'Revenus', 'icon' => 'income', 'color' => '#10B981', 'type' => 'income'],
            ['name' => 'Salaire', 'icon' => 'work', 'color' => '#3B82F6', 'type' => 'income'],
            ['name' => 'Business', 'icon' => 'business', 'color' => '#8B5CF6', 'type' => 'income'],
            ['name' => 'Investissement', 'icon' => 'trending_up', 'color' => '#10B981', 'type' => 'income'],
            ['name' => 'Épargne', 'icon' => 'savings', 'color' => '#06B6D4', 'type' => 'income'],
        ];

        foreach ($categories as $cat) {
            Category::factory()->system()->create($cat);
        }
    }
}
