(function () {
  function applyMarkers() {
    const slots = document.querySelectorAll('[data-item-name]');
    slots.forEach((slot) => {
      const flags = (slot.getAttribute('data-item-flags') || '').toLowerCase();
      slot.setAttribute('data-illegal', flags.includes('illegal') ? 'true' : 'false');
      slot.setAttribute('data-evidence', flags.includes('evidence') ? 'true' : 'false');
      slot.classList.add('pa-slot');
    });
  }

  function applyShellLayout() {
    const root = document.querySelector('.inventory-root') || document.body;
    root.classList.add('pa-inventory-shell');

    document.querySelector('.inventory-categories')?.classList.add('pa-inventory-column');
    document.querySelector('.inventory-grid')?.classList.add('pa-inventory-column');
    document.querySelector('.inventory-details')?.classList.add('pa-inventory-column');
  }

  window.PAInventorySkin = {
    refresh() {
      applyShellLayout();
      applyMarkers();
    },
  };

  window.addEventListener('load', function () {
    window.PAInventorySkin.refresh();
  });
})();
