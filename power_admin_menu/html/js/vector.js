(() => {
  const panel = document.getElementById('vector-tool');
  if (!panel) return;
  const options = [...document.querySelectorAll('.vector-option')];
  const status = document.getElementById('vector-copy-status');
  const copyButton = document.getElementById('vector-copy-button');
  const laserState = document.getElementById('laser-mode-state');
  const laserDetails = document.getElementById('laser-details');
  const laserStatus = document.getElementById('laser-target-status');
  const laserEmpty = document.getElementById('laser-target-empty');
  const laserInfo = document.getElementById('laser-target-info');
  let selected = 1;
  let isOpen = false;
  let laserActive = false;
  let target = null;
  const formats = ['vector3', 'vec3', 'vector4', 'vec4'];

  function select(index) {
    selected = ((Number(index) - 1 + options.length) % options.length) + 1;
    options.forEach((item, i) => item.classList.toggle('selected', i === selected - 1));
  }

  function playerValue() {
    const x = document.getElementById('vector-x').textContent;
    const y = document.getElementById('vector-y').textContent;
    const z = document.getElementById('vector-z').textContent;
    const h = document.getElementById('vector-heading').textContent;
    const format = formats[Math.min(selected - 1, 3)];
    const args = selected <= 2 ? `${x}, ${y}, ${z}` : `${x}, ${y}, ${z}, ${h}`;
    return `${format}(${args})`;
  }

  function targetValue() {
    if (!target) return null;
    const format = formats[Math.min(selected - 1, 3)];
    const args = selected <= 2
      ? `${target.x.toFixed(3)}, ${target.y.toFixed(3)}, ${target.z.toFixed(3)}`
      : `${target.x.toFixed(3)}, ${target.y.toFixed(3)}, ${target.z.toFixed(3)}, ${target.heading.toFixed(3)}`;
    return `${format}(${args})`;
  }

  async function copyText(value, label = 'coordinates') {
    if (!value) {
      status.textContent = 'No entity targeted. Aim the laser at an entity first.';
      status.classList.remove('copied');
      return;
    }
    let copied = false;
    try {
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(value);
        copied = true;
      }
    } catch (_) { /* use the FiveM NUI-compatible fallback */ }
    if (!copied) {
      const input = document.createElement('textarea');
      input.value = value;
      input.setAttribute('readonly', '');
      input.style.position = 'fixed';
      input.style.left = '-9999px';
      input.style.top = '0';
      document.body.appendChild(input);
      input.focus();
      input.select();
      input.setSelectionRange(0, input.value.length);
      try { copied = document.execCommand('copy') === true; } catch (_) { copied = false; }
      input.remove();
    }
    status.textContent = copied ? `Copied ${label}: ${value}` : `Clipboard unavailable — copy manually: ${value}`;
    status.classList.toggle('copied', copied);
  }

  function setLaser(active) {
    laserActive = !!active;
    laserState.textContent = laserActive ? 'ON · ENTER' : 'OFF · ENTER';
    options[4]?.classList.toggle('active', laserActive);
    laserStatus.textContent = laserActive ? (target ? 'TARGET LOCKED' : 'SCANNING') : 'INACTIVE';
    laserStatus.classList.toggle('active', laserActive);
    laserDetails.classList.toggle('has-target', !!target);
    if (!laserActive) setTarget(null);
  }

  function setTarget(data) {
    target = data || null;
    const hasTarget = !!target;
    laserEmpty.hidden = hasTarget;
    laserInfo.hidden = !hasTarget;
    laserDetails.classList.toggle('has-target', hasTarget);
    if (hasTarget) {
      laserStatus.textContent = 'TARGET LOCKED';
      document.getElementById('laser-type').textContent = target.type || 'Entity';
      document.getElementById('laser-model').textContent = target.model || '—';
      document.getElementById('laser-ids').textContent = `${target.entity ?? '—'} / ${target.netId || 'local'}`;
      document.getElementById('laser-health').textContent = `${target.health ?? '—'} / ${target.maxHealth ?? '—'}`;
      document.getElementById('laser-coords').textContent = `${target.x.toFixed(3)}, ${target.y.toFixed(3)}, ${target.z.toFixed(3)}`;
      document.getElementById('laser-heading').textContent = `${Number(target.heading || 0).toFixed(2)}°`;
      document.getElementById('laser-distance').textContent = `${Number(target.distance || 0).toFixed(2)} m`;
      document.getElementById('laser-extra').textContent = target.details || '—';
    } else {
      laserStatus.textContent = laserActive ? 'SCANNING' : 'INACTIVE';
    }
    laserStatus.classList.toggle('active', laserActive);
  }

  function toggleLaser() {
    fetch(`https://${GetParentResourceName()}/laserToggle`, {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: '{}'
    }).catch(() => {});
  }

  function deleteTarget() {
    if (!target) {
      status.textContent = 'No entity targeted to delete.';
      status.classList.remove('copied');
      return;
    }
    status.textContent = 'Sending delete request…';
    fetch(`https://${GetParentResourceName()}/laserDelete`, {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: '{}'
    }).catch(() => { status.textContent = 'Could not send delete request.'; });
  }

  copyButton?.addEventListener('click', () => copyText(playerValue(), 'player position'));
  options.forEach((item, index) => item.addEventListener('click', () => {
    select(index + 1);
    if (index === 4) toggleLaser();
  }));

  window.addEventListener('keydown', event => {
    if (!isOpen) return;
    if (['ArrowUp', 'ArrowLeft'].includes(event.key)) {
      event.preventDefault(); select(selected - 1);
    } else if (['ArrowDown', 'ArrowRight'].includes(event.key)) {
      event.preventDefault(); select(selected + 1);
    } else if (event.key === 'Enter') {
      event.preventDefault();
      if (selected === 5) toggleLaser();
      else copyText(playerValue(), 'player position');
    } else if (event.key.toLowerCase() === 'l') {
      event.preventDefault(); toggleLaser();
    } else if (event.key.toLowerCase() === 'c') {
      event.preventDefault(); copyText(targetValue(), 'entity coordinates');
    } else if (event.key === 'Delete') {
      event.preventDefault(); deleteTarget();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      fetch(`https://${GetParentResourceName()}/vectorClose`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: '{}'
      }).catch(() => {});
    }
  });

  window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.type === 'PAM_VECTOR_VISIBILITY') {
      isOpen = !!data.visible;
      panel.classList.toggle('visible', isOpen);
      panel.setAttribute('aria-hidden', String(!isOpen));
      if (isOpen) {
        select(data.selected || 1);
        setLaser(false);
        status.textContent = '↑ ↓ select · ENTER copy/toggle · L laser · C copy target · DEL delete';
        status.classList.remove('copied');
      }
    }
    if (data.type === 'PAM_VECTOR_SELECT') select(data.selected);
    if (data.type === 'PAM_VECTOR_UPDATE' && data.coords) {
      document.getElementById('vector-x').textContent = Number(data.coords.x).toFixed(3);
      document.getElementById('vector-y').textContent = Number(data.coords.y).toFixed(3);
      document.getElementById('vector-z').textContent = Number(data.coords.z).toFixed(3);
      document.getElementById('vector-heading').textContent = Number(data.coords.heading).toFixed(3);
    }
    if (data.type === 'PAM_LASER_MODE') setLaser(data.active);
    if (data.type === 'PAM_LASER_UPDATE') setTarget(data.target || null);
    if (data.type === 'PAM_LASER_DELETE_RESULT') {
      status.textContent = data.message || (data.success ? 'Entity deleted.' : 'Delete failed.');
      status.classList.toggle('copied', !!data.success);
      if (data.success) setTarget(null);
    }
  });
})();
