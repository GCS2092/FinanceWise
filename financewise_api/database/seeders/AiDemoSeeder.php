<?php

namespace Database\Seeders;

use App\Models\AiCategoryCorrection;
use App\Models\Budget;
use App\Models\Category;
use App\Models\FinancialGoal;
use App\Models\PaymentReminder;
use App\Models\Transaction;
use App\Models\User;
use App\Models\Wallet;
use Carbon\Carbon;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * Seeder de démonstration complet pour tester l'IA.
 *
 * Crée un utilisateur "Aminata Diop" (Sénégal) avec :
 * - 3 wallets (Wave, Orange Money, Épargne BICIS)
 * - 30+ transactions variées sur 2 mois (revenus + dépenses Sénégal)
 * - 4 budgets (sain, en alerte, dépassé, neuf)
 * - 3 objectifs financiers (en cours, presque atteint, en retard)
 * - 2 rappels de paiement (Sénélec, Canal+)
 * - Quelques corrections de catégorisation pour démontrer l'apprentissage IA
 *
 * Identifiants de connexion :
 *   Email    : aminata@financewise.com
 *   Password : password123
 *
 * Lancement :
 *   php artisan db:seed --class=AiDemoSeeder
 */
class AiDemoSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        $this->command?->info('🌱 AiDemoSeeder — création du dataset de démo IA...');

        // ── 1. Catégories système (au cas où) ──
        if (Category::where('is_system', true)->count() === 0) {
            $this->call(CategorySeeder::class);
        }

        // ── 2. Utilisateur ──
        $user = User::updateOrCreate(
            ['email' => 'aminata@financewise.com'],
            [
                'name' => 'Aminata Diop',
                'password' => Hash::make('password123'),
                'monthly_income_target' => 450000,
                'onboarding_completed' => true,
                'email_verified_at' => now(),
            ]
        );
        $this->command?->info("   ✓ Utilisateur : {$user->email} (#{$user->id})");

        // Reset des données existantes pour éviter les doublons à chaque run
        Transaction::where('user_id', $user->id)->delete();
        Wallet::where('user_id', $user->id)->delete();
        Budget::where('user_id', $user->id)->delete();
        FinancialGoal::where('user_id', $user->id)->delete();
        PaymentReminder::where('user_id', $user->id)->delete();
        AiCategoryCorrection::where('user_id', $user->id)->delete();

        // ── 3. Wallets ──
        $wave = Wallet::create([
            'user_id' => $user->id, 'name' => 'Wave', 'type' => 'mobile_money',
            'currency' => 'XOF', 'balance' => 187500, 'is_default' => true,
        ]);
        $om = Wallet::create([
            'user_id' => $user->id, 'name' => 'Orange Money', 'type' => 'mobile_money',
            'currency' => 'XOF', 'balance' => 64200, 'is_default' => false,
        ]);
        $epargne = Wallet::create([
            'user_id' => $user->id, 'name' => 'Épargne BICIS', 'type' => 'bank',
            'currency' => 'XOF', 'balance' => 1_250_000, 'is_default' => false,
        ]);
        $this->command?->info('   ✓ 3 wallets (Wave, Orange Money, Épargne BICIS)');

        // ── 4. Catégories de référence ──
        $cat = fn (string $name) => Category::where('name', $name)->where('is_system', true)->first();

        $catSalaire     = $cat('Salaire');
        $catBusiness    = $cat('Business');
        $catRestaurant  = $cat('Restaurant');
        $catTaxi        = $cat('Taxi');
        $catTransport   = $cat('Transport');
        $catNourriture  = $cat('Nourriture');
        $catInternet    = $cat('Internet / Data');
        $catSenelec     = $cat('Sénélec');
        $catEau         = $cat('Eau');
        $catLoyer       = $cat('Loyer');
        $catPharmacie   = $cat('Pharmacie');
        $catCanal       = $cat('Canal+');
        $catWave        = $cat('Wave');
        $catFamille     = $cat('Transferts famille');
        $catLoisirs     = $cat('Loisirs');
        $catCarburant   = $cat('Carburant');
        $catCafe        = $cat('Café');

        // ── 5. Transactions ──
        $now = Carbon::now();
        $thisMonth = $now->copy()->startOfMonth();
        $lastMonth = $now->copy()->subMonth()->startOfMonth();

        $tx = function (
            int $day, string $month, string $type, float $amount,
            ?Category $category, string $desc, Wallet $wallet, string $source = 'manual'
        ) use ($user) {
            $date = Carbon::createFromFormat('Y-m-d', $month)->day(min($day, Carbon::createFromFormat('Y-m-d', $month)->daysInMonth));
            return Transaction::create([
                'user_id' => $user->id,
                'category_id' => $category?->id,
                'wallet_id' => $wallet->id,
                'type' => $type,
                'amount' => $amount,
                'description' => $desc,
                'transaction_date' => $date,
                'source' => $source,
                'status' => 'completed',
            ]);
        };

        // Mois précédent — référence pour comparer
        $lm = $lastMonth->format('Y-m-d');
        $tx(1,  $lm, 'income',  450_000, $catSalaire,    'Salaire mensuel',                $wave, 'sms_wave');
        $tx(3,  $lm, 'expense', 150_000, $catLoyer,      'Loyer appartement Mermoz',       $epargne);
        $tx(4,  $lm, 'expense',  35_000, $catSenelec,    'Facture Sénélec',                $wave, 'sms_wave');
        $tx(5,  $lm, 'expense',  18_000, $catEau,        'Facture SDE',                    $wave, 'sms_wave');
        $tx(6,  $lm, 'expense',  15_000, $catInternet,   'Abonnement Free 50 Go',          $om, 'sms_orange_money');
        $tx(8,  $lm, 'expense',  12_500, $catCanal,      'Canal+ Access',                  $wave, 'sms_wave');
        $tx(10, $lm, 'expense',   8_500, $catRestaurant, 'Resto Le Lagon',                 $wave);
        $tx(12, $lm, 'expense',   3_500, $catTaxi,       'Yango Plateau → Almadies',       $wave);
        $tx(15, $lm, 'expense',  25_000, $catFamille,    'Transfert famille Thiès',        $wave, 'sms_wave');
        $tx(18, $lm, 'expense',   6_200, $catNourriture, 'Marché Castor',                  $om);
        $tx(20, $lm, 'expense',  15_000, $catCarburant,  'Total Mermoz',                   $om);
        $tx(22, $lm, 'expense',   2_500, $catCafe,       'Café Touba matin',               $om);
        $tx(25, $lm, 'income',   75_000, $catBusiness,   'Mission freelance',              $wave, 'sms_wave');

        // Mois en cours — varié pour révéler des patterns
        $tm = $thisMonth->format('Y-m-d');
        $tx(1,  $tm, 'income',  450_000, $catSalaire,    'Salaire mensuel',                $wave, 'sms_wave');
        $tx(2,  $tm, 'expense', 150_000, $catLoyer,      'Loyer appartement Mermoz',       $epargne);
        $tx(3,  $tm, 'expense',  38_000, $catSenelec,    'Facture Sénélec (climatiseur)',  $wave, 'sms_wave');
        $tx(4,  $tm, 'expense',  15_000, $catInternet,   'Abonnement Free 50 Go',          $om, 'sms_orange_money');
        $tx(5,  $tm, 'expense',  12_500, $catCanal,      'Canal+ Access',                  $wave, 'sms_wave');
        $tx(6,  $tm, 'expense',   4_000, $catTaxi,       'Yango Plateau',                  $wave);
        $tx(7,  $tm, 'expense',  12_000, $catRestaurant, 'Resto La Calebasse',             $wave);
        $tx(8,  $tm, 'expense',   3_500, $catTaxi,       'Yango Almadies → centre',        $wave);
        $tx(9,  $tm, 'expense',  18_500, $catRestaurant, 'Dîner Chez Loutcha',             $wave);
        $tx(10, $tm, 'expense',   2_500, $catCafe,       'Café Touba',                     $om);
        $tx(11, $tm, 'expense',   8_000, $catNourriture, 'Auchan Sea Plaza',               $wave);
        $tx(12, $tm, 'expense',   6_000, $catTaxi,       'Bolt Yoff → Plateau',            $wave);
        $tx(13, $tm, 'expense',  22_000, $catRestaurant, 'Anniversaire au Brioche Dorée',  $wave);
        $tx(14, $tm, 'expense',   3_000, $catCafe,       'Café Touba',                     $om);
        $tx(15, $tm, 'expense',  35_000, $catFamille,    'Transfert famille Saint-Louis',  $wave, 'sms_wave');
        $tx(16, $tm, 'expense',  18_000, $catCarburant,  'Total Liberté 6',                $om);
        $tx(18, $tm, 'expense',   4_500, $catTaxi,       'Yango après cinéma',             $wave);
        $tx(19, $tm, 'expense',  10_500, $catLoisirs,    'Cinéma Sea Plaza + popcorn',     $wave);
        $tx(20, $tm, 'income',  120_000, $catBusiness,   'Mission freelance Dakar SA',     $wave, 'sms_wave');
        $tx(21, $tm, 'expense',   9_500, $catPharmacie,  'Pharmacie Mermoz',               $om);
        $tx(22, $tm, 'expense',   5_500, $catTaxi,       'Yango Sacré-Coeur',              $wave);
        $tx(23, $tm, 'expense',   7_200, $catNourriture, 'Marché Castor',                  $om);
        $tx(24, $tm, 'expense',  15_000, $catRestaurant, 'Resto Le Djoloff',               $wave);

        $this->command?->info('   ✓ ' . Transaction::where('user_id', $user->id)->count() . ' transactions sur 2 mois');

        // ── 6. Budgets (mois en cours) ──
        $monthStart = $thisMonth->format('Y-m-d');
        $monthEnd = $now->copy()->endOfMonth()->format('Y-m-d');

        $budgets = [
            // Dépassé : restaurant a déjà 67 500 FCFA et budget 50 000
            ['category' => $catRestaurant, 'amount' => 50_000],
            // En alerte (~80%) : transport
            ['category' => $catTaxi,       'amount' => 25_000],
            // Sain : nourriture
            ['category' => $catNourriture, 'amount' => 50_000],
            // Sain : loisirs
            ['category' => $catLoisirs,    'amount' => 30_000],
        ];

        foreach ($budgets as $b) {
            if (!$b['category']) continue;
            $budget = Budget::create([
                'user_id' => $user->id,
                'category_id' => $b['category']->id,
                'amount' => $b['amount'],
                'period' => 'monthly',
                'start_date' => $monthStart,
                'end_date' => $monthEnd,
                'spent' => 0,
                'is_active' => true,
            ]);
            $budget->updateSpent();
        }
        $this->command?->info('   ✓ 4 budgets (1 dépassé, 1 en alerte, 2 sains)');

        // ── 7. Objectifs financiers ──
        FinancialGoal::create([
            'user_id' => $user->id,
            'name' => 'Voyage Maroc décembre',
            'description' => 'Vol + hôtel 7 jours à Marrakech',
            'target_amount' => 800_000,
            'current_amount' => 620_000, // 77.5% — presque atteint
            'target_date' => $now->copy()->addMonths(2),
            'icon' => 'flight',
            'color' => '#3B82F6',
            'status' => 'in_progress',
            'reminder_frequency' => 'weekly',
        ]);

        FinancialGoal::create([
            'user_id' => $user->id,
            'name' => 'Achat MacBook Pro',
            'description' => 'Pour le freelance dev',
            'target_amount' => 1_500_000,
            'current_amount' => 380_000, // 25% — début
            'target_date' => $now->copy()->addMonths(8),
            'icon' => 'laptop',
            'color' => '#8B5CF6',
            'status' => 'in_progress',
        ]);

        FinancialGoal::create([
            'user_id' => $user->id,
            'name' => 'Fonds d\'urgence',
            'description' => '3 mois de dépenses',
            'target_amount' => 1_200_000,
            'current_amount' => 450_000, // 37.5% — en retard
            'target_date' => $now->copy()->subDays(15), // déjà dépassée
            'icon' => 'shield',
            'color' => '#10B981',
            'status' => 'in_progress',
        ]);
        $this->command?->info('   ✓ 3 objectifs (1 presque atteint, 1 en cours, 1 en retard)');

        // ── 8. Rappels de paiement ──
        PaymentReminder::create([
            'user_id' => $user->id,
            'name' => 'Facture Sénélec',
            'description' => 'Bimensuelle',
            'amount' => 38000,
            'due_date' => $now->copy()->addDays(5),
            'frequency' => 'monthly',
            'next_reminder_date' => $now->copy()->addDays(3),
            'status' => 'pending',
        ]);

        PaymentReminder::create([
            'user_id' => $user->id,
            'name' => 'Canal+ Access',
            'description' => 'Renouvellement automatique',
            'amount' => 12500,
            'due_date' => $now->copy()->addDays(12),
            'frequency' => 'monthly',
            'next_reminder_date' => $now->copy()->addDays(10),
            'status' => 'pending',
        ]);
        $this->command?->info('   ✓ 2 rappels de paiement');

        // ── 9. Corrections de catégorisation (mémoire IA) ──
        if ($catTaxi && $catRestaurant && $catNourriture) {
            AiCategoryCorrection::create([
                'user_id' => $user->id,
                'description' => 'Yango Plateau Almadies',
                'category_id' => $catTaxi->id,
            ]);
            AiCategoryCorrection::create([
                'user_id' => $user->id,
                'description' => 'Bolt course nuit',
                'category_id' => $catTaxi->id,
            ]);
            AiCategoryCorrection::create([
                'user_id' => $user->id,
                'description' => 'Auchan Sea Plaza',
                'category_id' => $catNourriture->id,
            ]);
        }
        $this->command?->info('   ✓ 3 corrections IA (apprentissage Yango/Bolt/Auchan)');

        $this->command?->newLine();
        $this->command?->info('✅ Dataset prêt !');
        $this->command?->line('');
        $this->command?->line('  📧 Email    : aminata@financewise.com');
        $this->command?->line('  🔐 Password : password123');
        $this->command?->line('');
        $this->command?->line('Connecte-toi dans l\'app et teste l\'assistant IA :');
        $this->command?->line('  • « Combien j\'ai dépensé en restaurants ce mois ? »');
        $this->command?->line('  • « Compare mon mois actuel au mois précédent »');
        $this->command?->line('  • « Quel est l\'état de mes budgets ? »');
        $this->command?->line('  • « Mes objectifs financiers sont-ils atteignables ? »');
        $this->command?->line('  • « Donne-moi 3 conseils pour économiser ce mois »');
    }
}
