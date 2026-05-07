// Remove dark mode CSS script
(function() {
    var style = document.getElementById('webappwrapper-dark-mode');
    if (style) {
        style.remove();
        console.log('Dark mode CSS removed');
    }
})();
