<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\WalletResource;
use App\Models\Wallet;
use Illuminate\Http\Request;

class WalletController extends Controller
{
    public function index()
    {
        return WalletResource::collection(auth()->user()->wallets);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'type' => ['required', 'in:cash,mobile_money,bank'],
            'currency' => ['nullable', 'string', 'size:3'],
            'balance' => ['nullable', 'numeric', 'min:0'],
        ]);

        $validated['user_id'] = auth()->id();
        $wallet = Wallet::create($validated);

        return new WalletResource($wallet);
    }

    public function show(Wallet $wallet)
    {
        abort_if($wallet->user_id !== auth()->id(), 403, 'Non autorisé');
        return new WalletResource($wallet);
    }

    public function update(Request $request, Wallet $wallet)
    {
        abort_if($wallet->user_id !== auth()->id(), 403, 'Non autorisé');
        $validated = $request->validate([
            'name' => ['nullable', 'string', 'max:255'],
            'type' => ['nullable', 'in:cash,mobile_money,bank'],
        ]);

        $wallet->update($validated);

        return new WalletResource($wallet);
    }

    public function destroy(Wallet $wallet)
    {
        abort_if($wallet->user_id !== auth()->id(), 403, 'Non autorisé');

        if ($wallet->transactions()->exists()) {
            return response()->json(['message' => 'Impossible de supprimer un portefeuille contenant des transactions'], 409);
        }

        $wallet->delete();

        return response()->json(['message' => 'Wallet deleted']);
    }
}
