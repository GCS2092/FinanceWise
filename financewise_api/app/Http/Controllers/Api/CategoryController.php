<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\CategoryResource;
use App\Services\CategoryService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class CategoryController extends Controller
{
    public function __construct(protected CategoryService $service)
    {
    }

    public function index()
    {
        $categories = $this->service->getForUser(auth()->id());
        return CategoryResource::collection($categories);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'icon' => ['nullable', 'string'],
            'color' => ['nullable', 'string'],
            'type' => ['required', 'in:income,expense'],
        ]);

        $category = $this->service->createForUser($validated, auth()->id());

        return response()->json([
            'message' => 'Catégorie créée',
            'data' => new CategoryResource($category),
        ], 201);
    }

    public function show(\App\Models\Category $category)
    {
        abort_if(!$category->is_system && $category->user_id !== auth()->id(), 403, 'Non autorisé');
        return new CategoryResource($category);
    }

    public function update(Request $request, \App\Models\Category $category): JsonResponse
    {
        if ($category->is_system && $category->user_id !== auth()->id()) {
            return response()->json(['message' => 'Non autorisé'], 403);
        }

        $validated = $request->validate([
            'name' => ['nullable', 'string', 'max:255'],
            'icon' => ['nullable', 'string'],
            'color' => ['nullable', 'string'],
        ]);

        $category->update($validated);

        CategoryService::clearCache(auth()->id());

        return response()->json([
            'message' => 'Catégorie mise à jour',
            'data' => new CategoryResource($category),
        ]);
    }

    public function destroy(\App\Models\Category $category): JsonResponse
    {
        if ($category->is_system) {
            return response()->json(['message' => 'Impossible de supprimer une catégorie système'], 403);
        }

        if ($category->user_id !== auth()->id()) {
            return response()->json(['message' => 'Non autorisé'], 403);
        }

        if ($category->transactions()->exists() || $category->budgets()->exists()) {
            return response()->json(['message' => 'Impossible de supprimer une catégorie utilisée dans des transactions ou budgets'], 409);
        }

        $category->delete();

        CategoryService::clearCache(auth()->id());

        return response()->json(['message' => 'Catégorie supprimée']);
    }
}
