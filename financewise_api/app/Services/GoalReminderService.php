<?php

namespace App\Services;

use App\Models\FinancialGoal;
use App\Models\GoalReminder;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Support\Facades\Log;

class GoalReminderService
{
    public function scheduleDeadlineReminders(FinancialGoal $goal)
    {
        if (!$goal->target_date) {
            return;
        }

        $targetDate = Carbon::parse($goal->target_date);

        // Supprimer les anciens rappels de deadline pour cet objectif
        GoalReminder::where('financial_goal_id', $goal->id)
            ->whereIn('type', ['deadline_7days', 'deadline_3days', 'deadline_today', 'overdue'])
            ->delete();

        // Créer les rappels de deadline
        $reminders = [
            [
                'type' => 'deadline_7days',
                'scheduled_at' => $targetDate->copy()->subDays(7),
                'message' => "Votre objectif \"{$goal->name}\" arrive à échéance dans 7 jours. Progression: {$goal->progress}%.",
            ],
            [
                'type' => 'deadline_3days',
                'scheduled_at' => $targetDate->copy()->subDays(3),
                'message' => "Votre objectif \"{$goal->name}\" arrive à échéance dans 3 jours. Progression: {$goal->progress}%.",
            ],
            [
                'type' => 'deadline_today',
                'scheduled_at' => $targetDate->copy()->startOfDay(),
                'message' => "C'est le jour J pour votre objectif \"{$goal->name}\" ! Progression: {$goal->progress}%.",
            ],
        ];

        foreach ($reminders as $reminder) {
            if ($reminder['scheduled_at']->isFuture()) {
                GoalReminder::create([
                    'financial_goal_id' => $goal->id,
                    'user_id' => $goal->user_id,
                    'type' => $reminder['type'],
                    'scheduled_at' => $reminder['scheduled_at'],
                    'message' => $reminder['message'],
                    'status' => 'pending',
                ]);
            }
        }

        // Si déjà en retard, créer un rappel immédiat
        if ($goal->is_overdue) {
            GoalReminder::create([
                'financial_goal_id' => $goal->id,
                'user_id' => $goal->user_id,
                'type' => 'overdue',
                'scheduled_at' => now(),
                'message' => "Votre objectif \"{$goal->name}\" est en retard de {$goal->days_remaining} jours. Progression: {$goal->progress}%.",
                'status' => 'pending',
            ]);
        }
    }

    public function scheduleRegularReminders(FinancialGoal $goal)
    {
        if (!$goal->reminder_frequency) {
            return;
        }

        // Supprimer les anciens rappels réguliers
        GoalReminder::where('financial_goal_id', $goal->id)
            ->whereIn('type', ['weekly', 'biweekly', 'monthly'])
            ->where('status', 'pending')
            ->delete();

        $frequency = $goal->reminder_frequency;
        $nextReminder = now();

        switch ($frequency) {
            case 'weekly':
                $nextReminder = now()->addWeek();
                $type = 'weekly';
                break;
            case 'biweekly':
                $nextReminder = now()->addWeeks(2);
                $type = 'biweekly';
                break;
            case 'monthly':
                $nextReminder = now()->addMonth();
                $type = 'monthly';
                break;
            default:
                return;
        }

        GoalReminder::create([
            'financial_goal_id' => $goal->id,
            'user_id' => $goal->user_id,
            'type' => $type,
            'scheduled_at' => $nextReminder,
            'message' => "N'oubliez pas d'ajouter à votre objectif \"{$goal->name}\" ! Il vous reste {$goal->remaining_amount} FCFA à atteindre.",
            'status' => 'pending',
        ]);

        // Mettre à jour la date du dernier rappel
        $goal->update(['last_reminder_sent_at' => now()]);
    }

