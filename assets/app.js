(function(){
  const btn = document.querySelector('[data-sidebar-toggle]');
  const sidebar = document.querySelector('.sidebar');
  const backdrop = document.querySelector('[data-backdrop]');
  function close(){
    sidebar?.classList.remove('open');
    backdrop?.classList.remove('show');
  }
  function open(){
    sidebar?.classList.add('open');
    backdrop?.classList.add('show');
  }
  btn?.addEventListener('click', () => {
    if(sidebar?.classList.contains('open')) close();
    else open();
  });
  backdrop?.addEventListener('click', close);
  window.addEventListener('keydown', (e) => {
    if(e.key === 'Escape') close();
  });
})();
