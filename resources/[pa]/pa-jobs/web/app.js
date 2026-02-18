const panel = document.getElementById('panel');
const jobsEl = document.getElementById('jobs');
const currentEl = document.getElementById('current');
const hintEl = document.getElementById('hint');
const closeBtn = document.getElementById('closeBtn');

function post(name, data = {}) {
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });
}

function requirementSummary(req = {}) {
  const licenses = Array.isArray(req.licenses) && req.licenses.length > 0
    ? `Licenses: ${req.licenses.join(', ')}`
    : 'Licenses: none';

  const rep = Number(req.minReputation || 0);
  return `${licenses} • Reputation: ${rep}`;
}

function renderJobs(jobs) {
  jobsEl.innerHTML = '';
  jobs.forEach((job) => {
    const card = document.createElement('article');
    card.className = 'job-card';

    const pay = Number(job.payRules?.starterPay || 0);
    const availability = job.available
      ? '<div class="good">Available</div>'
      : `<div class="bad">${job.unavailableReason || 'Not available'}</div>`;

    card.innerHTML = `
      <h3>${job.label}</h3>
      <div class="req">${requirementSummary(job.requirements)}</div>
      <div class="req">Starter pay: $${pay.toLocaleString()}</div>
      ${availability}
      <div style="margin-top:8px;display:flex;gap:8px;">
        <button class="apply-btn" ${job.available ? '' : 'disabled'}>Apply</button>
      </div>
    `;

    card.querySelector('.apply-btn')?.addEventListener('click', () => {
      post('jobs:apply', { jobName: job.name, grade: 0 });
    });

    jobsEl.appendChild(card);
  });
}

window.addEventListener('message', (event) => {
  const data = event.data || {};

  if (data.action === 'jobs:open') {
    panel.classList.remove('hidden');
    hintEl.classList.add('hidden');
    const jobs = data.payload?.jobs || [];
    renderJobs(jobs);
  }

  if (data.action === 'jobs:close') {
    panel.classList.add('hidden');
  }

  if (data.action === 'jobs:hint') {
    hintEl.textContent = data.payload?.text || 'Press E to interact';
    hintEl.classList.remove('hidden');
    setTimeout(() => hintEl.classList.add('hidden'), 1200);
  }

  if (data.action === 'jobs:current') {
    const p = data.payload || {};
    currentEl.textContent = `Current Job: ${p.label || p.name || 'Unemployed'} (Grade ${Number(p.grade || 0)}) • ${p.onDuty ? 'On Duty' : 'Off Duty'}`;
  }
});

window.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    post('jobs:close');
  }
});

closeBtn.addEventListener('click', () => post('jobs:close'));
