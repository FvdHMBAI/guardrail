if (new URLSearchParams(window.location.search).get('analytics') === 'off') {
  localStorage.setItem('umami.disabled', '1');
}
