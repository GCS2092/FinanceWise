@echo off
chcp 65001 >nul
REM ============================================================
REM  Script de test complet — FinanceWise Backend (Windows)
REM  Usage : double-clique ou exécute dans CMD/PowerShell
REM ============================================================

echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║           TEST COMPLET — FINANCEWISE BACKEND                 ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.

cd /d "%~dp0"

REM --- 1. Vérification de la connexion PostgreSQL ---
echo [1/8] Vérification connexion PostgreSQL ...
php artisan db:monitor
if %errorlevel% neq 0 (
    echo [ERREUR] Connexion PostgreSQL échouée. Vérifie .env et PostgreSQL.
    pause
    exit /b 1
)
echo [OK] Connexion PostgreSQL OK
echo.

REM --- 2. État des migrations ---
echo [2/8] État des migrations ...
php artisan migrate:status
echo.

REM --- 3. Vider et recréer la base de test (optionnel) ---
echo [3/8] Préparation de la base de test ...
php artisan migrate:fresh --seed --env=testing 2>nul
if %errorlevel% neq 0 (
    echo [INFO] Base de test non configurée, utilisation de la base locale.
)
echo.

REM --- 4. Cache & config clear ---
echo [4/8] Nettoyage cache ...
php artisan config:clear
php artisan cache:clear
php artisan route:clear
echo.

REM --- 5. Vérification des routes ---
echo [5/8] Liste des routes API ...
php artisan route:list --path=api
echo.

REM --- 6. Tests automatisés PHPUnit ---
echo [6/8] Lancement de la suite de tests ...
php artisan test --verbose
if %errorlevel% neq 0 (
    echo [ERREUR] Certains tests ont échoué.
) else (
    echo [OK] Tous les tests sont passés.
)
echo.

REM --- 7. Vérification rapide des tables ---
echo [7/8] Compte des enregistrements dans la base ...
php artisan tinker --execute="echo 'Users: ' . App\Models\User::count() . PHP_EOL; echo 'Wallets: ' . App\Models\Wallet::count() . PHP_EOL; echo 'Transactions: ' . App\Models\Transaction::count() . PHP_EOL; exit;"
echo.

REM --- 8. Vérification finale ---
echo [8/8] Vérification du serveur local ...
php artisan serve --host=127.0.0.1 --port=8000 >nul 2>&1 &
timeout /t 2 >nul
curl -s -o nul -w "HTTP Status: %%{http_code}\n" http://127.0.0.1:8000/
if %errorlevel% neq 0 (
    echo [INFO] Serveur non démarré automatiquement. Lance manuellement : php artisan serve
)
echo.

echo ╔══════════════════════════════════════════════════════════════╗
echo ║                      TESTS TERMINÉS                          ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
pause
