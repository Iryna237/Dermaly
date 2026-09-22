// Connexion admin.
//
// Même contrat que lib/pages/auth/login.dart : on authentifie, on lit
// users/{uid}, et seul role === 'admin' donne accès au dashboard.

import { auth, db } from './firebase-config.js';
import {
  signInWithEmailAndPassword,
  signOut,
} from 'https://www.gstatic.com/firebasejs/12.0.0/firebase-auth.js';
import { doc, getDoc } from 'https://www.gstatic.com/firebasejs/12.0.0/firebase-firestore.js';

const form = document.getElementById('login-form');
const alertBox = document.getElementById('alert');
const submitBtn = document.getElementById('submit-btn');
const spinner = document.getElementById('spinner');
const submitLabel = document.getElementById('submit-label');

// Message hérité d'une redirection de guard.js.
const REASONS = {
  forbidden: "Ce compte n'a pas les droits administrateur.",
  rules: 'Profil illisible. Vérifiez les Security Rules Firestore.',
};
const reason = new URLSearchParams(window.location.search).get('reason');
if (reason && REASONS[reason]) showError(REASONS[reason]);

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  hideError();

  const email = document.getElementById('email').value.trim();
  const password = document.getElementById('password').value;
  if (!email || !password) return showError('Renseignez votre email et votre mot de passe.');

  setBusy(true);
  try {
    const { user } = await signInWithEmailAndPassword(auth, email, password);
    const snap = await getDoc(doc(db, 'users', user.uid));

    if (!snap.exists() || snap.data().role !== 'admin') {
      await signOut(auth);
      return showError(REASONS.forbidden);
    }

    window.location.replace('dashboard.html');
  } catch (err) {
    showError(messageFor(err));
  } finally {
    setBusy(false);
  }
});

function messageFor(err) {
  switch (err?.code) {
    case 'auth/invalid-email':
      return 'Adresse email invalide.';
    case 'auth/user-disabled':
      return 'Ce compte a été désactivé.';
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
      return 'Email ou mot de passe incorrect.';
    case 'auth/too-many-requests':
      return 'Trop de tentatives. Réessayez dans quelques minutes.';
    case 'auth/network-request-failed':
      return 'Connexion réseau impossible.';
    case 'permission-denied':
      return REASONS.rules;
    default:
      console.error(err);
      return 'Connexion impossible. Réessayez.';
  }
}

function setBusy(busy) {
  submitBtn.disabled = busy;
  spinner.classList.toggle('d-none', !busy);
  submitLabel.textContent = busy ? 'Connexion…' : 'Se connecter';
}

function showError(message) {
  alertBox.textContent = message;
  alertBox.classList.remove('d-none');
}

function hideError() {
  alertBox.classList.add('d-none');
}
