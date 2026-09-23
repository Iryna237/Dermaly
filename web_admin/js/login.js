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
  forbidden: 'This account does not have administrator access.',
  rules: 'Profile unreadable. Check your Firestore Security Rules.',
};
const reason = new URLSearchParams(window.location.search).get('reason');
if (reason && REASONS[reason]) showError(REASONS[reason]);

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  hideError();

  const email = document.getElementById('email').value.trim();
  const password = document.getElementById('password').value;
  if (!email || !password) return showError('Enter your email and password.');

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
      return 'Invalid email format.';
    case 'auth/user-disabled':
      return 'This user account has been disabled.';
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
      return 'Incorrect email or password.';
    case 'auth/too-many-requests':
      return 'Too many attempts. Try again in a few minutes.';
    case 'auth/network-request-failed':
      return 'Network connection failed.';
    case 'permission-denied':
      return REASONS.rules;
    default:
      console.error(err);
      return 'Login failed. Please try again.';
  }
}

function setBusy(busy) {
  submitBtn.disabled = busy;
  spinner.classList.toggle('d-none', !busy);
  submitLabel.textContent = busy ? 'Logging in…' : 'Log In';
}

function showError(message) {
  alertBox.textContent = message;
  alertBox.classList.remove('d-none');
}

function hideError() {
  alertBox.classList.add('d-none');
}
