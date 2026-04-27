<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\WalletResource;
use App\Models\Wallet;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class WalletController extends Controller
{
    public function index()
    {
        $userId = auth()->id();
        $wallets = Cache::remember("wallets:user:{$userId}", 30, function () {
            return auth()->user()->wallets;
        });
        return WalletResource::collection($wallets);
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

        self::clearCache(auth()->id());

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

        self::clearCache(auth()->id());

        return new WalletResource($wallet);
    }

    public function destroy(Wallet $wallet)
    {
        abort_if($wallet->user_id !== auth()->id(), 403, 'Non autorisé');

        if ($wallet->transactions()->exists()) {
            return response()->json(['message' => 'Impossible de supprimer un portefeuille contenant des transactions'], 409);
        }

        $wallet->delete();

        self::clearCache(auth()->id());

        return response()->json(['message' => 'Portefeuille supprimé']);
    }

    public static function clearCache(int $userId): void
    {
        Cache::forget("wallets:user:{$userId}");
    }
}
