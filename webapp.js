const state = { tickets: [], recipes: {}, selected: null, now: Date.now(), events: [] };

const kds = document.getElementById('kds');
const ticketDetail = document.getElementById('ticketDetail');
const log = document.getElementById('log');

const fmt = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;

function render() {
  kds.innerHTML = '';
  state.tickets.filter(t => t.status !== 'served').forEach(t => {
    const age = Math.floor((state.now - t.enteredAt) / 1000);
    const div = document.createElement('article');
    div.className = `ticket ${age >= 90 ? 'urgent' : ''} ${state.selected?.order_id === t.order_id ? 'selected' : ''}`;
    div.innerHTML = `<strong>${t.source}</strong><br><strong>${t.item_name}</strong> (${t.size})<br><span>${fmt(age)}</span><br><span class="small">${t.status}</span>`;
    div.onclick = () => { state.selected = t; renderDetail(); render(); };
    kds.appendChild(div);
  });
}

function reqCount(ticket) { return ticket.size === 'large' ? 2 : 1; }

function renderDetail() {
  const t = state.selected;
  if (!t) return (ticketDetail.textContent = 'Select a ticket.');
  const r = state.recipes[t.item_name];
  ticketDetail.innerHTML = `
    <strong>${t.order_id} — ${t.item_name}</strong><br>
    State: ${t.status}<br>
    Pre-oven progress: ${t.preDone}/${r.pre_oven.length * reqCount(t)}<br>
    Post-oven progress: ${t.postDone}/${(r.post_oven.length + 2) * reqCount(t)}<br>
    <span class="small">Hot+Honey requires hot_sauce + honey_garlic_sauce if present.</span>
  `;
}

function addEvent(text) { state.events.unshift(`${new Date().toLocaleTimeString()}: ${text}`); log.innerHTML = state.events.slice(0, 8).join('<br>'); }

function act(action) {
  const t = state.selected; if (!t) return;
  const r = state.recipes[t.item_name]; const clicks = reqCount(t);
  if (action === 'start' && t.status === 'queued') { t.status = 'being_assembled'; addEvent(`${t.order_id} started from plate/takeout zone`); }
  if (action === 'pre' && t.status === 'being_assembled') { t.preDone = r.pre_oven.length * clicks; t.status = 'ready_for_oven'; addEvent(`${t.order_id} pre-oven set complete`); }
  if (action === 'oven' && t.status === 'ready_for_oven') { t.status = 'in_oven'; t.ovenDoneAt = state.now + (t.size === 'large' ? 40000 : 30000); addEvent(`${t.order_id} sent to oven`); }
  if (action === 'post' && (t.status === 'oven_done' || t.status === 'finishing')) { t.postDone = (r.post_oven.length + 2) * clicks; t.status = 'finishing'; addEvent(`${t.order_id} post-oven + sides complete`); }
  if (action === 'serve' && t.status === 'finishing') { t.status = 'served'; addEvent(`${t.order_id} served`); }
  renderDetail(); render();
}

document.querySelectorAll('button[data-action]').forEach(btn => btn.onclick = () => act(btn.dataset.action));

function tick() {
  state.now = Date.now();
  for (const t of state.tickets) if (t.status === 'in_oven' && state.now >= t.ovenDoneAt) t.status = 'oven_done';
  render(); renderDetail();
}

(async function init() {
  const [recipesData, ticketsData] = await Promise.all([
    fetch('./data/recipes/nacho_recipes_v1.json').then(r => r.json()),
    fetch('./data/tickets/sample_tickets_v1.json').then(r => r.json())
  ]);
  state.recipes = recipesData.recipes;
  state.tickets = ticketsData.tickets.slice(0, 5).map((t, i) => ({ ...t, enteredAt: Date.now() - (i * 42000), status: 'queued', preDone: 0, postDone: 0 }));
  addEvent('V1 loaded: 3+ tickets visible, count-up timers running, no station tags/recalled.');
  tick();
  setInterval(tick, 1000);
})();
