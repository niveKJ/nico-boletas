import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["idle", "input", "filename", "preview", "processing", "submit"]

  dragOver(event) {
    event.preventDefault()
    this.idleTarget.style.borderColor = "#4F46E5"
    this.idleTarget.style.background  = "#EEF2FF"
  }

  dragLeave() {
    this.idleTarget.style.borderColor = "#9CA3AF"
    this.idleTarget.style.background  = "#FFFFFF"
  }

  drop(event) {
    event.preventDefault()
    this.dragLeave()
    const file = event.dataTransfer?.files?.[0]
    if (file) this._applyFile(file)
  }

  zoneClick() { this.inputTarget.click() }

  fileSelected(event) {
    const file = event.target.files?.[0]
    if (file) this._applyFile(file)
  }

  reset(event) {
    if (event) event.stopPropagation()
    this.inputTarget.value = ""
    this._show("idle")
  }

  submitting() {
  if (!this.inputTarget.files?.length) return
  this._show("processing")
  if (this.hasSubmitTarget) {
    this.submitTarget.disabled = true
  }
  // dejar que el submit nativo del form continúe
}

  _applyFile(file) {
    if (this.hasFilenameTarget) this.filenameTarget.textContent = file.name
    try {
      const dt = new DataTransfer()
      dt.items.add(file)
      this.inputTarget.files = dt.files
    } catch (_) {}
    this._show("preview")
  }

  _show(state) {
    ;["idle", "preview", "processing"].forEach(s => {
      const t = this[`${s}Target`]
      if (t) t.style.display = s === state ? "flex" : "none"
    })
  }
}