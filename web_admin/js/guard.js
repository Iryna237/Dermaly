// Garde d'accès admin.
//
// Équivalent web du routage de lib/pages/auth/login.dart:105 — on lit
// users/{uid}.role et on n'ouvre la page que si role === 'admin'.
//
// NOTE SÉCURITÉ : cette garde est cosmétique. Elle cache l'interface, elle
// ne protège pas les données — n'importe qui peut désactiver le JS. La vraie
// protection, ce sont les Firestore Security Rules (cf. README.md).

import { auth, db } from './firebase-config.js';
import { onAuthStateChanged, signOut } from 'https://www.gstatic.com/firebasejs/12.0.0/firebase-auth.js';
import { doc, getDoc } from 'https://www.gstatic.com/firebasejs/12.0.0/firebase-firestore.js';

/**
 * Bloque le rendu tant que l'utilisateur n'est pas un admin authentifié.
 * Redirige vers le login sinon.
 * @returns {Promise<{user: import('firebase/auth').User, profile: object}>}
 */
export function requireAdmin() {
  return new Promise((resolve) => {
    onAuthStateChanged(auth, async (user) => {
      if (!user) return redirectToLogin();

      let snap;
      try {
        snap = await getDoc(doc(db, 'users', user.uid));
      } catch (err) {
        console.error('Unable to read the admin profile:', err);
        return redirectToLogin('rules');
      }

      const profile = snap.exists() ? snap.data() : null;
      if (profile?.role !== 'admin') {
        await signOut(auth);
        return redirectToLogin('forbidden');
      }

      // Profil admin confirmé : on révèle la page.
      document.body.classList.remove('gated');
      paintIdentity(user, profile);
      resolve({ user, profile });
    });
  });
}

function redirectToLogin(reason) {
  const query = reason ? `?reason=${reason}` : '';
  window.location.replace(`index.html${query}`);
}

/** Remplit l'en-tête (nom + initiale) si les éléments existent. */
function paintIdentity(user, profile) {
  const name = profile.fullName || user.email || 'Admin';
  const nameEl = document.querySelector('[data-admin-name]');
  const initialEl = document.querySelector('[data-admin-initial]');
  if (nameEl) nameEl.textContent = name;
  if (initialEl) initialEl.textContent = name.charAt(0).toUpperCase();
}

/** Branche le bouton de déconnexion présent dans la barre latérale. */
export function wireLogout(selector = '[data-logout]') {
  document.querySelectorAll(selector).forEach((btn) => {
    btn.addEventListener('click', async (event) => {
      event.preventDefault();
      await signOut(auth);
      window.location.replace('index.html');
    });
  });
}
