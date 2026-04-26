# Architecture Backend — FinanceWise API

> Ce document décrit le fonctionnement du backend de FinanceWise, l'importance de chaque dossier/fichier, et les points clés pour l'intégration mobile.

---

## 1. Vue d'ensemble

FinanceWise est une API REST construite avec **Laravel 12** (PHP 8.2). Elle expose des endpoints JSON sécurisés via **Laravel Sanctum** (tokens d'API). Le backend utilise **SQLite** par défaut (fichier `database/database.sqlite`) pour simplifier le déploiement local.

**Rôle principal :**
- Gestion des utilisateurs (inscription / connexion / token)
- Gestion des portefeuilles, catégories, transactions et budgets
- Parsing automatique des SMS de Wave & Orange Money pour créer des transactions
- Tableau de bord récapitulatif (revenus, dépenses, alertes budget)

---

## 2. Architecture générale

Le backend suit le pattern **MVC amélioré** avec une couche **Service** pour isoler la logique métier.

```
Requête HTTP
    ↓
Routes (routes/api.php)
    ↓
Middleware (auth:sanctum)
    ↓
Form Request Validation (app/Http/Requests)
    ↓
Controller (app/Http/Controllers/Api)
    ↓
Service (app/Services) ← Logique métier complexe
    ↓
Model Eloquent (app/Models) ← ORM / Base de données
    ↓
Resource (app/Http/Resources) ← Format JSON de réponse
```

---

## 3. Dossiers et fichiers — Importance

### `app/` — Coeur de l'application

#### `app/Models/` — Entités de la base de données
| Fichier | Rôle |
|---------|------|
| `User.php` | Utilisateur authentifiable. Contient les relations vers wallets, transactions, budgets, categories. Utilise `HasApiTokens` pour Sanctum. |
| `Wallet.php` | Portefeuille (nom, solde, devise, type). Chaque utilisateur a au moins un wallet "Principal" créé à l'inscription. |
| `Category.php` | Catégories de transactions (nourriture, transport…). Supporte les catégories **système** (`is_system=true`) et personnalisées par utilisateur. |
| `Transaction.php` | Transaction financière (revenu/dépense/transfer). Contient `amount`, `type`, `wallet_id`, `category_id`, `source` (manual, sms_wave, sms_orange_money). |
| `Budget.php` | Budget lié à une catégorie avec montant alloué, période, montant dépensé (`spent`). Possède des accessors `remaining` et `percentage`. |
| `ParsedSms.php` | SMS brut reçu, résultat du parsing (montant, type, fournisseur). Lié éventuellement à une transaction créée automatiquement. |

#### `app/Http/Controllers/Api/` — Gestionnaires de requêtes
| Fichier | Rôle |
|---------|------|
| `AuthController.php` | `register`, `login`, `logout`, `me`. Crée automatiquement un wallet Principal à l'inscription. Retourne un token Sanctum. |
| `WalletController.php` | CRUD des wallets (`apiResource`). |
| `CategoryController.php` | CRUD des catégories (`apiResource`). |
| `TransactionController.php` | CRUD des transactions avec filtres (`type`, `category_id`, plage de dates). Vérifie la propriété via `abort_if`. |
| `BudgetController.php` | CRUD des budgets (`apiResource`). |
| `DashboardController.php` | Point unique `/dashboard` qui agrège : solde total, revenus/dépenses du mois, top catégories, transactions récentes, budgets actifs, alertes. |
| `SmsParserController.php` | Reçoit un SMS brut (`/sms/parse`) ou un batch (`/sms/batch`), délègue à `SmsParserService`. |

#### `app/Http/Requests/` — Validation des entrées
| Fichier | Rôle |
|---------|------|
| `RegisterRequest.php` | Règles d'inscription (name, email, password). |
| `LoginRequest.php` | Règles de connexion. |
| `StoreTransactionRequest.php` | Validation transaction + règles custom (catégorie doit appartenir à l'utilisateur ou être système, wallet doit appartenir à l'utilisateur). |
| `UpdateTransactionRequest.php` | Idem pour la mise à jour. |
| `StoreWalletRequest.php` / `UpdateWalletRequest.php` | Validation des wallets. |
| `StoreBudgetRequest.php` / `UpdateBudgetRequest.php` | Validation des budgets. |

#### `app/Http/Resources/` — Formatage JSON des réponses
| Fichier | Rôle |
|---------|------|
| `TransactionResource.php` | Expose `id`, `type`, `amount`, `description`, `category`, `wallet`, `transaction_date`, `source`, `status`. |
| `CategoryResource.php` | Format d'une catégorie. |
| `WalletResource.php` | Format d'un wallet. |
| `BudgetResource.php` | Format d'un budget. |

> **Pourquoi les Resources ?** Cela garantit que l'API mobile reçoit **toujours la même structure JSON**, même si le modèle évolue en base.

#### `app/Services/` — Logique métier complexe
| Fichier | Rôle |
|---------|------|
| `TransactionService.php` | **Coeur financier**. Crée/met à jour/supprime une transaction **dans une transaction DB** : met à jour le solde du wallet, met à jour le `spent` du budget. Gère la réversion lors d'une update (restaure l'ancien solde, applique le nouveau). |
| `SmsParserService.php` | **Parsing intelligent** des SMS Wave / Orange Money. Extrait montant, type (income/expense), date. Détecte la catégorie par mots-clés. Crée la transaction via `TransactionService`. Log les erreurs. |
| `CategoryService.php` | Logique métier des catégories (peut évoluer). |
| `BudgetService.php` | Logique métier des budgets. |

