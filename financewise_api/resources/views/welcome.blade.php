<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ config('app.name', 'FinanceWise') }}</title>
    <style>
        body { font-family: system-ui, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #f3f4f6; }
        .card { background: white; padding: 2rem 3rem; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); text-align: center; }
        h1 { color: #1f2937; margin-bottom: 0.5rem; }
        p { color: #6b7280; }
        .status { display: inline-block; width: 10px; height: 10px; background: #10b981; border-radius: 50%; margin-right: 6px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>FinanceWise API</h1>
        <p><span class="status"></span>Service opérationnel</p>
        <p style="font-size: 0.85rem; margin-top: 1rem;">Laravel {{ app()->version() }}</p>
    </div>
</body>
</html>
