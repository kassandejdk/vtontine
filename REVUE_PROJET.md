# Revue du projet vTontine

Dernière mise à jour : 2026-08-14
Périmètre : backend Django (`vTontine/`) + application mobile Flutter (`vTontineMobile/`)

---

## 1. Résumé exécutif

| Domaine | État réel |
|---|---|
| Auth (Keycloak) | ✅ Complet et fonctionnel côté backend et mobile |
| Tontines (CRUD, invitations, règles, cycles, chat) | ✅ Complet, le plus abouti du projet |
| Paiements (backend) | ✅ Déclaration + confirmation manuelle, **+ vérification IA** de la preuve, pas de vraie passerelle Mobile Money |
| Paiements (mobile) | ✅ Écran réel, branché sur l'API, avec upload de capture d'écran |
| Notifications | ✅ Fonctionnel des deux côtés, mais 0 test backend dédié |
| Tests automatisés backend | ✅ 65 tests réels, tous passants |
| Tests automatisés mobile | ❌ Toujours aucun (le seul test présent ne compile pas) |
| Sécurité (config) | ⚠️ Plusieurs points à corriger avant toute mise en production (voir §5.1) |
| Scalabilité | ⚠️ Fonctionne bien pour un usage pilote ; plusieurs limites à lever avant une croissance forte (voir §5.2) |

---

## 2. Ce qui a été livré (chronologie de ce projet)

1. **Correction d'environnement** : `.env` manquant recréé, port Postgres et mot de passe alignés sur `docker-compose.yml`, migrations `users`/`tontines`/`paiements` en retard appliquées, secret client Keycloak corrigé (celui codé en dur dans `settings.py` ne correspondait pas au vrai secret configuré côté Keycloak — trouvé et corrigé via l'API admin Keycloak).
2. **Revue complète** du backend et du mobile (voir détail §3 et §4).
3. **Preuve de paiement (capture d'écran)** : champ `piece_jointe` sur `Paiement`, upload multipart côté mobile (`image_picker`), écran paiement entièrement rebranché sur l'API réelle (avant : entièrement factice).
4. **Vérification automatique par IA (Gemini)** : à l'enregistrement d'un paiement avec preuve jointe, extraction du montant et du numéro destinataire via `gemini-2.5-flash`, comparaison au montant attendu et au téléphone du créateur → statut `CONCORDANT` / `DIVERGENT` / `NON_VERIFIABLE`, affiché au membre. Reste une aide à la décision : la confirmation finale demeure manuelle, côté créateur.
5. **Logos réels** Orange Money / Moov Money dans l'écran de paiement (à la place d'icônes génériques).

---

## 3. Backend Django (`vTontine/`)

### 3.1 Vue d'ensemble par app

| App | Endpoints | Tests | Notes |
|---|---|---|---|
| `users` | 11, tous réels | 7 | Keycloak entièrement intégré (appels HTTP réels, vérification de signature JWT) |
| `tontines` | 22, tous réels | 33 | Le plus riche : invitations, règles, cycles/rotation, chat de groupe |
| `paiements` | 4, tous réels | 23 (dont 10 sur la vérification IA) | Pas de passerelle Mobile Money réelle — attestation manuelle + aide IA |
| `notifications` | 3, tous réels | 0 dédié | Comportement vérifié indirectement via les autres apps |

### 3.2 Points morts / dette technique identifiés
- `apps/users/middleware.py` (`KeycloakMiddleware`) : enregistré dans `MIDDLEWARE` mais ne fait rien (no-op complet).
- `djangorestframework_simplejwt` dans `requirements.txt` : jamais utilisé (auth 100% Keycloak).
- `RechercherUserParTelephoneView` dupliquée à l'identique dans `apps/users` et `apps/tontines`.
- `RegisterView` n'a pas de transaction compensatoire : si la création Django échoue après succès Keycloak, le compte Keycloak reste orphelin.

---

## 4. Application mobile (`vTontineMobile/`)

