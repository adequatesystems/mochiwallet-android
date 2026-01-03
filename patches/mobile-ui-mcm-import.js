// Mobile UI patch: removes "Import MCM File" option (file system APIs not available on mobile)
// MCM file import requires browser file picker APIs that are unavailable in mobile WebView
(function () {
  var MARK_ATTR = "data-mobile-ui-mcm";
  var TEXT_MATCH = ["import mcm", "import mcm file", "mcm file"];

  function matchesText(node) {
    var text = (node.textContent || "").trim().toLowerCase();
    if (!text) return false;
    return TEXT_MATCH.some(function (frag) { return text.indexOf(frag) !== -1; });
  }

  function consider(node) {
    if (!(node instanceof HTMLElement)) return;
    if (node.hasAttribute(MARK_ATTR)) return;
    var roleButton = node.tagName === "BUTTON" || node.getAttribute("role") === "button";
    var label = (node.getAttribute("aria-label") || node.getAttribute("title") || "").toLowerCase();
    if (roleButton && (matchesText(node) || TEXT_MATCH.some(function (frag) { return label.indexOf(frag) !== -1; }))) {
      node.setAttribute(MARK_ATTR, "true");
      node.style.display = "none";
    }
  }

  function scan(root) {
    if (!root || !(root instanceof HTMLElement)) return;
    consider(root);
    root.querySelectorAll('button, [role="button"]').forEach(consider);
  }

  function start() {
    var body = document.body || document.documentElement;
    if (!body) return;
    scan(body);

    var observer = new MutationObserver(function (mutations) {
      mutations.forEach(function (mutation) {
        mutation.addedNodes.forEach(function (node) {
          if (node.nodeType === 1) {
            scan(node);
          }
        });
      });
    });

    observer.observe(body, { childList: true, subtree: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
})();