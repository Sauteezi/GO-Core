const app = document.getElementById('app');
const hint = document.getElementById('hint');
const propertiesEl = document.getElementById('properties');

function post(name, body={}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method:'POST',
    headers:{ 'Content-Type':'application/json; charset=UTF-8' },
    body:JSON.stringify(body),
  });
}

function renderProperties(properties) {
  propertiesEl.innerHTML = '';
  (properties || []).forEach((p) => {
    const card = document.createElement('article');
    card.className = 'card';

    const pressureClass = (Number(p.gangPressure || 0) >= 70) ? 'warn' : '';
    card.innerHTML = `
      <div><strong>${p.label}</strong></div>
      <div class="meta">${p.key} • ${p.interiorType}</div>
      <div class="meta">Neighborhood: ${p.neighborhood} • Rep ${p.neighborhoodRep || 0} • <span class="${pressureClass}">Pressure ${p.gangPressure || 0}</span></div>
      <div>Price: $${Number(p.price || 0).toLocaleString()} | Rent: $${Number(p.rent || 0).toLocaleString()}</div>
      <div class="meta">${p.owned ? (p.hasKey ? 'You have access' : 'Owned by someone else') : 'Available'}</div>
      <div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:8px;">
        <button data-buy="${p.key}" ${p.owned ? 'disabled' : ''}>Purchase</button>
        <button data-rent="${p.key}">Rent</button>
        <button data-enter="${p.key}" ${p.hasKey ? '' : 'disabled'}>Enter</button>
        <button data-stash="${p.key}" ${p.hasKey ? '' : 'disabled'}>Storage</button>
      </div>
    `;

    card.querySelector('[data-buy]')?.addEventListener('click', ()=>post('housing:purchase',{ propertyKey:p.key }));
    card.querySelector('[data-rent]')?.addEventListener('click', ()=>post('housing:rent',{ propertyKey:p.key }));
    card.querySelector('[data-enter]')?.addEventListener('click', ()=>post('housing:enter',{ propertyKey:p.key }));
    card.querySelector('[data-stash]')?.addEventListener('click', ()=>post('housing:stash',{ propertyKey:p.key }));

    propertiesEl.appendChild(card);
  });
}

window.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.action === 'housing:open') {
    app.classList.remove('hidden');
    hint.classList.add('hidden');
    renderProperties(data.payload?.properties || []);
  }
  if (data.action === 'housing:close') {
    app.classList.add('hidden');
  }
  if (data.action === 'housing:hint') {
    hint.textContent = data.payload?.text || 'Press E to interact';
    hint.classList.remove('hidden');
    setTimeout(()=>hint.classList.add('hidden'), 1200);
  }
});

document.getElementById('closeBtn').addEventListener('click', ()=>post('housing:close'));
document.getElementById('shareBtn').addEventListener('click', ()=>post('housing:shareKey', {
  propertyKey: document.getElementById('keyProperty').value,
  targetSrc: Number(document.getElementById('keyTarget').value || 0),
}));
document.getElementById('revokeBtn').addEventListener('click', ()=>post('housing:revokeKey', {
  propertyKey: document.getElementById('keyProperty').value,
  targetSrc: Number(document.getElementById('keyTarget').value || 0),
}));
window.addEventListener('keydown', (e)=>{ if (e.key === 'Escape') post('housing:close'); });
