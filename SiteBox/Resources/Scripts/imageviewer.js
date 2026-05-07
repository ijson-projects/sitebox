// 原生图片查看器 - 智能拦截图片点击
// 只拦截明确是"查看大图"的场景，放过按钮/表情/贴图等 UI 元素
(function() {
    'use strict';

    var IMAGE_EXTENSIONS = /\.(jpg|jpeg|png|gif|webp|bmp|svg|heic|heif|avif)(\?.*)?$/i;
    var MIN_DISPLAY_SIZE = 200; // 展示尺寸小于 200px 的不拦截（图标/表情）

    // 判断元素是否为可交互控件（不应拦截的）
    function isInteractiveElement(el) {
        if (!el) return false;
        var tag = el.tagName;
        // 按钮类元素
        if (tag === 'BUTTON' || tag === 'INPUT' || tag === 'SELECT' || tag === 'TEXTAREA') return true;
        if (tag === 'LABEL') return true;
        // ARIA role 暗示可交互
        var role = el.getAttribute('role') || '';
        if (/button|tab|menuitem|option|switch|checkbox|radio|link/i.test(role)) return true;
        // 有 onclick 处理器
        if (el.onclick || el.getAttribute('onclick')) return true;
        return false;
    }

    // 检查图片是否在可交互容器中（向上遍历）
    function isInsideInteractive(img) {
        var el = img.parentElement;
        var depth = 0;
        while (el && depth < 5) {
            if (isInteractiveElement(el)) return true;
            // 检查是否有点击事件监听器（无法直接检测 JS addEventListener，查 cursor:pointer 作为信号）
            var style = window.getComputedStyle(el);
            if (style.cursor === 'pointer' && el.tagName !== 'A') return true;
            el = el.parentElement;
            depth++;
        }
        return false;
    }

    // 获取图片 URL（仅限"查看大图"场景）
    function getViewableImageUrl(target) {
        // Case 1: <a href="image.jpg"> ... </a>
        // 这是最明确的"点击查看大图"信号
        if (target.tagName === 'A') {
            var href = target.getAttribute('href') || '';
            if (IMAGE_EXTENSIONS.test(href)) {
                var a = document.createElement('a');
                a.href = href;
                return a.href;
            }
            return null;
        }

        // Case 2: <img> 标签
        if (target.tagName === 'IMG') {
            var img = target;
            var src = img.src || '';
            if (!src || src === 'about:blank' || src.startsWith('data:')) return null;

            // 太小不拦截（图标、表情）
            var w = img.naturalWidth || img.offsetWidth || 0;
            var h = img.naturalHeight || img.offsetHeight || 0;
            if (w > 0 && h > 0 && (w < MIN_DISPLAY_SIZE || h < MIN_DISPLAY_SIZE)) return null;

            // 在可交互容器中不拦截（按钮内的图标、表情包按钮等）
            if (isInsideInteractive(img)) return null;

            // 父元素是 <a> 且 href 是图片 → 用 href（高清原图）
            var parent = img.parentElement;
            if (parent && parent.tagName === 'A') {
                var parentHref = parent.getAttribute('href') || '';
                if (IMAGE_EXTENSIONS.test(parentHref)) {
                    var a2 = document.createElement('a');
                    a2.href = parentHref;
                    return a2.href;
                }
            }

            return src;
        }

        return null;
    }

    function openNativeViewer(imageUrl) {
        console.log('[SiteBox] 打开原生图片查看器: ' + imageUrl);
        try {
            window.webkit.messageHandlers.imageViewer.postMessage({ url: imageUrl });
            return true;
        } catch (e) {
            console.warn('[SiteBox] 无法调用原生查看器: ' + e.message);
            return false;
        }
    }

    // 主拦截：只处理明确指向图片 URL 的点击
    document.addEventListener('click', function(e) {
        var imageUrl = getViewableImageUrl(e.target);
        if (!imageUrl) return;

        e.preventDefault();
        e.stopPropagation();
        openNativeViewer(imageUrl);
    }, true);

    console.log('[SiteBox] 原生图片查看器已就绪');
})();
