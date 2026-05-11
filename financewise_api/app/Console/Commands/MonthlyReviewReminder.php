<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Models\Alert;
use Carbon\Carbon;
use Illuminate\Console\Command;

class MonthlyReviewReminder extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'app:monthly-review-reminder';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Envoie des rappels de fin de mois pour la revue mensuelle';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $now = Carbon::now();
        $endOfMonth = $now->copy()->endOfMonth();
        $daysUntilEnd = $now->diffInDays($endOfMonth);

        // Envoyer le rappel 2-3 jours avant la fin du mois
        if ($daysUntilEnd <= 3 && $daysUntilEnd >= 1) {
            $users = User::all();

            foreach ($users as $user) {
                // Vérifier si une alerte existe déjà pour ce mois
                $existingAlert = Alert::where('user_id', $user->id)
                    ->where('type', 'monthly_review')
                    ->where('created_at', '>=', $now->startOfMonth())
                    ->first();

                if (!$existingAlert) {
                    Alert::create([
                        'user_id' => $user->id,
                        'type' => 'monthly_review',
                        'title' => 'Revue mensuelle',
                        'message' => "Le mois se termine dans $daysUntilEnd jour(s). Il est temps de faire votre revue mensuelle et de préparer le mois suivant.",
                        'severity' => 'info',
                        'data' => json_encode([
                            'days_until_end' => $daysUntilEnd,
                            'month' => $now->format('F'),
                            'year' => $now->year,
                        ]),
                    ]);

                    $this->info("Rappel envoyé à l'utilisateur {$user->id}");
                }
            }

            $this->info("Rappels de fin de mois envoyés avec succès.");
        } else {
            $this->info("Pas encore le moment d'envoyer les rappels ({$daysUntilEnd} jours restants).");
        }

        return 0;
    }
}
