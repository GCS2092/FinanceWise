<?php

namespace App\Observers;

use App\Models\PaymentReminder;
use App\Models\Alert;

class PaymentReminderObserver
{
    /**
     * Handle the PaymentReminder "created" event.
     */
    public function created(PaymentReminder $paymentReminder): void
    {
        // Envoyer une alerte de confirmation
        Alert::create([
            'user_id' => $paymentReminder->user_id,
            'type' => 'payment_reminder',
            'title' => 'Rappel de paiement créé',
            'message' => "Rappel '{$paymentReminder->name}' de {$paymentReminder->amount} XOF créé pour le {$paymentReminder->due_date}",
            'data' => ['reminder_id' => $paymentReminder->id],
            'is_read' => false,
        ]);
    }

    /**
     * Handle the PaymentReminder "updated" event.
     */
    public function updated(PaymentReminder $paymentReminder): void
    {
        // Envoyer une alerte si le rappel est marqué comme complété
        if ($paymentReminder->isDirty('status') && $paymentReminder->status === 'completed') {
            Alert::create([
                'user_id' => $paymentReminder->user_id,
                'type' => 'payment_reminder',
                'title' => 'Paiement complété',
                'message' => "Rappel '{$paymentReminder->name}' marqué comme complété",
                'data' => ['reminder_id' => $paymentReminder->id],
                'is_read' => false,
            ]);
        }
    }

    /**
     * Handle the PaymentReminder "deleted" event.
     */
    public function deleted(PaymentReminder $paymentReminder): void
    {
        //
    }

    /**
     * Handle the PaymentReminder "restored" event.
     */
    public function restored(PaymentReminder $paymentReminder): void
    {
        //
    }

    /**
     * Handle the PaymentReminder "force deleted" event.
     */
    public function forceDeleted(PaymentReminder $paymentReminder): void
    {
        //
    }
}
