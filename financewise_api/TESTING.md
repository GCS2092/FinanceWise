# Guide de Test Complet — FinanceWise Backend

## Prérequis

- PHP 8.2+
- Composer installé
- PostgreSQL en cours d'exécution
- Extension `pgsql` activée dans PHP

## 1. Installation et Configuration

### 1.1 Installer les dépendances

```bash
composer install
```

### 1.2 Copier le fichier d'environnement

```bash
cp .env.example .env
```

### 1.3 Générer la clé d'application

```bash
php artisan key:generate
```

### 1.4 Configurer la base de données

Editer `.env` :

```env
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=FinanceWise
DB_USERNAME=postgres
DB_PASSWORD=votre_mot_de_passe
```

### 1.5 Créer la base de données

```bash
# Se connecter à PostgreSQL
createdb FinanceWise
# ou via psql : CREATE DATABASE FinanceWise;
```

### 1.6 Exécuter les migrations

```bash
php artisan migrate
```

### 1.7 (Optionnel) Remplir la base avec des données de test

```bash
php artisan db:seed
```

---

## 2. Lancer la Suite de Tests Complète

### 2.1 Tous les tests

```bash
php artisan test
```

### 2.2 Tests avec rapport détaillé

```bash
php artisan test --verbose
```

### 2.3 Tests par fichier

```bash
php artisan test --filter=AuthTest
php artisan test --filter=TransactionTest
php artisan test --filter=EndToEndWorkflowTest
php artisan test --filter=WalletAuthorizationTest
```

### 2.4 Tests avec couverture de code (si Xdebug installé)

```bash
php artisan test --coverage
```

---

## 3. Tests Manuels via API

### Option A — Postman (recommandé)

Crée un **Environment** `FinanceWise Local` avec ces variables :

| Variable | Initial Value | Current Value |
|----------|--------------|---------------|
| `base_url` | `http://localhost:8000` | `http://localhost:8000` |
| `token` | *laisser vide* | *sera rempli après login* |

Puis crée une **Collection** `FinanceWise API` avec ces requêtes :

#### 1. Register
- **Method** : `POST`
- **URL** : `{{base_url}}/api/register`
- **Body** → raw JSON :
```json
{
  "name": "Test User",
  "email": "test@example.com",
  "password": "password123",
  "password_confirmation": "password123"
}
```
- **Test** (onglet Tests) — sauvegarde le token :
```javascript
pm.environment.set("token", pm.response.json().token);
```

#### 2. Login
- **Method** : `POST`
- **URL** : `{{base_url}}/api/login`
- **Body** → raw JSON :
```json
{
  "email": "test@example.com",
  "password": "password123"
}
```
- **Test** :
```javascript
pm.environment.set("token", pm.response.json().token);
```

#### 3. Get User
- **Method** : `GET`
- **URL** : `{{base_url}}/api/user`
- **Headers** :
  - `Authorization` : `Bearer {{token}}`

#### 4. List Wallets
- **Method** : `GET`
- **URL** : `{{base_url}}/api/wallets`
- **Headers** : `Authorization: Bearer {{token}}`

#### 5. Create Category
- **Method** : `POST`
- **URL** : `{{base_url}}/api/categories`
- **Headers** :
  - `Authorization` : `Bearer {{token}}`
  - `Content-Type` : `application/json`
- **Body** → raw JSON :
```json
{
  "name": "Alimentation",
  "type": "expense",
  "icon": "food",
  "color": "#ff0000"
}
```

#### 6. Create Transaction
- **Method** : `POST`
- **URL** : `{{base_url}}/api/transactions`
- **Headers** : `Authorization: Bearer {{token}}`, `Content-Type: application/json`
- **Body** → raw JSON :
```json
{
  "wallet_id": 1,
  "category_id": 1,
  "type": "expense",
  "amount": 5000,
  "description": "Courses",
  "transaction_date": "2025-04-25",
  "source": "manual"
}
```

#### 7. Get Wallet (vérifier le solde)
- **Method** : `GET`
- **URL** : `{{base_url}}/api/wallets/1`
- **Headers** : `Authorization: Bearer {{token}}`

#### 8. Create Budget
- **Method** : `POST`
- **URL** : `{{base_url}}/api/budgets`
- **Headers** : `Authorization: Bearer {{token}}`, `Content-Type: application/json`
- **Body** → raw JSON :
```json
{
  "category_id": 1,
  "amount": 20000,
  "period": "monthly",
  "start_date": "2025-04-01",
  "end_date": "2025-04-30",
  "is_active": true
}
```

#### 9. Dashboard
- **Method** : `GET`
- **URL** : `{{base_url}}/api/dashboard`
- **Headers** : `Authorization: Bearer {{token}}`

#### 10. Logout
- **Method** : `POST`
- **URL** : `{{base_url}}/api/logout`
- **Headers** : `Authorization: Bearer {{token}}`

---

### Option B — curl (terminal)

### 3.1 Enregistrer un utilisateur

