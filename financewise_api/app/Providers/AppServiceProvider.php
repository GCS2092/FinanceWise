<?php

namespace App\Providers;

use App\Models\Transaction;
use App\Models\PaymentReminder;
use App\Observers\TransactionObserver;
use App\Observers\PaymentReminderObserver;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        if (app()->environment('production')) {
            \Illuminate\Support\Facades\URL::forceScheme('https');
        }
        
        // Enregistrer les observateurs
        Transaction::observe(TransactionObserver::class);
        PaymentReminder::observe(PaymentReminderObserver::class);

        $this->configureRateLimiting();
    }

    protected function configureRateLimiting(): void
    {
        // Global API : 60/min par user_id si connecté, sinon par IP
        RateLimiter::for('api', function (Request $request) {
            $key = $request->user()?->id ?: $request->ip();
            return Limit::perMinute(60)->by($key)->response(function () {
                return response()->json([
                    'message' => 'Trop de requêtes. Réessayez dans quelques instants.',
                ], 429);
            });
        });

        // Login : 5 tentatives/min par IP + log quand dépassé
        RateLimiter::for('login', function (Request $request) {
            return Limit::perMinute(5)->by($request->ip())->response(function (Request $request) {
                Log::warning('Rate limit dépassé sur login', [
                    'ip' => $request->ip(),
                    'email' => $request->input('email'),
                    'user_agent' => $request->userAgent(),
                ]);
                return response()->json([
                    'message' => 'Trop de tentatives de connexion. Réessayez dans 1 minute.',
                ], 429);
            });
        });

        // Register : 3 tentatives/10min par IP
        RateLimiter::for('register', function (Request $request) {
            return Limit::perMinutes(10, 3)->by($request->ip())->response(function () {
                return response()->json([
                    'message' => 'Trop de tentatives d\'inscription. Réessayez dans 10 minutes.',
                ], 429);
            });
        });

        // SMS parse : 30/min par user_id
        RateLimiter::for('sms', function (Request $request) {
            return Limit::perMinute(30)->by($request->user()?->id)->response(function () {
                return response()->json([
                    'message' => 'Limite de parsing SMS atteinte. Réessayez dans quelques instants.',
                ], 429);
            });
        });
    }
}