    public function scheduleGeneralReviewReminder(User $user, string $frequency = 'monthly')
    {
        // Supprimer les anciens rappels de review
        GoalReminder::where('user_id', $user->id)
            ->where('type', 'general_review')
            ->where('status', 'pending')
            ->delete();

        $nextReminder = now();

        switch ($frequency) {
            case 'biweekly':
                $nextReminder = now()->addWeeks(2);
                break;
            case 'monthly':
            default:
                $nextReminder = now()->addMonth();
                break;
        }

        // Récupérer les statistiques pour le message
        $activeGoals = FinancialGoal::where('user_id', $user->id)
            ->where('status', '!=', 'completed')
            ->get();
        
        $totalProgress = 0;
        if ($activeGoals->isNotEmpty()) {
            $totalTarget = $activeGoals->sum('target_amount');
            $totalCurrent = $activeGoals->sum('current_amount');
            $totalProgress = $totalTarget > 0 ? round(($totalCurrent / $totalTarget) * 100) : 0;
        }

        GoalReminder::create([
            'financial_goal_id' => null,
            'user_id' => $user->id,
            'type' => 'general_review',
            'scheduled_at' => $nextReminder,
            'message' => "C'est le moment de faire le point sur vos objectifs financiers ! Progression globale: {$totalProgress}%. Vérifiez vos objectifs et ajustez vos stratégies d'épargne.",
            'status' => 'pending',
        ]);
    }

    public function processDueReminders()
    {
        $dueReminders = GoalReminder::due()->with('financialGoal')->get();

        foreach ($dueReminders as $reminder) {
            try {
                // Envoyer la notification (à implémenter avec le système de notification)
                $this->sendReminderNotification($reminder);

                $reminder->update([
                    'status' => 'sent',
                    'sent_at' => now(),
                ]);

                // Si c'est un rappel régulier, programmer le prochain
                if ($reminder->financial_goal && in_array($reminder->type, ['weekly', 'biweekly', 'monthly'])) {
                    $this->scheduleNextRegularReminder($reminder->financial_goal, $reminder->type);
                }

                // Si c'est un rappel de review général, programmer le prochain
                if ($reminder->type === 'general_review') {
                    $frequency = $reminder->scheduled_at->diffInDays(now()) > 20 ? 'monthly' : 'biweekly';
                    $this->scheduleGeneralReviewReminder($reminder->user, $frequency);
                }

                Log::info('Reminder sent successfully', [
                    'reminder_id' => $reminder->id,
                    'type' => $reminder->type,
                ]);
            } catch (\Exception $e) {
                $reminder->update(['status' => 'failed']);
                Log::error('Failed to send reminder', [
                    'reminder_id' => $reminder->id,
                    'error' => $e->getMessage(),
                ]);
            }
        }
    }

    private function scheduleNextRegularReminder(FinancialGoal $goal, string $type)
    {
        $nextReminder = now();

        switch ($type) {
            case 'weekly':
                $nextReminder = now()->addWeek();
                break;
            case 'biweekly':
                $nextReminder = now()->addWeeks(2);
                break;
            case 'monthly':
                $nextReminder = now()->addMonth();
                break;
        }

        GoalReminder::create([
            'financial_goal_id' => $goal->id,
            'user_id' => $goal->user_id,
            'type' => $type,
            'scheduled_at' => $nextReminder,
            'message' => "N'oubliez pas d'ajouter à votre objectif \"{$goal->name}\" ! Il vous reste {$goal->remaining_amount} FCFA à atteindre.",
            'status' => 'pending',
        ]);

        $goal->update(['last_reminder_sent_at' => now()]);
    }

    private function sendReminderNotification(GoalReminder $reminder)
    {
        // Implémenter l'envoi réel de la notification
        // Pour l'instant, on log le message
        Log::info('Goal reminder notification', [
            'user_id' => $reminder->user_id,
            'type' => $reminder->type,
            'message' => $reminder->message,
        ]);

        // TODO: Intégrer avec le système de notification push/email
        // $reminder->user->notify(new GoalReminderNotification($reminder));
    }
}
