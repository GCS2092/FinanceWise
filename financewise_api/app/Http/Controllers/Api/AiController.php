<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AiConversation;
use App\Models\AiInsight;
use App\Services\Ai\AiCategorizationService;
use App\Services\Ai\AiCoachService;
use App\Services\Ai\AiInsightsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class AiController extends Controller
{
    public function __construct(
        protected AiCoachService $coach,
        protected AiInsightsService $insights,
        protected AiCategorizationService $categorizer,
    ) {
    }

    public function status(): JsonResponse
    {
        $raw = (string) config('services.ai.provider', 'groq');
        $names = $raw === 'auto'
            ? ['groq', 'gemini']
            : array_map('trim', explode(',', $raw));

        $details = [];
        foreach ($names as $name) {
            $details[] = [
                'name' => $name,
                'configured' => match ($name) {
                    'groq'   => !empty(config('services.groq.key')),
                    'gemini' => !empty(config('services.gemini.key')),
                    default  => false,
                },
                'model' => match ($name) {
                    'groq'   => config('services.groq.model'),
                    'gemini' => config('services.gemini.model'),
                    default  => null,
                },
            ];
        }

        $anyConfigured = collect($details)->contains('configured', true);

        return response()->json([
            'enabled' => (bool) config('services.ai.enabled', true),
            'provider' => $raw,
            'configured' => $anyConfigured,
            'failover' => count($details) > 1,
            'providers' => $details,
            // Compat champ legacy
            'model' => $details[0]['model'] ?? null,
        ]);
    }

    public function chat(Request $request): JsonResponse
    {
        $data = $request->validate([
            'message' => ['required', 'string', 'min:1', 'max:1000'],
            'conversation_id' => ['nullable', 'integer'],
        ]);

        $result = $this->coach->ask(
            $request->user(),
            $data['message'],
            $data['conversation_id'] ?? null,
        );

        return response()->json($result);
    }

    public function conversations(Request $request): JsonResponse
    {
        $convos = AiConversation::where('user_id', $request->user()->id)
            ->latest('updated_at')
            ->limit(30)
            ->get(['id', 'title', 'created_at', 'updated_at']);

        return response()->json(['data' => $convos]);
    }

    public function conversationMessages(Request $request, int $id): JsonResponse
    {
        $convo = AiConversation::where('user_id', $request->user()->id)->findOrFail($id);
        $messages = $convo->messages()
            ->whereIn('role', ['user', 'assistant'])
            ->get(['id', 'role', 'content', 'created_at']);

        return response()->json([
            'conversation' => $convo->only(['id', 'title']),
            'messages' => $messages,
        ]);
    }

    public function deleteConversation(Request $request, int $id): JsonResponse
    {
        $convo = AiConversation::where('user_id', $request->user()->id)->findOrFail($id);
        $convo->delete();
        return response()->json(['message' => 'Conversation supprimée']);
    }

    public function monthlyInsight(Request $request): JsonResponse
    {
        $period = $request->query('period');
        if ($period && !preg_match('/^\d{4}-\d{2}$/', $period)) {
            return response()->json(['message' => 'period doit être au format YYYY-MM'], 422);
        }

        $insight = $this->insights->getOrGenerateMonthlyBrief($request->user(), $period);

        return response()->json([
            'period' => $insight->period,
            'summary' => $insight->summary,
            'highlights' => $insight->highlights ?? [],
            'suggestions' => $insight->suggestions ?? [],
            'is_read' => $insight->is_read,
            'created_at' => $insight->created_at,
        ]);
    }

    public function markInsightRead(Request $request): JsonResponse
    {
        $period = $request->input('period');
        AiInsight::where('user_id', $request->user()->id)
            ->where('type', 'monthly_brief')
            ->when($period, fn ($q) => $q->where('period', $period))
            ->update(['is_read' => true]);
        return response()->json(['message' => 'OK']);
    }

    public function categorize(Request $request): JsonResponse
    {
        $data = $request->validate([
            'description' => ['required', 'string', 'max:500'],
            'type' => ['nullable', Rule::in(['income', 'expense'])],
        ]);

        $result = $this->categorizer->categorize(
            $request->user(),
            $data['description'],
            $data['type'] ?? null,
        );

        return response()->json($result);
    }

    public function learnCorrection(Request $request): JsonResponse
    {
        $data = $request->validate([
            'description' => ['required', 'string', 'max:500'],
            'category_id' => ['required', 'integer', 'exists:categories,id'],
        ]);

        $this->categorizer->learnFromCorrection(
            $request->user(),
            $data['description'],
            $data['category_id'],
        );

        return response()->json(['message' => 'Merci, j\'apprends de tes corrections.']);
    }
}
