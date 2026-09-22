// Demandes de vérification des dermatologues.
//
// Portage de AdminRequestsTab (lib/admin_dash.dart:222) : mêmes champs,
// même requête (role == 'dermatologist' && status == 'pending'), et le même
// double format de document — professionalDocBase64 en priorité, sinon
// professionalDocUrl.

import { db } from './firebase-config.js';
import {
  collection,
  doc,
  onSnapshot,
  query,
  updateDoc,
  where,
} from 'https://www.gstatic.com/firebasejs/12.0.0/firebase-firestore.js';
import { requireAdmin, wireLogout } from './guard.js';

const listEl = document.getElementById('requests');
const errorEl = document.getElementById('requests-error');
const toastEl = document.getElementById('requests-toast');
const modalEl = document.getElementById('doc-modal');
const modalBody = document.getElementById('doc-modal-body');
const modalTitle = document.getElementById('doc-modal-title');
const modal = new bootstrap.Modal(modalEl);

/** Cache local, pour retrouver un document au clic sans relire Firestore. */
let requests = [];

await requireAdmin();
wireLogout();

// Requête à deux égalités : Firestore la sert par intersection des index
// simples, aucun index composite à créer.
const pendingQuery = query(
  collection(db, 'users'),
  where('role', '==', 'dermatologist'),
  where('status', '==', 'pending'),
);

onSnapshot(
  pendingQuery,
  (snap) => {
    requests = snap.docs.map((d) => ({ id: d.id, ...(d.data() ?? {}) }));
    render();
  },
  (err) => {
    console.error(err);
    errorEl.textContent = `Lecture impossible : ${err.message}`;
    errorEl.classList.remove('d-none');
  },
);

function render() {
  const badge = document.querySelector('[data-pending-count]');
  if (badge) {
    badge.textContent = requests.length;
    badge.classList.toggle('d-none', requests.length === 0);
  }

  if (requests.length === 0) {
    listEl.innerHTML = `
      <div class="col-12">
        <div class="card"><div class="card-body text-center py-5">
          <i class="bi bi-check-circle text-success" style="font-size:2.5rem"></i>
          <p class="text-secondary mt-3 mb-0">Aucune demande en attente.</p>
        </div></div>
      </div>`;
    return;
  }

  listEl.innerHTML = requests.map(cardHtml).join('');

  listEl.querySelectorAll('[data-status]').forEach((btn) => {
    btn.addEventListener('click', () => setStatus(btn.dataset.uid, btn.dataset.status, btn));
  });
  listEl.querySelectorAll('[data-view-doc]').forEach((btn) => {
    btn.addEventListener('click', () => showDocument(btn.dataset.viewDoc));
  });
}

function cardHtml(req) {
  const name = req.fullName || 'Dermatologue';
  const media = resolveDocument(req);

  return `
    <div class="col-12 col-xl-6">
      <div class="card h-100">
        <div class="card-body">

          <div class="d-flex align-items-center gap-3">
            <div class="avatar">${esc(name.charAt(0).toUpperCase())}</div>
            <div class="flex-grow-1 text-truncate">
              <div class="fw-bold text-truncate">${esc(name)}</div>
              <div class="text-secondary small text-truncate">${esc(req.email ?? '')}</div>
            </div>
            <span class="badge badge-soft rounded-pill text-bg-warning">
              <i class="bi bi-hourglass-split me-1"></i>En attente
            </span>
          </div>

          <hr class="my-3">

          <div class="d-flex flex-wrap gap-2 mb-3">
            ${chip('bi-patch-check', `ONMC : ${req.onmcNumber ?? '—'}`)}
            ${chip('bi-geo-alt', req.city || 'Ville inconnue')}
          </div>

          <dl class="row small mb-3">
            <dt class="col-5 col-sm-4 text-secondary fw-normal">Diplôme</dt>
            <dd class="col-7 col-sm-8 mb-1">${esc(req.degree ?? '—')}</dd>
            <dt class="col-5 col-sm-4 text-secondary fw-normal">Établissement</dt>
            <dd class="col-7 col-sm-8 mb-0">${esc(req.establishment ?? '—')}</dd>
          </dl>

          ${documentPreview(req.id, media)}

          <div class="d-flex gap-2 mt-3">
            <button class="btn btn-outline-danger flex-fill" data-status="rejected" data-uid="${req.id}">
              Rejeter
            </button>
            <button class="btn btn-success flex-fill" data-status="accepted" data-uid="${req.id}">
              Accepter et vérifier
            </button>
          </div>

        </div>
      </div>
    </div>`;
}

