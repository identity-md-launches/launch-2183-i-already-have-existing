try {
  await import('./assets-future-v1/index-IgEJPNDv.js');
} catch (error) {
  const root = document.getElementById('root');
  const section = document.createElement('section');
  section.style.cssText = 'max-width:640px;margin:10vh auto;padding:2rem;color:#e9eddf;font:16px/1.6 system-ui';
  const title = document.createElement('h1');
  title.textContent = 'IMDPot is waiting for its new deployment';
  const message = document.createElement('p');
  message.textContent = error instanceof Error ? error.message : 'The game could not be loaded.';
  const retry = document.createElement('button');
  retry.textContent = 'Reload game';
  retry.onclick = () => location.reload();
  section.append(title, message, retry);
  root.replaceChildren(section);
}
