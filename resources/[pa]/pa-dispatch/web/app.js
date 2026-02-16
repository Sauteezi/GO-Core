const app = document.getElementById('app');
const feedEl = document.getElementById('feed');

let feed = [];

const post = async (event, payload = {}) => {
  await fetch(`https://${GetParentResourceName()}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
};

const renderFeed = () => {
  feedEl.innerHTML = '';

  if (!feed.length) {
    feedEl.innerHTML = '<div class="meta">No active calls.</div>';
    return;
  }

  feed.forEach((call) => {
    const el = document.createElement('article');
    el.className = 'call';
    el.innerHTML = `
      <strong>#${call.id} • ${call.type}</strong>
      <div class="meta">Priority: ${call.priority} • Status: ${call.status}</div>
      <div>${call.description}</div>
      <div class="meta">Units: ${(call.assignedUnits || []).map((u) => u.callsign).join(', ') || 'None'}</div>
      <div class="actions">
        <button data-action="assign">Assign Self</button>
        <button data-action="enroute">En Route</button>
        <button data-action="onscene">On Scene</button>
        <button data-action="close">Close</button>
      </div>
    `;

    el.querySelector('[data-action="assign"]').addEventListener('click', () => {
      post('dispatch:assignSelf', { callId: call.id, callsign: 'Unit', unitType: 'responding' });
    });

    el.querySelector('[data-action="enroute"]').addEventListener('click', () => {
      post('dispatch:updateStatus', { callId: call.id, status: 'enroute', note: 'Unit en route' });
    });

    el.querySelector('[data-action="onscene"]').addEventListener('click', () => {
      post('dispatch:updateStatus', { callId: call.id, status: 'onscene', note: 'Unit on scene' });
    });

    el.querySelector('[data-action="close"]').addEventListener('click', () => {
      post('dispatch:closeCall', { callId: call.id, note: 'Incident resolved' });
    });

    feedEl.appendChild(el);
  });
};

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};
  if (action === 'setVisible') {
    app.classList.toggle('hidden', !data.visible);
  }

  if (action === 'setFeed') {
    feed = Array.isArray(data.feed) ? data.feed : [];
    renderFeed();
  }
});

document.getElementById('closeBtn').addEventListener('click', () => post('dispatch:close'));

document.getElementById('createBtn').addEventListener('click', () => {
  post('dispatch:createCall', {
    type: document.getElementById('type').value || 'unknown',
    priority: document.getElementById('priority').value,
    description: document.getElementById('description').value,
    coords: { x: 0.0, y: 0.0, z: 0.0 },
  });
});
