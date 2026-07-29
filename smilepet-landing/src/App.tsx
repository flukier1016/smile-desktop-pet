import { useEffect, useState, type CSSProperties, type PointerEvent } from 'react'
import {
  Apple,
  ArrowDownToLine,
  ArrowUpRight,
  BarChart3,
  Check,
  Code2,
  Coffee,
  Gift,
  Heart,
  LockKeyhole,
  Monitor,
  MousePointer2,
  ScanLine,
  Settings2,
  ShieldCheck,
  Sparkles,
  Star,
  Terminal,
  Video,
  WifiOff,
} from 'lucide-react'

const DOWNLOAD_URL =
  'https://github.com/flukier1016/smile-desktop-pet/releases/download/v1.4.1/SmilePet-v1.4.1-macos-universal.dmg'
const GITHUB_URL = 'https://github.com/flukier1016/smile-desktop-pet'
const CHECKSUM_URL =
  'https://github.com/flukier1016/smile-desktop-pet/releases/download/v1.4.1/SHA256SUMS.txt'

const scenes = [
  {
    id: 'develop',
    number: '04',
    label: '开发',
    title: '认真写代码',
    subtitle: 'Claude · 前台 App',
    message: '我不催你。这个 bug 我们一起盯。',
    note: '检测到开发环境，进入专注陪伴',
    icon: Code2,
    color: '#4d918c',
  },
  {
    id: 'market',
    number: '11',
    label: '盯盘',
    title: '市场雷达开启',
    subtitle: 'TradingView · 本地场景',
    message: '先看风险，再看机会。别追那根线。',
    note: '识别到金融场景，切换风险提醒',
    icon: BarChart3,
    color: '#d64a3a',
  },
  {
    id: 'meeting',
    number: '16',
    label: '会议',
    title: '安静旁听中',
    subtitle: 'Zoom · 前台 App',
    message: '我替你守着桌面，记得留行动项。',
    note: '检测到会议，降低动效和提示频率',
    icon: Video,
    color: '#7a6ab3',
  },
  {
    id: 'break',
    number: '21',
    label: '摸鱼',
    title: '合理休息',
    subtitle: 'Bilibili · 本地场景',
    message: '五分钟可以。第六分钟我会眨眼。',
    note: '识别到休息场景，启动轻松模式',
    icon: Coffee,
    color: '#df8d58',
  },
]

const dailyActions = [
  { label: '摸摸', icon: Heart, detail: '今日已点亮' },
  { label: '喂食', icon: Gift, detail: '经验 +1' },
  { label: '夸夸', icon: Sparkles, detail: '关系升温' },
  { label: '今日签', icon: Star, detail: '好运已签收' },
]

const marqueeItems = [
  '写代码',
  '报错抢救',
  '测试通过',
  '表格提醒',
  '盯盘守护',
  '会议静音',
  '阅读陪伴',
  '摸鱼计时',
  '深夜催下班',
]

function GitHubIcon({ size = 18 }: { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M12 .7a11.5 11.5 0 0 0-3.64 22.41c.58.11.79-.25.79-.56v-2.02c-3.22.7-3.9-1.36-3.9-1.36-.53-1.34-1.29-1.7-1.29-1.7-1.05-.72.08-.7.08-.7 1.17.08 1.78 1.2 1.78 1.2 1.03 1.77 2.71 1.26 3.37.96.1-.75.4-1.26.74-1.55-2.57-.29-5.27-1.28-5.27-5.68 0-1.26.45-2.28 1.19-3.09-.12-.29-.52-1.46.11-3.05 0 0 .97-.31 3.16 1.18a10.94 10.94 0 0 1 5.76 0c2.2-1.49 3.16-1.18 3.16-1.18.63 1.59.23 2.76.12 3.05.74.81 1.18 1.83 1.18 3.09 0 4.41-2.71 5.38-5.29 5.67.42.36.79 1.07.79 2.16v3.2c0 .31.21.68.8.56A11.5 11.5 0 0 0 12 .7Z" />
    </svg>
  )
}

