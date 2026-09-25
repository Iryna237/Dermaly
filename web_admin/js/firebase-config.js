// Configuration Firebase — reprise de lib/firebase_options.dart (cible web).
//
// Ces clés sont PUBLIQUES par conception : le SDK web les expose forcément.
// La sécurité ne vient pas de leur secret mais des Firestore Security Rules.
// Voir README.md § Règles Firestore.

import { initializeApp } from 'https://www.gstatic.com/firebasejs/12.0.0/firebase-app.js';
import { getAuth } from 'https://www.gstatic.com/firebasejs/12.0.0/firebase-auth.js';
import { getFirestore } from 'https://www.gstatic.com/firebasejs/12.0.0/firebase-firestore.js';

const firebaseConfig = {
  apiKey: 'AIzaSyA_0SPJ131uxXKe7Ts8Epsp927sJ6sBsKc',
  authDomain: 'dermaly-65610.firebaseapp.com',
  projectId: 'dermaly-65610',
  storageBucket: 'dermaly-65610.firebasestorage.app',
  messagingSenderId: '218878146050',
  appId: '1:218878146050:web:fa21f80dde04b59080191b',
  measurementId: 'G-V2Y8LD88JK',
};

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
