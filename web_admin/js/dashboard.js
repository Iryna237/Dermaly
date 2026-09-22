// Vue d'ensemble : compteurs temps réel sur la collection `users`.
//
// Portage de AdminOverviewTab (lib/admin_dash.dart:104) — même logique de
// comptage, même découpage par rôle et statut. onSnapshot remplace StreamBuilder.

import { db } from './firebase-config.js';
import { collection, onSnapshot } from 'https://www.gstatic.com/firebasejs/12.0.0/firebase-firestore.js';
import { requireAdmin, wireLogout } from './guard.js';

const statsEl = document.getElementById('stats');
const errorEl = document.getElementById('stats-error');

const CARDS = [
  { key: 'clients', label: 'Clients', icon: 'bi-person-fill', color: '#0d6efd' },
  { key: 'doctors', label: 'Dermatologues actifs', icon: 'bi-clipboard2-pulse-fill', color: '#198754' },
  { key: 'pending', label: 'Demandes en attente', icon: 'bi-hourglass-split', color: '#fd7e14' },
  { key: 'admins', label: 'Administrateurs', icon: 'bi-shield-lock-fill', color: '#9371E1' },
];

await requireAdmin();
wireLogout();

onSnapshot(
  collection(db, 'users'),
  (snap) => {
    const counts = { clients: 0, doctors: 0, pending: 0, admins: 0 };

    snap.forEach((docSnap) => {
      const data = docSnap.data() ?? {};
      switch (data.role) {
        case 'client':
          counts.clients++;
          break;
        case 'dermatologist':
          if (data.status === 'accepted') counts.doctors++;
          if (data.status === 'pending') counts.pending++;
          break;
        case 'admin':
          counts.admins++;
          break;
      }
    });

    render(counts);
  },
  (err) => {
    console.error(err);
    errorEl.textContent = `Lecture impossible : ${err.message}`;
    errorEl.classList.remove('d-none');
  },
);

function render(counts) {
  statsEl.innerHTML = CARDS.map((card) => `
    <div class="col-12 col-sm-6 col-xl-3">
      <div class="card h-100">
        <div class="card-body d-flex align-items-center gap-3">
          <div class="stat-icon" style="background:${card.color}1a; color:${card.color}">
            <i class="bi ${card.icon}"></i>
          </div>
          <div>
            <div class="stat-label">${card.label}</div>
            <div class="stat-value">${counts[card.key]}</div>
          </div>
        </div>
      </div>
    </div>
  `).join('');
}
