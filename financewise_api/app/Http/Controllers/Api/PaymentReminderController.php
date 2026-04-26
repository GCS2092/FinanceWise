<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PaymentReminder;
use Illuminate\Http\Request;

class PaymentReminderController extends Controller
{
    public function index()
    {
        $reminders = PaymentReminder::forUser()->get();
        return response()->json(['data' => $reminders]);
    }

    public function upcoming()
    {
        $reminders = PaymentReminder::forUser()
            ->upcoming()
            ->orWhere('due_date', '<', now())
            ->get();
        return response()->json(['data' => $reminders]);
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'amount' => 'required|numeric|min:0',
            'due_date' => 'required|date',
            'frequency' => 'required|in:once,weekly,monthly,yearly',
        ]);

        $reminder = PaymentReminder::create([
            'user_id' => auth()->id(),
            'name' => $validated['name'],
            'description' => $validated['description'] ?? null,
            'amount' => $validated['amount'],
            'due_date' => $validated['due_date'],
            'frequency' => $validated['frequency'],
            'next_reminder_date' => $validated['due_date'],
            'status' => 'pending',
        ]);

        return response()->json(['data' => $reminder], 201);
    }

    public function show(PaymentReminder $paymentReminder)
    {
        $this->authorize('view', $paymentReminder);
        return response()->json(['data' => $paymentReminder]);
    }

    public function update(Request $request, PaymentReminder $paymentReminder)
    {
        $this->authorize('update', $paymentReminder);

        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'amount' => 'sometimes|numeric|min:0',
            'due_date' => 'sometimes|date',
            'frequency' => 'sometimes|in:once,weekly,monthly,yearly',
            'status' => 'sometimes|in:pending,completed,overdue',
        ]);

        $paymentReminder->update($validated);

        return response()->json(['data' => $paymentReminder]);
    }

    public function destroy(PaymentReminder $paymentReminder)
    {
        $this->authorize('delete', $paymentReminder);
        $paymentReminder->delete();
        return response()->json(null, 204);
    }

    public function markCompleted(PaymentReminder $paymentReminder)
    {
        $this->authorize('update', $paymentReminder);
        
        $paymentReminder->update(['status' => 'completed']);
        
        // Si c'est un rappel récurrent, créer le prochain
        if ($paymentReminder->frequency != 'once') {
            $nextDate = $this->calculateNextReminderDate($paymentReminder);
            PaymentReminder::create([
                'user_id' => auth()->id(),
                'name' => $paymentReminder->name,
                'description' => $paymentReminder->description,
                'amount' => $paymentReminder->amount,
                'due_date' => $nextDate,
                'frequency' => $paymentReminder->frequency,
                'next_reminder_date' => $nextDate,
                'status' => 'pending',
            ]);
        }

        return response()->json(['data' => $paymentReminder]);
    }

    private function calculateNextReminderDate(PaymentReminder $reminder)
    {
        $dueDate = $reminder->due_date;
        
        return match ($reminder->frequency) {
            'weekly' => $dueDate->addWeek(),
            'monthly' => $dueDate->addMonth(),
            'yearly' => $dueDate->addYear(),
            default => $dueDate,
        };
    }
}
