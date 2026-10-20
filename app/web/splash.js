// Removes the splash in index.html once Flutter renders its first frame.
// (A file, not an inline script, so the Content-Security-Policy needs no
// 'unsafe-inline' for scripts.)
window.addEventListener('flutter-first-frame', function () {
  var s = document.getElementById('splash');
  if (!s) return;
  s.style.opacity = '0';
  setTimeout(function () { s.remove(); }, 300);
});
