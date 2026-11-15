(() => {
  const app = document.getElementById('app');
  const content = document.getElementById('page-content');
  const overviewMarkup = content.innerHTML;
  const title = document.getElementById('page-title');
  const breadcrumb = document.getElementById('breadcrumb');
  const resource = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'power_admin_menu';
  const state = { data: null, page: 'overview', subview: 'list', frozen: new Set(), search: '', pageIndex: 0, dossier: null, catalogs: {vehicles:[],items:[],jobs:[]}, catalogSearch:'', catalogCategory:'all', selectedItem:'' };
  const pageNames = { overview: 'Command Center', players: 'Player Management', bans: 'Active Bans', vehicles:'Vehicle Catalog', items:'Item Management', jobs:'Job Management', world: 'World Control', security: 'Security Center', system: 'System Overview', developer: 'Developer Tools' };

  async function nui(name, payload = {}) {
    try {
      const response = await fetch(`https://${resource}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(payload)
      });
      return await response.json();
    } catch (error) {
      toast('Unable to communicate with the game client.', true);
      return { success: false };
    }
  }

  function toast(message, error = false) {
    const region = document.getElementById('toast-region');
    const item = document.createElement('div');
    item.className = `toast${error ? ' error' : ''}`;
    item.textContent = message || 'Action completed.';
    region.appendChild(item);
    setTimeout(() => item.remove(), 3200);
  }

  function can(permission) {
    return !!(state.data && state.data.permissions && state.data.permissions[permission]);
  }

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
  }

  function playerRows(players, full = false) {
    if (!players || !players.length) return '<tr><td colspan="6" class="empty-state">No players are currently connected.</td></tr>';
    return players.map(player => {
      const id = Number(player.id), name = escapeHtml(player.name), job = escapeHtml(player.job || 'Unknown');
      const frozen = state.frozen.has(id), actions = [];
      if (full && can('players.dossier')) actions.push(`<button class="mini-action" data-action="player.dossier" data-target="${id}">INSPECT</button>`);
      if (can('players.teleport')) actions.push(`<button class="mini-action" data-action="player.teleportTo" data-target="${id}">TP</button>`);
      if (can('players.bring')) actions.push(`<button class="mini-action" data-action="player.bring" data-target="${id}">Bring</button>`);
      if (can('players.freeze')) actions.push(`<button class="mini-action" data-action="player.freeze" data-target="${id}" data-value="${!frozen}">${frozen ? 'Unfreeze' : 'Freeze'}</button>`);
      if (can('players.heal')) actions.push(`<button class="mini-action" data-action="player.heal" data-target="${id}">Heal</button>`);
      if (can('players.kick')) actions.push(`<button class="mini-action" data-action="player.kick" data-target="${id}">Kick</button>`);
      if (!full) return `<tr><td><div class="player-name"><span class="player-avatar">${name.slice(0,1).toUpperCase()}</span><span>${name}</span></div></td><td>#${id}</td><td>${job}</td><td>${Number(player.ping)||0} ms</td><td><span class="status-dot"></span>ONLINE</td></tr>`;
      return `<tr><td><div class="player-name"><span class="player-avatar">${name.slice(0,1).toUpperCase()}</span><span>${name}</span></div></td><td>#${id}</td><td>${job}</td><td>${Number(player.ping)||0} ms</td><td><span class="status-dot"></span>ONLINE</td><td><div class="player-actions">${actions.join('') || '<small>No actions</small>'}</div></td></tr>`;
    }).join('');
  }

  function renderOverview() {
    const payload = state.data || {};
    const players = Array.isArray(payload.players) ? payload.players : [];
    const count = Number(payload.playerCount ?? players.length) || 0;
    const framework = String(payload.framework || '—').toUpperCase();
    const ai = payload.aiEnabled ? 'ENABLED' : 'DISABLED';
    const statPlayers = document.getElementById('stat-players');
    const statFramework = document.getElementById('stat-framework');
    const statAi = document.getElementById('stat-ai');
    const operatorRole = document.getElementById('operator-role');
    const frameworkLabel = document.getElementById('framework-label');
    const recent = document.getElementById('recent-players');
    if (statPlayers) statPlayers.textContent = String(count);
    if (statFramework) statFramework.textContent = framework;
    if (statAi) statAi.textContent = ai;
    if (operatorRole) operatorRole.textContent = payload.roleLabel || payload.role || 'Administrator';
    if (frameworkLabel) frameworkLabel.textContent = framework === '—' ? 'Framework loading' : `${framework} ADAPTER`;
    if (recent) recent.innerHTML = playerRows(players.slice(0, 8), false);
  }

  function renderPlayers() {
    state.subview='list';
    const all = state.data?.players || [];
    const query = state.search.toLowerCase();
    const filtered = all.filter(p => `${p.name} ${p.id} ${p.job} ${p.characterId || ''}`.toLowerCase().includes(query));
    const pageSize = Number(state.data?.playerPageSize) || 25, pages = Math.max(1, Math.ceil(filtered.length / pageSize));
    state.pageIndex = Math.min(state.pageIndex, pages - 1);
    const shown = filtered.slice(state.pageIndex * pageSize, (state.pageIndex + 1) * pageSize);
    content.innerHTML = `
      <div class="welcome-row"><div><div class="eyebrow">LIVE SESSION MONITOR</div><h2>Player <span>intelligence.</span></h2><p>Search connected players, open dossiers and perform authorized actions.</p></div><div class="date-chip">${filtered.length} MATCHES</div></div>
      <div class="toolbar"><input id="player-search" class="search-input" placeholder="Search name, server ID or job..." value="${escapeHtml(state.search)}"><button class="action-button" id="refresh-players">↻ REFRESH</button>${can('players.unban')?'<button class="action-button" id="open-bans">ACTIVE BANS</button>':''}</div>
      <div class="table-wrap"><table><thead><tr><th>PLAYER</th><th>SERVER ID</th><th>JOB</th><th>PING</th><th>STATUS</th><th>PLAYER ACTIONS</th></tr></thead><tbody>${playerRows(shown, true)}</tbody></table></div>
      <div class="form-row" style="justify-content:space-between;margin-top:12px"><small class="muted">Page ${state.pageIndex + 1} of ${pages} · ${filtered.length} players</small><div class="form-row"><button class="action-button" id="players-prev" ${state.pageIndex===0?'disabled':''}>← PREVIOUS</button><button class="action-button" id="players-next" ${state.pageIndex>=pages-1?'disabled':''}>NEXT →</button></div></div>
      <p class="muted" style="margin-top:12px">Player actions are authorized and validated again by the server. Search and pagination are local to the current live player snapshot.</p>`;
    document.getElementById('player-search').addEventListener('input', event => { state.search = event.target.value; state.pageIndex = 0; renderPlayers(); const input = document.getElementById('player-search'); input.focus(); input.setSelectionRange(input.value.length,input.value.length); });
    document.getElementById('refresh-players').addEventListener('click', () => nui('refresh'));
    if(document.getElementById('open-bans')) document.getElementById('open-bans').addEventListener('click', () => sendAction({action:'bans.search'}));
    document.getElementById('players-prev').addEventListener('click', () => { state.pageIndex=Math.max(0,state.pageIndex-1); renderPlayers(); });
    document.getElementById('players-next').addEventListener('click', () => { state.pageIndex=Math.min(pages-1,state.pageIndex+1); renderPlayers(); });
  }

  function renderDossier(d) {
    state.dossier = d; state.subview='dossier'; title.textContent='Player Dossier'; breadcrumb.textContent='PLAYER DOSSIER';
    const money = d.money ? `<div class="permission-list"><div class="permission-item"><span>Cash</span><b>${Number(d.money.cash||0).toLocaleString()}</b></div><div class="permission-item"><span>Bank</span><b>${Number(d.money.bank||0).toLocaleString()}</b></div></div>` : '<p class="muted">Money data unavailable or permission required.</p>';
    const inventory = Array.isArray(d.inventory) ? d.inventory.map(item => `<div class="permission-item"><span>${escapeHtml(item.label||item.name||item.item||'Unknown item')}</span><b>×${Number(item.count||item.amount||1)}</b></div>`).join('') || '<p class="muted">Inventory is empty.</p>' : `<p class="muted">Inventory: ${escapeHtml(d.inventoryStatus||'unavailable')}.</p>`;
    const notes = (d.notes||[]).map(n => `<div class="permission-item"><span>${escapeHtml(n.note)}<br><small>${escapeHtml(n.staff_name||'Staff')} · ${escapeHtml(n.created_at||'')}</small></span></div>`).join('') || '<p class="muted">No recorded staff notes.</p>';
    const warnings = (d.warnings||[]).map(w => `<div class="permission-item"><span>${escapeHtml(w.reason)}<br><small>${escapeHtml(w.staff_name||'Staff')} · ${escapeHtml(w.created_at||'')}</small></span></div>`).join('') || '<p class="muted">No recorded warnings.</p>';
    const bans = (d.bans||[]).map(b => `<div class="permission-item"><span>Ban #${b.id}: ${escapeHtml(b.reason)}<br><small>${b.expires_at ? 'Expires '+escapeHtml(b.expires_at) : 'Permanent'} · ${escapeHtml(b.created_at||'')}</small></span>${Number(b.active) === 1 && can('players.unban') ? `<button class="mini-action" data-action="player.unban" data-banid="${b.id}">REVOKE</button>` : `<b>${Number(b.active)===1?'ACTIVE':'REVOKED'}</b>`}</div>`).join('') || '<p class="muted">No ban records.</p>';
    const activity = (d.activity||[]).map(a => `<div class="permission-item"><span>${escapeHtml(a.event_type)}<br><small>${escapeHtml(JSON.stringify(a.details||{}))} · ${escapeHtml(a.created_at||'')}</small></span><b>RECORDED</b></div>`).join('') || `<p class="muted">${escapeHtml(d.historyStatus||'No activity events recorded yet. History begins when Power Admin Menu Phase 2 is installed.')}</p>`;
    const transactions = (d.transactions||[]).map(t => `<div class="permission-item"><span>${escapeHtml(t.account)} · ${Number(t.amount).toLocaleString()}<br><small>${escapeHtml(t.reason)} · ${escapeHtml(t.staff_name||'Staff')} · ${escapeHtml(t.created_at||'')}</small></span></div>`).join('') || '<p class="muted">No recorded Power Admin money adjustments.</p>';
    const vehicles = Array.isArray(d.vehicles) ? d.vehicles.map(v=>`<div class="permission-item"><span>${escapeHtml(v.plate||'Unknown plate')}</span><b>${escapeHtml(v.vehicle||v.model||'Vehicle')}</b></div>`).join('') : `<p class="muted">${escapeHtml(d.vehiclesStatus||'Vehicle integration unavailable')}.</p>`;
    const identifiers = Array.isArray(d.identifiers) && d.identifiers.length ? d.identifiers.map(v=>`<div class="permission-item"><span>${escapeHtml(v)}</span></div>`).join('') : '<p class="muted">Identifiers hidden by privacy configuration or permission.</p>';
    content.innerHTML = `<div class="welcome-row"><div><div class="eyebrow">PLAYER DOSSIER / LIVE RECORD</div><h2>${escapeHtml(d.name)} <span>#${d.id}</span></h2><p>${escapeHtml(d.playerName||'')} · ${escapeHtml(d.framework||'').toUpperCase()} · ${escapeHtml(d.job||'Unknown')}</p></div><button class="action-button" id="dossier-back">← BACK TO PLAYERS</button></div>
      <div class="stats-grid"><article class="stat-card"><div class="stat-head">SERVER ID</div><strong>#${d.id}</strong><small>${Number(d.ping)||0} ms ping</small></article><article class="stat-card"><div class="stat-head">CHARACTER ID</div><strong class="stat-text">${escapeHtml(d.characterId||'Unavailable')}</strong><small>Framework identity</small></article><article class="stat-card"><div class="stat-head">PLAYTIME THIS SESSION</div><strong>${d.connection?.playtimeSeconds!=null?Math.floor(d.connection.playtimeSeconds/60)+'m':'—'}</strong><small>Since Phase 2 observed connection</small></article><article class="stat-card"><div class="stat-head">FRAMEWORK</div><strong class="stat-text">${escapeHtml(String(d.framework||'').toUpperCase())}</strong><small>Adapter</small></article></div>
      <div class="quick-grid" style="grid-template-columns:repeat(3,minmax(0,1fr));margin-bottom:15px">${can('players.spectate')?'<button class="action-button" data-action="player.spectate.start" data-target="'+d.id+'">SPECTATE</button>':''}${can('players.warn')?'<button class="action-button" data-action="player.warn" data-target="'+d.id+'">WARN</button>':''}${can('players.ban')?'<button class="action-button danger" data-action="player.ban" data-target="'+d.id+'">BAN</button>':''}</div>
      <div class="quick-grid" style="grid-template-columns:repeat(2,minmax(0,1fr))"><section class="page-panel"><h3>Economy</h3>${money}${can('players.money.modify')?`<button class="action-button" data-action="player.money.adjust" data-target="${d.id}">ADJUST CASH / BANK</button>`:''}</section><section class="page-panel"><h3>Inventory · Read only</h3>${inventory}</section><section class="page-panel"><h3>Staff notes</h3>${notes}${can('players.notes.add')?`<button class="action-button" data-action="player.note.add" data-target="${d.id}">ADD NOTE</button>`:''}</section><section class="page-panel"><h3>Warnings</h3>${warnings}</section><section class="page-panel"><h3>Ban history</h3>${bans}</section><section class="page-panel"><h3>Recorded activity</h3>${activity}<p class="muted">Only events recorded by this resource or configured integrations are shown. No pre-install history is reconstructed.</p></section><section class="page-panel"><h3>Identifiers</h3>${identifiers}</section><section class="page-panel"><h3>Economy transaction history</h3>${transactions}</section><section class="page-panel"><h3>Vehicles</h3>${vehicles}</section></div>`;
    document.getElementById('dossier-back').addEventListener('click',()=>navigate('players'));
  }

  function renderBans(rows) {
    state.bans = rows || []; state.subview='bans';
    state.page='bans'; title.textContent=pageNames.bans; breadcrumb.textContent='BANS';
    document.querySelectorAll('.nav-item').forEach(button=>button.classList.toggle('active',button.dataset.page==='players'));
    const body=state.bans.map(b=>`<tr><td>#${b.id}</td><td>${escapeHtml(b.player_name||'Unknown')}</td><td>${escapeHtml(b.reason)}</td><td>${escapeHtml(b.staff_name||'Staff')}</td><td>${escapeHtml(b.expires_at||'Permanent')}</td><td><button class="mini-action" data-action="player.unban" data-banid="${b.id}">REVOKE BAN</button></td></tr>`).join('') || '<tr><td colspan="6" class="empty-state">No active bans.</td></tr>';
    content.innerHTML=`<div class="welcome-row"><div><div class="eyebrow">MODERATION RECORDS</div><h2>Active <span>bans.</span></h2><p>Persistent bans enforced at connection time.</p></div><button id="bans-back" class="action-button">← BACK</button></div><div class="table-wrap"><table><thead><tr><th>BAN ID</th><th>PLAYER</th><th>REASON</th><th>STAFF</th><th>EXPIRY</th><th>ACTION</th></tr></thead><tbody>${body}</tbody></table></div>`;
    document.getElementById('bans-back').onclick=()=>navigate('players');
  }

  function renderWorld() {
    const weatherOptions = ['EXTRASUNNY','CLEAR','CLOUDS','OVERCAST','RAIN','THUNDER','CLEARING','NEUTRAL','SMOG','FOGGY','XMAS','SNOW','BLIZZARD'];
    content.innerHTML = `
      <div class="welcome-row"><div><div class="eyebrow">ENVIRONMENT OPERATIONS</div><h2>World <span>control.</span></h2><p>Manage global weather and time across connected clients.</p></div></div>
      <div class="quick-grid" style="grid-template-columns:repeat(2,minmax(0,1fr))">
        <section class="page-panel"><h3>Weather control</h3><p class="muted">Choose an approved weather preset and apply it globally.</p><div class="form-row"><select id="weather-select" class="select-input">${weatherOptions.map(w => `<option value="${w}">${w}</option>`).join('')}</select><button id="apply-weather" class="action-button" ${can('world.weather') ? '' : 'disabled'}>APPLY WEATHER</button></div>${can('world.weather') ? '' : '<p class="muted">Missing permission: world.weather</p>'}</section>
        <section class="page-panel"><h3>Time control</h3><p class="muted">Set the networked world clock.</p><div class="form-row"><input id="time-hour" class="text-input" type="number" min="0" max="23" value="12" style="width:70px"><span class="muted">:</span><input id="time-minute" class="text-input" type="number" min="0" max="59" value="0" style="width:70px"><button id="apply-time" class="action-button" ${can('world.time') ? '' : 'disabled'}>APPLY TIME</button></div>${can('world.time') ? '' : '<p class="muted">Missing permission: world.time</p>'}</section>
      </div><p class="muted" style="margin-top:15px">Global weather and clock controls are inherited from the core release. Per-zone weather, safe zones and density controls are planned for later phases.</p>`;
    document.getElementById('apply-weather').addEventListener('click', () => sendAction({ action: 'world.weather', weather: document.getElementById('weather-select').value }));
    document.getElementById('apply-time').addEventListener('click', () => sendAction({ action: 'world.time', hour: Number(document.getElementById('time-hour').value), minute: Number(document.getElementById('time-minute').value) }));
  }

  function renderSecurity() {
    const perms = Object.entries(state.data?.permissions || {});
    content.innerHTML = `<div class="welcome-row"><div><div class="eyebrow">ACCESS GOVERNANCE</div><h2>Security <span>center.</span></h2><p>Your current server-authorized capabilities.</p></div></div>
      <section class="page-panel"><h3>Active operator session</h3><p class="muted">Role: <strong>${escapeHtml(state.data?.role || 'Unknown')}</strong> · Framework: <strong>${escapeHtml(state.data?.framework || 'Unknown')}</strong></p><div class="permission-list">${perms.map(([key, value]) => `<div class="permission-item"><span>${escapeHtml(key)}</span><b>${value ? 'GRANTED' : 'DENIED'}</b></div>`).join('')}</div></section>
      <p class="muted" style="margin-top:13px">Permissions shown here are informational. The server independently checks every protected action. Staff assignments are configured in config.lua or through ACE permissions.</p>`;
  }

  function renderSystem() {
    content.innerHTML = `<div class="welcome-row"><div><div class="eyebrow">CORE SERVICES</div><h2>System <span>overview.</span></h2><p>Runtime information for this Power Admin Menu instance.</p></div></div>
      <section class="page-panel"><h3>Runtime configuration</h3><div class="permission-list">
        <div class="permission-item"><span>Resource version</span><b>${escapeHtml(state.data?.version || '—')}</b></div>
        <div class="permission-item"><span>Framework adapter</span><b>${escapeHtml(String(state.data?.framework || '—').toUpperCase())}</b></div>
        <div class="permission-item"><span>AI integration</span><b>${state.data?.aiEnabled ? 'ENABLED' : 'DISABLED'}</b></div>
        <div class="permission-item"><span>Database</span><b>OXMYSQL</b></div>
        <div class="permission-item"><span>UI build</span><b>PHASE 2</b></div>
        <div class="permission-item"><span>Session</span><b>AUTHORIZED</b></div>
      </div></section><p class="muted" style="margin-top:13px">Resource management, diagnostics, database administration and configurable integrations are planned for subsequent releases.</p>`;
  }

  function requestCatalog(kind) { nui('catalog',{kind}); }
  function renderCatalog(kind) {
    const rows=state.catalogs[kind]||[]; const query=state.catalogSearch.toLowerCase();
    const filtered=rows.filter(v=>`${v.name||''} ${v.label||''} ${v.spawnName||''} ${v.model||''} ${v.category||''}`.toLowerCase().includes(query) && (state.catalogCategory==='all'||String(v.category||'Other')===state.catalogCategory));
    const categories=[...new Set(rows.map(v=>String(v.category||'Other')))].sort();
    const catSelect=`<select id="catalog-category" class="select-input"><option value="all">All categories</option>${categories.map(c=>`<option value="${escapeHtml(c)}" ${state.catalogCategory===c?'selected':''}>${escapeHtml(c)}</option>`).join('')}</select>`;
    let body='';
    if(kind==='vehicles') {
      const targetOptions=(state.data?.players||[]).map(p=>`<option value="${Number(p.id)}">${escapeHtml(p.name||p.playerName||('Player '+p.id))} (#${Number(p.id)})${Number(p.id)===Number(state.data?.selfId)?' · YOU':''}</option>`).join('');
      body=`<section class="page-panel" style="margin-bottom:14px"><h3>Vehicle delivery target</h3><p class="muted">Choose who should receive a purchased/owned garage entry. Spawn Vehicle only creates a temporary admin vehicle.</p><select id="vehicle-target" class="select-input"><option value="">Select connected player</option>${targetOptions}</select></section>`+(filtered.length?`<div class="quick-grid">${filtered.map(v=>{const model=String(v.spawnName||v.model||v.name||'');return `<article class="page-panel"><div class="eyebrow">${escapeHtml(v.category||'Other')}</div><h3>${escapeHtml(v.name||v.model||model)}</h3><p class="muted">Spawn name: <b>${escapeHtml(model)}</b></p><div class="quick-grid" style="grid-template-columns:repeat(2,minmax(0,1fr))"><button class="action-button" data-spawn-model="${escapeHtml(model)}" ${can('vehicles.spawn')?'':'disabled'}>SPAWN FOR ME</button><button class="action-button" data-give-model="${escapeHtml(model)}" ${can('vehicles.give')?'':'disabled'}>GIVE + GARAGE</button></div></article>`}).join('')}</div>`:'<div class="page-panel muted">No vehicles found. Check that your framework shared vehicle table is loaded.</div>');
    } else if(kind==='items') {
      const selected=rows.find(v=>v.name===state.selectedItem);
      body=`<div class="quick-grid" style="grid-template-columns:repeat(2,minmax(0,1fr))"><section class="page-panel"><h3>Item catalog</h3><div class="permission-list">${filtered.slice(0,250).map(v=>`<button class="permission-item item-pick" data-item-name="${escapeHtml(v.name)}"><span>${escapeHtml(v.label||v.name)}</span><b>${escapeHtml(v.name)}</b></button>`).join('')||'<p class="muted">No items found.</p>'}</div><small class="muted">Showing up to 250 matches.</small></section><section class="page-panel"><h3>Give item</h3><p class="muted">Selected: ${selected?escapeHtml(selected.label||selected.name)+' ('+escapeHtml(selected.name)+')':'Choose an item from the list'}</p><label class="muted">Target player</label><select id="item-target" class="select-input"><option value="${Number(state.data?.selfId)||0}">Yourself</option>${(state.data?.players||[]).map(p=>`<option value="${Number(p.id)}">${escapeHtml(p.name)} (#${Number(p.id)})</option>`).join('')}</select><label class="muted">Quantity</label><input id="item-amount" class="search-input" type="number" min="1" max="10000" value="1"><button id="give-item" class="action-button" ${can('items.give')&&selected?'':'disabled'}>GIVE ITEM</button></section></div>
      ${can('items.create') && state.data?.canCreateItems?`<section class="page-panel" style="margin-top:14px"><div class="section-heading"><div><div class="eyebrow">LIVE REGISTRY</div><h3>Create new item</h3></div><span class="subtle-label">ADMIN ONLY</span></div><div class="quick-grid" style="grid-template-columns:repeat(2,minmax(0,1fr))"><input id="new-item-name" class="search-input" placeholder="Spawn name (e.g. water_bottle)"><input id="new-item-label" class="search-input" placeholder="Display label"><input id="new-item-weight" class="search-input" type="number" min="0" value="100" placeholder="Weight"><input id="new-item-image" class="search-input" placeholder="Image filename (optional)"><input id="new-item-description" class="search-input" placeholder="Description (optional)"><select id="new-item-unique" class="select-input"><option value="false">Stackable</option><option value="true">Unique</option></select><select id="new-item-useable" class="select-input"><option value="false">Not usable</option><option value="true">Usable</option></select></div><button id="create-item" class="action-button" style="margin-top:12px">REGISTER ITEM LIVE</button><p class="muted">Definitions are saved in the Power Admin registry and injected into the running framework table where supported. Inventory resources may cache definitions separately.</p></section>`:(can('items.create') && !state.data?.canCreateItems?`<section class="page-panel" style="margin-top:14px"><h3>Item creation is not exposed by ${escapeHtml(state.data?.inventoryProvider||'the selected inventory')}</h3><p class="muted">The selected inventory can be browsed and items can be given, but it does not expose a verified live item-registration bridge. Configure integrations/custom_inventory.lua if your inventory provides one.</p></section>`:'')}`;
    } else {
      body=`<section class="page-panel"><h3>Available jobs</h3><div class="permission-list">${filtered.map(v=>`<div class="permission-item"><span>${escapeHtml(v.label||v.name)}</span><b>${escapeHtml(v.name)}</b></div>`).join('')||'<p class="muted">No jobs found.</p>'}</div></section>${can('jobs.create') && ['qbcore','qbox'].includes(state.data?.framework)?`<section class="page-panel" style="margin-top:14px"><div class="eyebrow">LIVE REGISTRY</div><h3>Create new job</h3><div class="quick-grid job-create-grid"><input id="new-job-name" class="search-input" placeholder="Job name (e.g. mechanic)"><input id="new-job-label" class="search-input" placeholder="Job label"><input id="new-job-type" class="search-input" value="none" placeholder="Job type (e.g. leo)"><select id="new-job-duty" class="select-input"><option value="true">Default duty: on</option><option value="false">Default duty: off</option></select><select id="new-job-offduty" class="select-input"><option value="false">No off-duty pay</option><option value="true">Pay off duty</option></select><textarea id="new-job-grades" class="search-input" rows="4" placeholder="Grade definitions JSON">{"0":{"name":"Recruit","payment":0},"1":{"name":"Employee","payment":100}}</textarea></div><button id="create-job" class="action-button" style="margin-top:12px">REGISTER JOB LIVE</button><p class="muted">Supports configurable grades. Runtime registration uses the QBCore shared table or the native Qbox CreateJob export. Qbox jobs are runtime-only in qbx_core; Power Admin stores them in its own database and re-registers them on startup.</p></section>`:(can('jobs.create') && state.data?.framework==='esx'?'<section class="page-panel" style="margin-top:14px"><h3>Job creation unavailable for this ESX adapter</h3><p class="muted">ESX job and grade schemas vary by version. Existing jobs can be browsed; creation requires a custom ESX adapter.</p></section>':'')}`;
    }
    content.innerHTML=`<div class="welcome-row"><div><div class="eyebrow">SERVER DATA / ${kind.toUpperCase()}</div><h2>${kind==='vehicles'?'Vehicle':kind==='items'?'Item':'Job'} <span>management.</span></h2><p>${kind==='vehicles'?'Browse shared vehicles, spawn for yourself, or register and deliver a vehicle to another player.':kind==='items'?'Search item definitions, give quantities, or register a new item.':'Browse framework jobs and register a new runtime job.'}</p></div><div class="date-chip">${filtered.length} RESULTS</div></div><div class="toolbar"><input id="catalog-search" class="search-input" placeholder="Search ${kind}..." value="${escapeHtml(state.catalogSearch)}">${catSelect}<button id="catalog-refresh" class="action-button">↻ REFRESH</button></div>${body}`;
    document.getElementById('catalog-search').addEventListener('input',e=>{state.catalogSearch=e.target.value;renderCatalog(kind);const x=document.getElementById('catalog-search');x.focus();x.setSelectionRange(x.value.length,x.value.length)});
    document.getElementById('catalog-category').addEventListener('change',e=>{state.catalogCategory=e.target.value;renderCatalog(kind)});
    document.getElementById('catalog-refresh').onclick=()=>requestCatalog(kind);
    if(kind==='items') {
      content.querySelectorAll('[data-item-name]').forEach(b=>b.onclick=()=>{state.selectedItem=b.dataset.itemName;renderCatalog(kind)});
      const give=document.getElementById('give-item'); if(give) give.onclick=()=>{const target=Number(document.getElementById('item-target').value),amount=Number(document.getElementById('item-amount').value);if(!state.selectedItem||!Number.isInteger(amount)||amount<1||amount>10000){toast('Choose an item and valid quantity.',true);return}sendAction({action:'item.give',name:state.selectedItem,target,amount})};
      const create=document.getElementById('create-item'); if(create) create.onclick=()=>{const payload={action:'item.create',name:document.getElementById('new-item-name').value.trim(),label:document.getElementById('new-item-label').value.trim(),weight:Number(document.getElementById('new-item-weight').value),image:document.getElementById('new-item-image').value.trim(),description:document.getElementById('new-item-description').value.trim(),unique:document.getElementById('new-item-unique').value==='true',useable:document.getElementById('new-item-useable').value==='true'};if(!payload.name||!payload.label){toast('Item name and label are required.',true);return}sendAction(payload)};
    }
    if(kind==='vehicles') {
      content.querySelectorAll('[data-spawn-model]').forEach(b=>b.onclick=()=>sendAction({action:'vehicle.spawn',model:b.dataset.spawnModel}));
      content.querySelectorAll('[data-give-model]').forEach(b=>b.onclick=()=>{const target=Number(document.getElementById('vehicle-target')?.value);if(!target){toast('Select a connected player first.',true);return}sendAction({action:'vehicle.give',model:b.dataset.giveModel,target})});
    }
    if(kind==='jobs') {const create=document.getElementById('create-job');if(create)create.onclick=()=>{const payload={action:'job.create',name:document.getElementById('new-job-name').value.trim(),label:document.getElementById('new-job-label').value.trim(),type:document.getElementById('new-job-type').value.trim()||'none',defaultDuty:document.getElementById('new-job-duty').value==='true',offDutyPay:document.getElementById('new-job-offduty').value==='true',grades:{}};try{payload.grades=JSON.parse(document.getElementById('new-job-grades').value)}catch(e){toast('Grades must be valid JSON.',true);return}if(!payload.name||!payload.label||!payload.grades||typeof payload.grades!=='object'){toast('Job name, label and grade definitions are required.',true);return}sendAction(payload)}}
  }

  function renderDeveloperTools() {
    content.innerHTML = `
      <div class="welcome-row"><div><div class="eyebrow">DEVELOPER WORKSPACE</div><h2>Developer <span>tools.</span></h2><p>Utilities for building, testing and positioning resources in your world.</p></div><div class="date-chip">STAFF UTILITY</div></div>
      <div class="section-heading"><div><div class="eyebrow">WORLD INSPECTION</div><h3>Coordinate tools</h3></div><span class="subtle-label">LIVE UTILITIES</span></div>
      <div class="quick-grid">
        <button class="quick-card" id="open-coords-tool" type="button"><span class="quick-icon cyan">⌖</span><strong>Coords</strong><small>Open the live coordinate panel while keeping player movement enabled</small><span class="card-arrow">↗</span></button>
        ${can('entities.spawn') ? '<button class="quick-card" id="open-object-spawner" type="button"><span class="quick-icon violet">▦</span><strong>Spawn Object</strong><small>Choose a prop model and place it precisely in the world with a live preview</small><span class="card-arrow">↗</span></button>' : ''}
      </div>
      <p class="muted" style="margin-top:14px">Coords: use the arrow keys to select a format, Enter to copy, and Escape to close. Object placement: aim at a surface, use the arrow keys to rotate, scroll to adjust distance, E to place or Backspace to cancel.</p>`;
    const button = document.getElementById('open-coords-tool');
    if (button) button.addEventListener('click', async () => { await nui('vector'); });
    const objectButton = document.getElementById('open-object-spawner');
    if (objectButton) objectButton.addEventListener('click', openObjectSpawner);
  }

  let objectCatalogPromise = null;
  const OBJECT_CATALOG_URL = 'https://fam-tools.com/data/props.json';
  const OBJECT_THUMB_URL = 'https://fam-tools.com/props-3d/thumb/';

  function normalizeObjectCatalog(payload) {
    if (Array.isArray(payload)) return payload.map(row => typeof row === 'string' ? { name: row } : row).filter(row => row && row.name);
    const rows = Array.isArray(payload?.rows) ? payload.rows : (Array.isArray(payload?.data) ? payload.data : []);
    const cols = payload?.cols || payload?.columns || payload?.fields || [];
    if (rows.length && Array.isArray(rows[0]) && Array.isArray(cols)) {
      return rows.map(row => Object.fromEntries(cols.map((key, index) => [String(key), row[index]]))).filter(row => row.name);
    }
    return rows.filter(row => row && row.name);
  }

  function loadObjectCatalog() {
    if (!objectCatalogPromise) {
      objectCatalogPromise = fetch(OBJECT_CATALOG_URL, { mode: 'cors', cache: 'force-cache' })
        .then(response => { if (!response.ok) throw new Error(`Catalogue HTTP ${response.status}`); return response.json(); })
        .then(normalizeObjectCatalog)
        .then(rows => { if (!rows.length) throw new Error('The prop catalogue returned no models.'); return rows; })
        .catch(error => { objectCatalogPromise = null; throw error; });
    }
    return objectCatalogPromise;
  }

  function openObjectSpawner() {
    const existing = document.getElementById('pam-object-dialog');
    if (existing) existing.remove();
    const presets = [
      ['prop_toolchest_05','Tool chest'], ['prop_barrel_02a','Barrel'],
      ['prop_box_wood02a_pu','Wood crate'], ['prop_table_03','Table'],
      ['prop_chair_01a','Chair'], ['prop_roadcone02a','Road cone'],
      ['prop_barrier_work05','Road barrier'], ['prop_mp_cone_02','Traffic cone']
    ];
    const overlay = document.createElement('div');
    overlay.id = 'pam-object-dialog';
    overlay.className = 'dialog-overlay';
    overlay.innerHTML = `<section class="reason-dialog object-spawn-dialog">
      <div class="eyebrow">DEVELOPER TOOLS / WORLD BUILDER</div>
      <h3>Spawn <span>object.</span></h3>
      <p class="muted">Browse the GTA V object catalogue, preview prop pictures, or enter a custom/add-on model name. Select a model to begin precise placement.</p>
      <label class="object-model-label" for="pam-object-model">OBJECT MODEL NAME</label>
      <div class="object-model-entry"><input id="pam-object-model" class="search-input" maxlength="64" autocomplete="off" spellcheck="false" placeholder="e.g. prop_toolchest_05"><button id="pam-object-start" class="action-button primary" type="button">PLACE</button></div>
      <div class="object-selected-preview" id="pam-object-selected"><div class="object-preview-empty">Select a prop from the catalogue</div></div>
      <div class="object-catalog-toolbar"><input id="pam-object-search" class="search-input" placeholder="Search 21,631 models by name or hash..."><select id="pam-object-group" class="search-input"><option value="all">All model groups</option><option value="props">Props</option><option value="interior">Interior</option><option value="mission">Mission</option><option value="world">World & DLC</option><option value="helper">LOD & helper</option></select></div>
      <div class="object-catalog-status" id="pam-object-status">Loading GTA V prop catalogue…</div>
      <div class="object-catalog-grid" id="pam-object-grid"></div>
      <button id="pam-object-more" class="action-button object-more" type="button" hidden>SHOW MORE</button>
      <div class="object-preset-label">QUICK PICKS</div>
      <div class="object-presets">${presets.map(([model,label]) => `<button type="button" class="object-preset" data-model="${model}"><strong>${label}</strong><small>${model}</small></button>`).join('')}</div>
      <div class="object-placement-note"><strong>Placement controls</strong><span>← / → rotate · Mouse wheel adjusts distance · E place · Backspace cancel</span></div>
      <div class="dialog-actions"><button id="pam-object-cancel" class="action-button">CLOSE</button></div>
    </section>`;
    app.appendChild(overlay);

    const input = document.getElementById('pam-object-model');
    const search = document.getElementById('pam-object-search');
    const group = document.getElementById('pam-object-group');
    const grid = document.getElementById('pam-object-grid');
    const status = document.getElementById('pam-object-status');
    const selected = document.getElementById('pam-object-selected');
    const more = document.getElementById('pam-object-more');
    let catalogue = [];
    let filtered = [];
    let shown = 0;
    let selectedModel = '';
    const pageSize = 72;

    function selectModel(model, label, hash, hasThumb = true) {
      selectedModel = model;
      input.value = model;
      const thumb = `${OBJECT_THUMB_URL}${encodeURIComponent(model)}.png`;
      selected.innerHTML = `<div class="object-selected-image"><img src="${thumb}" alt="${escapeHtml(label || model)}" onerror="this.style.display='none';this.parentElement.classList.add('no-image')"><span>${escapeHtml((label || model).slice(0,2).toUpperCase())}</span></div><div class="object-selected-meta"><strong>${escapeHtml(label || model)}</strong><code>${escapeHtml(model)}</code><small>${escapeHtml(hash || 'Hash unavailable')}</small></div>`;
      grid.querySelectorAll('.object-catalog-card').forEach(card => card.classList.toggle('selected', card.dataset.model === model));
    }

    function renderGrid(reset = false) {
      if (reset) { shown = 0; grid.innerHTML = ''; }
      const query = search.value.trim().toLowerCase();
      const selectedGroup = group.value;
      filtered = catalogue.filter(item => {
        const name = String(item.name || '');
        const groupName = String(item.group || '');
        const hash = String(item.hash_hex || '');
        return (selectedGroup === 'all' || groupName === selectedGroup) && (!query || name.toLowerCase().includes(query) || hash.toLowerCase().includes(query));
      });
      const next = filtered.slice(shown, shown + pageSize);
      next.forEach(item => {
        const model = String(item.name);
        const label = String(item.group_label || item.group || 'GTA V object');
        const hash = String(item.hash_hex || '');
        const thumb = `${OBJECT_THUMB_URL}${encodeURIComponent(model)}.png`;
        const card = document.createElement('button');
        card.type = 'button'; card.className = 'object-catalog-card'; card.dataset.model = model;
        card.innerHTML = `<span class="object-card-image"><img loading="lazy" src="${thumb}" alt="${escapeHtml(model)}" onerror="this.style.display='none';this.parentElement.classList.add('no-image')"><span>${escapeHtml(model.slice(0,2).toUpperCase())}</span></span><span class="object-card-name">${escapeHtml(model)}</span><span class="object-card-meta">${escapeHtml(label)}${hash ? ' · '+escapeHtml(hash) : ''}</span>`;
        card.addEventListener('click', () => selectModel(model, label, hash));
        grid.appendChild(card);
      });
      shown += next.length;
      status.textContent = `${filtered.length.toLocaleString()} matching models · showing ${shown.toLocaleString()}${catalogue.length ? ` of ${catalogue.length.toLocaleString()}` : ''}`;
      more.hidden = shown >= filtered.length;
      more.textContent = `SHOW MORE (${Math.max(0, filtered.length - shown).toLocaleString()} remaining)`;
    }

    async function start() {
      const model = input.value.trim();
      if (!/^[a-zA-Z0-9_]{3,64}$/.test(model)) { toast('Enter a valid model name (letters, numbers and underscores).', true); input.focus(); return; }
      const result = await nui('spawnObject', { model });
      if (result && result.success) overlay.remove();
    }

    overlay.querySelectorAll('[data-model]').forEach(button => button.addEventListener('click', () => {
      selectModel(button.dataset.model, button.querySelector('strong')?.textContent || button.dataset.model, 'Quick pick');
      input.focus();
    }));
    document.getElementById('pam-object-cancel').onclick = () => overlay.remove();
    document.getElementById('pam-object-start').onclick = start;
    input.addEventListener('keydown', event => { if (event.key === 'Enter') start(); });
    search.addEventListener('input', () => renderGrid(true));
    group.addEventListener('change', () => renderGrid(true));
    more.addEventListener('click', () => renderGrid(false));

    loadObjectCatalog().then(rows => {
      catalogue = rows;
      status.textContent = `Loaded ${catalogue.length.toLocaleString()} GTA V object models. Images are shown where available.`;
      renderGrid(true);
    }).catch(error => {
      status.textContent = 'Could not load the online catalogue. You can still enter any GTA/custom model name above.';
      toast('GTA V prop catalogue unavailable. Manual model entry remains available.', true);
      console.warn('[Power Admin] Prop catalogue load failed:', error);
    });
    input.focus();
  }

  function navigate(page) {
    if (!pageNames[page]) return;
    state.page = page;
    title.textContent = pageNames[page];
    breadcrumb.textContent = page.toUpperCase();
    document.querySelectorAll('.nav-item').forEach(button => button.classList.toggle('active', button.dataset.page === page));
    if (page === 'overview') { content.innerHTML = overviewMarkup; renderOverview(); }
    if (page === 'players') { state.dossier=null; renderPlayers(); }
    if (page === 'vehicles' || page === 'items' || page === 'jobs') { state.catalogSearch=''; state.catalogCategory='all'; renderCatalog(page); requestCatalog(page); }
    if (page === 'bans') sendAction({action:'bans.search'});
    if (page === 'world') renderWorld();
    if (page === 'security') renderSecurity();
    if (page === 'system') renderSystem();
    if (page === 'developer') renderDeveloperTools();
  }

  async function sendAction(payload) {
    const result = await nui('action', payload);
    if (result && result.success) toast('Request sent to server for validation.');
  }

  function openReasonDialog(target, action) {
    const existing = document.getElementById('pam-reason-dialog');
    if (existing) existing.remove();
    const overlay = document.createElement('div');
    overlay.id = 'pam-reason-dialog';
    overlay.className = 'dialog-overlay';
    overlay.innerHTML = `<section class="reason-dialog"><div class="eyebrow">SENSITIVE ADMIN ACTION</div><h3>Kick player #${target}</h3><p class="muted">A reason is required and will be recorded in the audit trail.</p><input id="pam-kick-reason" class="search-input" maxlength="250" placeholder="Enter a clear moderation reason..."><div class="dialog-actions"><button id="pam-dialog-cancel" class="action-button">CANCEL</button><button id="pam-dialog-submit" class="action-button danger">CONFIRM KICK</button></div></section>`;
    app.appendChild(overlay);
    const input = document.getElementById('pam-kick-reason');
    input.focus();
    document.getElementById('pam-dialog-cancel').addEventListener('click', () => overlay.remove());
    document.getElementById('pam-dialog-submit').addEventListener('click', () => {
      const reason = input.value.trim();
      if (!reason) { toast('Please enter a reason.', true); input.focus(); return; }
      overlay.remove();
      sendAction({ action, target, reason });
    });
  }

  function openPhase2Dialog(target, action) {
    const overlay=document.createElement('div'); overlay.className='dialog-overlay'; overlay.id='pam-phase2-dialog';
    const titleMap={'player.kick':'Kick player','player.warn':'Issue warning','player.ban':'Ban player','player.note.add':'Add staff note','player.money.adjust':'Adjust player balance'};
    let fields='<input id="pam-reason" class="search-input" maxlength="250" placeholder="Reason (required)">';
    if(action==='player.note.add') fields='<textarea id="pam-note" class="search-input" maxlength="1000" placeholder="Staff note (required)"></textarea>';
    if(action==='player.money.adjust') fields='<select id="pam-account" class="select-input"><option value="cash">Cash</option><option value="bank">Bank</option></select><input id="pam-amount" class="search-input" type="number" step="1" placeholder="Positive to add, negative to remove"><input id="pam-reason" class="search-input" maxlength="250" placeholder="Reason (required)">';
    if(action==='player.ban') fields+='<input id="pam-days" class="search-input" type="number" min="0" max="3650" value="0" placeholder="Days (0 = permanent)">';
    overlay.innerHTML=`<section class="reason-dialog"><div class="eyebrow">PLAYER INTELLIGENCE / #${target}</div><h3>${titleMap[action]||'Confirm action'}</h3><p class="muted">This operation is checked again by the server and recorded where applicable.</p>${fields}<div class="dialog-actions"><button id="pam-cancel" class="action-button">CANCEL</button><button id="pam-confirm" class="action-button danger">CONFIRM</button></div></section>`;
    app.appendChild(overlay);
    document.getElementById('pam-cancel').onclick=()=>overlay.remove();
    document.getElementById('pam-confirm').onclick=()=>{
      const payload={action,target};
      if(action==='player.note.add') payload.note=document.getElementById('pam-note').value.trim();
      else payload.reason=document.getElementById('pam-reason')?.value.trim()||'';
      if(action==='player.money.adjust'){payload.account=document.getElementById('pam-account').value;payload.amount=Number(document.getElementById('pam-amount').value);}
      if(action==='player.ban') payload.days=Number(document.getElementById('pam-days').value);
      if(!payload.reason && action!=='player.note.add' || action==='player.note.add'&&!payload.note){toast('A reason or note is required.',true);return;}
      overlay.remove(); sendAction(payload);
    };
  }

  document.addEventListener('click', event => {
    const nav = event.target.closest('[data-page]');
    if (nav) navigate(nav.dataset.page);
    const go = event.target.closest('[data-go]');
    if (go) navigate(go.dataset.go);
    const actionButton = event.target.closest('[data-action]');
    if (actionButton) {
      const action = actionButton.dataset.action;
      const target = Number(actionButton.dataset.target);
      const payload = { action, target };
      if (action === 'player.freeze') { payload.value = actionButton.dataset.value === 'true'; state.frozen[payload.value ? 'add' : 'delete'](target); }
      if (action === 'player.kick' || action === 'player.warn' || action === 'player.ban' || action === 'player.note.add' || action === 'player.money.adjust') { openPhase2Dialog(target, action); return; }
      if (action === 'player.unban') { payload.banId = Number(actionButton.dataset.banid); state.page='bans'; }
      sendAction(payload);
      if (state.page === 'players') renderPlayers();
    }
  });

  document.getElementById('close-button').addEventListener('click', () => nui('close'));
  document.getElementById('top-close').addEventListener('click', () => nui('close'));
  document.getElementById('refresh-button').addEventListener('click', () => nui('refresh'));
  document.addEventListener('keydown', event => {
    const placement = document.getElementById('pam-object-placement-ui');
    const placing = placement && !placement.classList.contains('hidden');
    if (placing) {
      const keys = {
        KeyW: ['moveY', 1], KeyS: ['moveY', -1], KeyA: ['moveX', -1], KeyD: ['moveX', 1],
        PageUp: ['moveZ', 1], PageDown: ['moveZ', -1],
        ArrowLeft: ['moveX', -1], ArrowRight: ['moveX', 1],
        ArrowUp: ['rotZ', -1], ArrowDown: ['rotZ', 1],
        KeyQ: ['rotX', 1], KeyR: ['rotX', -1]
      };
      if (event.code === 'ControlLeft') { event.preventDefault(); nui('objectPlacementControl', { control: 'toggleCursor' }); return; }
      if (event.code === 'Enter') { event.preventDefault(); nui('objectPlacementControl', { control: 'place' }); return; }
      if (event.code === 'Escape' || event.code === 'Backspace') { event.preventDefault(); nui('objectPlacementControl', { control: 'cancel' }); return; }
      if (keys[event.code]) { event.preventDefault(); nui('objectPlacementControl', { control: keys[event.code][0], value: keys[event.code][1] }); }
      return;
    }
    if (event.key === 'Escape') nui('close');
  });
  setInterval(() => { if (!app.classList.contains('hidden') && ((state.page === 'players' && state.subview === 'list') || state.page === 'vehicles')) nui('refresh'); }, 15000);

  function ensureObjectPlacementPanel() {
    let panel = document.getElementById('pam-object-placement-ui');
    if (panel) return panel;
    panel = document.createElement('section');
    panel.id = 'pam-object-placement-ui';
    panel.className = 'hidden';
    panel.innerHTML = `
      <div class="pam-place-head"><div><strong>OBJECT TRANSFORM GIZMO</strong><small id="pam-place-model">Placing object…</small></div><span class="pam-place-live">LIVE PREVIEW</span></div>
      <div class="pam-place-cursor-state" id="pam-place-cursor-state">MOUSE CURSOR: ON · LEFT CTRL TO HIDE</div>
      <div class="pam-place-coords"><span>X POSITION<b id="pam-place-x">0.000</b></span><span>Y POSITION<b id="pam-place-y">0.000</b></span><span>Z POSITION<b id="pam-place-z">0.000</b></span></div>
      <div class="pam-place-coords"><span>ROT X<b id="pam-place-rx">0.0°</b></span><span>ROT Y<b id="pam-place-ry">0.0°</b></span><span>ROT Z<b id="pam-place-rz">0.0°</b></span></div>
      <div class="pam-gizmo-section"><div class="pam-gizmo-title"><span>MOVE · WORLD AXES</span><span>± STEP</span></div>
        <div class="pam-gizmo-row"><b class="pam-gizmo-axis x">X</b><button data-place="moveX" data-value="-1">− X</button><button data-place="moveX" data-value="1">+ X</button><button data-place="resetOffset">RESET</button></div>
        <div class="pam-gizmo-row"><b class="pam-gizmo-axis y">Y</b><button data-place="moveY" data-value="-1">− Y</button><button data-place="moveY" data-value="1">+ Y</button><span></span></div>
        <div class="pam-gizmo-row"><b class="pam-gizmo-axis z">Z</b><button data-place="moveZ" data-value="-1">− Z</button><button data-place="moveZ" data-value="1">+ Z</button><span></span></div>
      </div>
      <div class="pam-gizmo-section"><div class="pam-gizmo-title"><span>ROTATE · EULER AXES</span><span>± STEP</span></div>
        <div class="pam-gizmo-row"><b class="pam-gizmo-axis x">RX</b><button data-place="rotX" data-value="-1">− X</button><button data-place="rotX" data-value="1">+ X</button><button data-place="resetRotation">RESET</button></div>
        <div class="pam-gizmo-row"><b class="pam-gizmo-axis y">RY</b><button data-place="rotY" data-value="-1">− Y</button><button data-place="rotY" data-value="1">+ Y</button><span></span></div>
        <div class="pam-gizmo-row"><b class="pam-gizmo-axis z">RZ</b><button data-place="rotZ" data-value="-1">− Z</button><button data-place="rotZ" data-value="1">+ Z</button><span></span></div>
      </div>
      <div class="pam-gizmo-section"><div class="pam-gizmo-title"><span>MOVE STEP</span><select id="pam-place-step" class="pam-step-select"><option value="0.01">0.01 · Fine</option><option value="0.05">0.05</option><option value="0.1" selected>0.10 · Normal</option><option value="0.25">0.25</option><option value="1">1.00 · Coarse</option></select></div>
        <div class="pam-gizmo-title" style="margin-top:8px"><span>ROTATION STEP</span><select id="pam-place-rotation-step" class="pam-step-select"><option value="1">1° · Fine</option><option value="5" selected>5° · Normal</option><option value="15">15°</option><option value="45">45° · Coarse</option></select></div></div>
      <div class="pam-place-actions"><button class="place-cancel" data-place="cancel">CANCEL · ESC</button><button class="place-confirm" data-place="place">PLACE OBJECT · ENTER</button></div>
      <div class="pam-place-keys">LEFT CTRL toggles mouse cursor · Aim camera for surface anchor · WASD moves X/Y · Page Up/Down moves Z · ←/→ moves X · ↑/↓ rotates Z · Q/R rotate X · Mouse wheel changes distance</div>`;
    document.body.appendChild(panel);
    panel.addEventListener('click', event => {
      const button = event.target.closest('[data-place]');
      if (!button) return;
      const control = button.dataset.place;
      nui('objectPlacementControl', { control, value: button.dataset.value === undefined ? undefined : Number(button.dataset.value) });
    });
    panel.querySelector('#pam-place-step').addEventListener('change', event => nui('objectPlacementControl', { control: 'step', value: Number(event.target.value) }));
    panel.querySelector('#pam-place-rotation-step').addEventListener('change', event => nui('objectPlacementControl', { control: 'rotationStep', value: Number(event.target.value) }));
    return panel;
  }

  window.addEventListener('message', event => {
    const message = event.data || {};
    if (message.type === 'PAM_OBJECT_PLACEMENT') {
      const panel = ensureObjectPlacementPanel();
      panel.classList.toggle('hidden', !message.visible);
      if (message.model) panel.querySelector('#pam-place-model').textContent = message.model;
    }
    if (message.type === 'PAM_OBJECT_PLACEMENT_CURSOR') {
      const cursorState = document.getElementById('pam-place-cursor-state');
      if (cursorState) cursorState.textContent = message.visible ? 'MOUSE CURSOR: ON · LEFT CTRL TO HIDE' : 'MOUSE CURSOR: OFF · LEFT CTRL TO SHOW';
    }
    if (message.type === 'PAM_OBJECT_PLACEMENT_STATE') {
      const panel = ensureObjectPlacementPanel();
      const coords = message.coords || {};
      ['x','y','z'].forEach(axis => { const node = panel.querySelector(`#pam-place-${axis}`); if (node) node.textContent = Number(coords[axis] || 0).toFixed(3); });
      const rotation = message.rotation || {};
      ['x','y','z'].forEach(axis => { const node = panel.querySelector(`#pam-place-r${axis}`); if (node) node.textContent = `${Number(rotation[axis] || 0).toFixed(1)}°`; });
      const step = panel.querySelector('#pam-place-step');
      if (step && message.step !== undefined) step.value = String(message.step);
      const rotationStep = panel.querySelector('#pam-place-rotation-step');
      if (rotationStep && message.rotationStep !== undefined) rotationStep.value = String(message.rotationStep);
    }
    if (message.type === 'PAM_VISIBILITY') {
      app.classList.toggle('hidden', !message.visible);
      app.setAttribute('aria-hidden', String(!message.visible));
      if (message.visible) navigate('overview');
    }
    if (message.type === 'PAM_BOOTSTRAP') {
      state.data = message.payload || {};
      renderOverview();
      if (state.page !== 'overview') navigate(state.page);
    }
    if (message.type === 'PAM_CATALOG') { if(['vehicles','items','jobs'].includes(message.kind)){state.catalogs[message.kind]=message.payload||[];if(state.page===message.kind)renderCatalog(message.kind);} }
    if (message.type === 'PAM_PLAYER_LIST') { if(state.data) state.data.players=message.payload||[]; if(state.page==='players') renderPlayers(); else if(state.page==='vehicles') renderCatalog('vehicles'); }
    if (message.type === 'PAM_PLAYER_DOSSIER') renderDossier(message.payload||{});
    if (message.type === 'PAM_BAN_LIST') renderBans(message.payload||[]);
    if (message.type === 'PAM_SPECTATE_STATE' && message.active) toast(`Spectating player #${message.target}. Use /pamspectatestop or wait for disconnect.`);
    if (message.type === 'PAM_ACTION_RESULT') {
      const result = message.payload || {};
      toast(result.message || (result.success ? 'Action completed.' : 'Action failed.'), !result.success);
      if (result.success && (result.action === 'player.ban' || result.action === 'player.kick')) {
        state.dossier = null;
        nui('refresh');
      } else if (result.success && ['player.note.add','player.warn','player.money.adjust','player.unban'].includes(result.action)) {
        if (state.page === 'players' && state.dossier) sendAction({action:'player.dossier',target:state.dossier.id});
        else if (state.page === 'players') nui('refresh');
        else if (state.page === 'bans' && result.action === 'player.unban') sendAction({action:'bans.search'});
      }
    }
  });
})();
