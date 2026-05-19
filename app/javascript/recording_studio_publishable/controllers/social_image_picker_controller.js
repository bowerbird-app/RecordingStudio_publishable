import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "previewImage", "previewName", "emptyState", "clearButton"]

  static values = {
    pickerId: String
  }

  connect() {
    this.#syncFromInput()
  }

  handleConfirm(event) {
    const detail = event?.detail || {}
    if (this.hasPickerIdValue && detail.pickerId && detail.pickerId !== this.pickerIdValue) {
      return
    }

    const selectedItem = Array.isArray(detail.selection) ? detail.selection[0] : null
    if (!selectedItem) {
      this.clear()
      return
    }

    this.inputTarget.value = String(selectedItem.id || "")
    this.#renderSelection(selectedItem)
  }

  clear() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }

    if (this.hasPreviewTarget) {
      this.previewTarget.classList.add("hidden")
    }

    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.remove("hidden")
    }

    if (this.hasClearButtonTarget) {
      this.clearButtonTarget.classList.add("hidden")
    }

    if (this.hasPreviewImageTarget) {
      this.previewImageTarget.src = ""
      this.previewImageTarget.alt = "Selected social image"
    }

    if (this.hasPreviewNameTarget) {
      this.previewNameTarget.textContent = ""
    }
  }

  #syncFromInput() {
    if (!this.hasInputTarget || !this.inputTarget.value) {
      return
    }

    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.add("hidden")
    }

    if (this.hasPreviewTarget) {
      this.previewTarget.classList.remove("hidden")
    }

    if (this.hasClearButtonTarget) {
      this.clearButtonTarget.classList.remove("hidden")
    }
  }

  #renderSelection(selectedItem) {
    const imageUrl = selectedItem.thumbnail_url || selectedItem.thumbnailUrl || ""
    const label = selectedItem.title || selectedItem.label || selectedItem.name || "Selected social image"

    if (this.hasPreviewTarget) {
      this.previewTarget.classList.remove("hidden")
    }

    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.add("hidden")
    }

    if (this.hasClearButtonTarget) {
      this.clearButtonTarget.classList.remove("hidden")
    }

    if (this.hasPreviewNameTarget) {
      this.previewNameTarget.textContent = label
    }

    if (this.hasPreviewImageTarget) {
      this.previewImageTarget.src = imageUrl
      this.previewImageTarget.alt = label
    }
  }
}