```bash
curl -X POST http://localhost:8000/api/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","password":"password123","password_confirmation":"password123"}'
```

**Réponse attendue** : `201 Created` avec `user` et `token`.

### 3.2 Se connecter

```bash
curl -X POST http://localhost:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

**Réponse attendue** : `200 OK` avec `token`.

### 3.3 Récupérer l'utilisateur authentifié

```bash
curl -X GET http://localhost:8000/api/user \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

**Réponse attendue** : `200 OK` avec les données utilisateur.

### 3.4 Lister les wallets

```bash
curl -X GET http://localhost:8000/api/wallets \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

**Réponse attendue** : `200 OK` avec un tableau contenant le wallet "Principal".

### 3.5 Créer une catégorie

```bash
curl -X POST http://localhost:8000/api/categories \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Alimentation","type":"expense","icon":"food","color":"#ff0000"}'
```

**Réponse attendue** : `201 Created`.

### 3.6 Créer une transaction

```bash
curl -X POST http://localhost:8000/api/transactions \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "wallet_id": 1,
    "category_id": 1,
    "type": "expense",
    "amount": 5000,
    "description": "Courses",
    "transaction_date": "2025-04-25",
    "source": "manual"
  }'
```

**Réponse attendue** : `201 Created`.

### 3.7 Vérifier le solde du wallet

```bash
curl -X GET http://localhost:8000/api/wallets/1 \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

**Réponse attendue** : `balance` mis à jour (ex: -5000 pour une dépense).

### 3.8 Créer un budget

```bash
curl -X POST http://localhost:8000/api/budgets \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "category_id": 1,
    "amount": 20000,
    "period": "monthly",
    "start_date": "2025-04-01",
    "end_date": "2025-04-30",
    "is_active": true
  }'
```

**Réponse attendue** : `201 Created` avec `spent` recalculé.

### 3.9 Dashboard

```bash
curl -X GET http://localhost:8000/api/dashboard \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

**Réponse attendue** : `200 OK` avec `balance`, `monthly_income`, `monthly_expense`, `top_categories`, `recent_transactions`, `budgets`, `alerts`.

### 3.10 Se déconnecter

```bash
curl -X POST http://localhost:8000/api/logout \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

**Réponse attendue** : `200 OK` avec `"message": "Déconnecté"`.

---

## 4. Tests de Sécurité

### 4.1 Accès sans token (401)

```bash
curl -X GET http://localhost:8000/api/user
curl -X GET http://localhost:8000/api/wallets
curl -X GET http://localhost:8000/api/transactions
curl -X GET http://localhost:8000/api/budgets
curl -X GET http://localhost:8000/api/dashboard
curl -X GET http://localhost:8000/api/categories
```

**Réponse attendue** : `401 Unauthorized` pour toutes.

### 4.2 Accès croisé interdit (403)

1. Créer l'utilisateur A et récupérer son wallet ID.
2. Créer l'utilisateur B et récupérer son token.
3. Tenter d'accéder au wallet de A avec le token de B :

```bash
curl -X GET http://localhost:8000/api/wallets/ID_WALLET_A \
  -H "Authorization: Bearer TOKEN_B"
```

**Réponse attendue** : `403 Forbidden`.

### 4.3 Association de ressource étrangère (422)

```bash
curl -X POST http://localhost:8000/api/transactions \
  -H "Authorization: Bearer TOKEN_B" \
  -H "Content-Type: application/json" \
  -d '{
    "wallet_id": ID_WALLET_A,
    "type": "expense",
    "amount": 100,
    "transaction_date": "2025-04-25"
  }'
```

**Réponse attendue** : `422 Unprocessable Entity` (wallet non autorisé).

---

## 5. Structure des Tests Automatisés

| Fichier | Ce qui est testé |
|---------|-----------------|
| `tests/Feature/AuthTest.php` | Register, login, logout |
| `tests/Feature/TransactionTest.php` | Liste et création de transactions |
| `tests/Feature/WalletAuthorizationTest.php` | Blocage d'accès croisé entre utilisateurs |
| `tests/Feature/EndToEndWorkflowTest.php` | Workflow complet : auth, CRUD wallets/categories/transactions, budgets, dashboard, sécurité |
| `tests/Unit/ExampleTest.php` | Test unitaire minimal |

---

## 6. Dépannage

### Erreur `SQLSTATE[08006] [7] connection to server ... refused`
- Vérifier que PostgreSQL est démarré.
- Vérifier `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD` dans `.env`.

### Erreur `Access denied` ou `Authentication failed`
- Vérifier les credentials PostgreSQL dans `.env`.

### Tests échouent sur des comparaisons de float
- JSON encode les floats entiers sans décimale (ex: `5000` au lieu de `5000.0`).
- Les tests ont été corrigés pour matcher ce comportement.

### Token Sanctum invalide ou 401 inattendu
- Vérifier que le header `Authorization: Bearer TOKEN` est bien envoyé.
- Vérifier que la table `personal_access_tokens` existe (migration Sanctum).

