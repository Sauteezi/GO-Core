const app = document.getElementById('app');
const resultEl = document.getElementById('result');

const post = async (event, payload = {}) => {
  await fetch(`https://${GetParentResourceName()}/${event}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload)
  });
};

const parsePayload = (id) => {
  try { return JSON.parse(document.getElementById(id).value || '{}'); }
  catch (e) { resultEl.textContent = `Invalid JSON (${id}): ${e.message}`; return null; }
};

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};
  if (action === 'setVisible') app.classList.toggle('hidden', !data.visible);
  if (action === 'actionResult') resultEl.textContent = JSON.stringify(data, null, 2);
  if (action === 'injuryUpdated' || action === 'transported' || action === 'revived') {
    resultEl.textContent = JSON.stringify({ action, data }, null, 2);
  }
});

document.getElementById('closeBtn').addEventListener('click', () => post('ems:close'));
document.getElementById('dutyOn').addEventListener('click', () => post('ems:setDuty', { onDuty: true }));
document.getElementById('dutyOff').addEventListener('click', () => post('ems:setDuty', { onDuty: false }));
document.getElementById('reviveBtn').addEventListener('click', () => { const p = parsePayload('revivePayload'); if (p) post('ems:revive', p); });
document.getElementById('transportBtn').addEventListener('click', () => { const p = parsePayload('transportPayload'); if (p) post('ems:transport', p); });
document.getElementById('billBtn').addEventListener('click', () => { const p = parsePayload('billPayload'); if (p) post('ems:bill', p); });
document.getElementById('recordBtn').addEventListener('click', () => { const p = parsePayload('recordPayload'); if (p) post('ems:record', p); });
document.getElementById('callBtn').addEventListener('click', () => { const p = parsePayload('callPayload'); if (p) post('ems:call911', p); });
document.getElementById('cprBtn').addEventListener('click', () => { const p = parsePayload('cprPayload'); if (p) post('ems:cpr', p); });
document.querySelectorAll('[data-injury]').forEach((btn) => {
  btn.addEventListener('click', () => post('ems:setInjury', { injury: btn.dataset.injury }));
});
