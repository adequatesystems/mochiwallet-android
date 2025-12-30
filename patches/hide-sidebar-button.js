// Android-only patch: hide the panel toggle button
(function () {
  var MARK_ATTR = "data-android-hidden-panel";

  function hide(el) {
    if (!el || el.hasAttribute(MARK_ATTR)) return;
    el.setAttribute(MARK_ATTR, "true");
    el.style.setProperty("display", "none", "important");
    console.log("[Android Patch] Hidden panel button");
  }

  function scanAndHide() {
    // Find all buttons in the header area
    var headerButtons = document.querySelectorAll("[class*='border-b'] button, header button");
    
    headerButtons.forEach(function (btn) {
      if (btn.hasAttribute(MARK_ATTR)) return;
      
      var svg = btn.querySelector("svg");
      if (!svg) return;
      
      // Log what we find for debugging
      var rect = svg.querySelector("rect");
      var lines = svg.querySelectorAll("line");
      var paths = svg.querySelectorAll("path");
      
      // The panel button is the LAST button in the header (after network status)
      // It's NOT the menu button (first button, has 3 lines)
      // Check: has SVG, is in header, has rect OR has path (Lucide icons vary)
      
      // Skip if it has 3 lines (menu icon)
      if (lines.length === 3) return;
      
      // PanelRight can be: rect+line OR just paths
      // It's typically the rightmost button in the header
      var parent = btn.parentElement;
      if (!parent) return;
      
      // Check if this button is after a network status indicator (green/red dot)
      var prevSibling = btn.previousElementSibling;
      var hasDotBefore = false;
      if (prevSibling) {
        var dot = prevSibling.querySelector("span[class*='rounded-full']");
        if (dot) hasDotBefore = true;
      }
      
      // Also check: button with SVG that has rect, in header, not menu
      if (rect && lines.length <= 2) {
        console.log("[Android Patch] Found rect+line button, hiding");
        hide(btn);
        return;
      }
      
      // Check for path-based panel icon (some Lucide versions)
      if (paths.length > 0 && paths.length <= 3 && !rect && lines.length === 0) {
        // Could be panel icon - check if after network dot
        if (hasDotBefore) {
          console.log("[Android Patch] Found path button after dot, hiding");
          hide(btn);
          return;
        }
      }
    });
  }

  function start() {
    scanAndHide();
    setTimeout(scanAndHide, 200);
    setTimeout(scanAndHide, 500);
    setTimeout(scanAndHide, 1000);
    setTimeout(scanAndHide, 2000);
    
    var observer = new MutationObserver(scanAndHide);
    if (document.body) {
      observer.observe(document.body, { childList: true, subtree: true });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
})();