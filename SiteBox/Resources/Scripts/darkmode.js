// Dark Mode CSS injection script
// Injected by SiteBox when system/app theme changes to dark mode

(function() {
    // Remove old style if exists
    var oldStyle = document.getElementById('webappwrapper-dark-mode');
    if (oldStyle) {
        oldStyle.remove();
    }

    // Create new style element
    var style = document.createElement('style');
    style.id = 'webappwrapper-dark-mode';
    style.type = 'text/css';

    var css = document.body.getAttribute('data-webapp-dark-css') || [
        "html { background-color: #1e1e1e !important; color: #e0e0e0 !important; }",
        "body { background-color: #1e1e1e !important; color: #e0e0e0 !important; }",
        "div, section, article, main, header, footer, nav, aside { background-color: #1e1e1e !important; color: #e0e0e0 !important; }",
        "input, textarea, select { background-color: #2d2d2d !important; color: #e0e0e0 !important; border-color: #404040 !important; }",
        "a { color: #4a9eff !important; }",
        "a:visited { color: #b19cd9 !important; }",
        "button, [role=\"button\"] { background-color: #2d2d2d !important; color: #e0e0e0 !important; border-color: #404040 !important; }",
        ".card, .panel, [class*=\"card\"], [class*=\"panel\"] { background-color: #252525 !important; color: #e0e0e0 !important; }",
        "code, pre { background-color: #2d2d2d !important; color: #e0e0e0 !important; }"
    ].join('\n');

    // Escape backticks and dollar signs for template literal
    css = css.replace(/\\/g, '\\\\').replace(/`/g, '\\`').replace(/\$/g, '\\$');
    style.innerHTML = css;
    document.head.appendChild(style);
    console.log('Dark mode CSS injected');
})();
