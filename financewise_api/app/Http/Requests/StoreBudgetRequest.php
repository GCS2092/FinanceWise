<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreBudgetRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'category_id' => [
                'required',
                'exists:categories,id',
                function ($attribute, $value, $fail) {
                    if (\App\Models\Category::where('id', $value)
                        ->where(function ($query) {
                            $query->where('is_system', true)
                                  ->orWhere('user_id', auth()->id());
                        })->doesntExist()) {
                        $fail('La catégorie sélectionnée n\'est pas valide.');
                    }
                },
            ],
            'amount' => ['required', 'numeric', 'min:0'],
            'period' => ['required', 'in:daily,weekly,monthly,yearly'],
            'start_date' => ['required', 'date'],
            'end_date' => ['required', 'date', 'after_or_equal:start_date'],
        ];
    }
}
