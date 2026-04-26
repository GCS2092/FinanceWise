<?php

namespace Database\Seeders;

use App\Models\ParsedSms;
use App\Models\User;
use Illuminate\Database\Seeder;

class ParsedSmsSeeder extends Seeder
{
    public function run(): void
    {
        // Récupérer l'utilisateur demo
        $user = User::where('email', 'demo@financewise.com')->first();

        if (!$user) {
            return;
        }

        // SMS Wave reçus (income)
        ParsedSms::factory()->create([
            'user_id' => $user->id,
            'provider' => 'wave',
            'raw_content' => 'Vous avez reçu 50000 FCFA de Jean Dupont le 25/04/2026 14:30',
            'parsed_amount' => 50000,
            'parsed_phone' => 'Jean Dupont',
            'parsed_type' => 'income',
            'status' => 'processed',
            'parsed_at' => now(),
        ]);

        ParsedSms::factory()->create([
            'user_id' => $user->id,
            'provider' => 'wave',
            'raw_content' => 'Dépot de 100000 FCFA effectué avec succès le 20/04/2026 09:15',
            'parsed_amount' => 100000,
            'parsed_type' => 'income',
            'status' => 'processed',
            'parsed_at' => now(),
        ]);

        // SMS Orange Money dépenses (expense)
        ParsedSms::factory()->create([
            'user_id' => $user->id,
            'provider' => 'orange_money',
            'raw_content' => 'Transfert effectué: 25000 FCFA à Marie le 22/04/2026 16:45',
            'parsed_amount' => 25000,
            'parsed_type' => 'expense',
            'status' => 'processed',
            'parsed_at' => now(),
        ]);

        ParsedSms::factory()->create([
            'user_id' => $user->id,
            'provider' => 'orange_money',
            'raw_content' => 'Paiement restaurant nourriture: 15000 FCFA le 23/04/2026 12:30',
            'parsed_amount' => 15000,
            'parsed_type' => 'expense',
            'status' => 'processed',
            'parsed_at' => now(),
        ]);

        // SMS Wave dépenses
        ParsedSms::factory()->create([
            'user_id' => $user->id,
            'provider' => 'wave',
            'raw_content' => 'Paiement internet: 5000 FCFA le 24/04/2026 10:00',
            'parsed_amount' => 5000,
            'parsed_type' => 'expense',
            'status' => 'processed',
            'parsed_at' => now(),
        ]);

        // SMS échoué (non parsable)
        ParsedSms::factory()->create([
            'user_id' => $user->id,
            'provider' => 'wave',
            'raw_content' => 'Message texte sans montant spécifique',
            'status' => 'failed',
            'error_message' => 'Unable to parse SMS',
        ]);
    }
}
