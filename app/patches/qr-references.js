// ==== RockOS backport: PR 255 offline QR popups ====
// Adapted from upstream OogaBoogaX/entropylab PR 255
// (src/js/qr-references.js @ 66358f49) for direct injection into the
// single-file v0.1.3 bundle: no ES module imports, uqr's renderSVG is
// expected in scope (injected just above this block from
// app/vendor/uqr-0.1.3.js with its export line stripped).
// Logic is unchanged from upstream.
(function(){
const NETWORK_TAG_ID = "network-status";
const escapeHtml = (text) =>
  String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
const isOfflineLink = (anchor) => {
  if (!anchor || anchor.tagName !== "A") return false;
  const href = anchor.getAttribute("href") ?? "";
  return /^https?:\/\//i.test(href);
};
const referenceQrSvg = (url) =>
  renderSVG(url, { ecc: "M", border: 4, pixelSize: 4, blackColor: "#111111", whiteColor: "#ffffff" });
const pageIsOffline = () => {
  const tag = document.getElementById(NETWORK_TAG_ID);
  return !!tag && tag.dataset.state === "offline";
};
let overlayEl = null;
let lastFocused = null;
const closeOverlay = () => {
  if (!overlayEl) return;
  overlayEl.hidden = true;
  lastFocused?.focus?.({ preventScroll: true });
  lastFocused = null;
};
const openOverlay = (url, label) => {
  if (!overlayEl) return;
  const qrSvg = referenceQrSvg(url);
  const card = overlayEl.querySelector(".qr-ref-card");
  card.innerHTML = `
    <p class="qr-ref-title">${escapeHtml(label)}</p>
    <div class="qr-ref-qr" aria-label="QR code for ${escapeHtml(url)}">${qrSvg}</div>
    <p class="qr-ref-url mono">${escapeHtml(url)}</p>
    <p class="qr-ref-hint muted">Scan with a phone camera to open this reference on an online device.</p>
    <div class="row qr-ref-actions">
      <button class="btn secondary" id="qr-ref-copy" type="button">Copy URL</button>
      <button class="btn primary" id="qr-ref-close" type="button">Close</button>
    </div>`;
  const copyBtn = card.querySelector("#qr-ref-copy");
  copyBtn.addEventListener("click", () => {
    navigator.clipboard?.writeText(url).then(() => {
      copyBtn.textContent = "Copied";
      setTimeout(() => { copyBtn.textContent = "Copy URL"; }, 1500);
    }).catch(() => {});
  });
  card.querySelector("#qr-ref-close").addEventListener("click", closeOverlay);
  overlayEl.hidden = false;
  card.querySelector("#qr-ref-close").focus();
};
const initQrReferences = () => {
  if (document.getElementById("qr-ref-overlay")) return;
  overlayEl = document.createElement("div");
  overlayEl.className = "qr-ref-overlay no-print";
  overlayEl.id = "qr-ref-overlay";
  overlayEl.hidden = true;
  overlayEl.setAttribute("role", "dialog");
  overlayEl.setAttribute("aria-modal", "true");
  overlayEl.innerHTML = `<div class="qr-ref-card"></div>`;
  document.body.append(overlayEl);
  overlayEl.addEventListener("click", (event) => {
    if (event.target === overlayEl) closeOverlay();
  });
  overlayEl.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeOverlay();
  });
  // Event delegation: handles links present at boot and links created
  // later (e.g. by dynamic re-renders) with no per-link registration.
  document.addEventListener("click", (event) => {
    if (!pageIsOffline()) return;
    const anchor = event.target.closest?.("a");
    if (!isOfflineLink(anchor)) return;
    event.preventDefault();
    const url = anchor.getAttribute("href");
    const label = anchor.textContent?.trim() || url;
    lastFocused = anchor;
    openOverlay(url, label);
  });
};
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initQrReferences);
} else {
  initQrReferences();
}
})();
// ==== end RockOS backport ====
