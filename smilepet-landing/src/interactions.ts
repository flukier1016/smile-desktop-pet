import { sceneDetails } from './scenes'

export function startLanding() {
  const controller = new AbortController()
  const { signal } = controller
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)')
  const hero = document.querySelector<HTMLElement>('.hero-stage')!
  const heroWrap = document.querySelector<HTMLElement>('.hero-stage-wrap')!
  const consolePanel = document.querySelector<HTMLElement>('.scene-console')!
  const tabs = [...document.querySelectorAll<HTMLButtonElement>('[data-scene-index]')]
  const visible = new Set<Element>()
  let sceneIndex = 0
  let sceneTimer: number | undefined
  let sceneRunning = false
  let spriteAnimation: Animation | undefined
  let spriteVisible = false
  let spriteImage: HTMLImageElement | undefined
  let tiltFrame: number | undefined
  let heroBounds: DOMRect | undefined
  let tilt = { x: 0, y: 0 }

  const text = (selector: string, value: string) => {
    const element = document.querySelector(selector)
    if (element && element.textContent !== value) element.textContent = value
  }
  const replaceIcon = (selector: string, source: SVGElement, size: number) => {
    const copy = source.cloneNode(true) as SVGElement
    copy.setAttribute('width', String(size))
    copy.setAttribute('height', String(size))
    document.querySelector(selector)?.replaceWith(copy)
  }
  const selectScene = (index: number) => {
    const scene = sceneDetails[index]
    if (!scene || index === sceneIndex) return
    sceneIndex = index
    for (const [position, tab] of tabs.entries()) {
      tab.classList.toggle('active', position === index)
      tab.setAttribute('aria-selected', String(position === index))
    }
    hero.style.setProperty('--scene-color', scene.color)
    consolePanel.style.setProperty('--scene-color', scene.color)
    text('.scene-chip-top span', `SCENE ${scene.number}/23`)
    text('.speech-bubble > span', scene.title)
    text('.speech-bubble > strong', scene.message)
    text('.scene-panel strong', scene.title)
    const miniIcon = document.querySelector<HTMLElement>('.scene-panel .mini-icon')!
    miniIcon.style.background = scene.color
    text('.huge-scene-number', scene.number)
    text('.scene-readout h3', scene.title)
    text('.scene-readout > span', scene.subtitle)
    text('.console-message strong', `“${scene.message}”`)
    text('.console-aside .event-entry:first-of-type p', scene.note)
    const icon = tabs[index].querySelector('svg')!
    replaceIcon('.scene-readout > svg', icon, 34)
    replaceIcon('.scene-panel .mini-icon > svg', icon, 18)
  }
  for (const [index, tab] of tabs.entries()) {
    tab.addEventListener('click', () => selectScene(index), { signal })
  }

  const resetTilt = () => {
    if (tiltFrame !== undefined) cancelAnimationFrame(tiltFrame)
    tiltFrame = undefined
    heroBounds = undefined
    hero.style.setProperty('--tilt-x', '0deg')
    hero.style.setProperty('--tilt-y', '0deg')
  }
  heroWrap.addEventListener('pointerenter', () => { heroBounds = heroWrap.getBoundingClientRect() }, { signal })
  heroWrap.addEventListener('pointermove', (event) => {
    if (reducedMotion.matches || event.pointerType !== 'mouse' || !matchMedia('(hover: hover) and (pointer: fine)').matches) return
    heroBounds ??= heroWrap.getBoundingClientRect()
    tilt = {
      x: Math.max(-0.5, Math.min(0.5, (event.clientX - heroBounds.left) / heroBounds.width - 0.5)) * 7,
      y: Math.max(-0.5, Math.min(0.5, (event.clientY - heroBounds.top) / heroBounds.height - 0.5)) * -6,
    }
    if (tiltFrame !== undefined) return
    tiltFrame = requestAnimationFrame(() => {
      tiltFrame = undefined
      hero.style.setProperty('--tilt-x', `${tilt.y}deg`)
      hero.style.setProperty('--tilt-y', `${tilt.x}deg`)
    })
  }, { signal })
  heroWrap.addEventListener('pointerleave', resetTilt, { signal })
  window.addEventListener('resize', resetTilt, { signal, passive: true })
  window.addEventListener('scroll', () => { heroBounds = undefined }, { signal, passive: true })

  const syncSprite = () => {
    if (!spriteImage) return
    if (reducedMotion.matches) {
      spriteAnimation?.cancel()
      spriteAnimation = undefined
      return
    }
    if (!spriteAnimation) {
      spriteAnimation = spriteImage.animate(Array.from({ length: 89 }, (_, index) => {
        const frame = (24 + index) % 88
        return {
          transform: `translate3d(${-192 * (frame % 8)}px, ${-208 * Math.floor(frame / 8)}px, 0)`,
          easing: 'steps(1, end)',
        }
      }), { duration: 88 * 115, iterations: Infinity })
    }
    if (spriteVisible && !document.hidden) spriteAnimation.play()
    else spriteAnimation.pause()
  }
  const sync = () => {
    document.documentElement.dataset.motion = document.hidden || reducedMotion.matches ? 'paused' : 'running'
    const activeRegion = [...visible].some((region) => region.id === 'top' || region.id === 'scenes')
    const shouldRun = !document.hidden && !reducedMotion.matches && activeRegion
    if (shouldRun !== sceneRunning) {
      window.clearInterval(sceneTimer)
      sceneTimer = shouldRun ? window.setInterval(() => selectScene((sceneIndex + 1) % sceneDetails.length), 3600) : undefined
      sceneRunning = shouldRun
    }
    if (document.hidden || reducedMotion.matches) resetTilt()
    syncSprite()
  }
  const regionObserver = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      (entry.target as HTMLElement).dataset.active = String(entry.isIntersecting)
      if (entry.isIntersecting) visible.add(entry.target)
      else visible.delete(entry.target)
    }
    sync()
  }, { rootMargin: '80px 0px' })
  document.querySelectorAll('[data-motion-region]').forEach((region) => regionObserver.observe(region))

  const sprite = document.querySelector<HTMLElement>('.sprite-pet')!
  const preloadObserver = new IntersectionObserver(([entry]) => {
    if (!entry.isIntersecting) return
    spriteImage = document.createElement('img')
    spriteImage.className = 'sprite-sheet'
    spriteImage.src = '/spritesheet.webp'
    spriteImage.alt = ''
    spriteImage.setAttribute('aria-hidden', 'true')
    spriteImage.width = 1536
    spriteImage.height = 2288
    spriteImage.decoding = 'async'
    sprite.append(spriteImage)
    preloadObserver.disconnect()
    syncSprite()
  }, { rootMargin: '300px 0px' })
  const spriteObserver = new IntersectionObserver(([entry]) => {
    spriteVisible = entry.isIntersecting
    syncSprite()
  })
  preloadObserver.observe(sprite)
  spriteObserver.observe(sprite)
  document.addEventListener('visibilitychange', sync, { signal })
  reducedMotion.addEventListener('change', sync, { signal })
  sync()

  return () => {
    controller.abort()
    resetTilt()
    window.clearInterval(sceneTimer)
    regionObserver.disconnect()
    preloadObserver.disconnect()
    spriteObserver.disconnect()
    spriteAnimation?.cancel()
    spriteImage?.remove()
  }
}
