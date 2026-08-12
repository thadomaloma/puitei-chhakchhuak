import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "placeholder", "gallery"]

  connect() {
    this.objectUrls = []
  }

  preview() {
    this.releaseObjectUrls()
    const files = Array.from(this.inputTarget.files || [])
    if (files.length === 0) return

    if (this.hasGalleryTarget) {
      this.galleryTarget.replaceChildren(...files.map((file) => this.previewImage(file)))
      this.galleryTarget.classList.remove("hidden")
      this.galleryTarget.classList.add("grid")
      return
    }

    const url = this.objectUrl(files[0])
    this.previewTarget.src = url
    this.previewTarget.classList.remove("hidden")
    if (this.hasPlaceholderTarget) this.placeholderTarget.classList.add("hidden")
  }

  disconnect() {
    this.releaseObjectUrls()
  }

  previewImage(file) {
    const image = document.createElement("img")
    image.src = this.objectUrl(file)
    image.alt = ""
    image.className = "aspect-square w-full rounded-xl border border-line object-cover"
    return image
  }

  objectUrl(file) {
    const url = URL.createObjectURL(file)
    this.objectUrls.push(url)
    return url
  }

  releaseObjectUrls() {
    this.objectUrls.forEach((url) => URL.revokeObjectURL(url))
    this.objectUrls = []
  }
}
