import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "button", "close"]

  open() {
    this.previouslyFocused = document.activeElement
    this.panelTarget.hidden = false
    this.panelTarget.classList.remove("hidden")
    this.panelTarget.setAttribute("aria-hidden", "false")
    this.buttonTarget.setAttribute("aria-expanded", "true")
    document.body.style.overflow = "hidden"
    this.closeTarget.focus()
  }

  close() {
    if (this.panelTarget.classList.contains("hidden")) return

    this.panelTarget.hidden = true
    this.panelTarget.classList.add("hidden")
    this.panelTarget.setAttribute("aria-hidden", "true")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    document.body.style.overflow = ""
    const target = this.previouslyFocused?.isConnected ? this.previouslyFocused : this.buttonTarget
    target.focus()
  }

  trapFocus(event) {
    if (this.panelTarget.classList.contains("hidden")) return

    const elements = Array.from(this.panelTarget.querySelectorAll(
      "a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex='-1'])"
    )).filter((element) => element.getClientRects().length > 0)
    if (elements.length === 0) return

    const first = elements[0]
    const last = elements[elements.length - 1]
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  disconnect() {
    document.body.style.overflow = ""
  }
}
