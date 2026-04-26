<?php

namespace App\Policies;

use App\Models\PaymentReminder;
use App\Models\User;

class PaymentReminderPolicy
{
    public function view(User $user, PaymentReminder $paymentReminder)
    {
        return $user->id === $paymentReminder->user_id;
    }

    public function create(User $user)
    {
        return true;
    }

    public function update(User $user, PaymentReminder $paymentReminder)
    {
        return $user->id === $paymentReminder->user_id;
    }

    public function delete(User $user, PaymentReminder $paymentReminder)
    {
        return $user->id === $paymentReminder->user_id;
    }
}
