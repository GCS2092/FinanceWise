<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateTransactionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'wallet_id' => [
                'nullable',
                'exists:wallets,id',
                function ($attribute, $value, $fail) {
                    if (\App\Models\Wallet::where('id', $value)->where('user_id', auth()->id())->doesntExist()) {
                        $fail('Le portefeuille sélectionné n\'appartient pas à l\'utilisateur.');
                    }
                },
            ],
            'category_id' => [
                'nullable',
                'exists:categories,id',
                function ($attribute, $value, $fail) {
                    // Si c'est un revenu, la catégorie doit être null
                    if (request()->input('type') === 'income' && $value !== null) {
                        $fail('Les revenus ne doivent pas avoir de catégorie.');
                        return;
                    }
                    
                    // Si c'est une dépense avec une catégorie, vérifier qu'elle est valide
                    if ($value !== null) {
                        if (\App\Models\Category::where('id', $value)
                            ->where(function ($query) {
                                $query->where('is_system', true)
                                      ->orWhere('user_id', auth()->id());
                            })->doesntExist()) {
                            $fail('La catégorie sélectionnée n\'est pas valide.');
                        }
                    }
                },
            ],
            'type' => ['nullable', 'in:income,expense,transfer'],
            'amount' => ['nullable', 'numeric', 'min:0'],
            'description' => ['nullable', 'string'],
            'transaction_date' => ['nullable', 'date'],
            'source' => ['nullable', 'string', 'max:50'],
            'status' => ['nullable', 'in:pending,completed,cancelled'],
        ];
    }
}
