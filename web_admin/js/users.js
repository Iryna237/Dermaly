// Table des utilisateurs, branchée en temps réel sur la collection `users`.
//
// Portage de AdminUsersTab (lib/admin_dash.dart:455). Le changement de statut
// reprend _updateStatus() : un simple update du champ `status`.

import { db } from './firebase-config.js';
import {
  collection,
  doc,
  onSnapshot,
  updateDoc,
} from 'https://www.gstatic.com/firebasejs/12.0.0/firebase-firestore.js';
import { requireAdmin, wireLogout } from './guard.js';

const tbody = document.getElementById('users-body');
const countEl = document.getElementById('count');
const errorEl = document.getElementById('users-error');
const toastEl = document.getElementById('users-toast');
const searchEl = document.getElementById('search');
const roleEl = document.getElementById('filter-role');
const statusEl = document.getElementById('filter-status');

const ROLES = {
  client: { label: 'Client', icon: 'bi-person-fill' },
  dermatologist: { label: 'Dermatologue', icon: 'bi-clipboard2-pulse-fill' },
  admin: { label: 'Admin', icon: 'bi-shield-lock-fill' },
};
const STATUSES = {
  accepted: { label: 'Accepté', bg: 'success' },
  pending: { label: 'En attente', bg: 'warning' },
  rejected: { label: 'Rejeté', bg: 'danger' },
};

/** Cache local de la collection : les filtres travaillent dessus, sans requête. */
let users = [];

const { user: currentUser } = await requireAdmin();
wireLogout();

onSnapshot(
  collection(db, 'users'),
  (snap) => {
    users = snap.docs.map((d) => ({ id: d.id, ...(d.data() ?? {}) }));
    render();
  },
  (err) => {
    console.error(err);
    errorEl.textContent = `Lecture impossible : ${err.message}`;
    errorEl.classList.remove('d-none');
  },
);

[searchEl, roleEl, statusEl].forEach((el) => el.addEventListener('input', render));

function render() {
  const term = searchEl.value.trim().toLowerCase();
  const role = roleEl.value;
  const status = statusEl.value;

  const rows = users
    .filter((u) => !role || u.role === role)
    .filter((u) => !status || (u.status ?? 'accepted') === status)
    .filter((u) => {
      if (!term) return true;
      return `${u.fullName ?? ''} ${u.email ?? ''}`.toLowerCase().includes(term);
    })
    .sort((a, b) => (a.fullName ?? '').localeCompare(b.fullName ?? '', 'fr'));

  countEl.textContent = `(${rows.length}${rows.length !== users.length ? ` sur ${users.length}` : ''})`;

  if (rows.length === 0) {
    tbody.innerHTML = `<tr><td colspan="4" class="text-center text-secondary py-4">
      <i class="bi bi-inbox fs-4 d-block mb-2"></i>Aucun utilisateur ne correspond.</td></tr>`;
    return;
  }

  tbody.innerHTML = rows.map(rowHtml).join('');
  tbody.querySelectorAll('[data-action]').forEach((btn) => {
    btn.addEventListener('click', () => setStatus(btn.dataset.uid, btn.dataset.action));
  });
}

function rowHtml(user) {
  const name = user.fullName || 'Utilisateur';
  const status = user.status ?? 'accepted';
  const role = ROLES[user.role] ?? { label: user.role || 'inconnu', icon: 'bi-question-circle' };
  const badge = STATUSES[status] ?? { label: status, bg: 'secondary' };
  const isSelf = user.id === currentUser.uid;

  // Les actions ne concernent que les demandes de dermatologues en attente,
  // comme dans AdminRequestsTab.
  const actions = user.role === 'dermatologist' && status === 'pending'
    ? `<button class="btn btn-sm btn-outline-danger me-1" data-action="rejected" data-uid="${user.id}">Rejeter</button>
       <button class="btn btn-sm btn-success" data-action="accepted" data-uid="${user.id}">Accepter</button>`
    : '<span class="text-secondary small">—</span>';

  return `
    <tr>
      <td>
        <div class="d-flex align-items-center gap-2">
          <div class="avatar">${esc(name.charAt(0).toUpperCase())}</div>
          <div class="text-truncate">
            <div class="fw-semibold text-truncate">${esc(name)}${isSelf ? ' <span class="text-secondary fw-normal small">(vous)</span>' : ''}</div>
            <div class="text-secondary small text-truncate">${esc(user.email ?? '')}</div>
          </div>
        </div>
      </td>
      <td><span class="badge badge-soft rounded-pill text-bg-light"><i class="bi ${role.icon} me-1"></i>${esc(role.label)}</span></td>
      <td><span class="badge badge-soft rounded-pill text-bg-${badge.bg}">${esc(badge.label)}</span></td>
      <td class="text-end text-nowrap">${actions}</td>
    </tr>`;
}

async function setStatus(uid, status) {
  try {
    await updateDoc(doc(db, 'users', uid), { status });
    flash(`Statut mis à jour : ${STATUSES[status]?.label ?? status}.`);
  } catch (err) {
    console.error(err);
    errorEl.textContent = `Mise à jour refusée : ${err.message}`;
    errorEl.classList.remove('d-none');
  }
}

function flash(message) {
  toastEl.textContent = message;
  toastEl.classList.remove('d-none');
  setTimeout(() => toastEl.classList.add('d-none'), 3000);
}

/** Les noms et emails viennent des utilisateurs : jamais injectés bruts. */
function esc(value) {
  return String(value).replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));
}
