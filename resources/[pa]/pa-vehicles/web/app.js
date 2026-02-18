const app = document.getElementById('app');
const vehiclesEl = document.getElementById('vehicles');
const keyVehicleId = document.getElementById('keyVehicleId');
const keyTargetId = document.getElementById('keyTargetId');

function post(name, body={}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method:'POST',
    headers:{ 'Content-Type':'application/json; charset=UTF-8' },
    body:JSON.stringify(body),
  });
}

function renderVehicles(vehicles) {
  vehiclesEl.innerHTML = '';
  (vehicles || []).forEach((v) => {
    const card = document.createElement('article');
    card.className = 'card';
    card.innerHTML = `
      <div><strong>${v.model}</strong> [${v.plate}]</div>
      <div class="meta">ID ${v.id} • ${v.state} • ${v.garage}</div>
      <div class="meta">${v.insured ? 'Insured' : 'No Insurance'}</div>
      <div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:8px;">
        <button data-spawn="${v.id}">Spawn</button>
        <button data-store="${v.id}">Store</button>
        <button data-impound="${v.id}">Impound</button>
        <button data-repair="${v.id}">Repair</button>
        <button data-claim="${v.id}">Insurance Claim</button>
      </div>
    `;

    card.querySelector('[data-spawn]')?.addEventListener('click', ()=>post('vehicles:spawn',{ vehicleId:v.id, garageKey:v.garage }));
    card.querySelector('[data-store]')?.addEventListener('click', ()=>post('vehicles:despawn',{ vehicleId:v.id, garageKey:v.garage }));
    card.querySelector('[data-impound]')?.addEventListener('click', ()=>post('vehicles:despawn',{ vehicleId:v.id, garageKey:'impound' }));
    card.querySelector('[data-repair]')?.addEventListener('click', ()=>post('vehicles:repair',{ vehicleId:v.id }));
    card.querySelector('[data-claim]')?.addEventListener('click', ()=>post('vehicles:claim',{ vehicleId:v.id }));

    vehiclesEl.appendChild(card);
  });
}

window.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.action === 'vehicles:open') {
    app.classList.remove('hidden');
    renderVehicles(data.payload?.vehicles || []);
  }
  if (data.action === 'vehicles:close') {
    app.classList.add('hidden');
  }
});

document.getElementById('closeBtn').addEventListener('click', ()=>post('vehicles:close'));
document.getElementById('giveKeyBtn').addEventListener('click', ()=>post('vehicles:giveKey', { vehicleId:Number(keyVehicleId.value||0), targetSrc:Number(keyTargetId.value||0) }));
document.getElementById('revokeKeyBtn').addEventListener('click', ()=>post('vehicles:revokeKey', { vehicleId:Number(keyVehicleId.value||0), targetSrc:Number(keyTargetId.value||0) }));
window.addEventListener('keydown', (e)=>{ if (e.key === 'Escape') post('vehicles:close'); });
