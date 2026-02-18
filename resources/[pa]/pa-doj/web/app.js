const app = document.getElementById('app');
const docketList = document.getElementById('docketList');
let docket = [];

const post = (event, data = {}) => fetch(`https://${GetParentResourceName()}/${event}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
});

const renderDocket = () => {
  docketList.innerHTML = '';
  if (!Array.isArray(docket) || docket.length === 0) {
    docketList.innerHTML = '<div class="case-item">No cases loaded.</div>';
    return;
  }

  for (const c of docket) {
    const el = document.createElement('div');
    el.className = 'case-item';
    el.innerHTML = `
      <strong>#${c.id} - ${c.title || 'DOJ Case'}</strong><br />
      Status: ${c.status || 'draft'}<br />
      Defendant Char: ${c.defendant_char_id || '-'}<br />
      Bail: $${c.bail_amount || 0}<br />
      Reports: ${(c.references?.reportIds || []).join(', ') || '-'}<br />
      Citations: ${(c.references?.citationIds || []).join(', ') || '-'}<br />
      Warrants: ${(c.references?.warrantIds || []).join(', ') || '-'}<br />
      Evidence: ${(c.references?.evidenceIds || []).join(', ') || '-'}
    `;
    docketList.appendChild(el);
  }
};

window.addEventListener('message', (event) => {
  const msg = event.data || {};
  if (msg.action === 'doj:setVisible') {
    if (msg.visible) {
      app.classList.remove('hidden');
      docket = msg.payload?.docket || [];
      renderDocket();
    } else {
      app.classList.add('hidden');
    }
  }

  if (msg.action === 'doj:caseCreated' && msg.payload) {
    docket.unshift(msg.payload);
    renderDocket();
  }
});

document.getElementById('closeBtn').onclick = () => post('dojClose');

document.getElementById('createCaseBtn').onclick = () => post('dojCreateCase', {
  title: document.getElementById('caseTitle').value,
  defendantCharId: Number(document.getElementById('defCharId').value),
  summary: document.getElementById('caseSummary').value,
});

document.getElementById('scheduleBtn').onclick = () => post('dojScheduleCourt', {
  caseId: Number(document.getElementById('scheduleCaseId').value),
  dayOfWeek: Number(document.getElementById('courtDay').value),
  hour24: Number(document.getElementById('courtHour').value),
});

document.getElementById('proposePleaBtn').onclick = () => post('dojProposePlea', {
  caseId: Number(document.getElementById('pleaCaseId').value),
  pleaText: document.getElementById('pleaText').value,
  recommendedBail: Number(document.getElementById('pleaBail').value),
});

document.getElementById('issueWarrantBtn').onclick = () => post('dojIssueWarrant', {
  targetCharId: Number(document.getElementById('warrantTarget').value),
  reason: document.getElementById('warrantReason').value,
});

document.getElementById('setBailBtn').onclick = () => post('dojSetBail', {
  caseId: Number(document.getElementById('bailCaseId').value),
  amount: Number(document.getElementById('bailAmount').value),
});

document.getElementById('acceptPleaBtn').onclick = () => post('dojReviewPlea', {
  pleaId: Number(document.getElementById('reviewPleaId').value),
  accept: true,
});

document.getElementById('rejectPleaBtn').onclick = () => post('dojReviewPlea', {
  pleaId: Number(document.getElementById('reviewPleaId').value),
  accept: false,
});
