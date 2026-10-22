import { Controller } from "@hotwired/stimulus"

// The trigger node stays. A publish replaces only the label, then this
// copies the new style onto that node.
export default class extends Controller {
  static targets = ["state"]

  stateTargetConnected(element) {
    const trigger = this.element.querySelector("[data-flat-pack--button-dropdown-target='trigger']")
    if (!trigger) return

    const style = element.dataset.style
    if (style) trigger.dataset.fpStyle = style

    const press = element.dataset.press
    trigger.classList.toggle("fp-button-flat", press === "flat")
    trigger.classList.toggle("fp-button-raised", press === "raised")

    const menu = this.element.querySelector("[data-flat-pack--button-dropdown-target='menu']")
    const label = element.textContent.trim()
    if (menu && label && menu.hasAttribute("aria-label")) menu.setAttribute("aria-label", label)
  }
}
