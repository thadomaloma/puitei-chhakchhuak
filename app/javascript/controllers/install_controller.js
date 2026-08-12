import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.beforeInstallPrompt = event => {
      event.preventDefault()
      this.promptEvent = event
      this.buttonTarget.classList.remove("hidden")
    }
    window.addEventListener("beforeinstallprompt", this.beforeInstallPrompt)
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this.beforeInstallPrompt)
  }

  async prompt() {
    if (!this.promptEvent) return
    await this.promptEvent.prompt()
    this.promptEvent = null
    this.buttonTarget.classList.add("hidden")
  }
}