- Toutes les fonctionnalités principales (auth, tontines, notifications, profil, **paiements**) sont désormais branchées sur de vraies données et de vrais appels API.
- Riverpod est déclaré comme architecture mais quasiment inutilisé — tous les écrans utilisent `setState`.
- `test/widget_test.dart` reste le boilerplate par défaut (référence une classe `MyApp` inexistante) — `flutter test` échoue toujours à la compilation.
- Éléments encore inertes dans `profil_screen.dart` : bouton "Changer le mot de passe" (endpoint backend pourtant fonctionnel), toggle "Notifications push" (pas de persistance), icône menu "plus".
- `assets/images/om.png` (censé représenter Orange Money) ne ressemble pas au vrai logo Orange Money — à vérifier/remplacer avant mise en production.
- `wave.png` ajouté mais non utilisé dans l'UI.

---

## 5. Améliorations futures

### 5.1 Sécurité

**À corriger avant toute mise en production réelle :**
1. **Secrets en dur dans `settings.py`** : `SECRET_KEY`, `KEYCLOAK_CONFIG['CLIENT_SECRET']`, `ADMIN_USER`/`ADMIN_PASSWORD` (`admin`/`admin`) ont des valeurs de repli codées en clair dans le code source. Elles ne s'activent que si la variable d'environnement correspondante est absente, mais leur simple présence dans le dépôt est un risque (fuite via `git log`, accès au code). À sortir complètement du code, avec échec explicite au démarrage si absentes en prod.
2. **`DEBUG=True` par défaut** (`.env` actuel) : à passer à `False` en production — sinon les pages d'erreur Django exposent stack traces et variables d'environnement.
3. **`ALLOWED_HOSTS`** vide par défaut (`['']`) et **`CORS_ALLOWED_ORIGINS`** codé en dur sur `localhost` : à configurer avec les vrais domaines de prod, hors code source (env var).
4. **Aucun réglage HTTPS/cookies sécurisés** : `SECURE_SSL_REDIRECT`, `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE`, `SECURE_HSTS_SECONDS` ne sont pas configurés. Nécessaire dès que l'API est exposée publiquement.
5. **Pas de rate limiting** sur les endpoints sensibles (`/auth/login/`, `/auth/register/`) : aujourd'hui rien n'empêche du brute-force sur les mots de passe ou du spam de comptes. DRF propose `DEFAULT_THROTTLE_CLASSES`/`DEFAULT_THROTTLE_RATES` prêts à l'emploi.
6. **`KeycloakMiddleware` no-op** : soit le supprimer (code mort trompeur), soit l'implémenter si une vérification supplémentaire par requête était prévue (ex. révocation de token).
7. **Dépendance morte `djangorestframework_simplejwt`** : à retirer pour réduire la surface d'attaque et la maintenance de sécurité (CVE à suivre sur des libs inutilisées).
8. **Clé API Gemini en clair dans `.env`** : correct pour du développement local, mais en prod elle doit venir d'un gestionnaire de secrets (Vault, AWS Secrets Manager, variables d'env injectées par la CI/CD), jamais d'un fichier sur le serveur.
9. **Données personnelles dans les captures de paiement** : les preuves de paiement contiennent potentiellement des numéros de téléphone et des informations financières, et transitent maintenant par un service tiers (Gemini). À documenter dans une politique de confidentialité (durée de conservation, base légale, information des utilisateurs que l'image est analysée par une IA externe).
10. **Pas d'audit trail explicite** au-delà du journal d'admin Django par défaut : envisager une table d'événements pour les actions sensibles (confirmation/refus de paiement, exclusion de participant) si un litige entre membres doit un jour être arbitré.

### 5.2 Scalabilité

1. **Appel Gemini synchrone dans la requête HTTP** (`PaiementListCreateView.post`) : bloque le worker Django le temps de l'appel réseau (souvent 1 à 3 secondes). Sous charge, ça épuise vite le pool de workers. À déplacer vers une tâche asynchrone (Celery + Redis, ou Django-Q) dès que le volume de paiements grossit — le paiement serait créé immédiatement avec statut `NON_VERIFIE`, et le résultat de la vérification arriverait ensuite (webhook interne / notification).
2. **Stockage média local (`MEDIA_ROOT` sur disque)** : fonctionne pour une seule instance serveur, mais ne scale pas horizontalement (plusieurs instances = fichiers non partagés) et n'est pas durable en cas de perte du serveur. À migrer vers un stockage objet (S3-compatible, ex. AWS S3, Backblaze, MinIO auto-hébergé) via `django-storages`.
3. **Aucune pagination ni throttling** sur les endpoints de liste (`/tontines/`, `/paiements/`, etc.) : ils renvoient l'intégralité du queryset. Correct au stade actuel (peu d'utilisateurs), mais à corriger avant une croissance significative — DRF propose `PageNumberPagination` prête à l'emploi.
4. **Pas de cache** : chaque requête retape la base (ex. `mes-tontines/`, `decouvrir/`). Un cache court (Redis, `django-cacheops` ou simple `cache_page`) sur les endpoints de lecture les plus fréquents réduirait la charge DB à mesure que le nombre d'utilisateurs augmente.
5. **Serveur de développement (`runserver`)** : à ne jamais utiliser en production (le warning Django le rappelle). Prévoir Gunicorn/Uvicorn derrière Nginx, avec plusieurs workers.
6. **Pas de séparation lecture/écriture ni d'index documentés** sur les requêtes à fort volume potentiel (`Paiement`, `Cycle`) : à surveiller avec des index composites si les tontines comptent beaucoup de membres/cycles.
7. **`generer_cycles()` appelé à chaque déclaration de paiement** (`serializers.py`) : idempotent donc pas incorrect, mais recalculer les cycles à chaque paiement plutôt qu'une seule fois (à la création/au changement de statut de la tontine) ajoute une charge évitable à grande échelle.

