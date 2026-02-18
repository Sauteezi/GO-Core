const app = document.getElementById('app');
const businessesEl = document.getElementById('businesses');
const invoicesEl = document.getElementById('invoices');

const targetSrcEl = document.getElementById('targetSrc');
const businessIdEl = document.getElementById('businessId');
const amountEl = document.getElementById('amount');
const reasonEl = document.getElementById('reason');

function post(name, body = {}) {
  return fetch(`https://${GetParentResourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body),
  });
}

function renderBusinesses(list) {
  businessesEl.innerHTML = '';
  list.forEach((item) => {
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `
      <div><strong>${item.label}</strong></div>
      <div class="muted">${item.id} • ${item.role}</div>
      <div>Balance: $${Number(item.balance || 0).toLocaleString()}</div>
      <div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap;">
        <button data-payroll="${item.id}">Run Payroll</button>
        <button data-license="${item.id}">Pay License</button>
        <button data-meal="${item.id}">Civilian Effect</button>
        <button data-security="${item.id}">Hire Security</button>
      </div>
    `;

    card.querySelector('[data-payroll]')?.addEventListener('click', () => post('business:runPayroll', { businessId: item.id }));
    card.querySelector('[data-license]')?.addEventListener('click', () => post('business:purchaseLicense', { businessId: item.id }));
    card.querySelector('[data-meal]')?.addEventListener('click', () => post('business:buyMeal', { businessId: item.id }));
    card.querySelector('[data-security]')?.addEventListener('click', () => post('business:hireSecurity', { businessId: item.id, eventName: 'community_event' }));

    businessesEl.appendChild(card);
  });
}

function renderInvoices(invoicesObj) {
  invoicesEl.innerHTML = '';
  const list = Object.values(invoicesObj || {}).sort((a,b)=> b.id-a.id).slice(0, 20);
  list.forEach((inv) => {
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `
      <div><strong>Invoice #${inv.id}</strong></div>
      <div class="muted">${inv.businessId} • ${inv.reason}</div>
      <div>Amount: $${Number(inv.amount || 0).toLocaleString()} • Status: ${inv.status}</div>
      <div style="margin-top:8px;">
        ${inv.status === 'pending' ? `<button data-pay="${inv.id}">Pay</button>` : '<span class="muted">Paid</span>'}
      </div>
    `;
    card.querySelector('[data-pay]')?.addEventListener('click', () => post('business:payInvoice', { invoiceId: inv.id }));
    invoicesEl.appendChild(card);
  });
}

window.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.action === 'business:open') {
    app.classList.remove('hidden');
    const payload = data.payload || {};
    renderBusinesses(payload.businesses || []);
    renderInvoices(payload.invoices || {});
  }
  if (data.action === 'business:close') {
    app.classList.add('hidden');
  }
});

document.getElementById('createInvoiceBtn').addEventListener('click', () => {
  post('business:createInvoice', {
    targetSrc: Number(targetSrcEl.value || 0),
    businessId: businessIdEl.value || '',
    amount: Number(amountEl.value || 0),
    reason: reasonEl.value || 'service_invoice',
  });
});

document.getElementById('closeBtn').addEventListener('click', () => post('business:close'));
window.addEventListener('keydown', (e) => { if (e.key === 'Escape') post('business:close'); });
