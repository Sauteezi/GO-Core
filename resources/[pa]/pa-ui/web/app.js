const app = document.getElementById('app');
const statusEl = document.getElementById('status');
const characterListEl = document.getElementById('character-list');
const spawnListEl = document.getElementById('spawn-list');
const createForm = document.getElementById('create-form');

const toastContainer = document.getElementById('toast-container');
const modalBackdrop = document.getElementById('modal-backdrop');
const modalTitle = document.getElementById('modal-title');
const modalMessage = document.getElementById('modal-message');
const modalCancel = document.getElementById('modal-cancel');
const modalConfirm = document.getElementById('modal-confirm');

const promptBackdrop = document.getElementById('prompt-backdrop');
const promptText = document.getElementById('prompt-text');
const promptInput = document.getElementById('prompt-input');
const promptCancel = document.getElementById('prompt-cancel');
const promptSubmit = document.getElementById('prompt-submit');

const progressEl = document.getElementById('progress');
const progressFill = document.getElementById('progress-fill');
const progressLabel = document.getElementById('progress-label');
const hintEl = document.getElementById('hint');

let pendingConfirm = null;
let pendingPromptKey = null;
let progressTimer = null;
let hintTimer = null;

const state = { characters: [], spawns: [], selectedCharId: null };

const nui = (event, data = {}) => fetch(`https://${GetParentResourceName()}/${event}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
});

function setStatus(text) { statusEl.textContent = text; }

function showToast(payload = {}) {
  const type = payload.type || 'info';
  const title = payload.title || 'Port Aurora';
  const message = payload.message || '';
  const duration = Number(payload.duration || 4000);

  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `<h4>${title}</h4><p>${message}</p>`;
  toastContainer.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    setTimeout(() => toast.remove(), 200);
  }, duration);
}

function openConfirm({ title, message, onConfirm }) {
  pendingConfirm = onConfirm;
  modalTitle.textContent = title || 'Confirm action';
  modalMessage.textContent = message || 'Are you sure?';
  modalBackdrop.classList.remove('hidden');
}

function closeConfirm() {
  pendingConfirm = null;
  modalBackdrop.classList.add('hidden');
}

modalCancel.addEventListener('click', closeConfirm);
modalConfirm.addEventListener('click', () => {
  if (pendingConfirm) pendingConfirm();
  closeConfirm();
});

function openPrompt(payload = {}) {
  pendingPromptKey = payload.key;
  promptText.textContent = payload.text || 'Enter a value';
  promptInput.value = '';
  promptBackdrop.classList.remove('hidden');
  promptInput.focus();
}

function respondPrompt(ok) {
  const key = pendingPromptKey;
  const value = promptInput.value;
  pendingPromptKey = null;
  promptBackdrop.classList.add('hidden');
  nui('promptResponse', { key, ok, value });
}

promptCancel.addEventListener('click', () => respondPrompt(false));
promptSubmit.addEventListener('click', () => respondPrompt(true));
promptInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') respondPrompt(true);
  if (e.key === 'Escape') respondPrompt(false);
});

function showProgress(payload = {}) {
  const duration = Number(payload.duration || 3000);
  progressLabel.textContent = payload.label || 'Working...';
  progressFill.style.width = '0%';
  progressEl.classList.remove('hidden');

  const start = performance.now();
  if (progressTimer) cancelAnimationFrame(progressTimer);

  const tick = (now) => {
    const elapsed = now - start;
    const pct = Math.min(100, (elapsed / duration) * 100);
    progressFill.style.width = `${pct}%`;
    if (pct < 100) {
      progressTimer = requestAnimationFrame(tick);
    } else {
      progressEl.classList.add('hidden');
      progressTimer = null;
    }
  };

  progressTimer = requestAnimationFrame(tick);
}

function showHint(payload = {}) {
  hintEl.textContent = payload.text || 'Press E to interact';
  hintEl.classList.remove('hidden');
  if (hintTimer) clearTimeout(hintTimer);
  hintTimer = setTimeout(() => hintEl.classList.add('hidden'), Number(payload.duration || 3000));
}

function renderCharacters() {
  characterListEl.innerHTML = '';
  if (!state.characters.length) {
    characterListEl.innerHTML = '<p>No characters yet. Create your first one.</p>';
    return;
  }

  state.characters.forEach((character) => {
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `
      <h3>${character.name}</h3>
      <small>Char ID: ${character.charId} • DOB: ${character.dob || 'Unknown'} • Job: ${character.job || 'unemployed'}</small>
      <div class="actions">
        <button data-select="${character.charId}">Select</button>
        <button class="danger" data-delete="${character.charId}">Delete</button>
      </div>
    `;
    characterListEl.appendChild(card);
  });

  characterListEl.querySelectorAll('[data-select]').forEach((button) => {
    button.addEventListener('click', () => {
      state.selectedCharId = Number(button.dataset.select);
      setStatus(`Selected character ${state.selectedCharId}. Pick a spawn point.`);
      showHint({ text: 'Select a spawn point on the right.' });
      nui('selectCharacter', { charId: state.selectedCharId });
    });
  });

  characterListEl.querySelectorAll('[data-delete]').forEach((button) => {
    button.addEventListener('click', () => {
      const charId = Number(button.dataset.delete);
      openConfirm({
        title: 'Delete character',
        message: `Delete character ${charId}? This action cannot be undone.`,
        onConfirm: () => nui('deleteCharacter', { charId, confirm: true }),
      });
    });
  });
}

function renderSpawns() {
  spawnListEl.innerHTML = '';
  state.spawns.forEach((spawn) => {
    const allowed = spawn.allowed !== false;
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `
      <h3>${spawn.label}</h3>
      <small>${spawn.description || ''}</small>
      <button data-spawn="${spawn.id}" ${state.selectedCharId && allowed ? '' : 'disabled'}>${allowed ? 'Spawn Here' : 'Whitelisted'}</button>
    `;
    spawnListEl.appendChild(card);
  });

  spawnListEl.querySelectorAll('[data-spawn]').forEach((button) => {
    button.addEventListener('click', () => {
      if (!state.selectedCharId) {
        setStatus('Select a character first.');
        showToast({ type: 'warn', title: 'Character required', message: 'Select a character before choosing a spawn.' });
        return;
      }
      showProgress({ label: 'Finalizing spawn...', duration: 1800 });
      nui('selectSpawn', { charId: state.selectedCharId, spawnId: button.dataset.spawn });
    });
  });
}

window.addEventListener('message', (event) => {
  const { action, visible, payload } = event.data || {};

  if (action === 'setVisible') {
    app.classList.toggle('hidden', !visible);
    if (visible) nui('requestCharacters');
    return;
  }

  if (action === 'hydrate') {
    state.characters = payload.characters || [];
    state.spawns = payload.spawns || [];
    renderCharacters();
    renderSpawns();
    if (payload.message) setStatus(payload.message);
    return;
  }

  if (action === 'result') {
    if (payload.message) setStatus(payload.message);
    if (payload.refresh) nui('requestCharacters');
    return;
  }

  if (action === 'showToast') return showToast(payload);
  if (action === 'openPrompt') return openPrompt(payload);
  if (action === 'showProgress') return showProgress(payload);
  if (action === 'showHint') return showHint(payload);
});

createForm.addEventListener('submit', (event) => {
  event.preventDefault();
  showProgress({ label: 'Creating character...', duration: 1600 });
  nui('createCharacter', {
    firstName: document.getElementById('firstName').value,
    lastName: document.getElementById('lastName').value,
    dob: document.getElementById('dob').value,
    gender: document.getElementById('gender').value,
    skipTutorial: document.getElementById('skipTutorial').checked,
  });
});
