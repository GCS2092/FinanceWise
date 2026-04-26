<?php

namespace App\Console\Commands;

use App\Models\PaymentReminder;
use App\Models\Alert;
use Carbon\Carbon;
use Illuminate\Console\Command;

class CheckPaymentReminders extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'app:check-payment-reminders';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Vérifie les rappels de paiement et envoie des alertes automatiques';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $today = Carbon::today();
        $threeDaysLater = Carbon::today()->addDays(3);

        // Rappels dans 3 jours
        $upcomingReminders = PaymentReminder::where('status', 'pending')
            ->where('due_date', $threeDaysLater)
            ->get();

        foreach ($upcomingReminders as $reminder) {
            Alert::create([
                'user_id' => $reminder->user_id,
                'type' => 'payment_reminder',
                'title' => 'Rappel de paiement dans 3 jours',
                'message' => "Rappel '{$reminder->name}' de {$reminder->amount} XOF est dû dans 3 jours ({$reminder->due_date->format('d/m/Y')})",
                'data' => ['reminder_id' => $reminder->id],
                'is_read' => false,
            ]);
        }

        // Rappels dus aujourd'hui
        $dueTodayReminders = PaymentReminder::where('status', 'pending')
            ->where('due_date', $today)
            ->get();

        foreach ($dueTodayReminders as $reminder) {
            Alert::create([
                'user_id' => $reminder->user_id,
                'type' => 'payment_reminder',
                'title' => 'Paiement dû aujourd\'hui',
                'message' => "Rappel '{$reminder->name}' de {$reminder->amount} XOF est dû aujourd'hui !",
                'data' => ['reminder_id' => $reminder->id],
                'is_read' => false,
            ]);
        }

        // Rappels en retard
        $overdueReminders = PaymentReminder::where('status', 'pending')
            ->where('due_date', '<', $today)
            ->get();

        foreach ($overdueReminders as $reminder) {
            Alert::create([
                'user_id' => $reminder->user_id,
                'type' => 'payment_reminder',
                'title' => 'Paiement en retard',
                'message' => "Rappel '{$reminder->name}' de {$reminder->amount} XOF est en retard depuis {$reminder->due_date->diffForHumans()} !",
                'data' => ['reminder_id' => $reminder->id],
                'is_read' => false,
            ]);
        }

        $this->info('Vérification des rappels de paiement terminée.');
        $this->info("- {$upcomingReminders->count()} rappels dans 3 jours");
        $this->info("- {$dueTodayReminders->count()} rappels dus aujourd'hui");
        $this->info("- {$overdueReminders->count()} rappels en retard");
    }
}
