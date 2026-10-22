import { Controller } from "@hotwired/stimulus"

// The phone menu keeps the trigger node and listens on it. A publish
// replaces only the label, then this copies the new style onto that node.
//
// TopNav wires a dropdown as a disclosure once, and only if the menu is
// still inside it. A menu that is open (portaled to body) at that moment
// is missed. This puts that menu back and discloses it in place.
export default class extends Controller {
  static targets = ["state"]
  static values = { menuId: String }

  connect() {
    this.ownDisclosure = false
    this.onClick = this.onClick.bind(this)
    this.onResize = this.onResize.bind(this)
    document.addEventListener("click", this.onClick, true)
    window.addEventListener("resize", this.onResize)
  }

  disconnect() {
    document.removeEventListener("click", this.onClick, true)
    window.removeEventListener("resize", this.onResize)
  }

  stateTargetConnected(element) {
    const trigger = this.triggerElement()
    if (!trigger) return

    const style = element.dataset.style
    if (style) trigger.dataset.fpStyle = style

    const press = element.dataset.press
    trigger.classList.toggle("fp-button-flat", press === "flat")
    trigger.classList.toggle("fp-button-raised", press === "raised")

    const menu = this.menuElement()
    const label = element.textContent.trim()
    if (menu && label && menu.hasAttribute("aria-label")) menu.setAttribute("aria-label", label)
  }

  onClick(event) {
    const trigger = event.target.closest?.("[data-flat-pack--button-dropdown-target='trigger']")
    if (!trigger || !this.element.contains(trigger)) return
    if (!this.element.closest("[data-flat-pack--top-nav-target='panel']")) return
    if (this.element.dataset.flatPackTopNavDisclosure === "true" && !this.ownDisclosure) return

    this.rehomeMenu()
    this.ownDisclosure = true
    const open = this.element.dataset.flatPackTopNavExpanded !== "true"
    this.element.dataset.flatPackTopNavDisclosure = "true"
    this.element.dataset.flatPackTopNavExpanded = open ? "true" : "false"
    trigger.setAttribute("aria-expanded", open ? "true" : "false")

    const menu = this.menuElement()
    if (menu) {
      menu.setAttribute("aria-hidden", open ? "false" : "true")
      const label = (trigger.getAttribute("aria-label") || trigger.textContent || "").trim()
      if (label && !menu.hasAttribute("aria-label")) menu.setAttribute("aria-label", label)
    }

    event.preventDefault()
    event.stopPropagation()
    event.stopImmediatePropagation()
  }

  onResize() {
    if (!this.ownDisclosure) return
    if (this.element.closest("[data-flat-pack--top-nav-target='panel']")) return

    this.ownDisclosure = false
    delete this.element.dataset.flatPackTopNavDisclosure
    delete this.element.dataset.flatPackTopNavExpanded

    const trigger = this.triggerElement()
    if (trigger) trigger.setAttribute("aria-expanded", "false")

    const menu = this.menuElement()
    if (menu) menu.setAttribute("aria-hidden", "true")
  }

  rehomeMenu() {
    const menu = this.menuElement()
    if (!menu || this.element.contains(menu)) return

    this.element.appendChild(menu)
    menu.style.top = ""
    menu.style.left = ""
    menu.style.transform = ""
    menu.style.transformOrigin = ""
  }

  triggerElement() {
    return this.element.querySelector("[data-flat-pack--button-dropdown-target='trigger']")
  }

  menuElement() {
    if (this.hasMenuIdValue) {
      const byId = document.getElementById(this.menuIdValue)
      if (byId) return byId
    }

    return this.element.querySelector("[data-flat-pack--button-dropdown-target='menu']")
  }
}
