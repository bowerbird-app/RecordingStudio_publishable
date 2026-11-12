import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["native"]
  static values = { url: String, title: String, text: String }

  connect() {
    if (typeof navigator.share !== "function" || !this.hasNativeTarget) return

    this.nativeTarget.hidden = false
    this.nativeTarget.classList.remove("hidden")
  }

  async native(event) {
    event.preventDefault()
    if (typeof navigator.share !== "function") return

    try {
      await navigator.share({ title: this.titleValue, text: this.textValue, url: this.urlValue })
    } catch (error) {
      if (error && error.name === "AbortError") return
    }
  }
}
