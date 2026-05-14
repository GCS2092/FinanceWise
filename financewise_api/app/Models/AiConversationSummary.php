<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AiConversationSummary extends Model
{
    protected $table = 'ai_conversation_summaries';

    protected $fillable = [
        'conversation_id',
        'from_message_id',
        'to_message_id',
        'body',
        'meta',
    ];

    protected $casts = [
        'meta' => 'array',
    ];

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(AiConversation::class, 'conversation_id');
    }
}
