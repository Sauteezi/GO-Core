const hud = document.getElementById('hud');
const healthEl = document.getElementById('health');
const armorEl = document.getElementById('armor');
const hungerEl = document.getElementById('hunger');
const thirstEl = document.getElementById('thirst');
const stressEl = document.getElementById('stress');
const voiceEl = document.getElementById('voice');
const radioEl = document.getElementById('radio');
const cashEl = document.getElementById('cash');
const bankEl = document.getElementById('bank');

function setLevelClass(el, value, lowIsBad = true) {
  el.classList.remove('good', 'warn', 'bad');
  const v = Number(value) || 0;

  if (lowIsBad) {
    if (v <= 25) el.classList.add('bad');
    else if (v <= 50) el.classList.add('warn');
    else el.classList.add('good');
  } else {
    if (v >= 75) el.classList.add('bad');
    else if (v >= 50) el.classList.add('warn');
    else el.classList.add('good');
  }
}

window.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.action !== 'hud:update') return;

  const p = data.payload || {};

  if (p.visible) hud.classList.remove('hidden');
  else hud.classList.add('hidden');

  healthEl.textContent = Math.max(0, Math.floor(Number(p.health) || 0));
  armorEl.textContent = Math.max(0, Math.floor(Number(p.armor) || 0));
  hungerEl.textContent = Math.max(0, Math.floor(Number(p.hunger) || 0));
  thirstEl.textContent = Math.max(0, Math.floor(Number(p.thirst) || 0));
  stressEl.textContent = Math.max(0, Math.floor(Number(p.stress) || 0));

  setLevelClass(hungerEl, p.hunger, true);
  setLevelClass(thirstEl, p.thirst, true);
  setLevelClass(stressEl, p.stress, false);

  voiceEl.textContent = `Voice: ${p.voice || 'idle'}`;
  radioEl.textContent = `Radio: ${p.radio ? 'on' : 'off'}`;

  cashEl.textContent = Math.floor(Number(p.cash) || 0).toLocaleString();
  bankEl.textContent = Math.floor(Number(p.bank) || 0).toLocaleString();
});
