(function () {
  function apply(lang) {
    document.querySelectorAll('[data-lang-block]').forEach(function (el) {
      el.classList.toggle('active', el.getAttribute('data-lang-block') === lang);
    });
    document.querySelectorAll('.lang-toggle button').forEach(function (btn) {
      btn.classList.toggle('active', btn.getAttribute('data-lang') === lang);
    });
    try { localStorage.setItem('plainlaunch-lang', lang); } catch (e) {}
    document.documentElement.setAttribute('lang', lang);
  }

  function initialLang() {
    var params = new URLSearchParams(window.location.search);
    if (params.get('lang') === 'en' || params.get('lang') === 'ja') return params.get('lang');
    try {
      var stored = localStorage.getItem('plainlaunch-lang');
      if (stored) return stored;
    } catch (e) {}
    return navigator.language && navigator.language.startsWith('ja') ? 'ja' : 'en';
  }

  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('.lang-toggle button').forEach(function (btn) {
      btn.addEventListener('click', function () {
        apply(btn.getAttribute('data-lang'));
      });
    });
    apply(initialLang());
  });
})();
