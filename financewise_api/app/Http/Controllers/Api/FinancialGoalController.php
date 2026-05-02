<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FinancialGoal;
use App\Models\GoalHistory;
use App\Models\GoalReminder;
use App\Services\GoalReminderService;
use Illuminate\Http\Request;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Validation\Rule;

class FinancialGoalController extends Controller
{
    use AuthorizesRequests;

    protected $reminderService;

    public function __construct(GoalReminderService $reminderService)
    {
        $this->reminderService = $reminderService;
    }
    public function index()
    {
        $goals = FinancialGoal::forUser()->with(['user', 'category'])->get();
        return response()->json(['data' => $goals]);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255', Rule::unique('financial_goals')->where('user_id', auth()->id())],
            'description' => 'nullable|string',
            'target_amount' => 'required|numeric|min:0',
            'current_amount' => 'nullable|numeric|min:0',
            'target_date' => 'nullable|date',
            'icon' => 'nullable|string',
            'color' => 'nullable|string',
            'category_id' => 'nullable|exists:categories,id',
            'reminder_frequency' => 'nullable|in:weekly,biweekly,monthly',
        ]);

        $goal = FinancialGoal::create([
            'user_id' => auth()->id(),
            'name' => $validated['name'],
            'description' => $validated['description'] ?? null,
            'target_amount' => $validated['target_amount'],
            'current_amount' => $validated['current_amount'] ?? 0,
            'target_date' => $validated['target_date'] ?? null,
            'icon' => $validated['icon'] ?? 'savings',
            'color' => $validated['color'] ?? '#4CAF50',
            'category_id' => $validated['category_id'] ?? null,
            'reminder_frequency' => $validated['reminder_frequency'] ?? null,
            'status' => 'pending',
        ]);

        // Programmer les rappels de deadline
        if ($goal->target_date) {
            $this->reminderService->scheduleDeadlineReminders($goal);
        }

        // Programmer les rappels réguliers si demandé
        if ($goal->reminder_frequency) {
            $this->reminderService->scheduleRegularReminders($goal);
        }

        return response()->json(['data' => $goal], 201);
    }

    public function show(FinancialGoal $financialGoal)
    {
        $this->authorize('view', $financialGoal);
        $financialGoal->load(['category', 'histories' => function ($query) {
            $query->orderBy('created_at', 'desc')->limit(50);
        }]);
        return response()->json(['data' => $financialGoal]);
    }

    public function update(Request $request, FinancialGoal $financialGoal)
    {
        $this->authorize('update', $financialGoal);

        \Log::info('Update financial goal', [
            'id' => $financialGoal->id,
            'request' => $request->all(),
        ]);

        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'target_amount' => 'sometimes|numeric|min:0',
            'current_amount' => 'sometimes|numeric|min:0',
            'target_date' => 'nullable|date',
            'icon' => 'nullable|string',
            'color' => 'nullable|string',
            'status' => 'sometimes|in:pending,in_progress,completed',
            'category_id' => 'nullable|exists:categories,id',
            'reminder_frequency' => 'nullable|in:weekly,biweekly,monthly',
        ]);

        // Enregistrer l'historique si current_amount change
        if (isset($validated['current_amount']) && $validated['current_amount'] != $financialGoal->current_amount) {
            $oldAmount = $financialGoal->current_amount;
            $newAmount = $validated['current_amount'];
            $difference = $newAmount - $oldAmount;

            if ($difference != 0) {
                \App\Models\GoalHistory::create([
                    'financial_goal_id' => $financialGoal->id,
                    'user_id' => $financialGoal->user_id,
                    'amount' => abs($difference),
                    'balance_before' => $oldAmount,
                    'balance_after' => $newAmount,
                    'type' => $difference > 0 ? 'addition' : 'withdrawal',
                    'notes' => 'Modification directe',
                ]);
            }
        }

        $financialGoal->update($validated);

        // Reprogrammer les rappels si la date ou la fréquence a changé
        if (isset($validated['target_date'])) {
            $this->reminderService->scheduleDeadlineReminders($financialGoal);
        }
        if (isset($validated['reminder_frequency'])) {
            $this->reminderService->scheduleRegularReminders($financialGoal);
        }

        // Update status based on progress
        if ($financialGoal->current_amount >= $financialGoal->target_amount) {
            $financialGoal->update(['status' => 'completed']);
        } elseif ($financialGoal->current_amount > 0) {
            $financialGoal->update(['status' => 'in_progress']);
        }

        \Log::info('Financial goal updated', [
            'id' => $financialGoal->id,
            'current_amount' => $financialGoal->current_amount,
            'status' => $financialGoal->status,
        ]);

        return response()->json(['data' => $financialGoal]);
    }

    public function destroy(FinancialGoal $financialGoal)
    {
        $this->authorize('delete', $financialGoal);

        \Log::info('Delete financial goal', [
            'id' => $financialGoal->id,
            'name' => $financialGoal->name,
        ]);

        $financialGoal->delete();
        return response()->json(null, 204);
    }

    public function addAmount(Request $request, FinancialGoal $financialGoal)
    {
        $this->authorize('update', $financialGoal);

        $validated = $request->validate([
            'amount' => 'required|numeric|min:0',
        ]);

        $amount = $validated['amount'];

        // Vérifier que le montant n'est pas négatif après l'ajout
        if ($financialGoal->current_amount + $amount < 0) {
            return response()->json(['error' => 'Le montant ne peut pas être négatif'], 400);
        }

        $balanceBefore = $financialGoal->current_amount;
        $financialGoal->increment('current_amount', $amount);
        $financialGoal = $financialGoal->fresh();

        // Enregistrer dans l'historique
        GoalHistory::create([
            'financial_goal_id' => $financialGoal->id,
            'user_id' => auth()->id(),
            'amount' => $amount,
            'balance_before' => $balanceBefore,
            'balance_after' => $financialGoal->current_amount,
            'type' => $amount >= 0 ? 'add' : 'remove',
        ]);

        // Mettre à jour le statut automatiquement
        $newAmount = $financialGoal->fresh()->current_amount;
        $targetAmount = $financialGoal->target_amount;

        if ($newAmount >= $targetAmount) {
            $financialGoal->update(['status' => 'completed']);
        } elseif ($newAmount > 0) {
            $financialGoal->update(['status' => 'in_progress']);
        } else {
            $financialGoal->update(['status' => 'pending']);
        }

        \Log::info('Amount added successfully', [
            'id' => $financialGoal->id,
            'amount_added' => $amount,
            'current_amount_after' => $financialGoal->current_amount,
            'status' => $financialGoal->status,
        ]);

        return response()->json([
            'data' => $financialGoal,
            'message' => 'Montant ajouté avec succès',
            'progress' => $targetAmount > 0 ? round(($financialGoal->current_amount / $targetAmount) * 100, 2) : 0,
            'remaining' => max(0, $targetAmount - $financialGoal->current_amount),
        ]);
    }

    public function history(FinancialGoal $financialGoal)
    {
        $this->authorize('view', $financialGoal);

        $histories = $financialGoal->histories()
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json(['data' => $histories]);
    }

    public function revertHistory(GoalHistory $goalHistory)
    {
        $this->authorize('update', $goalHistory->financialGoal);

        if ($goalHistory->is_reverted) {
            return response()->json(['error' => 'Cet ajout a déjà été annulé'], 400);
        }

        $goal = $goalHistory->financialGoal;
        $amountToRevert = $goalHistory->amount;

        // Annuler le montant
        $goal->decrement('current_amount', $amountToRevert);

        // Marquer comme réverti
        $goalHistory->update([
            'is_reverted' => true,
            'reverted_at' => now(),
        ]);

        // Créer une entrée d'historique pour l'annulation
        GoalHistory::create([
            'financial_goal_id' => $goal->id,
            'user_id' => auth()->id(),
            'amount' => -$amountToRevert,
            'balance_before' => $goal->current_amount + $amountToRevert,
            'balance_after' => $goal->fresh()->current_amount,
            'type' => 'adjustment',
            'notes' => "Annulation de l'ajout du {$goalHistory->created_at}",
        ]);

        // Mettre à jour le statut
        $goal = $goal->fresh();
        if ($goal->current_amount >= $goal->target_amount) {
            $goal->update(['status' => 'completed']);
        } elseif ($goal->current_amount > 0) {
            $goal->update(['status' => 'in_progress']);
        } else {
            $goal->update(['status' => 'pending']);
        }

        return response()->json([
            'data' => $goal,
            'message' => 'Ajout annulé avec succès',
        ]);
    }

    public function categories()
    {
        $categories = \App\Models\Category::where('type', 'financial_goal')
            ->where(function ($query) {
                $query->where('is_system', true)
                    ->orWhere('user_id', auth()->id());
            })
            ->get();

        return response()->json(['data' => $categories]);
    }

    public function scheduleGeneralReview(Request $request)
    {
        $validated = $request->validate([
            'frequency' => 'required|in:biweekly,monthly',
        ]);

        $this->reminderService->scheduleGeneralReviewReminder(auth()->user(), $validated['frequency']);

        return response()->json([
            'message' => 'Rappel de mise au point programmé',
            'frequency' => $validated['frequency'],
        ]);
    }

    public function suggestions()
    {
        $suggestions = [
            [
                'name' => 'Achat voiture',
                'target_amount' => 5000000,
                'icon' => 'car',
            ],
            [
                'name' => 'Achat maison',
                'target_amount' => 20000000,
                'icon' => 'home',
            ],
            [
                'name' => 'Voyage',
                'target_amount' => 1500000,
                'icon' => 'vacation',
            ],
            [
                'name' => 'Fonds d\'urgence',
                'target_amount' => 1000000,
                'icon' => 'savings',
            ],
            [
                'name' => 'Études',
                'target_amount' => 3000000,
                'icon' => 'education',
            ],
            [
                'name' => 'Téléphone',
                'target_amount' => 500000,
                'icon' => 'phone',
            ],
        ];

        return response()->json(['data' => $suggestions]);
    }

    public function monthlySavingsRecommendation(FinancialGoal $financialGoal)
    {
        $this->authorize('view', $financialGoal);

        if (!$financialGoal->target_date) {
            return response()->json([
                'monthly_saving' => null,
                'message' => 'Veuillez définir une date limite pour calculer l\'épargne mensuelle recommandée',
            ]);
        }

        $remaining = $financialGoal->target_amount - $financialGoal->current_amount;
        
        if ($remaining <= 0) {
            return response()->json([
                'monthly_saving' => 0,
                'message' => 'Objectif déjà atteint !',
                'remaining' => 0,
            ]);
        }

        $targetDate = \Carbon\Carbon::parse($financialGoal->target_date);
        $now = \Carbon\Carbon::now();
        
        if ($targetDate->isPast()) {
            return response()->json([
                'monthly_saving' => null,
                'message' => 'La date limite est déjà passée',
                'remaining' => $remaining,
                'days_overdue' => $now->diffInDays($targetDate),
            ]);
        }

        $monthsRemaining = $now->diffInMonths($targetDate);
        
        if ($monthsRemaining == 0) {
            $monthsRemaining = 1; // Au moins 1 mois
        }

        $monthlySaving = ceil($remaining / $monthsRemaining);

        return response()->json([
            'monthly_saving' => $monthlySaving,
            'remaining' => $remaining,
            'months_remaining' => $monthsRemaining,
            'target_date' => $financialGoal->target_date,
            'current_amount' => $financialGoal->current_amount,
            'target_amount' => $financialGoal->target_amount,
        ]);
    }
}