function useReducedMotion() {
  const [reduced, setReduced] = useState(false)

  useEffect(() => {
    const query = window.matchMedia('(prefers-reduced-motion: reduce)')
    const sync = () => setReduced(query.matches)
    sync()
    query.addEventListener('change', sync)
    return () => query.removeEventListener('change', sync)
  }, [])

  return reduced
}

function SpritePet() {
  const [frame, setFrame] = useState(24)
  const reducedMotion = useReducedMotion()

  useEffect(() => {
    if (reducedMotion) return
    const timer = window.setInterval(() => {
      setFrame((current) => (current + 1) % 88)
    }, 115)
    return () => window.clearInterval(timer)
  }, [reducedMotion])

  const column = frame % 8
  const row = Math.floor(frame / 8)
  const style = {
    backgroundPosition: `${(column / 7) * 100}% ${(row / 10) * 100}%`,
  }

  return (
    <div className="sprite-pet" style={style} role="img" aria-label="88 帧动态笑笑桌宠" />
  )
}

function HeroStage({ sceneIndex }: { sceneIndex: number }) {
  const scene = scenes[sceneIndex]
  const [tilt, setTilt] = useState({ x: 0, y: 0 })
  const reducedMotion = useReducedMotion()

  const handlePointerMove = (event: PointerEvent<HTMLDivElement>) => {
    if (reducedMotion) return
    const rect = event.currentTarget.getBoundingClientRect()
    const x = (event.clientX - rect.left) / rect.width - 0.5
    const y = (event.clientY - rect.top) / rect.height - 0.5
    setTilt({ x: x * 7, y: y * -6 })
  }

  const stageStyle = {
    '--scene-color': scene.color,
    transform: `perspective(1200px) rotateX(${tilt.y}deg) rotateY(${tilt.x}deg)`,
  } as CSSProperties

  return (
    <div
      className="hero-stage-wrap"
      onPointerMove={handlePointerMove}
      onPointerLeave={() => setTilt({ x: 0, y: 0 })}
    >
      <div className="hero-stage" style={stageStyle}>
        <div className="window-bar">
          <div className="traffic-lights" aria-hidden="true">
            <span />
            <span />
            <span />
          </div>
          <span className="window-title">XIAOXIAO://COMPANION</span>
          <span className="window-live">
            <i />
            LIVE
          </span>
        </div>

        <div className="stage-grid" aria-hidden="true" />
        <div className="stage-orbit orbit-one" aria-hidden="true" />
        <div className="stage-orbit orbit-two" aria-hidden="true" />
        <div className="stage-reticle" aria-hidden="true">
          <span />
        </div>

        <div className="scene-chip scene-chip-top">
          <ScanLine size={14} />
          SCENE {scene.number}/23
        </div>
        <div className="scene-chip scene-chip-bottom">
          <LockKeyhole size={14} />
          LOCAL ONLY
        </div>

        <div className="pet-shadow" aria-hidden="true" />
        <img
          className="hero-pet"
          src="/xiaoxiao.png"
          alt="笑笑桌宠，穿着白色绒衣微笑奔跑"
          width="799"
          height="1181"
          fetchPriority="high"
        />

        <div className="speech-bubble" aria-live="polite">
          <span>{scene.title}</span>
          <strong>{scene.message}</strong>
        </div>

        <div className="mini-panel scene-panel">
          <div className="mini-icon" style={{ background: scene.color }}>
            <scene.icon size={18} />
          </div>
          <div>
            <span>正在</span>
            <strong>{scene.title}</strong>
          </div>
          <div className="signal-bars" aria-label="场景信号稳定">
            <i />
            <i />
            <i />
            <i />
          </div>
        </div>

        <div className="mini-panel privacy-panel">
          <ShieldCheck size={18} />
          <div>
            <span>隐私状态</span>
            <strong>没有任何内容离开 Mac</strong>
          </div>
        </div>
      </div>
    </div>
  )
}

