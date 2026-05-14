# Tests sur appareil réel — Détection SMS / notifications (FinanceWise)

## Prérequis

- Téléphone Android **12+** (idéalement 13 ou 14) avec carte SIM ou SMS de test.
- USB debugging activé, `adb` installé.
- Backend Laravel joignable depuis le téléphone (Wi‑Fi / tunnel / IP LAN).

---

## 1. Logs filtrés (adb)

```bash
adb logcat -s FinanceWise/SmsReceiver FinanceWise/SmsActionReceiver FinanceWise/MainActivity FinanceWise/NotifListener flutter:V
```

Chaîne attendue pour un SMS Wave / Orange :

1. `[SMS_RECEIVED]` (Kotlin `SmsReceiver`)
2. `[SMS_PARSED]`
3. `[TRANSACTION_DETECTED] true`
4. `[SMS_SENT_TO_FLUTTER] onSmsReceived invoked` **ou** message « channel null » si app tuée (normal → prefs).
5. Côté Flutter (via `Logger` / console) : `[FLUTTER_SMS_RECEIVED]`, `[TRANSACTION_DETECTED]`, éventuellement `[SYNC]` / `[OFFLINE_QUEUE]`.

---

## 2. Permissions

1. Désinstaller/réinstaller l’app pour réinitialiser les prompts.
2. Au premier lancement **Home** : accepter **SMS** et **Notifications** (Android 13+).
3. Si refus permanent : Paramètres → Apps → FinanceWise → Autorisations → activer SMS + Notifications.

**Listener notifications (bonus)**  
Paramètres → Notifications → **Accès aux notifications** → activer **FinanceWise**.

---

## 3. Scénario SMS (app au premier plan)

1. Ouvrir l’app, rester sur l’onglet **Transactions** ou **Wallets** (pas besoin d’être sur Dashboard).
2. Envoyer un SMS de test (ou faire envoyer par un service) avec corps contenant **Wave** / **Orange** + montant **FCFA** / **XOF**.
3. Vérifier : notification Android « Transaction détectée » + dialogue Flutter OU snackbar selon filtre.

---

## 4. Scénario SMS (app en arrière-plan / écran éteint)

1. Mettre l’app en arrière-plan.
2. Recevoir un SMS pertinent.
3. Vérifier la **notification** système.
4. Ouvrir l’app depuis la notif (contenu) ou bouton **Ajouter**.
5. Vérifier logs `[SMS_SENT_TO_FLUTTER]` ou, si engine mort, ouverture app puis `[FLUTTER_SMS_RECEIVED]` via prefs.

---

## 5. Android 12 / 13 / 14 — check-list

| Test | 12 | 13 | 14 |
|------|----|----|-----|
| Permission SMS runtime | ✓ | ✓ | ✓ |
| POST_NOTIFICATIONS | N/A | ✓ | ✓ |
| Actions notif (Ajouter / Ignorer) | ✓ | ✓ | ✓ |
| PendingIntent IMMUTABLE | ✓ | ✓ | ✓ |

---

## 6. Constructeurs (indications)

### Samsung

- Paramètres → Apps → FinanceWise → **Batterie** → non restreint / « Autoriser en arrière-plan ».

### Xiaomi / Redmi (MIUI)

- Sécurité → **Autostart** pour FinanceWise.  
- Batterie → **Sans restrictions**.

### Tecno / Infinix / Transsion

- Phone Master / Game Mode : désactiver restriction pour FinanceWise.  
- Vérifier **Autostart** si présent.

---

## 7. Commandes adb utiles

```bash
adb shell dumpsys package com.example.financewise_flutter | findstr /i permission
adb shell cmd notification allow_listener com.example.financewise_flutter/.TransactionNotificationListener
```

(La seconde peut être refusée selon ROM ; l’utilisateur doit souvent activer via UI.)

---

## 8. Validation finale

- [ ] SMS reçu → log `[SMS_RECEIVED]` puis `[SMS_PARSED]`
- [ ] Flutter reçoit → `[FLUTTER_SMS_RECEIVED]`
- [ ] Dialogue confirmation s’affiche (app ouverte, filtre OK)
- [ ] Création transaction → `[SYNC]` ou `[OFFLINE_QUEUE]` si hors ligne
- [ ] Changement d’onglet : SMS suivants **toujours** reçus (handler sur `HomeScreen`)
- [ ] Auto-transaction activée : pas de régression sur le dialogue (handler unique)

---

## 9. Limites connues

- **NotificationListener** : dépend des **packages** réels sur l’appareil ; la whitelist dans `TransactionNotificationListener.kt` peut nécessiter des ajustements régionaux.
- **SMS** : opérateurs / formats non couverts par `SmsParserService` peuvent ne pas produire de transaction parsée malgré une détection native.
