(function () {
  "use strict"

  var statusEl = document.getElementById("offline-status")
  var statusText = document.getElementById("offline-status-text")
  var recoveryEl = document.getElementById("offline-recovery")
  var continueButton = document.getElementById("offline-continue")
  var retryForm = document.getElementById("offline-retry-form")
  var retryButton = document.getElementById("offline-retry")

  function setOnline(isOnline) {
    if (statusEl) statusEl.classList.toggle("is-online", isOnline)
    if (statusText) statusText.textContent = isOnline ? "Connection restored" : "No internet connection"
    if (recoveryEl) recoveryEl.hidden = !isOnline
  }

  setOnline(navigator.onLine)
  window.addEventListener("online", function () { setOnline(true) })
  window.addEventListener("offline", function () { setOnline(false) })

  if (continueButton) {
    continueButton.addEventListener("click", function () { window.location.reload() })
  }

  if (retryForm && retryButton) {
    retryForm.addEventListener("submit", function () {
      retryButton.disabled = true
      retryButton.textContent = "Retrying…"
    })
  }
})()
