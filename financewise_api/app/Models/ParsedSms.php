<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ParsedSms extends Model
{
    use HasFactory;

    protected $table = 'parsed_sms';

    protected $fillable = [
        'user_id',
        'provider',
        'raw_content',
        'parsed_amount',
        'parsed_phone',
        'parsed_type',
        'transaction_id',
        'status',
        'error_message',
        'parsed_at',
    ];

    protected function casts(): array
    {
        return [
            'parsed_amount' => 'decimal:2',
            'parsed_at' => 'datetime',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function transaction()
    {
        return $this->belongsTo(Transaction::class);
    }
}
