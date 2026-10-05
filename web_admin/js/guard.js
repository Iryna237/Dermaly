// Garde d'accès admin.
//
// Équivalent web du routage de lib/pages/auth/login.dart:105 — on lit
// users/{uid}.role et on n'ouvre la page que si role === 'admin'.
//
// NOTE SÉCURITÉ : cette garde est cosmétique. Elle cache l'interface, elle
// ne protège pas les données — n'importe qui peut désactiver le JS. La vraie
// protection, ce sont les Firestore Security Rules (cf. README.md).

import { auth, db } from './firebase-config.js';
import {
  EmailAuthProvider,
  onAuthStateChanged,
  reauthenticateWithCredential,
  signOut,
  verifyBeforeUpdateEmail,
} from 'https://www.gstatic.com/firebasejs/12.0.0/firebase-auth.js';
import { doc, getDoc, updateDoc } from 'https://www.gstatic.com/firebasejs/12.0.0/firebase-firestore.js';

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

      // Après un changement d'email validé, Auth a la nouvelle adresse mais
      // pas encore users/{uid} : on les réaligne.
      if (user.email && profile.email !== user.email) {
        updateDoc(snap.ref, { email: user.email })
          .then(() => { profile.email = user.email; })
          .catch((err) => console.warn('Unable to sync the admin email:', err));
      }

      // Profil admin confirmé : on révèle la page.
      document.body.classList.remove('gated');
      paintIdentity(user, profile);
      resolve({ user, profile });
    });
  });
}

// Admin déjà vérifié dans cet onglet : son nom, gardé pour la session.
// Le script en tête de chaque page lit la même clé pour révéler la page sans
// attendre Firebase ; la vérification ci-dessus continue en arrière-plan et
// renvoie au login si la session n'est plus valide.
const VERIFIED_KEY = 'dermaly-admin';

function rememberAdmin(name) {
  try { sessionStorage.setItem(VERIFIED_KEY, name); } catch { /* stockage indisponible */ }
}

function forgetAdmin() {
  try { sessionStorage.removeItem(VERIFIED_KEY); } catch { /* stockage indisponible */ }
}

function rememberedAdmin() {
  try { return sessionStorage.getItem(VERIFIED_KEY); } catch { return null; }
}

// Nom affiché tout de suite, sans le « Admin » provisoire
const remembered = rememberedAdmin();
if (remembered) paintName(remembered);

function redirectToLogin(reason) {
  forgetAdmin();
  const query = reason ? `?reason=${reason}` : '';
  window.location.replace(`index.html${query}`);
}

/** Remplit l'en-tête (nom + initiale) si les éléments existent. */
function paintIdentity(user, profile) {
  const name = profile.fullName || user.email || 'Admin';
  rememberAdmin(name);
  paintName(name);
}

function paintName(name) {
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
      forgetAdmin();
      await signOut(auth);
      window.location.replace('index.html');
    });
  });
}

/**
 * Branche le bouton « Account » : l'admin remplace l'email de son compte.
 *
 * Le lien de « Forgot Password? » part vers l'email du compte Auth. Si c'est
 * une adresse sans vraie boîte derrière, l'admin ne le reçoit jamais. Firebase
 * envoie d'abord un lien de vérification à la nouvelle adresse ; l'email ne
 * change qu'une fois ce lien ouvert.
 */
export function wireAccount(selector = '[data-account]') {
  const buttons = document.querySelectorAll(selector);
  if (!buttons.length) return;

  document.body.insertAdjacentHTML('beforeend', ACCOUNT_MODAL);
  const modalEl = document.getElementById('account-modal');
  const modal = new bootstrap.Modal(modalEl);
  const form = modalEl.querySelector('form');
  const currentEl = modalEl.querySelector('[data-current-email]');
  const emailInput = modalEl.querySelector('#account-email');
  const passwordInput = modalEl.querySelector('#account-password');
  const alertBox = modalEl.querySelector('.alert');
  const submitBtn = modalEl.querySelector('[type=submit]');

  const showAlert = (message, variant) => {
    alertBox.textContent = message;
    alertBox.className = `alert alert-${variant} py-2 small`;
  };

  buttons.forEach((btn) => btn.addEventListener('click', (event) => {
    event.preventDefault();
    form.reset();
    alertBox.className = 'alert d-none';
    currentEl.textContent = auth.currentUser?.email ?? '—';
    modal.show();
  }));
  modalEl.addEventListener('shown.bs.modal', () => emailInput.focus());

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const user = auth.currentUser;
    const newEmail = emailInput.value.trim();
    const password = passwordInput.value;
    if (!user || !newEmail || !password) {
      return showAlert('Enter the new email address and your current password.', 'danger');
    }
    if (newEmail.toLowerCase() === user.email?.toLowerCase()) {
      return showAlert('This is already your account email.', 'danger');
    }

    submitBtn.disabled = true;
    try {
      // Firebase exige une connexion récente pour changer l'email.
      await reauthenticateWithCredential(user, EmailAuthProvider.credential(user.email, password));
      await verifyBeforeUpdateEmail(user, newEmail);
      form.reset();
      showAlert(
        `A verification link was sent to ${newEmail}. Open it to confirm the change, `
          + 'then log in again with this address. Password reset emails will go there.',
        'success',
      );
    } catch (err) {
      showAlert(accountErrorFor(err), 'danger');
    } finally {
      submitBtn.disabled = false;
    }
  });
}

function accountErrorFor(err) {
  switch (err?.code) {
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
      return 'Incorrect current password.';
    case 'auth/invalid-email':
    case 'auth/invalid-new-email':
      return 'Invalid email format.';
    case 'auth/email-already-in-use':
      return 'This email is already used by another account.';
    case 'auth/too-many-requests':
      return 'Too many attempts. Try again in a few minutes.';
    case 'auth/operation-not-allowed':
      return 'Email change is disabled in Firebase Authentication settings.';
    default:
      console.error(err);
      return 'Unable to change the email. Please try again.';
  }
}

const ACCOUNT_MODAL = `
<div class="modal fade" id="account-modal" tabindex="-1" aria-labelledby="account-modal-title" aria-hidden="true">
  <div class="modal-dialog modal-dialog-centered">
    <form class="modal-content" novalidate>
      <div class="modal-header border-0 pb-0">
        <h2 class="modal-title h5 fw-bold" id="account-modal-title">Account email</h2>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
      </div>
      <div class="modal-body">
        <p class="small text-secondary mb-3">
          Password reset links are sent to this address. Use a mailbox you can open.
        </p>
        <p class="small mb-3">Current email: <span class="fw-semibold" data-current-email></span></p>
        <div class="alert d-none"></div>
        <div class="mb-3">
          <label for="account-email" class="form-label small fw-semibold">New email address</label>
          <input type="email" class="form-control" id="account-email" autocomplete="email" required>
        </div>
        <div>
          <label for="account-password" class="form-label small fw-semibold">Current password</label>
          <input type="password" class="form-control" id="account-password" autocomplete="current-password" required>
        </div>
      </div>
      <div class="modal-footer border-0 pt-0">
        <button type="button" class="btn btn-light" data-bs-dismiss="modal">Cancel</button>
        <button type="submit" class="btn btn-primary">Send verification link</button>
      </div>
    </form>
  </div>
</div>`;
