import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "count", "progress", "submit"]

  connect() {
    this.update()
  }

  update() {
    const completed = this.itemTargets.filter((item) => item.checked).length
    const total = this.itemTargets.length
    const percent = total === 0 ? 0 : (completed / total) * 100

    this.countTarget.textContent = `${completed}/${total}`
    this.progressTarget.style.width = `${percent}%`
    this.submitTarget.disabled = completed !== total
  }
}
