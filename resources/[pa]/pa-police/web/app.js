const app = document.getElementById('app');
const results = document.getElementById('results');
const rosterEl = document.getElementById('roster');

const post = async (event, payload = {}) => {
  await fetch(`https://${GetParentResourceName()}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
};

const jsonPayload = (id) => {
  try {
    return JSON.parse(document.getElementById(id).value || '{}');
  } catch (err) {
    results.textContent = `Invalid JSON in ${id}: ${err.message}`;
    return null;
  }
};

const setResults = (data) => {
  results.textContent = JSON.stringify(data, null, 2);
};

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};

  if (action === 'setVisible') {
    app.classList.toggle('hidden', !data.visible);
  }

  if (action === 'mdtResult') {
    setResults(data);
  }

  if (action === 'setRoster') {
    const roster = data.roster || [];
    rosterEl.innerHTML = roster.map((u) => `<div>${u.callsign} • ${u.status} • grade ${u.grade}</div>`).join('') || 'No duty units.';
  }
});

document.getElementById('closeBtn').addEventListener('click', () => post('police:close'));
document.getElementById('dutyOn').addEventListener('click', () => post('police:setDuty', { onDuty: true }));
document.getElementById('dutyOff').addEventListener('click', () => post('police:setDuty', { onDuty: false }));
document.getElementById('statusBusy').addEventListener('click', () => post('police:status', { status: 'busy' }));
document.getElementById('statusAvail').addEventListener('click', () => post('police:status', { status: 'available' }));

document.getElementById('personLookupBtn').addEventListener('click', () => {
  post('police:lookupPerson', { query: document.getElementById('personQuery').value });
});

document.getElementById('plateLookupBtn').addEventListener('click', () => {
  post('police:lookupPlate', { plate: document.getElementById('plateQuery').value });
});

document.getElementById('citationBtn').addEventListener('click', () => {
  const payload = jsonPayload('citationPayload');
  if (payload) post('police:createCitation', payload);
});

document.getElementById('arrestBtn').addEventListener('click', () => {
  const payload = jsonPayload('arrestPayload');
  if (payload) post('police:processArrest', payload);
});

document.getElementById('reportBtn').addEventListener('click', () => {
  const payload = jsonPayload('reportPayload');
  if (payload) post('police:writeReport', payload);
});

document.getElementById('warrantBtn').addEventListener('click', () => {
  const payload = jsonPayload('warrantPayload');
  if (payload) post('police:addWarrant', payload);
});

document.getElementById('caseBtn').addEventListener('click', () => {
  const payload = jsonPayload('casePayload');
  if (payload) post('police:addCaseNote', payload);
});

document.getElementById('evidenceBtn').addEventListener('click', () => {
  const payload = jsonPayload('evidencePayload');
  if (payload) post('police:collectEvidence', payload);
});
