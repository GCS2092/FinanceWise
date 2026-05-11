<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Scheduler pour vérifier les rappels de paiement quotidiennement
Schedule::command('app:check-payment-reminders')->daily();

// Scheduler pour les rappels de revue mensuelle
Schedule::command('app:monthly-review-reminder')->daily();

// IA : génération du brief mensuel le 1er du mois à 19h (heure locale serveur)
Schedule::command('ai:monthly-insights')->monthlyOn(1, '19:00');
