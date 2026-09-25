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
seules les Security Rules protègent réellement les données. Il faut autoriser
un admin à lire toute la collection `users` et à modifier `status` :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAdmin() {
      return request.auth != null
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    match /users/{uid} {
      allow read: if request.auth != null && (request.auth.uid == uid || isAdmin());
      allow update: if isAdmin() || request.auth.uid == uid;
    }
  }
}
```

À adapter à vos règles existantes — celles-ci sont un point de départ, pas un
fichier à copier tel quel par-dessus le vôtre.

> Le `get()` dans `isAdmin()` coûte une lecture par requête. Pour s'en passer,
> migrer le rôle vers un **custom claim** Auth (`request.auth.token.role == 'admin'`),
> posé par une Cloud Function.

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
