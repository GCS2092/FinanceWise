<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Alert;

class AlertController extends Controller
{
    public function index(Request $request)
    {
        $alerts = $request->user()->alerts()
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json(['data' => $alerts]);
    }

    public function markAsRead(Request $request, $id)
    {
        $alert = $request->user()->alerts()->findOrFail($id);
        $alert->markAsRead();

        return response()->json(['data' => $alert]);
    }

    public function markAllAsRead(Request $request)
    {
        $request->user()->alerts()->where('is_read', false)->update([
            'is_read' => true,
            'read_at' => now(),
        ]);

        return response()->json(['message' => 'All alerts marked as read']);
    }

    public function unreadCount(Request $request)
    {
        $count = $request->user()->alerts()->where('is_read', false)->count();

        return response()->json(['count' => $count]);
    }
}
