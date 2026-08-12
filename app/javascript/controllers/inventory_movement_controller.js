import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "quantity", "onHand", "reserved", "available", "projectedOnHand", "projectedAvailable", "description", "warning", "submit"]
  static values = { onHand: Number, reserved: Number, unit: String }

  connect() {
    this.preview()
  }

  preview() {
    const quantity = this.numberValue(this.quantityTarget.value)
    const option = this.typeTarget.selectedOptions[0]
    const direction = option?.dataset.direction || "in"
    const delta = direction === "in" ? quantity : -quantity
    const projectedOnHand = this.onHandValue + delta
    const projectedAvailable = projectedOnHand - this.reservedValue
    const invalid = projectedOnHand < 0 || projectedAvailable < 0

    this.onHandTarget.textContent = this.formatQuantity(this.onHandValue)
    this.reservedTarget.textContent = this.formatQuantity(this.reservedValue)
    this.availableTarget.textContent = this.formatQuantity(this.onHandValue - this.reservedValue)
    this.projectedOnHandTarget.textContent = this.formatQuantity(projectedOnHand)
    this.projectedAvailableTarget.textContent = this.formatQuantity(projectedAvailable)
    this.descriptionTarget.textContent = option?.dataset.description || ""
    this.warningTarget.classList.toggle("hidden", !invalid)
    this.submitTarget.disabled = invalid || quantity <= 0
  }

  numberValue(value) {
    const parsed = Number.parseFloat(value)
    return Number.isFinite(parsed) ? parsed : 0
  }

  formatQuantity(value) {
    const formatted = new Intl.NumberFormat(document.documentElement.lang || "en", { maximumFractionDigits: 3 }).format(value)
    return `${formatted} ${this.unitValue}`
  }
}