function chip(icon, text) {
  return `<span class="badge badge-soft rounded-pill"
    style="background: var(--soft-purple); color: var(--dark-purple)">
    <i class="bi ${icon} me-1 text-brand"></i>${esc(text)}</span>`;
}

function documentPreview(uid, media) {
  if (!media) {
    return '<div class="text-secondary small fst-italic">Aucun document fourni.</div>';
  }
  if (media.kind === 'pdf') {
    return `<button class="btn btn-light w-100 text-start border" data-view-doc="${uid}">
      <i class="bi bi-file-earmark-pdf text-danger me-2"></i>Ouvrir le document (PDF)</button>`;
  }
  return `<button class="btn p-0 border-0 w-100" data-view-doc="${uid}" title="Agrandir">
    <img src="${media.src}" alt="Document professionnel"
         class="w-100 rounded" style="height:140px; object-fit:cover; cursor:zoom-in">
  </button>`;
}

/**
 * Résout le document à afficher.
 * Le base64 stocké en base est nu (sans en-tête `data:`), il faut donc
 * deviner le type à la signature pour construire une data-URI valide.
 */
function resolveDocument(req) {
  const b64 = req.professionalDocBase64;
  if (typeof b64 === 'string' && b64.length > 0) {
    if (b64.startsWith('data:')) {
      return { src: b64, kind: b64.startsWith('data:application/pdf') ? 'pdf' : 'image' };
    }
    const mime = sniffMime(b64);
    return { src: `data:${mime};base64,${b64}`, kind: mime === 'application/pdf' ? 'pdf' : 'image' };
  }

  const url = req.professionalDocUrl;
  if (typeof url === 'string' && url.length > 0) {
    return { src: url, kind: /\.pdf(\?|$)/i.test(url) ? 'pdf' : 'image' };
  }
  return null;
}

/** Signature du contenu, lue sur les premiers caractères du base64. */
function sniffMime(b64) {
  if (b64.startsWith('/9j/')) return 'image/jpeg';
  if (b64.startsWith('iVBORw0KGgo')) return 'image/png';
  if (b64.startsWith('R0lGOD')) return 'image/gif';
  if (b64.startsWith('UklGR')) return 'image/webp';
  if (b64.startsWith('JVBER')) return 'application/pdf';
  return 'image/jpeg'; // Format historique de l'app mobile.
}

function showDocument(uid) {
  const req = requests.find((r) => r.id === uid);
  const media = req && resolveDocument(req);
  if (!media) return;

  modalTitle.textContent = `Document — ${req.fullName || 'Dermatologue'}`;
  modalBody.innerHTML = media.kind === 'pdf'
    ? `<iframe src="${media.src}" title="Document professionnel"
         style="width:100%; height:75vh; border:0"></iframe>`
    : `<img src="${media.src}" alt="Document professionnel" class="img-fluid">`;
  modal.show();
}

async function setStatus(uid, status, btn) {
  const siblings = btn.parentElement.querySelectorAll('button');
  siblings.forEach((b) => (b.disabled = true));

  try {
    await updateDoc(doc(db, 'users', uid), { status });
    // Pas de retrait manuel : la requête filtre sur status == 'pending',
    // onSnapshot fait disparaître la carte tout seul.
    flash(status === 'accepted' ? 'Dermatologue vérifié.' : 'Demande rejetée.');
  } catch (err) {
    console.error(err);
    siblings.forEach((b) => (b.disabled = false));
    errorEl.textContent = `Mise à jour refusée : ${err.message}`;
    errorEl.classList.remove('d-none');
  }
}

function flash(message) {
  toastEl.textContent = message;
  toastEl.classList.remove('d-none');
  setTimeout(() => toastEl.classList.add('d-none'), 3000);
}

/** Les champs viennent du formulaire d'inscription : jamais injectés bruts. */
function esc(value) {
  return String(value).replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));
}
