import "./application.css"

const flagUrls = Object.fromEntries(
  Object.entries(import.meta.glob("../flags/*.svg", { eager: true, query: "?url", import: "default" }))
    .map(([path, url]) => [path.split("/").pop().replace(".svg", ""), url])
)
const flagFor = code =>
  flagUrls[[...code.toUpperCase()].map(letter => (0x1f1e6 + letter.charCodeAt(0) - 65).toString(16)).join("-")]

const enhanceCountrySelect = (root, select) => {
  const flag = root.querySelector("[data-country-flag]")
  const button = document.createElement("button")
  button.type = "button"
  button.className = "country-button"
  button.setAttribute("aria-haspopup", "listbox")
  button.setAttribute("aria-expanded", "false")
  const label = document.createElement("span")
  button.append(flag, label)
  root.prepend(button)
  root.classList.add("is-enhanced")
  select.tabIndex = -1

  const popover = document.createElement("div")
  popover.className = "country-popover"
  popover.hidden = true
  popover.innerHTML = `<input type="search" class="country-search" role="combobox" aria-expanded="true" aria-controls="country-listbox"
    aria-autocomplete="list" autocomplete="off" placeholder="Search countries">
    <ul class="country-options" id="country-listbox" role="listbox" aria-label="Country"></ul>
    <p class="country-empty" hidden>No countries match that search.</p>`
  root.append(popover)
  const search = popover.querySelector("input"), list = popover.querySelector("ul"), empty = popover.querySelector("p")
  const fold = text => text.normalize("NFD").replace(/[\u0300-\u036f'\u2019]/g, "").toLowerCase()

  const options = [...select.options].filter(option => option.value).map((option, index) => {
    const item = document.createElement("li")
    item.id = `country-option-${index}`
    item.role = "option"
    item.dataset.value = option.value
    item.innerHTML = `<img alt="" width="22" height="22" loading="lazy" decoding="async" src="${flagFor(option.dataset.code)}"><span></span>`
    item.lastChild.textContent = option.value
    return { item, option, haystack: fold(option.value), code: option.dataset.code }
  })
  list.append(...options.map(entry => entry.item))

  let active = null
  const setActive = entry => {
    active = entry
    options.forEach(other => other.item.classList.toggle("is-active", other === entry))
    search.setAttribute("aria-activedescendant", entry ? entry.item.id : "")
    entry?.item.scrollIntoView({ block: "nearest" })
  }
  const shown = () => options.filter(entry => !entry.item.hidden)
  const sync = () => {
    const selected = select.selectedOptions[0]
    const url = selected?.dataset.code && flagFor(selected.dataset.code)
    if (url) flag.src = url
    flag.hidden = !url
    label.textContent = selected?.value || "Select your country"
    label.classList.toggle("is-placeholder", !selected?.value)
    options.forEach(entry => entry.item.setAttribute("aria-selected", String(entry.option.selected)))
  }
  const filter = () => {
    const query = fold(search.value.trim())
    options.forEach(entry => {
      entry.item.hidden = Boolean(query) && !entry.haystack.includes(query) && !entry.code.startsWith(query)
    })
    empty.hidden = shown().length > 0
    setActive(shown().find(entry => entry.option.selected) || shown()[0] || null)
  }
  const open = () => {
    popover.hidden = false
    button.setAttribute("aria-expanded", "true")
    search.value = ""
    filter()
    search.focus()
  }
  const close = ({ focus } = {}) => {
    popover.hidden = true
    button.setAttribute("aria-expanded", "false")
    if (focus) button.focus()
  }
  const commit = entry => {
    if (!entry) return
    select.value = entry.option.value
    select.dispatchEvent(new Event("change", { bubbles: true }))
    sync()
    close({ focus: true })
  }

  button.addEventListener("click", () => (popover.hidden ? open() : close({ focus: true })))
  select.addEventListener("change", sync)
  search.addEventListener("input", filter)
  list.addEventListener("pointerdown", event => event.preventDefault())
  list.addEventListener("click", event => commit(options.find(entry => entry.item === event.target.closest("li"))))
  search.addEventListener("keydown", event => {
    const visible = shown(), step = { ArrowDown: 1, ArrowUp: -1 }[event.key]
    if (step) setActive(visible[Math.min(Math.max(visible.indexOf(active) + step, 0), visible.length - 1)] || active)
    else if (event.key === "Enter") commit(active)
    else if (event.key === "Escape") close({ focus: true })
    else return
    event.preventDefault()
  })
  root.addEventListener("focusout", event => { if (!root.contains(event.relatedTarget)) close() })
  document.addEventListener("pointerdown", event => { if (!root.contains(event.target)) close() })
  sync()
}

const wizard = document.querySelector("[data-wizard]")
if (wizard) {
  const form = wizard.querySelector("[data-wizard-form]")
  const panels = [...wizard.querySelectorAll("[data-step]")]
  const progress = [...wizard.querySelectorAll(".progress-step")]
  let step = Number(wizard.dataset.initialStep) || 1
  const show = (next, scroll = true) => {
    step = next
    panels.forEach(panel => { panel.hidden = Number(panel.dataset.step) !== step })
    progress.forEach((item, index) => item.classList.toggle("active", index < step))
    if (scroll) window.scrollTo({ top: 0, behavior: "smooth" })
  }
  const valid = number => [...panels[number - 1].querySelectorAll("[required]")].every(field => field.reportValidity())
  const value = name => form.elements[name]?.value.trim() || ""
  const escapeHtml = string => string.replace(/[&<>'"]/g, char => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", "'":"&#39;", '"':"&quot;" })[char])
  const updatePledge = () => {
    const birthday = new Date(`${value("user[birthdate]")}T12:00:00`), today = new Date()
    let age = today.getFullYear() - birthday.getFullYear()
    if (today < new Date(today.getFullYear(), birthday.getMonth(), birthday.getDate())) age--
    const name = `${value("user[legal_first_name]")} ${value("user[legal_last_name]")}`.trim()
    const location = [value("user[city]"), value("user[region]"), value("user[country]")].filter(Boolean).join(", ")
    wizard.querySelector("[data-pledge-intro]").innerHTML =
      `My name is <strong>${escapeHtml(name)}</strong>. I am <strong>${age}</strong> years old. I currently live in <strong>${escapeHtml(location)}</strong>.`
    const minor = age >= 0 && age < 18, cosigner = wizard.querySelector("[data-cosigner]")
    cosigner.hidden = !minor
    cosigner.querySelectorAll("input").forEach(input => { input.required = minor })
  }
  updatePledge()
  show(step, false)
  wizard.querySelectorAll("[data-next]").forEach(button => button.addEventListener("click", () => { updatePledge(); if (valid(step)) show(step + 1) }))
  wizard.querySelectorAll("[data-back]").forEach(button => button.addEventListener("click", () => show(step - 1)))
  const fileInput = form.elements.identity_video
  const dropzone = wizard.querySelector("[data-dropzone]")
  const fileLabel = dropzone.querySelector("strong")
  const defaultFileLabel = fileLabel.innerHTML
  const fileError = wizard.querySelector("[data-upload-error]")
  const removeFile = wizard.querySelector("[data-remove-file]")
  const allowedVideoTypes = new Set(["video/mp4", "video/webm"])
  const updateFile = () => {
    const file = fileInput.files[0]
    let error = ""
    fileInput.setCustomValidity("")
    dropzone.classList.remove("is-invalid")
    fileError.hidden = true
    removeFile.hidden = !file
    if (!file) {
      fileLabel.innerHTML = defaultFileLabel
      return
    }

    fileLabel.textContent = file.name
    const allowedExtension = /\.(mp4|webm)$/i.test(file.name)
    if (!allowedExtension || (file.type && !allowedVideoTypes.has(file.type))) error = "Choose an MP4 or WebM video."
    else if (file.size > 25 * 1024 * 1024) error = "Choose a video that is 25 MB or smaller."
    if (error) {
      fileInput.setCustomValidity(error)
      dropzone.classList.add("is-invalid")
      fileError.textContent = error
      fileError.hidden = false
    }
  }
  const country = form.elements["user[country]"]
  enhanceCountrySelect(wizard.querySelector("[data-country]"), country)
  country.addEventListener("change", updatePledge)
  form.elements["user[birthdate]"].addEventListener("change", updatePledge)
  fileInput.addEventListener("change", updateFile)
  removeFile.addEventListener("click", () => { fileInput.value = ""; updateFile() })
  form.addEventListener("submit", () => {
    form.setAttribute("aria-busy", "true")
    wizard.querySelector("[data-processing-status]").hidden = false
    const submit = form.querySelector("[data-submit-label]")
    submit.disabled = true
    submit.value = "Video submitted — processing…"
  })
}

document.querySelectorAll("[data-local-time]").forEach(element => {
  const date = new Date(element.dateTime)
  if (!Number.isNaN(date.valueOf())) element.textContent = date.toLocaleString(undefined, { dateStyle: "long", timeStyle: "short" })
})

document.querySelector("[data-print]")?.addEventListener("click", () => window.print())

const statusForm = document.querySelector("[data-status-form]")
if (statusForm) statusForm.addEventListener("submit", async event => {
  event.preventDefault()
  const result = statusForm.querySelector("[data-status-result]")
  result.hidden = false; result.textContent = "Checking…"
  try {
    const response = await fetch(`/api/v1/nda_status/${encodeURIComponent(statusForm.elements.slack_id.value)}`), data = await response.json()
    if (!response.ok) throw new Error("Enter a valid Slack member ID.")
    result.className = `lookup-result ${data.status === "signed" ? "is-signed" : "is-missing"}`
    result.innerHTML = data.status === "signed" ? `<strong>✓ NDA signed</strong><span>Version ${data.nda_version} · ${new Date(data.signed_at).toLocaleDateString()}</span>` : `<strong>Not signed</strong><span>No active NDA was found for this Slack ID.</span>`
  } catch (error) { result.className = "lookup-result is-missing"; result.textContent = error.message }
})

if (document.querySelector("[data-import-pending]")) setTimeout(() => window.location.reload(), 3000)
