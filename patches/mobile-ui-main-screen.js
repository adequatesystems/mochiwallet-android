// Mobile UI patch: customizes main screen for mobile
// - Removes "Import from Backup" option (file system APIs not available on mobile)
// - Renames "Import from Mnemonic Phrase" to "Recover from Mnemonic Phrase"
(function () {
  var MARK_ATTR = "data-mobile-ui-main";
  var BACKUP_TEXTS = ["import from backup", "import backup", "from backup"];
  var MNEMONIC_TEXT = "import from mnemonic";
  var MNEMONIC_RENAME = "Recover from Mnemonic Phrase";

  function matchesBackupText(text) {
    var lower = text.toLowerCase().trim();
    return BACKUP_TEXTS.some(function (frag) { return lower.indexOf(frag) !== -1; });
  }

  function matchesMnemonicText(text) {
    var lower = text.toLowerCase().trim();
    return lower.indexOf(MNEMONIC_TEXT) !== -1;
  }

  function hideBackupButton(el) {
    if (!el || el.hasAttribute(MARK_ATTR + "-backup")) return;
    el.setAttribute(MARK_ATTR + "-backup", "true");
    el.style.setProperty("display", "none", "important");
    console.log("[Mobile UI] Removed 'Import from Backup' button (not available on mobile)");
  }

  function renameMnemonicButton(el) {
    if (!el || el.hasAttribute(MARK_ATTR + "-mnemonic")) return;
    
    // Find the text node or span containing the text
    var walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null, false);
    var node;
    while (node = walker.nextNode()) {
      if (matchesMnemonicText(node.textContent)) {
        node.textContent = node.textContent.replace(/import from mnemonic/i, "Recover from Mnemonic");
        el.setAttribute(MARK_ATTR + "-mnemonic", "true");
        console.log("[Mobile UI] Renamed 'Import from Mnemonic Phrase' to 'Recover from Mnemonic Phrase'");
        return;
      }
    }
    
    // Fallback: check if the element itself has the text
    if (matchesMnemonicText(el.textContent)) {
      el.textContent = el.textContent.replace(/import from mnemonic phrase/i, MNEMONIC_RENAME);
      el.setAttribute(MARK_ATTR + "-mnemonic", "true");
      console.log("[Mobile UI] Renamed 'Import from Mnemonic Phrase' to 'Recover from Mnemonic Phrase'");
    }
  }

  function processElement(el) {
    if (!(el instanceof HTMLElement)) return;
    
    var text = (el.textContent || "").toLowerCase().trim();
    
    // Check for backup import button
    if (matchesBackupText(text)) {
      // Find the clickable parent (button or link)
      var clickable = el.closest('button, a, [role="button"]');
      if (clickable) {
        hideBackupButton(clickable);
      } else if (el.tagName === "BUTTON" || el.tagName === "A") {
        hideBackupButton(el);
      }
    }
    
    // Check for mnemonic import button
    if (matchesMnemonicText(text)) {
      var clickable = el.closest('button, a, [role="button"]');
      if (clickable) {
        renameMnemonicButton(clickable);
      } else if (el.tagName === "BUTTON" || el.tagName === "A") {
        renameMnemonicButton(el);
      }
    }
  }

  function scan(root) {
    if (!root || !(root instanceof HTMLElement)) return;
    
    // Scan all potential text containers
    var elements = root.querySelectorAll('button, a, [role="button"], span, p, div');
    elements.forEach(processElement);
    
    // Also check the root itself
    processElement(root);
  }

  function start() {
    var body = document.body || document.documentElement;
    if (!body) return;
    
    // Initial scan
    scan(body);

    // Watch for dynamic content
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

  // Start when DOM is ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
