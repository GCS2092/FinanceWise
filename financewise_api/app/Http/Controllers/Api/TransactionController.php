<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreTransactionRequest;
use App\Http\Requests\UpdateTransactionRequest;
use App\Http\Resources\TransactionResource;
use App\Models\Transaction;
use App\Services\TransactionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TransactionController extends Controller
{
    public function __construct(protected TransactionService $service)
    {
    }

    public function index(Request $request)
    {
        $query = auth()->user()->transactions()
            ->with('category', 'wallet')
            ->latest('transaction_date');

        if ($request->has('type')) {
            $query->where('type', $request->type);
        }

        if ($request->has('category')) {
            $query->whereHas('category', function ($q) use ($request) {
                $q->where('name', 'like', '%' . $request->category . '%');
            });
        }

        if ($request->has('category_id')) {
            $query->where('category_id', $request->category_id);
        }

        if ($request->has('start_date') && $request->has('end_date')) {
            $query->whereBetween('transaction_date', [$request->start_date, $request->end_date]);
        }

        if ($request->has('min_amount')) {
            $query->where('amount', '>=', $request->min_amount);
        }

        if ($request->has('max_amount')) {
            $query->where('amount', '<=', $request->max_amount);
        }

        return TransactionResource::collection($query->paginate(20));
    }

    public function store(StoreTransactionRequest $request): JsonResponse
    {
        $transaction = $this->service->create($request->validated(), auth()->id());

        return response()->json([
            'message' => 'Transaction créée',
            'data' => new TransactionResource($transaction),
        ], 201);
    }

    public function show(Transaction $transaction)
    {
        abort_if($transaction->user_id !== auth()->id(), 403, 'Non autorisé');
        return new TransactionResource($transaction->load('category', 'wallet'));
    }

    public function update(UpdateTransactionRequest $request, Transaction $transaction)
    {
        abort_if($transaction->user_id !== auth()->id(), 403, 'Non autorisé');
        $transaction = $this->service->update($transaction, $request->validated());
        return new TransactionResource($transaction->load('category', 'wallet'));
    }

    public function destroy(Transaction $transaction): JsonResponse
    {
        abort_if($transaction->user_id !== auth()->id(), 403, 'Non autorisé');
        $this->service->delete($transaction);
        return response()->json(['message' => 'Transaction supprimée']);
    }
}
