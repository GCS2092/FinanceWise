<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreBudgetRequest;
use App\Http\Requests\UpdateBudgetRequest;
use App\Http\Resources\BudgetResource;
use App\Models\Budget;
use App\Services\BudgetService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BudgetController extends Controller
{
    public function __construct(protected BudgetService $service)
    {
    }

    public function index(Request $request)
    {
        $query = auth()->user()->budgets()->with('category')->latest();

        if ($request->has('is_active')) {
            $query->where('is_active', $request->boolean('is_active'));
        }

        return BudgetResource::collection($query->paginate(20));
    }

    public function store(StoreBudgetRequest $request): JsonResponse
    {
        $data = $request->validated();
        $data['user_id'] = auth()->id();
        $data['spent'] = 0;

        $budget = Budget::create($data);

        return response()->json([
            'message' => 'Budget créé',
            'data' => new BudgetResource($budget->load('category')),
        ], 201);
    }

    public function show(Budget $budget)
    {
        abort_if($budget->user_id !== auth()->id(), 403, 'Non autorisé');
        $this->service->recalculateSpent($budget);

        return new BudgetResource($budget->load('category'));
    }

    public function update(UpdateBudgetRequest $request, Budget $budget)
    {
        abort_if($budget->user_id !== auth()->id(), 403, 'Non autorisé');
        $budget->update($request->validated());
        $this->service->recalculateSpent($budget);

        return new BudgetResource($budget->load('category'));
    }

    public function destroy(Budget $budget): JsonResponse
    {
        abort_if($budget->user_id !== auth()->id(), 403, 'Non autorisé');
        $budget->delete();

        return response()->json(['message' => 'Budget supprimé']);
    }
}
