# Audit technique — Détection SMS / notifications Android (FinanceWise)

**Date :** 2026-05-12  
**Périmètre :** `financewise_flutter/android/*`, services Dart SMS/offline, API Laravel inchangée.

---

## 1. Permissions Android

| Permission | Manifest | Runtime | Rôle |
|------------|----------|---------|------|
| `INTERNET` | Oui | — | API Laravel |
| `POST_NOTIFICATIONS` | Oui | API 33+ (`MainActivity`) | Actions « Ajouter / Ignorer » sur la notif SMS |
| `RECEIVE_SMS` / `READ_SMS` | Oui | M+ (`MainActivity` + `permission_handler` côté Flutter) | Réception `SMS_RECEIVED` |
| `READ`/`WRITE_EXTERNAL_STORAGE` | Oui | Legacy | Déjà présent (hors périmètre détection) |
| `BIND_NOTIFICATION_LISTENER_SERVICE` | **Non** en `<uses-permission>` | Réglage utilisateur | Réservé au **service** système (listener) — ne pas dupliquer en uses-permission |

---

## 2. Receivers Android

| Composant | `exported` | Intent |
|-----------|------------|--------|
| `SmsReceiver` | `true` (obligatoire pour SMS système) | `android.provider.Telephony.SMS_RECEIVED` (priorité 999) |
| `SmsActionReceiver` | `false` | PendingIntent **explicites** internes (`ACTION_*`) — Android 12+ OK |

---

## 3. MethodChannel Flutter ↔ Kotlin

- Canal : `com.example.financewise_flutter/sms`
- Attach : `MainActivity.configureFlutterEngine` → `SmsReceiver` + `SmsActionReceiver`
- Detach : `MainActivity.onDestroy` → `setMethodChannel(null)` (évite fuites / invocations sur engine mort)
- Méthodes Dart → natif : `requestSmsPermission`, `checkSmsPermission`, `requestNotificationPermission`, `checkNotificationPermission`, `getPendingSms`, `clearPendingSms`
- Natif → Dart : `onSmsReceived`, `onSmsActionAdd`, `onBankNotification` (listener notifications)

---

## 4. Compatibilité Android 12 / 13 / 14

- **PendingIntent** : `FLAG_IMMUTABLE` (requis API 31+)
- **Notifications** : canal créé à la volée ; `POST_NOTIFICATIONS` demandé sur API 33+
- **Receivers** : attribut `exported` explicite sur les composants concernés

---

## 5. Restrictions background

- `SMS_RECEIVED` est un broadcast **temps réel** ; pas de `FOREGROUND_SERVICE` requis pour la seule réception SMS.
- Si l’utilisateur **force-stop** l’app, les receivers peuvent ne plus livrer jusqu’au prochain lancement (comportement OEM / Android).

---

## 6. SMS — permissions runtime

- Vérification `RECEIVE_SMS` dans `SmsReceiver.onReceive` avant parsing (log `[SMS_RECEIVED]` si refus).
- `MainActivity` redemande les permissions au démarrage si besoin.

---

## 7. Notifications — permissions runtime

- `POST_NOTIFICATIONS` (API 33+) pour afficher la notification « Transaction détectée » avec actions.
- Distinct de l’**accès aux notifications** (listener) : activation dans **Paramètres → Notifications → Accès aux notifications**.

---

## 8. `exported=true` obligatoire

- Uniquement pour ce qui doit recevoir des intents **système / framework** : `SmsReceiver`, `MainActivity`, `TransactionNotificationListener`.

---

## 9. BroadcastReceiver — enregistrement

- Déclaratif dans le manifest (pas d’enregistrement dynamique SMS) — comportement stable sur appareils physiques.

---

## 10. Téléphones physiques — causes d’échec identifiées (corrigées)

1. **Handler MethodChannel écrasé** : `SmsNativeService` enregistrait un second `setMethodCallHandler` qui **remplaçait** celui du dashboard et ne gérait qu’un sous-ensemble des méthodes → chaîne Flutter cassée lorsque l’auto-SMS était activée.
2. **Écoute liée au cycle de vie du Dashboard** : en changeant d’onglet, `DashboardScreen` était retiré de l’arbre → `dispose` → `stopListening()` → **plus aucun handler** pour les SMS suivants.
3. **`detectProvider` uniquement sur l’expéditeur** : sur réseaux réels, l’expéditeur est souvent un **code court** sans « wave » / « orange » → filtre Flutter rejetait le SMS **alors que le corps** contenait les mots-clés.
4. **Pending prefs + `user_choice=false`** : à l’ouverture d’app, `PendingSmsService` **effaçait** les SMS en attente au lieu de montrer le dialogue de confirmation.

---

## 11. OEM (Xiaomi, Samsung, Tecno, Infinix, …)

- **Autostart / batterie** : désoptimisation batterie recommandée pour fiabiliser les SMS en arrière-plan.
- **MIUI / HyperOS** : vérifier permissions SMS + « Afficher les notifications » + autostart.
- **Listener notifications** : l’utilisateur doit activer manuellement l’écoute pour chaque constructeur.

---

## 12. Processus tué

- Si le processus Flutter n’existe pas, `MethodChannel` est null : les données sont **persistées** dans `SharedPreferences` (`pending_sms`) puis rejouées à l’ouverture (`PendingSmsService.showPendingSmsDialog` depuis `HomeScreen`).

---

## 13. Proguard / minify

- Pas de règles spécifiques ajoutées ; le code Kotlin SMS est trivial (pas de réflexion). Vérifier les règles Flutter par défaut lors d’un passage `minifyEnabled true`.

---

## 14. Flutter embedding v2

- `flutterEmbedding` meta-data = `2` (inchangé).

---

## 15. Stabilité MethodChannel

- Un seul handler côté Dart : `SmsListenerService`.
- Invocations natives postées sur le **main thread** (`Handler(Looper.getMainLooper())`) depuis `SmsReceiver` / `SmsActionReceiver`.

---

## Bonus : `TransactionNotificationListener`

- Service `NotificationListenerService` avec **whitelist** de packages (Wave, Orange Money, etc.).
- Réutilise le même stockage prefs + `onBankNotification` que le flux SMS.
- Nécessite l’activation utilisateur dans les paramètres système.

---

## Fichiers impactés (résumé)

- Android : `AndroidManifest.xml`, `MainActivity.kt`, `SmsReceiver.kt`, `SmsActionReceiver.kt`, `TransactionNotificationListener.kt`
- Flutter : `home_screen.dart`, `dashboard_screen.dart`, `main.dart`, `sms_listener_service.dart`, `sms_native_service.dart`, `pending_sms_service.dart`, `auto_transaction_service.dart`, `permission_service.dart`, `sms_confirmation_dialog.dart`