---

## 7. Export Postman Rapide

Tu peux créer ces deux fichiers et les importer dans Postman.

### Fichier : `FinanceWise-Environment.json`

```json
{
  "name": "FinanceWise Local",
  "values": [
    { "key": "base_url", "value": "http://localhost:8000", "type": "default" },
    { "key": "token", "value": "", "type": "secret" }
  ]
}
```

### Fichier : `FinanceWise-Collection.json`

```json
{
  "info": { "name": "FinanceWise API", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json" },
  "item": [
    {
      "name": "1. Register",
      "request": {
        "method": "POST",
        "header": [{ "key": "Content-Type", "value": "application/json" }],
        "url": "{{base_url}}/api/register",
        "body": { "mode": "raw", "raw": "{\"name\":\"Test User\",\"email\":\"test@example.com\",\"password\":\"password123\",\"password_confirmation\":\"password123\"}" }
      },
      "event": [{ "listen": "test", "script": { "exec": ["pm.environment.set(\"token\", pm.response.json().token);"] } }]
    },
    {
      "name": "2. Login",
      "request": {
        "method": "POST",
        "header": [{ "key": "Content-Type", "value": "application/json" }],
        "url": "{{base_url}}/api/login",
        "body": { "mode": "raw", "raw": "{\"email\":\"test@example.com\",\"password\":\"password123\"}" }
      },
      "event": [{ "listen": "test", "script": { "exec": ["pm.environment.set(\"token\", pm.response.json().token);"] } }]
    },
    {
      "name": "3. Get User",
      "request": { "method": "GET", "header": [{ "key": "Authorization", "value": "Bearer {{token}}" }], "url": "{{base_url}}/api/user" }
    },
    {
      "name": "4. List Wallets",
      "request": { "method": "GET", "header": [{ "key": "Authorization", "value": "Bearer {{token}}" }], "url": "{{base_url}}/api/wallets" }
    },
    {
      "name": "5. Create Category",
      "request": {
        "method": "POST",
        "header": [{ "key": "Authorization", "value": "Bearer {{token}}" }, { "key": "Content-Type", "value": "application/json" }],
        "url": "{{base_url}}/api/categories",
        "body": { "mode": "raw", "raw": "{\"name\":\"Alimentation\",\"type\":\"expense\",\"icon\":\"food\",\"color\":\"#ff0000\"}" }
      }
    },
    {
      "name": "6. Create Transaction",
      "request": {
        "method": "POST",
        "header": [{ "key": "Authorization", "value": "Bearer {{token}}" }, { "key": "Content-Type", "value": "application/json" }],
        "url": "{{base_url}}/api/transactions",
        "body": { "mode": "raw", "raw": "{\"wallet_id\":1,\"category_id\":1,\"type\":\"expense\",\"amount\":5000,\"description\":\"Courses\",\"transaction_date\":\"2025-04-25\",\"source\":\"manual\"}" }
      }
    },
    {
      "name": "7. Get Wallet",
      "request": { "method": "GET", "header": [{ "key": "Authorization", "value": "Bearer {{token}}" }], "url": "{{base_url}}/api/wallets/1" }
    },
    {
      "name": "8. Create Budget",
      "request": {
        "method": "POST",
        "header": [{ "key": "Authorization", "value": "Bearer {{token}}" }, { "key": "Content-Type", "value": "application/json" }],
        "url": "{{base_url}}/api/budgets",
        "body": { "mode": "raw", "raw": "{\"category_id\":1,\"amount\":20000,\"period\":\"monthly\",\"start_date\":\"2025-04-01\",\"end_date\":\"2025-04-30\",\"is_active\":true}" }
      }
    },
    {
      "name": "9. Dashboard",
      "request": { "method": "GET", "header": [{ "key": "Authorization", "value": "Bearer {{token}}" }], "url": "{{base_url}}/api/dashboard" }
    },
    {
      "name": "10. Logout",
      "request": { "method": "POST", "header": [{ "key": "Authorization", "value": "Bearer {{token}}" }], "url": "{{base_url}}/api/logout" }
    }
  ]
}
```

**Import** : Postman → Import → Upload Files → sélectionne les deux fichiers JSON.

---

## 8. Résumé des Points Vérifiés

- [x] Migrations et modèles cohérents
- [x] Relations Eloquent définies (User, Wallet, Category, Transaction, Budget, ParsedSms)
- [x] Hashage des mots de passe via cast `hashed`
- [x] Création automatique du wallet "Principal" à l'inscription
- [x] Routes API protégées par `auth:sanctum`
- [x] Vérification de propriété (`user_id`) dans tous les contrôleurs
- [x] Validation des requêtes (Form Requests) avec vérification d'appartenance
- [x] Recalcul automatique des soldes et des budgets
- [x] Protection contre la suppression de wallets/catégories liés
- [x] Tous les tests automatisés passent (11 tests, 66 assertions)
