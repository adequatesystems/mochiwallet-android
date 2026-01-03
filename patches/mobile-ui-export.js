// Mobile UI patch: removes export/backup section (file download APIs not available on mobile)
// Wallet export requires browser download APIs that are unavailable in mobile WebView
(function () {
  var MARK_ATTR = "data-mobile-ui-export";

  function remove(el, reason) {
    if (!el || el.hasAttribute(MARK_ATTR)) return;
    el.setAttribute(MARK_ATTR, "true");
    el.style.setProperty("display", "none", "important");
    console.log("[Mobile UI] Removed element (not applicable on mobile):", el.tagName, reason);
  }

  function scanAndRemove() {
    // 1. Remove export wallet buttons (file download not available on mobile)
    document.querySelectorAll("button, [role='button']").forEach(function (btn) {
      if (btn.hasAttribute(MARK_ATTR)) return;
      var text = (btn.textContent || "").toLowerCase();
      if (text.indexOf("export") !== -1 && text.indexOf("wallet") !== -1) {
        remove(btn, "Export Wallet button");
      }
    });

    // 2. Remove "Backup" heading (file export not available on mobile)
    document.querySelectorAll("h2, h3, h4").forEach(function (h) {
      if (h.hasAttribute(MARK_ATTR)) return;
      var text = (h.textContent || "").trim();
      if (text === "Backup") {
        remove(h, "Backup heading");
      }
    });

    // 3. Remove description about exporting wallet
    document.querySelectorAll("p").forEach(function (p) {
      if (p.hasAttribute(MARK_ATTR)) return;
      var text = (p.textContent || "").toLowerCase();
      if (text.indexOf("export your wallet") !== -1) {
        remove(p, "export description");
      }
    });
  }

  function start() {
    scanAndRemove();
    setTimeout(scanAndRemove, 200);
    setTimeout(scanAndRemove, 500);
    setTimeout(scanAndRemove, 1000);
    
    var observer = new MutationObserver(scanAndRemove);
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