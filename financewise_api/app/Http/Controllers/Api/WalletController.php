<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\WalletResource;
use App\Models\Wallet;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Validation\Rule;

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
            'name' => ['required', 'string', 'max:255', Rule::unique('wallets')->where('user_id', auth()->id())],
            'type' => ['required', 'in:cash,mobile_money,bank'],
            'currency' => ['nullable', 'string', 'size:3'],
            'balance' => ['nullable', 'numeric', 'min:0'],
            'is_default' => ['nullable', 'boolean'],
        ]);

        $validated['user_id'] = auth()->id();
        
        // Si c'est le premier wallet ou is_default est true, le définir par défaut
        $walletCount = Wallet::where('user_id', auth()->id())->count();
        if ($walletCount === 0 || ($validated['is_default'] ?? false)) {
            $validated['is_default'] = true;
            // Désactiver les autres wallets par défaut
            Wallet::where('user_id', auth()->id())->update(['is_default' => false]);
        } else {
            $validated['is_default'] = $validated['is_default'] ?? false;
        }
        
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
            'balance' => ['nullable', 'numeric', 'min:0'],
        ]);

        $wallet->update($validated);

        self::clearCache(auth()->id());
        self::clearDashboardCache(auth()->id());

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

    public static function clearDashboardCache(int $userId): void
    {
        Cache::forget("dashboard:{$userId}");
    }

    public function setDefault(Wallet $wallet)
    {
        abort_if($wallet->user_id !== auth()->id(), 403, 'Non autorisé');
        
        // Désactiver tous les autres wallets par défaut
        Wallet::where('user_id', auth()->id())->update(['is_default' => false]);
        
        // Activer ce wallet comme par défaut
        $wallet->update(['is_default' => true]);
        
        self::clearCache(auth()->id());
        self::clearDashboardCache(auth()->id());
        
        return new WalletResource($wallet);
    }

    public function getDefault()
    {
        $wallet = Wallet::where('user_id', auth()->id())
            ->where('is_default', true)
            ->first();
            
        if (!$wallet) {
            // Fallback: retourner le premier wallet s'il n'y en a pas de par défaut
            $wallet = Wallet::where('user_id', auth()->id())->first();
        }
        
        if (!$wallet) {
            return response()->json(['message' => 'Aucun portefeuille trouvé'], 404);
        }
        
        return new WalletResource($wallet);
    }
}
