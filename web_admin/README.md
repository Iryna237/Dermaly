# Dermaly Admin — dashboard web

Console d'administration en HTML + Bootstrap 5 + Firebase JS SDK.
Aucun build, aucun `npm install` : tout passe par CDN.

Elle parle au **même projet Firebase** que l'app Flutter (`dermaly-65610`),
la même collection `users`, les mêmes comptes.

## Lancer en local

Les modules ES et Firebase Auth exigent une vraie origine HTTP.
Ouvrir `index.html` en `file://` **ne marchera pas**.

```bash
python web_admin/serve.py
```

Puis http://localhost:5500 (`localhost` est un domaine autorisé par défaut
dans Firebase Auth).

Ce petit serveur renvoie `Cache-Control: no-store`, sinon le navigateur
garde les modules `.js` en cache et affiche l'ancienne version après
chaque modification.

## Structure

| Fichier | Rôle |
| --- | --- |
| `index.html` / `js/login.js` | Connexion + vérification du rôle admin |
| `dashboard.html` / `js/dashboard.js` | Compteurs temps réel (clients, dermatologues, demandes) |
| `requests.html` / `js/requests.js` | Demandes de dermatologues : dossier, aperçu du document, accept/reject |
| `users.html` / `js/users.js` | Table utilisateurs temps réel, filtres, accept/reject |
| `js/guard.js` | Garde d'accès, identité de l'admin, déconnexion |
| `js/firebase-config.js` | Init Firebase (config reprise de `lib/firebase_options.dart`) |
| `css/style.css` | Palette de `lib/app_colors.dart` appliquée à Bootstrap |

## Règles Firestore

`js/guard.js` masque l'interface aux non-admins, mais c'est **cosmétique** :
seules les Security Rules protègent réellement les données.

Les règles de tout le projet, app mobile et console admin, sont dans
[`firestore.rules`](../firestore.rules) à la racine. Pour la console, elles
autorisent l'admin à lire toute la collection `users` et à modifier le seul
champ `status` des dermatologues. Elles empêchent aussi un compte de se donner
le rôle admin : le compte admin se crée depuis la console Firebase.

```bash
firebase deploy --only firestore:rules
```

> Le `get()` dans `isAdmin()` coûte une lecture par requête. Pour s'en passer,
> migrer le rôle vers un **custom claim** Auth (`request.auth.token.role == 'admin'`),
> posé par une Cloud Function.

## Email du compte admin

« Forgot Password? » envoie le lien à l'email du compte Firebase Auth. Le compte
créé par `lib/tool/seed_admin.dart` utilise `admin@dermascan.com`, une adresse
qui n'est pas à nous : le lien n'arriverait jamais chez l'admin.

Une fois connecté, **Account** (barre latérale) remplace cet email : Firebase
envoie un lien de vérification à la nouvelle adresse, l'email change quand on
l'ouvre, puis on se reconnecte avec. `users/{uid}.email` est réaligné au
chargement suivant de la console.

## Déployer sur Firebase Hosting

Ajouter à `firebase.json` (à la racine du projet) :

```json
"hosting": {
  "public": "web_admin",
  "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
}
```

puis :

```bash
firebase deploy --only hosting
```

Penser à ajouter le domaine de production dans
**Firebase Console → Authentication → Settings → Authorized domains**.