function App() {
  const [activeScene, setActiveScene] = useState(0)
  const reducedMotion = useReducedMotion()

  useEffect(() => {
    if (reducedMotion) return
    const timer = window.setInterval(() => {
      setActiveScene((current) => (current + 1) % scenes.length)
    }, 3600)
    return () => window.clearInterval(timer)
  }, [reducedMotion])

  const scene = scenes[activeScene]

  return (
    <main>
      <nav className="nav-shell" aria-label="主导航">
        <a className="brand" href="#top" aria-label="笑笑桌宠首页">
          <span className="brand-mark">
            <img src="/app-icon.avif" alt="" width="512" height="512" />
          </span>
          <span className="brand-copy">
            <strong>笑笑桌宠</strong>
            <small>AMBIENT COMPANION</small>
          </span>
        </a>

        <div className="nav-links">
          <a href="#scenes">她会什么</a>
          <a href="#privacy">隐私与安全</a>
          <a href="#codex">Codex 皮肤</a>
        </div>

        <a className="nav-cta" href={DOWNLOAD_URL}>
          <Apple size={16} />
          免费下载
        </a>
      </nav>

      <section className="hero-section" id="top">
        <div className="ambient-glow glow-one" aria-hidden="true" />
        <div className="ambient-glow glow-two" aria-hidden="true" />
        <div className="hero-copy">
          <div className="eyebrow">
            <span className="pulse-dot" />
            原生 macOS 桌面搭子 · v1.4.1
          </div>
          <h1>
            你的 Mac，
            <br />
            终于有个
            <span>会懂你的搭子。</span>
          </h1>
          <p className="hero-lede">
            会看场景、会接话、还能被你慢慢养熟。
            <br />
            她住在桌面边缘，不打扰，只陪伴。
          </p>

          <div className="hero-actions">
            <a className="button button-primary" href={DOWNLOAD_URL}>
              <ArrowDownToLine size={19} />
              免费下载 for Mac
              <span>v1.4.1</span>
            </a>
            <a className="button button-secondary" href={GITHUB_URL} target="_blank" rel="noreferrer">
              <GitHubIcon size={19} />
              GitHub
              <ArrowUpRight size={15} />
            </a>
          </div>

          <div className="trust-row" aria-label="产品特性">
            <span>
              <WifiOff size={15} />
              100% 本地
            </span>
            <span>
              <ShieldCheck size={15} />
              0 遥测
            </span>
            <span>
              <Monitor size={15} />
              Intel + Apple Silicon
            </span>
          </div>
        </div>

        <HeroStage sceneIndex={activeScene} />

        <div className="scroll-cue" aria-hidden="true">
          <MousePointer2 size={14} />
          MOVE / SCROLL
        </div>
      </section>

      <div className="marquee" aria-label="笑笑支持的场景">
        <div className="marquee-track">
          {[...marqueeItems, ...marqueeItems].map((item, index) => (
            <span key={`${item}-${index}`}>
              {item}
              <i>✦</i>
            </span>
          ))}
        </div>
      </div>

      <section className="statement-section">
        <div className="section-label">
          <span>01</span>
          不只是桌面挂件
        </div>
        <div className="statement-copy">
          <p>她观察工作节奏。</p>
          <p>她给出刚刚好的反应。</p>
          <p className="statement-accent">她会记得你们一起度过的每一天。</p>
        </div>
        <div className="stat-grid">
          <article>
            <strong>23</strong>
            <span>种场景状态</span>
            <small>从写代码到深夜催下班</small>
          </article>
          <article>
            <strong>5</strong>
            <span>段关系等级</span>
            <small>从初见搭子到灵魂工友</small>
          </article>
          <article>
            <strong>0</strong>
            <span>云端依赖</span>
            <small>不登录、不上传、不追踪</small>
          </article>
        </div>
      </section>

      <section className="scenes-section" id="scenes">
        <div className="section-heading">
          <div>
            <div className="section-label light">
              <span>02</span>
              场景感知
            </div>
            <h2>她知道你在忙什么。</h2>
          </div>
          <p>
            默认只读取前台 App；可选本地 OCR 会在内存中识别当前窗口，
            把你的桌面切换成恰到好处的陪伴现场。
          </p>
        </div>

        <div className="scene-console" style={{ '--scene-color': scene.color } as CSSProperties}>
          <div className="scene-tabs" role="tablist" aria-label="场景示例">
            {scenes.map((item, index) => (
              <button
                key={item.id}
                type="button"
                role="tab"
                aria-selected={activeScene === index}
                className={activeScene === index ? 'active' : ''}
                onClick={() => setActiveScene(index)}
              >
                <item.icon size={18} />
                <span>{item.label}</span>
                <small>{item.number}/23</small>
              </button>
            ))}
          </div>

          <div className="console-main">
            <div className="console-topline">
              <span>
                <i />
                XIAOXIAO LOCAL SIGNAL
              </span>
              <span>LATENCY 0ms</span>
            </div>
            <div className="console-scene">
              <span className="huge-scene-number">{scene.number}</span>
              <div className="scene-readout">
                <scene.icon size={34} />
                <p>当前场景</p>
                <h3>{scene.title}</h3>
                <span>{scene.subtitle}</span>
              </div>
              <div className="waveform" aria-hidden="true">
                {Array.from({ length: 42 }).map((_, index) => (
                  <i key={index} style={{ '--wave': `${18 + ((index * 23) % 74)}%` } as CSSProperties} />
                ))}
              </div>
            </div>
            <div className="console-message">
              <span>笑笑：</span>
              <strong>“{scene.message}”</strong>
            </div>
          </div>

          <aside className="console-aside">
            <span className="aside-kicker">LOCAL EVENT LOG</span>
            <div className="event-entry">
              <i>16:42:08</i>
              <p>{scene.note}</p>
            </div>
            <div className="event-entry">
              <i>16:42:08</i>
              <p>截图与识别文字仅在内存短暂存在</p>
            </div>
            <div className="event-entry success">
              <Check size={15} />
              <p>网络请求：0</p>
            </div>
            <div className="local-stamp">
              <LockKeyhole size={24} />
              <span>PROCESSED<br />ON YOUR MAC</span>
            </div>
          </aside>
        </div>
      </section>

      <section className="companion-section">
        <div className="companion-visual">
          <div className="control-halo" aria-hidden="true" />
          <div className="control-window">
            <div className="control-window-bar">
              <span />
              <span />
              <span />
              <small>陪伴中心</small>
            </div>
            <img
              src="/control-center.png"
              alt="笑笑桌宠原生陪伴控制中心"
              width="568"
              height="758"
              loading="lazy"
            />
          </div>
          <div className="floating-badge badge-level">
            <span>LV.5</span>
            灵魂工友
          </div>
          <div className="floating-badge badge-streak">
            <span>🔥 12</span>
            连续陪伴
          </div>
        </div>

        <div className="companion-copy">
          <div className="section-label">
            <span>03</span>
            每日陪伴
          </div>
          <h2>不是养成任务。<br />是每天的一小圈。</h2>
          <p>
            摸摸、喂食、夸夸、抽一支今日签。四件小事会留下经验、连续天数和关系等级，
            所有记录都只属于这台 Mac。
          </p>

          <div className="daily-list">
            {dailyActions.map((action, index) => (
              <div className="daily-action" key={action.label}>
                <span className="daily-index">0{index + 1}</span>
                <div className="daily-icon">
                  <action.icon size={19} />
                </div>
                <strong>{action.label}</strong>
                <small>{action.detail}</small>
                <Check size={17} />
              </div>
            ))}
          </div>

          <div className="relationship-progress">
            <div>
              <span>今日陪伴</span>
              <strong>4 / 4 · 全勤</strong>
            </div>
            <div className="progress-track">
              <i />
            </div>
          </div>
        </div>
      </section>

      <section className="privacy-section" id="privacy">
        <div className="privacy-noise" aria-hidden="true" />
        <div className="section-label light">
          <span>04</span>
          隐私边界
        </div>
        <div className="privacy-heading">
          <h2>聪明，但不偷看。</h2>
          <p>没有账号，没有广告，没有遥测。OCR 默认关闭，所有判断都在你的 Mac 本地完成。</p>
        </div>

        <div className="privacy-pipeline">
          <div className="pipeline-card">
            <span>01 / INPUT</span>
            <Monitor size={28} />
            <strong>前台 App</strong>
            <small>可选：当前窗口 OCR</small>
          </div>
          <div className="pipeline-link">
            <i />
            <span>仅内存</span>
          </div>
          <div className="pipeline-card featured">
            <span>02 / PROCESS</span>
            <ScanLine size={28} />
            <strong>macOS 本地识别</strong>
            <small>Vision + 场景分类</small>
          </div>
          <div className="pipeline-link">
            <i />
            <span>0ms</span>
          </div>
          <div className="pipeline-card">
            <span>03 / REACT</span>
            <Sparkles size={28} />
            <strong>笑笑做出反应</strong>
            <small>状态、台词与动效</small>
          </div>
        </div>

        <div className="privacy-boundary">
          <WifiOff size={20} />
          <span>这条线之外，没有你的数据。</span>
          <div>
            <small>截图保存</small><b>×</b>
            <small>文字上传</small><b>×</b>
            <small>后台追踪</small><b>×</b>
          </div>
        </div>
      </section>

      <section className="security-section" id="security">
        <div className="section-label">
          <span>05</span>
          安全工程
        </div>
        <div className="security-heading">
          <h2>安全靠可验证，<br />不靠一句“放心”。</h2>
          <p>
            权限边界、源码门禁、供应链和发布校验全部公开。
            做到什么就写什么，尚未做到的也明确告诉你。
          </p>
        </div>

        <div className="security-grid">
          <article>
            <span>01 / PERMISSION</span>
            <LockKeyhole size={27} />
            <strong>权限最小化</strong>
            <p>基础模式无需屏幕录制；OCR 仅在用户主动开启后请求权限，关闭后停止处理。</p>
          </article>
          <article>
            <span>02 / SOURCE GATE</span>
            <Terminal size={27} />
            <strong>源码安全门禁</strong>
            <p>仓库脚本扫描常见网络 API、凭据、私钥、环境文件和原始人物照片。</p>
          </article>
          <article>
            <span>03 / SUPPLY CHAIN</span>
            <ShieldCheck size={27} />
            <strong>供应链透明</strong>
            <p>GitHub Actions 固定完整提交 SHA，Dependabot 跟踪更新，CodeQL 分析 Swift 变更。</p>
          </article>
          <article>
            <span>04 / DISCLOSURE</span>
            <GitHubIcon size={27} />
            <strong>私密漏洞上报</strong>
            <p>敏感问题不进入公开 Issue；使用 GitHub Private Vulnerability Reporting 协调修复。</p>
          </article>
        </div>

        <div className="release-integrity">
          <div className="integrity-status">
            <ShieldCheck size={29} />
            <div>
              <span>RELEASE INTEGRITY · v1.4.1</span>
              <strong>官方 DMG + SHA-256 校验</strong>
            </div>
          </div>
          <div className="checksum-value">
            <small>DMG SHA-256</small>
            <code>94d2f16d8320a217…5247e1881b181a14</code>
          </div>
          <a href={CHECKSUM_URL} target="_blank" rel="noreferrer">
            查看完整校验文件 <ArrowUpRight size={14} />
          </a>
        </div>

        <div className="signing-boundary">
          <span>诚实边界</span>
          <p>
            当前 Release 使用临时签名，尚未经过 Apple 公证。首次打开需在 Finder
            右键选择“打开”；请只从本仓库官方 Releases 下载，并核验 SHA-256。
          </p>
          <a href={`${GITHUB_URL}/blob/main/SECURITY.md`} target="_blank" rel="noreferrer">
            阅读完整安全政策 <ArrowUpRight size={14} />
          </a>
        </div>
      </section>

      <section className="codex-section" id="codex">
        <div className="codex-copy">
          <div className="section-label">
            <span>06</span>
            Bonus mode
          </div>
          <span className="codex-kicker">
            <Terminal size={16} />
            CODEX NATIVE PET
          </span>
          <h2>她甚至能住进<br />你的 Codex。</h2>
          <p>
            一整套官方自定义接口兼容的 88 帧笑笑皮肤：待机、奔跑、专注、报错、庆祝，
            再加上暖白与墨棕主题。
          </p>
          <a className="text-link" href={`${GITHUB_URL}/tree/main/CodexSkin`} target="_blank" rel="noreferrer">
            查看一键安装方式
            <ArrowUpRight size={16} />
          </a>
        </div>

        <div className="codex-terminal">
          <div className="terminal-bar">
            <div>
              <span />
              <span />
              <span />
            </div>
            <small>codex — xiaoxiao.pet</small>
            <Settings2 size={14} />
          </div>
          <div className="terminal-code">
            <span><i>01</i><b>$</b> ./scripts/install-codex-skin.sh</span>
            <span><i>02</i><em>✓</em> Codex bundle verified</span>
            <span><i>03</i><em>✓</em> 88-frame sprite installed</span>
            <span><i>04</i><em>✓</em> config backup secured · 0600</span>
            <span><i>05</i><b>→</b> Smile mode is ready</span>
          </div>
          <div className="sprite-stage">
            <div className="sprite-grid" aria-hidden="true" />
            <SpritePet />
            <div className="sprite-caption">
              <span>FRAME LOOP</span>
              <strong>88 / 88</strong>
            </div>
          </div>
        </div>
      </section>

      <section className="final-section">
        <div className="final-orbit orbit-a" aria-hidden="true" />
        <div className="final-orbit orbit-b" aria-hidden="true" />
        <img
          className="final-pet"
          src="/xiaoxiao.png"
          alt=""
          width="799"
          height="1181"
          loading="lazy"
        />
        <div className="final-copy">
          <span className="final-kicker">YOUR MAC DESERVES A LITTLE LIFE.</span>
          <h2>把笑笑<br />带回桌面。</h2>
          <p>免费下载 · macOS 13+ · 通用架构 · 完全本地</p>
          <div className="hero-actions">
            <a className="button button-dark" href={DOWNLOAD_URL}>
              <Apple size={20} />
              下载 v1.4.1
            </a>
            <a className="button button-ghost" href={GITHUB_URL} target="_blank" rel="noreferrer">
              <GitHubIcon size={19} />
              Star on GitHub
            </a>
          </div>
        </div>
      </section>

      <footer>
        <a className="brand footer-brand" href="#top">
          <span className="brand-mark">
            <img src="/app-icon.avif" alt="" width="512" height="512" loading="lazy" />
          </span>
          <span className="brand-copy">
            <strong>笑笑桌宠</strong>
            <small>AMBIENT COMPANION</small>
          </span>
        </a>
        <p>原生 Swift 制作。代码 MIT 开源，角色素材保留权利。</p>
        <div>
          <a href={`${GITHUB_URL}/blob/main/PRIVACY.md`} target="_blank" rel="noreferrer">隐私</a>
          <a href={`${GITHUB_URL}/blob/main/SECURITY.md`} target="_blank" rel="noreferrer">安全</a>
          <a href={`${GITHUB_URL}/issues`} target="_blank" rel="noreferrer">反馈</a>
          <span>© 2026 XIAOXIAO</span>
        </div>
      </footer>
    </main>
  )
}

export default App
