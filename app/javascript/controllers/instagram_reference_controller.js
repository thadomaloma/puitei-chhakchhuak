import { Controller } from "@hotwired/stimulus"

// Live preview for the "paste an Instagram link" design reference flow.
// Never renders Instagram's HTML embed -- only a thumbnail/author summary
// returned by the server, so failures just fall back to a plain message.
export default class extends Controller {
  static targets = ["url", "preview", "thumbnail", "status", "author"]
  static values = { previewUrl: String, recognizedText: String, unavailableText: String }

  connect() {
    this.debounceTimer = null
    this.requestToken = 0
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
  }

  preview() {
    clearTimeout(this.debounceTimer)
    const url = this.urlTarget.value.trim()
    if (!url) {
      this.hidePreview()
      return
    }

    this.debounceTimer = setTimeout(() => this.fetchPreview(url), 500)
  }

  async fetchPreview(url) {
    const token = ++this.requestToken

    try {
      const response = await fetch(`${this.previewUrlValue}?url=${encodeURIComponent(url)}`, {
        headers: { Accept: "application/json" }
      })
      if (token !== this.requestToken) return

      const data = await response.json()
      if (!response.ok || !data.valid) {
        this.hidePreview()
        return
      }

      this.showPreview(data)
    } catch (error) {
      if (token === this.requestToken) this.hidePreview()
    }
  }

  showPreview(data) {
    this.previewTarget.classList.remove("hidden")
    this.previewTarget.classList.add("flex")
    this.statusTarget.textContent = this.recognizedTextValue

    if (data.preview_available && data.thumbnail_url) {
      this.thumbnailTarget.src = data.thumbnail_url
      this.thumbnailTarget.classList.remove("hidden")
      this.authorTarget.textContent = data.author_name ? `@${data.author_name}` : ""
    } else {
      this.thumbnailTarget.classList.add("hidden")
      this.authorTarget.textContent = this.unavailableTextValue
    }
  }

  hidePreview() {
    this.previewTarget.classList.add("hidden")
    this.previewTarget.classList.remove("flex")
    this.thumbnailTarget.classList.add("hidden")
  }
}
