import './index.css'
import { startLanding } from './interactions'

// React is a development/build-time template engine. The production branch is
// removed by Vite, leaving only the static page's small interaction controller.
if (import.meta.env.DEV) {
  const [{ createElement }, { createRoot }, { flushSync }, { default: App }] = await Promise.all([
    import('react'), import('react-dom/client'), import('react-dom'), import('./App'),
  ])
  const root = document.getElementById('root')!
  flushSync(() => createRoot(root).render(createElement(App)))
}

const cleanup = startLanding()
if (import.meta.hot) import.meta.hot.dispose(cleanup)
