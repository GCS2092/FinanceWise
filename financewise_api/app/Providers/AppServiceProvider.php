<?php

namespace App\Providers;

use App\Models\Transaction;
use App\Models\PaymentReminder;
use App\Observers\TransactionObserver;
use App\Observers\PaymentReminderObserver;
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
    }
}