> **Pourquoi les Services ?** Isoler la logique complexe hors des controllers pour la rendre **réutilisable et testable unitairement**.

#### `app/Providers/` / `app/Middleware/`
- `Providers/AppServiceProvider.php` : Enregistrement des bindings de l'application.
- `Middleware/` : Filtres HTTP (ex: authentification, CORS, etc.).

---

### `routes/` — Définition des endpoints API

| Fichier | Rôle |
|---------|------|
| `api.php` | **Routes publiques** : `/register`, `/login`. <br> **Routes protégées** (`auth:sanctum`) : `/user`, `/logout`, `/dashboard`, `/wallets`, `/categories`, `/transactions`, `/budgets`, `/sms/parse`, `/sms/batch`. |
| `web.php` | Routes web (non utilisées pour l'API mobile). |
| `console.php` | Commandes artisan personnalisées. |

---

### `database/` — Schéma et données

#### `database/migrations/`
Chaque fichier crée/modifie une table :
- `create_users_table.php` — Utilisateurs
- `create_categories_table.php` — Catégories (système + utilisateur)
- `create_wallets_table.php` — Wallets
- `create_budgets_table.php` — Budgets
- `create_transactions_table.php` — Transactions
- `create_parsed_sms_table.php` — SMS parsés
- `create_personal_access_tokens_table.php` — Tokens Sanctum

#### `database/seeders/`
| Fichier | Rôle |
|---------|------|
| `DatabaseSeeder.php` | Orchestrateur : appelle les seeders dans l'ordre. |
| `CategorySeeder.php` | Insère les catégories **système** (Nourriture, Transport, Internet/Data, Mobile Money, École, Santé, Dépenses personnelles). |
| `UserSeeder.php` | Crée 2 utilisateurs de démo avec wallets pré-remplis. |
| `TransactionSeeder.php` | Génère des transactions de test pour les 2 utilisateurs. |
| `BudgetSeeder.php` | Génère des budgets de test. |

#### `database/factories/`
Génèrent des données fictives pour les tests (ex: `TransactionFactory`, `UserFactory`).

---

### `tests/` — Tests automatisés

| Fichier | Rôle |
|---------|------|
| `Feature/AuthTest.php` | Teste inscription, connexion, récupération utilisateur, déconnexion. |
| `Feature/TransactionTest.php` | Teste création, lecture, filtres et suppression de transactions. |
| `Feature/WalletAuthorizationTest.php` | Vérifie qu'un utilisateur ne peut pas accéder au wallet d'un autre. |
| `Feature/EndToEndWorkflowTest.php` | Teste le workflow complet : register → créer wallet → créer catégorie → créer transaction → vérifier dashboard. |
| `TestCase.php` | Classe de base pour tous les tests (setup de la base SQLite en mémoire). |

> **Pourquoi ?** Garantir que le backend reste stable à chaque modification. Commande : `php artisan test --coverage`

---

### `config/` — Configuration Laravel

| Fichier clé | Rôle |
|-------------|------|
| `auth.php` | Configuration de l'authentification (guards, providers). |
| `database.php` | Connexion SQLite par défaut. |
| `cors.php` | Cross-Origin : autorise les requêtes depuis l'app mobile. |
| `services.php` | Configuration des services tiers (SMS providers). |

---

### `public/` — Point d'entrée web
- `index.php` : Front controller PHP. Toutes les requêtes HTTP passent par là.

---

### Fichiers à la racine

| Fichier | Rôle |
|---------|------|
| `.env` / `.env.example` | Variables d'environnement (DB, APP_KEY, config). |
| `composer.json` | Dépendances PHP (Laravel 12, Sanctum, PHPUnit…). |
| `phpunit.xml` | Configuration des tests (coverage, base de test SQLite). |
| `artisan` | CLI Laravel (migrations, seeders, serveur de dev, tests). |
| `test-backend.bat` | Script batch Windows pour lancer les tests rapidement. |
| `README.md` | Documentation générale Laravel. |
| `TESTING.md` | Documentation détaillée des tests. |

---

## 4. Modèle de données (simplifié)

```
User
 ├── hasMany Wallet
 ├── hasMany Transaction
 ├── hasMany Budget
 ├── hasMany Category
 └── hasMany ParsedSms

Wallet      → belongsTo User
            → hasMany Transaction

Category    → belongsTo User (nullable)
            → hasMany Transaction
            → hasMany Budget

Transaction → belongsTo User
            → belongsTo Wallet
            → belongsTo Category (nullable)
            → hasOne ParsedSms (nullable)

Budget      → belongsTo User
            → belongsTo Category

ParsedSms   → belongsTo User
            → belongsTo Transaction (nullable)
```

---

## 5. Flux type d'une requête API

### Exemple : Création d'une transaction manuelle

```
POST /api/transactions
Authorization: Bearer <token>
```

1. **Route** `routes/api.php` — Redirige vers `TransactionController@store`
2. **Middleware** `auth:sanctum` — Vérifie le token, injecte `auth()->user()`
3. **Form Request** `StoreTransactionRequest` — Valide les champs (amount > 0, wallet_id existe et appartient à l'utilisateur, category_id valide)
4. **Controller** `TransactionController::store()` — Appelle `$this->service->create($data, auth()->id())`
5. **Service** `TransactionService::create()` — Ouverture d'une **transaction DB** :
   - Crée la transaction
   - Met à jour le solde du wallet (+ ou - selon type)
   - Met à jour le `spent` du budget si c'est une dépense
6. **Resource** `TransactionResource` — Formate la réponse JSON
7. **Réponse HTTP 201** avec `{ message, data: { ... } }`

---

## 6. Sécurité

| Mécanisme | Implémentation |
|-----------|----------------|
| Authentification | **Laravel Sanctum** (tokens API stateless). |
| Autorisation | Vérification manuelle `abort_if($model->user_id !== auth()->id(), 403)` dans chaque controller. |
| Validation | `FormRequest` avec règles custom (ownership des wallets/catégories). |
| Protection données sensibles | `$hidden = ['password', 'remember_token']` dans `User.php`. |
| Hash mot de passe | `bcrypt` via cast `password => hashed` dans `User.php`. |
| CORS | Configuré dans `config/cors.php` pour autoriser l'origine de l'app mobile. |

---

## 7. Endpoints API (résumé pour le mobile)

| Méthode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| POST | `/api/register` | Non | Crée utilisateur + wallet Principal, retourne token |
| POST | `/api/login` | Non | Retourne token |
| POST | `/api/logout` | Oui | Révoque tous les tokens |
| GET | `/api/user` | Oui | Infos utilisateur connecté |
| GET | `/api/dashboard` | Oui | Résumé complet (solde, revenus, dépenses, alertes) |
| GET/POST/PUT/DELETE | `/api/wallets` | Oui | CRUD wallets |
| GET/POST/PUT/DELETE | `/api/categories` | Oui | CRUD catégories |
| GET/POST/PUT/DELETE | `/api/transactions` | Oui | CRUD transactions (+ filtres query string) |
| GET/POST/PUT/DELETE | `/api/budgets` | Oui | CRUD budgets |
| POST | `/api/sms/parse` | Oui | Envoie un SMS brut, retourne transaction auto-créée |
| POST | `/api/sms/batch` | Oui | Envoie plusieurs SMS en une fois |

**Filtres transactions (query params) :**
- `?type=income|expense`
- `?category_id=3`
- `?start_date=2026-04-01&end_date=2026-04-30`

---

## 8. Commandes essentielles

```bash
# Démarrer le serveur local
php artisan serve

# Créer la base + exécuter les migrations
php artisan migrate

# Remplir la base avec les données de démo
php artisan db:seed

# Lancer les tests
php artisan test

# Lancer les tests avec couverture de code
php artisan test --coverage

# Créer un utilisateur admin / tester rapidement
php artisan tinker
> \App\Models\User::factory()->create(['email'=>'test@test.com','password'=>'password'])
```

---

## 9. Points clés pour l'intégration Mobile

1. **Authentification par Token** — Après `login` ou `register`, stocke le token (`plainTextToken`) et envoie-le dans le header `Authorization: Bearer <token>` pour toutes les requêtes suivantes.

2. **Content-Type** — Toujours envoyer `Accept: application/json` et `Content-Type: application/json`.

3. **Devise** — Par défaut `XOF` (FCFA). Le solde et les montants sont retournés en `float`.

4. **Dates** — Format ISO 8601 (`2026-04-25T16:30:00`).

5. **Pagination** — Les listes (`/transactions`, `/wallets`) sont paginées (20 éléments/page). La réponse contient `data`, `links`, `meta`.

6. **Erreurs** — Le backend retourne :
   - `401` — Token invalide ou expiré
   - `403` — Accès interdit (ressource d'un autre utilisateur)
   - `422` — Validation échouée (détails dans `errors`)

7. **Parsing SMS** — L'app mobile peut envoyer le SMS brut via `/api/sms/parse`. Le backend gère tout (extraction, catégorisation, création transaction). L'app mobile n'a pas besoin de parser elle-même.

8. **Dashboard** — Un seul appel à `/api/dashboard` suffit pour afficher la page d'accueil complète.

---

## 10. Stack technique

| Composant | Technologie |
|-----------|-------------|
| Langage | PHP 8.2 |
| Framework | Laravel 12 |
| Authentification API | Laravel Sanctum 4.0 |
| Base de données | SQLite (par défaut) |
| Tests | PHPUnit 11.5 |
| ORM | Eloquent |
| Seeders | Laravel Factories + Seeders |

---

*Document généré pour faciliter la transition vers le développement mobile.*
