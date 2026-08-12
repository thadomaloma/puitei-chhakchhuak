import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { auto: Boolean }

  connect() {
    if (this.autoValue) this.timeout = window.setTimeout(() => this.dismiss(), 7000)
  }

  dismiss() {
    this.element.remove()
  }

  disconnect() {
    if (this.timeout) window.clearTimeout(this.timeout)
  }
}
