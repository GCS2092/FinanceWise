<?php

namespace App\Console\Commands;

use App\Services\GoalReminderService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class ProcessGoalReminders extends Command
{
    protected $signature = 'goals:process-reminders';
    protected $description = 'Traite les rappels d\'objectifs dus et envoie les notifications';

    public function __construct(private GoalReminderService $reminderService)
    {
        parent::__construct();
    }

    public function handle()
    {
        $this->info('Traitement des rappels d\'objectifs...');

        try {
            $this->reminderService->processDueReminders();
            $this->info('Rappels traités avec succès.');
        } catch (\Exception $e) {
            Log::error('Erreur lors du traitement des rappels', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);
            $this->error('Erreur lors du traitement des rappels: ' . $e->getMessage());
            return 1;
        }

        return 0;
    }
}
