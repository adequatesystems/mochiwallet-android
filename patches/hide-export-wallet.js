// Android-only patch: hide export wallet button and backup section
(function () {
  var MARK_ATTR = "data-android-hidden-export";

  function hide(el, reason) {
    if (!el || el.hasAttribute(MARK_ATTR)) return;
    el.setAttribute(MARK_ATTR, "true");
    el.style.setProperty("display", "none", "important");
    console.log("[Android Patch] Hidden export element:", el.tagName, reason);
  }

  function scanAndHide() {
    // 1. Hide export wallet buttons
    document.querySelectorAll("button, [role='button']").forEach(function (btn) {
      if (btn.hasAttribute(MARK_ATTR)) return;
      var text = (btn.textContent || "").toLowerCase();
      if (text.indexOf("export") !== -1 && text.indexOf("wallet") !== -1) {
        hide(btn, "Export Wallet button");
      }
    });

    // 2. Hide "Backup" heading
    document.querySelectorAll("h2, h3, h4").forEach(function (h) {
      if (h.hasAttribute(MARK_ATTR)) return;
      var text = (h.textContent || "").trim();
      if (text === "Backup") {
        hide(h, "Backup heading");
      }
    });

    // 3. Hide description about exporting wallet
    document.querySelectorAll("p").forEach(function (p) {
      if (p.hasAttribute(MARK_ATTR)) return;
      var text = (p.textContent || "").toLowerCase();
      if (text.indexOf("export your wallet") !== -1) {
        hide(p, "export description");
      }
    });
  }

  function start() {
    scanAndHide();
    setTimeout(scanAndHide, 200);
    setTimeout(scanAndHide, 500);
    setTimeout(scanAndHide, 1000);
    
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