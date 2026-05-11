<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\Ai\AiInsightsService;
use Illuminate\Console\Command;

/**
 * Génère le brief mensuel de chaque utilisateur pour le mois précédent.
 * À exécuter en cron le 1er du mois (par exemple à 19h).
 */
class GenerateMonthlyInsights extends Command
{
    protected $signature = 'ai:monthly-insights {--period= : Période YYYY-MM (défaut : mois précédent)} {--user= : Limiter à un user_id}';
    protected $description = 'Génère le brief financier mensuel IA pour les utilisateurs';

    public function handle(AiInsightsService $service): int
    {
        $period = $this->option('period') ?: now()->subMonth()->format('Y-m');
        if (!preg_match('/^\d{4}-\d{2}$/', $period)) {
            $this->error('Période invalide, format attendu YYYY-MM');
            return self::FAILURE;
        }

        $query = User::query();
        if ($userId = $this->option('user')) {
            $query->whereKey($userId);
        }

        $count = 0;
        $errors = 0;
        $query->chunkById(50, function ($users) use ($service, $period, &$count, &$errors) {
            foreach ($users as $user) {
                try {
                    $service->generateMonthlyBrief($user, $period);
                    $count++;
                } catch (\Throwable $e) {
                    $errors++;
                    $this->warn("User {$user->id}: {$e->getMessage()}");
                }
            }
        });

        $this->info("Briefs générés : {$count} (erreurs : {$errors}) pour la période {$period}");
        return self::SUCCESS;
    }
}
