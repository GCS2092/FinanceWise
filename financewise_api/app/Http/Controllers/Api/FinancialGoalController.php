<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\FinancialGoal;
use Illuminate\Http\Request;

class FinancialGoalController extends Controller
{
    public function index()
    {
        $goals = FinancialGoal::forUser()->with('user')->get();
        return response()->json(['data' => $goals]);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'target_amount' => 'required|numeric|min:0',
            'current_amount' => 'nullable|numeric|min:0',
            'target_date' => 'nullable|date',
            'icon' => 'nullable|string',
            'color' => 'nullable|string',
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
            'status' => 'pending',
        ]);

        return response()->json(['data' => $goal], 201);
    }

    public function show(FinancialGoal $financialGoal)
    {
        $this->authorize('view', $financialGoal);
        return response()->json(['data' => $financialGoal]);
    }

    public function update(Request $request, FinancialGoal $financialGoal)
    {
        $this->authorize('update', $financialGoal);

        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'target_amount' => 'sometimes|numeric|min:0',
            'current_amount' => 'sometimes|numeric|min:0',
            'target_date' => 'nullable|date',
            'icon' => 'nullable|string',
            'color' => 'nullable|string',
            'status' => 'sometimes|in:pending,in_progress,completed',
        ]);

        $financialGoal->update($validated);

        // Update status based on progress
        if ($financialGoal->current_amount >= $financialGoal->target_amount) {
            $financialGoal->update(['status' => 'completed']);
        } elseif ($financialGoal->current_amount > 0) {
            $financialGoal->update(['status' => 'in_progress']);
        }

        return response()->json(['data' => $financialGoal]);
    }

    public function destroy(FinancialGoal $financialGoal)
    {
        $this->authorize('delete', $financialGoal);
        $financialGoal->delete();
        return response()->json(null, 204);
    }

    public function addAmount(Request $request, FinancialGoal $financialGoal)
    {
        $this->authorize('update', $financialGoal);

        $validated = $request->validate([
            'amount' => 'required|numeric|min:0',
        ]);

        $financialGoal->increment('current_amount', $validated['amount']);

        // Update status
        if ($financialGoal->current_amount >= $financialGoal->target_amount) {
            $financialGoal->update(['status' => 'completed']);
        } elseif ($financialGoal->current_amount > 0) {
            $financialGoal->update(['status' => 'in_progress']);
        }

        return response()->json(['data' => $financialGoal]);
    }
}
