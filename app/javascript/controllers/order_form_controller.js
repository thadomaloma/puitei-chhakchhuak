import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "customer", "measurement", "designSelection", "item", "itemNumber", "itemTotal", "itemsContainer", "emptyItems", "template",
    "discount", "subtotal", "discountTotal", "tax", "total", "taxRate", "currency", "customerSummary",
    "measurementNotice", "measurementLink"
  ]

  static values = { newMeasurementUrlTemplate: String }

  connect() {
    this.customerChanged()
    this.renumberItems()
    this.recalculate()
  }

  customerChanged() {
    this.filterMeasurements()
    this.filterByCustomer(this.designSelectionTargets)
    this.updateCustomerSummary()
    this.updateMeasurementLink()
    this.recalculate()
  }

  filterMeasurements() {
    const customerId = this.customerTarget.value
    let availableMeasurements = 0

    this.measurementTargets.forEach((select, selectIndex) => {
      Array.from(select.options).forEach((option) => {
        if (!option.value) return
        option.hidden = customerId === "" || option.dataset.customerId !== customerId
        option.disabled = option.hidden
        if (selectIndex === 0 && !option.hidden) availableMeasurements += 1
      })

      const selected = select.selectedOptions[0]
      if (selected?.disabled) select.value = ""
    })

    if (this.hasMeasurementNoticeTarget) {
      this.measurementNoticeTarget.classList.toggle("hidden", customerId === "" || availableMeasurements > 0)
    }
  }

  filterByCustomer(selects) {
    const customerId = this.customerTarget.value

    selects.forEach((select) => {
      Array.from(select.options).forEach((option) => {
        if (!option.value) return
        option.hidden = customerId === "" || option.dataset.customerId !== customerId
        option.disabled = option.hidden
      })

      const selected = select.selectedOptions[0]
      if (selected?.disabled) select.value = ""
    })
  }

  addItem() {
    const key = `${Date.now()}${Math.floor(Math.random() * 1000)}`
    this.itemsContainerTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML.replaceAll("NEW_RECORD", key))
    this.renumberItems()
    this.filterMeasurements()
    this.filterByCustomer(this.designSelectionTargets)
    this.recalculate()
  }

  removeItem(event) {
    event.currentTarget.closest("[data-order-form-target='item']")?.remove()
    this.renumberItems()
    this.recalculate()
  }

  renumberItems() {
    this.itemNumberTargets.forEach((heading, index) => { heading.textContent = `Garment ${index + 1}` })
    if (this.hasEmptyItemsTarget) this.emptyItemsTarget.classList.toggle("hidden", this.itemTargets.length > 0)
  }

  recalculate() {
    let subtotal = 0

    this.itemTargets.forEach((item, index) => {
      const quantity = this.numberValue(item.querySelector("[name$='[quantity]']")?.value, 1)
      const price = this.numberValue(item.querySelector("[name$='[unit_price]']")?.value)
      const lineTotal = quantity * price
      subtotal += lineTotal
      if (this.itemTotalTargets[index]) this.itemTotalTargets[index].textContent = this.formatMoney(lineTotal)
    })

    const discount = Math.min(this.numberValue(this.hasDiscountTarget ? this.discountTarget.value : 0), subtotal)
    const taxRate = this.selectedCustomerOption()?.dataset.taxRate || 0
    const tax = Math.max(subtotal - discount, 0) * this.numberValue(taxRate) / 100
    const total = Math.max(subtotal - discount, 0) + tax

    this.subtotalTarget.textContent = this.formatMoney(subtotal)
    this.discountTotalTarget.textContent = this.formatMoney(discount)
    this.taxTarget.textContent = this.formatMoney(tax)
    this.totalTarget.textContent = this.formatMoney(total)
    this.taxRateTarget.textContent = `${this.numberValue(taxRate)}%`
    this.currencyTargets.forEach((element) => { element.textContent = this.currency() })
  }

  updateCustomerSummary() {
    const option = this.selectedCustomerOption()
    this.customerSummaryTarget.textContent = option?.value ? `${option.dataset.name} · ${option.dataset.phone}` : "Select a customer to apply branch pricing."
  }

  updateMeasurementLink() {
    if (!this.hasMeasurementLinkTarget) return
    const customerId = this.customerTarget.value
    this.measurementLinkTarget.href = customerId ? this.newMeasurementUrlTemplateValue.replace("__CUSTOMER_ID__", customerId) : "#"
  }

  selectedCustomerOption() {
    return this.customerTarget.selectedOptions[0]
  }

  currency() {
    return this.selectedCustomerOption()?.dataset.currency || "INR"
  }

  numberValue(value, fallback = 0) {
    const parsed = Number.parseFloat(value)
    return Number.isFinite(parsed) ? parsed : fallback
  }

  formatMoney(value) {
    return new Intl.NumberFormat(document.documentElement.lang || "en", { style: "currency", currency: this.currency(), currencyDisplay: "code" }).format(value)
  }
}
