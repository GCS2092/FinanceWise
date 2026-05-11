<?php

namespace Database\Seeders;

use App\Models\User;
use App\Models\Wallet;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class WalletSeeder extends Seeder
{
    public function run(): void
    {
        // Créer un seul wallet 'Divers' pour les transactions non catégorisées
        $users = User::all();

        foreach ($users as $user) {
            // Vérifier si l'utilisateur a déjà un wallet Divers
            $existingDiversWallet = Wallet::where('user_id', $user->id)
                ->where('name', 'Divers')
                ->first();

            if (!$existingDiversWallet) {
                Wallet::create([
                    'user_id' => $user->id,
                    'name' => 'Divers',
                    'balance' => 0,
                    'currency' => 'XOF',
                    'type' => 'cash',
                ]);
            }
        }
    }
}
