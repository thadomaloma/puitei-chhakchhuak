import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amount", "method", "reference", "projected", "warning", "submit"]
  static values = { outstanding: Number, currency: String }

  connect() {
    this.preview()
  }

  preview() {
    const amount = this.numberValue(this.amountTarget.value)
    const nonCash = this.methodTarget.value !== "cash"
    const invalidAmount = amount <= 0 || amount > this.outstandingValue
    const missingReference = nonCash && this.referenceTarget.value.trim() === ""

    this.referenceTarget.required = nonCash
    this.projectedTarget.textContent = this.formatMoney(Math.max(this.outstandingValue - amount, 0))
    this.warningTarget.classList.toggle("hidden", !invalidAmount)
    this.submitTarget.disabled = invalidAmount || missingReference
  }

  payFull() {
    this.amountTarget.value = this.outstandingValue.toFixed(2)
    this.preview()
    this.amountTarget.focus()
  }

  payHalf() {
    this.amountTarget.value = (this.outstandingValue / 2).toFixed(2)
    this.preview()
    this.amountTarget.focus()
  }

  numberValue(value) {
    const parsed = Number.parseFloat(value)
    return Number.isFinite(parsed) ? parsed : 0
  }

  formatMoney(value) {
    return new Intl.NumberFormat(document.documentElement.lang || "en", {
      style: "currency",
      currency: this.currencyValue,
      maximumFractionDigits: 2
    }).format(value)
  }
}