### 5.3 Fiabilité, tests, exploitation

1. **Tests mobile** : à remettre d'aplomb en priorité — actuellement `flutter test` ne compile même pas. Aucun filet de sécurité côté client.
2. **`apps/notifications`** : aucun test dédié malgré son rôle transverse (déclenché par tontines et paiements).
3. **Pas de CI/CD observée** : aucun pipeline (GitHub Actions, GitLab CI...) ne semble faire tourner les 65 tests backend automatiquement à chaque push. À mettre en place pour éviter les régressions silencieuses — d'autant plus critique maintenant qu'un appel réseau externe (Gemini) est dans le flux de paiement et doit être mocké en CI (déjà fait dans les tests, juste à automatiser l'exécution).
4. **Pas d'observabilité** : aucun suivi d'erreurs (Sentry ou équivalent), pas de logs structurés, pas de métriques. Dès que l'app a de vrais utilisateurs, un échec silencieux de l'extraction IA ou un 500 sur `/api/paiements/` passerait inaperçu.
5. **Pas de stratégie de sauvegarde documentée** pour Postgres et les médias (preuves de paiement, photos de profil) — à définir avant tout usage réel avec de l'argent en jeu, même symbolique.
6. **Robustesse déjà en place à noter positivement** : le module `verification_ia.py` encapsule bien les échecs externes (clé absente, timeout, réponse invalide) sans jamais bloquer l'enregistrement du paiement — bon pattern à répliquer pour toute future intégration tierce.

### 5.4 Produit / dette fonctionnelle restante

1. **Décider formellement de la stratégie de paiement à moyen terme** : rester sur une attestation entre membres (avec l'aide IA actuelle) ou intégrer une vraie API Mobile Money (Orange Money/Moov) pour un mouvement d'argent réellement vérifié côté opérateur. C'est la plus grosse décision produit restante — elle conditionne une partie des points de sécurité/scalabilité ci-dessus.
2. Compléter les actions inertes de `profil_screen.dart` (changement de mot de passe, toggle notifications push).
3. Vérifier/remplacer `assets/images/om.png` (ne ressemble pas au logo Orange Money).
4. Décider si Riverpod devient l'architecture réelle de gestion d'état mobile ou si l'app reste en `setState` (et retirer la dépendance si abandonnée).
5. Mutualiser `RechercherUserParTelephoneView` (dupliquée entre `users` et `tontines`).
6. Ajouter une transaction compensatoire dans `RegisterView` en cas d'échec de création côté Django après succès Keycloak.
