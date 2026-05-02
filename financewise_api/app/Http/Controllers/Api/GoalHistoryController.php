<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\GoalHistory;
use App\Models\FinancialGoal;
use Illuminate\Http\Request;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;

class GoalHistoryController extends Controller
{
    use AuthorizesRequests;

    public function index(Request $request, $financialGoalId)
    {
        $goal = FinancialGoal::findOrFail($financialGoalId);
        $this->authorize('view', $goal);

        $histories = GoalHistory::where('financial_goal_id', $financialGoalId)
            ->where('user_id', auth()->id())
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json(['data' => $histories]);
    }

    public function revert(Request $request, $id)
    {
        $history = GoalHistory::findOrFail($id);
        $goal = FinancialGoal::findOrFail($history->financial_goal_id);
        $this->authorize('update', $goal);

        if ($history->is_reverted) {
            return response()->json(['error' => 'Cet ajout a déjà été annulé'], 400);
        }

        // Annuler l'ajout
        $newAmount = $goal->current_amount - $history->amount;
        
        if ($newAmount < 0) {
            return response()->json(['error' => 'Impossible d\'annuler : le montant deviendrait négatif'], 400);
        }

        $goal->update(['current_amount' => $newAmount]);
        $history->update([
            'is_reverted' => true,
            'reverted_at' => now(),
        ]);

        return response()->json(['data' => $history, 'message' => 'Ajout annulé avec succès']);
    }
}
