// Android-only patch: add legal links (Terms of Service, Privacy Policy) to specific screens
// Only shows on: "Create Wallet" screen (first launch) and "Welcome Back" screen (login)
(function () {
  var CONTAINER_ID = "android-legal-links";
  var TOS_URL = "https://mochimo.org/mobile-wallet-terms";
  var PRIVACY_URL = "https://mochimo.org/mobile-wallet-privacy";

  function createLegalLinks() {
    // Don't create if already exists
    if (document.getElementById(CONTAINER_ID)) return;

    var root = document.getElementById("root");
    if (!root) return;

    // Create the legal links container
    var container = document.createElement("div");
    container.id = CONTAINER_ID;
    container.style.cssText = [
      "position: fixed",
      "bottom: 24px",
      "left: 0",
      "right: 0",
      "text-align: center",
      "font-size: 12px",
      "color: #888",
      "z-index: 1000",
      "padding: 0 16px",
      "line-height: 1.6"
    ].join(";");

    // Single line with both links: "By using this App you accept the Terms of Service and Privacy Policy"
    var legalLine = document.createElement("div");
    legalLine.innerHTML =
      'By using this App you accept the <a href="' +
      TOS_URL +
      '" target="_blank" rel="noopener" style="color: #6366f1; text-decoration: underline;">Terms of Service</a>' +
      ' and <a href="' +
      PRIVACY_URL +
      '" target="_blank" rel="noopener" style="color: #6366f1; text-decoration: underline;">Privacy Policy</a>';
    container.appendChild(legalLine);

    document.body.appendChild(container);
    console.log("[Android Patch] Added legal links to screen");
  }

  function isCreateWalletScreen() {
    // First launch screen with "Create New Wallet" button
    var bodyText = document.body.innerText || "";
    // Check for "Create New Wallet" or "Create Wallet" text (the button)
    // Also check for "Recover from Mnemonic" (renamed from Import) which is on the same screen
    var hasCreateWallet = bodyText.indexOf("Create New Wallet") !== -1 || 
                          bodyText.indexOf("Create Wallet") !== -1;
    var hasRecoverMnemonic = bodyText.indexOf("Recover from Mnemonic") !== -1 ||
                             bodyText.indexOf("Import from Mnemonic") !== -1;
    
    // Must NOT have "Welcome Back" - that's a different screen
    var hasWelcomeBack = bodyText.indexOf("Welcome Back") !== -1;
    
    return (hasCreateWallet || hasRecoverMnemonic) && !hasWelcomeBack;
  }

  function isWelcomeBackScreen() {
    // Login screen with "Welcome Back" text
    var bodyText = document.body.innerText || "";
    return bodyText.indexOf("Welcome Back") !== -1;
  }

  function checkAndShowLinks() {
    var container = document.getElementById(CONTAINER_ID);
    
    // Only show on Create Wallet screen OR Welcome Back screen
    var shouldShow = isCreateWalletScreen() || isWelcomeBackScreen();

    if (shouldShow) {
      createLegalLinks();
      if (container) container.style.display = "block";
    } else {
      if (container) container.style.display = "none";
    }
  }

  function start() {
    checkAndShowLinks();
    setTimeout(checkAndShowLinks, 200);
    setTimeout(checkAndShowLinks, 500);
    setTimeout(checkAndShowLinks, 1000);

    // Watch for navigation/DOM changes
    var observer = new MutationObserver(function () {
      checkAndShowLinks();
    });
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
