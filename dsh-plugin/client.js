window.__ModuleLoader__.load({
  id: 'dsh-memory-dock',
  factory(require) {
    const React = require('react')
    const h = React.createElement
    const { useEffect, useMemo, useRef, useState } = React

    const NS = 'dsh-memory-dock'
    const STATE_URL = '/memory-dock/api/state'
    const ACTION_URL = '/memory-dock/api/action'

    const DICT = {
      zh: {
        title: '记忆坞',
        subtitle: '拖一张记忆卡到 AI',
        search: '搜索标题、分组或内容…',
        all: '全部',
        empty: '还没有记忆卡',
        emptyHint: '把 .md 或 .txt 文件放进工作区\n或打开文件夹添加一张',
        refresh: '刷新',
        settings: '设置',
        close: '关闭',
        workspace: '记忆工作区',
        chooseFolder: '选择文件夹',
        openFolder: '在 Finder 中打开',
        back: '返回',
        dragHint: '拖动卡片可直接插入或拖到输入框',
        inserted: '已插入当前输入框',
        copied: '当前没有可插入的输入框，已复制记忆内容',
        copyFailed: '插入失败，且复制未成功',
        binary: '该格式不支持直接插入，已用默认应用打开',
        truncated: '内容较长，已截断',
        error: '读取记忆失败',
        retry: '重试',
        openFile: '打开',
        revealFile: '在 Finder 中显示',
        items: '张',
        count: '张记忆',
        saved: '工作区已更新',
        chooseFailed: '选择文件夹失败',
        loading: '读取中…',
        noResults: '没有匹配的记忆',
        noResultsHint: '换个关键词，或切换到全部记忆',
        insertHint: '点击插入 · 拖动带走',
        folderHint: '每个子文件夹是一个分类；支持 Markdown、TXT、JSON、PDF、DOCX 等。',
        tooltip: '记忆坞',
        openError: '打开失败'
      },
      en: {
        title: 'Memory dock',
        subtitle: 'Drag a memory card into AI',
        search: 'Search title, group, or content…',
        all: 'All',
        empty: 'No memory cards yet',
        emptyHint: 'Add .md or .txt files to the workspace\nor open the folder to create one',
        refresh: 'Refresh',
        settings: 'Settings',
        close: 'Close',
        workspace: 'Memory workspace',
        chooseFolder: 'Choose folder',
        openFolder: 'Open in Finder',
        back: 'Back',
        dragHint: 'Drag a card into the composer or another app',
        inserted: 'Inserted into the current composer',
        copied: 'No active composer; copied the memory text',
        copyFailed: 'Insert failed and copy was unavailable',
        binary: 'This format cannot be inserted; opened with the default app',
        truncated: 'Long content, truncated',
        error: 'Could not read memories',
        retry: 'Retry',
        openFile: 'Open',
        revealFile: 'Reveal in Finder',
        items: '',
        count: 'memories',
        saved: 'Workspace updated',
        chooseFailed: 'Could not choose a folder',
        loading: 'Loading…',
        noResults: 'No matching memories',
        noResultsHint: 'Try another keyword, or switch to All',
        insertHint: 'Click to insert · drag to take it',
        folderHint: 'Each subfolder is a group; Markdown, TXT, JSON, PDF, DOCX and more are supported.',
        tooltip: 'Memory dock',
        openError: 'Could not open'
      }
    }

    const bridge = { handler: null }

    const CSS = `
      .mdz-shell {
        --mdz-accent: #ff6a4d;
        --mdz-accent-warm: #ffb347;
        position: fixed;
        right: 24px;
        bottom: 178px;
        z-index: 2147483000;
        pointer-events: none;
        font-family: var(--ds-font-family, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif);
        color: var(--dsw-alias-label-primary);
      }
      .mdz-ball {
        pointer-events: auto;
        position: relative;
        width: 54px;
        height: 54px;
        padding: 0;
        border: 1px solid color-mix(in srgb, var(--mdz-accent) 62%, white 10%);
        border-radius: 50%;
        background:
          radial-gradient(circle at 32% 24%, rgba(255,255,255,.34), transparent 32%),
          linear-gradient(145deg, var(--mdz-accent-warm), var(--mdz-accent));
        box-shadow: 0 12px 30px rgba(120, 42, 28, .28), 0 3px 9px rgba(0,0,0,.18);
        cursor: pointer;
        transition: transform .16s ease, box-shadow .16s ease, filter .16s ease;
        outline: none;
      }
      .mdz-ball:hover, .mdz-ball:focus-visible {
        transform: translateY(-2px) scale(1.035);
        box-shadow: 0 16px 36px rgba(120, 42, 28, .34), 0 4px 12px rgba(0,0,0,.2);
        filter: saturate(1.04);
      }
      .mdz-ball:active { transform: translateY(0) scale(.98); }
      .mdz-ball svg { width: 28px; height: 28px; display: block; margin: auto; filter: drop-shadow(0 2px 2px rgba(84,22,10,.18)); }
      .mdz-badge {
        position: absolute;
        top: -5px;
        right: -5px;
        min-width: 18px;
        height: 18px;
        padding: 0 5px;
        border: 1px solid rgba(255,255,255,.35);
        border-radius: 9px;
        background: var(--dsw-alias-bg-overlay, #20232b);
        color: var(--dsw-alias-label-primary);
        font-size: 10px;
        font-weight: 700;
        line-height: 16px;
        text-align: center;
        box-shadow: 0 2px 6px rgba(0,0,0,.2);
      }
      .mdz-panel {
        pointer-events: auto;
        position: absolute;
        right: 0;
        bottom: 68px;
        width: min(392px, calc(100vw - 32px));
        max-height: min(480px, calc(100vh - 140px));
        display: flex;
        flex-direction: column;
        overflow: hidden;
        border: 1px solid var(--dsw-alias-border-l2);
        border-radius: 18px;
        background: color-mix(in srgb, var(--dsw-alias-bg-overlay) 94%, transparent);
        box-shadow: 0 24px 70px rgba(0,0,0,.28), 0 5px 18px rgba(0,0,0,.12);
        backdrop-filter: blur(24px);
        -webkit-backdrop-filter: blur(24px);
        animation: mdz-in .16s ease-out;
        z-index: 2;
      }
      @keyframes mdz-in {
        from { opacity: 0; transform: translateY(8px) scale(.985); }
        to { opacity: 1; transform: translateY(0) scale(1); }
      }
      .mdz-head {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 15px 16px 11px 16px;
        flex: none;
      }
      .mdz-logo {
        width: 34px; height: 34px; flex: none; border-radius: 10px;
        display: flex; align-items: center; justify-content: center;
        background: radial-gradient(circle at 32% 22%, rgba(255,255,255,.3), transparent 34%), linear-gradient(145deg, var(--mdz-accent-warm), var(--mdz-accent));
        box-shadow: 0 5px 14px rgba(180,65,35,.22);
      }
      .mdz-logo svg { width: 21px; height: 21px; }
      .mdz-headcopy { min-width: 0; flex: 1; }
      .mdz-title { font-size: 14px; line-height: 1.3; font-weight: 650; letter-spacing: -.01em; }
      .mdz-sub { margin-top: 1px; font-size: 10px; color: var(--dsw-alias-label-secondary); }
      .mdz-icon-btn {
        width: 27px; height: 27px; flex: none; padding: 0; border: 0; border-radius: 7px;
        background: transparent; color: var(--dsw-alias-label-secondary);
        font: inherit; font-size: 18px; line-height: 1; cursor: pointer;
        display: inline-flex; align-items: center; justify-content: center;
      }
      .mdz-icon-btn:hover { background: var(--dsw-alias-interactive-bg-hover, rgba(255,255,255,.08)); color: var(--dsw-alias-label-primary); }
      .mdz-search {
        flex: none; margin: 0 14px 10px; height: 34px;
        display: flex; align-items: center; gap: 7px;
        padding: 0 10px; border: 1px solid var(--dsw-alias-border-l2); border-radius: 9px;
        background: color-mix(in srgb, var(--dsw-alias-bg-layer-2) 62%, transparent);
        color: var(--dsw-alias-label-secondary);
        transition: border-color .16s ease;
      }
      .mdz-search:focus-within { border-color: color-mix(in srgb, var(--dsw-alias-brand-primary) 55%, var(--dsw-alias-border-l2)); }
      .mdz-search svg { width: 14px; height: 14px; flex: none; opacity: .72; }
      .mdz-search input {
        width: 100%; min-width: 0; border: 0; outline: 0; background: transparent;
        color: var(--dsw-alias-label-primary); font: inherit; font-size: 12px;
      }
      .mdz-search input::placeholder { color: var(--dsw-alias-label-secondary); opacity: .82; }
      .mdz-chips {
        display: flex; flex: none; gap: 5px; overflow-x: auto; padding: 0 14px 10px;
        scrollbar-width: none;
      }
      .mdz-chips::-webkit-scrollbar { display: none; }
      .mdz-chip {
        flex: none; max-width: 156px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
        padding: 4px 9px; border: 1px solid var(--dsw-alias-border-l2); border-radius: 999px;
        background: transparent; color: var(--dsw-alias-label-secondary);
        font: inherit; font-size: 10px; cursor: pointer;
      }
      .mdz-chip:hover { color: var(--dsw-alias-label-primary); border-color: var(--dsw-alias-border-l4, var(--dsw-alias-border-l2)); }
      .mdz-chip.is-on { color: var(--dsw-alias-label-primary-foreground, #fff); background: var(--dsw-alias-button-primary-fill, var(--dsw-alias-brand-primary)); border-color: transparent; }
      .mdz-chip-count { opacity: .65; margin-left: 4px; font-variant-numeric: tabular-nums; }
      .mdz-body {
        flex: 1 1 auto; min-height: 110px; overflow-y: auto; overscroll-behavior: contain;
        padding: 0 10px 8px; scrollbar-width: thin;
      }
      .mdz-body::-webkit-scrollbar { width: 5px; }
      .mdz-body::-webkit-scrollbar-thumb { background: var(--dsw-alias-border-l2); border-radius: 4px; }
      .mdz-card {
        box-sizing: border-box; display: flex; gap: 10px; align-items: flex-start;
        width: 100%; margin: 0 0 7px; padding: 10px 10px 9px;
        border: 1px solid var(--dsw-alias-border-l2); border-radius: 11px;
        background: color-mix(in srgb, var(--dsw-alias-bg-layer-2) 64%, transparent);
        cursor: grab; outline: none; transition: border-color .14s ease, background .14s ease, transform .14s ease;
        user-select: none;
      }
      .mdz-card:hover, .mdz-card:focus-visible {
        border-color: color-mix(in srgb, var(--mdz-accent) 44%, var(--dsw-alias-border-l2));
        background: var(--dsw-alias-interactive-bg-hover, color-mix(in srgb, var(--dsw-alias-bg-layer-2) 82%, transparent));
      }
      .mdz-card:active { cursor: grabbing; transform: scale(.995); }
      .mdz-card-icon {
        width: 32px; height: 32px; flex: none; border-radius: 9px; display: flex;
        align-items: center; justify-content: center;
        color: var(--mdz-accent); background: color-mix(in srgb, var(--mdz-accent) 13%, transparent);
        border: 1px solid color-mix(in srgb, var(--mdz-accent) 18%, transparent);
      }
      .mdz-card-icon svg { width: 17px; height: 17px; }
      .mdz-card-copy { flex: 1; min-width: 0; padding-top: 1px; }
      .mdz-card-title {
        font-size: 12px; line-height: 1.35; font-weight: 620; color: var(--dsw-alias-label-primary);
        overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
      }
      .mdz-card-preview {
        margin-top: 2px; font-size: 10.5px; line-height: 1.42; color: var(--dsw-alias-label-secondary);
        display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;
        overflow-wrap: anywhere;
      }
      .mdz-card-meta {
        margin-top: 5px; font-size: 9px; line-height: 1.2; color: var(--dsw-alias-label-secondary); opacity: .72;
        display: flex; align-items: center; gap: 5px; overflow: hidden; white-space: nowrap;
      }
      .mdz-dot { width: 3px; height: 3px; flex: none; border-radius: 50%; background: currentColor; opacity: .55; }
      .mdz-card-actions { display: flex; flex: none; gap: 2px; margin: -2px -2px 0 0; opacity: .56; }
      .mdz-card:hover .mdz-card-actions, .mdz-card:focus-within .mdz-card-actions { opacity: 1; }
      .mdz-mini {
        border: 0; background: transparent; color: var(--dsw-alias-label-secondary); border-radius: 5px;
        width: 22px; height: 22px; padding: 0; font: inherit; font-size: 13px; cursor: pointer;
        display: inline-flex; align-items: center; justify-content: center;
      }
      .mdz-mini:hover { color: var(--dsw-alias-label-primary); background: var(--dsw-alias-interactive-bg-hover, rgba(255,255,255,.08)); }
      .mdz-empty { padding: 34px 16px 36px; text-align: center; color: var(--dsw-alias-label-secondary); }
      .mdz-empty svg { width: 31px; height: 31px; opacity: .48; margin-bottom: 9px; }
      .mdz-empty-title { font-size: 12px; font-weight: 600; color: var(--dsw-alias-label-secondary); }
      .mdz-empty-copy { margin-top: 4px; font-size: 10px; line-height: 1.45; white-space: pre-line; opacity: .78; }
      .mdz-foot {
        flex: none; display: flex; align-items: center; gap: 4px;
        min-height: 42px; padding: 8px 14px 9px;
        border-top: 1px solid var(--dsw-alias-border-l1);
        background: color-mix(in srgb, var(--dsw-alias-bg-layer-1) 38%, transparent);
      }
      .mdz-foot-path {
        flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
        font-size: 9px; color: var(--dsw-alias-label-secondary); opacity: .76;
      }
      .mdz-foot-btn {
        flex: none; height: 24px; padding: 0 7px; border: 0; border-radius: 6px;
        background: transparent; color: var(--dsw-alias-label-secondary);
        font: inherit; font-size: 10px; cursor: pointer;
      }
      .mdz-foot-btn:hover { color: var(--dsw-alias-label-primary); background: var(--dsw-alias-interactive-bg-hover, rgba(255,255,255,.08)); }
      .mdz-settings { padding: 0 14px 16px; }
      .mdz-settings-title { font-size: 12px; font-weight: 650; margin: 0 0 3px; }
      .mdz-settings-copy { font-size: 10px; line-height: 1.5; color: var(--dsw-alias-label-secondary); opacity: .82; overflow-wrap: anywhere; }
      .mdz-path {
        margin: 12px 0 10px; padding: 9px 10px; border: 1px solid var(--dsw-alias-border-l2); border-radius: 8px;
        background: color-mix(in srgb, var(--dsw-alias-bg-layer-2) 62%, transparent);
        font-family: var(--ds-font-family-code, ui-monospace, monospace); font-size: 10px;
        line-height: 1.35; color: var(--dsw-alias-label-secondary); overflow-wrap: anywhere;
      }
      .mdz-button-row { display: flex; flex-wrap: wrap; gap: 6px; }
      .mdz-action {
        height: 28px; padding: 0 10px; border: 1px solid var(--dsw-alias-border-l2); border-radius: 7px;
        background: transparent; color: var(--dsw-alias-label-primary); font: inherit; font-size: 10.5px; cursor: pointer;
      }
      .mdz-action:hover { background: var(--dsw-alias-interactive-bg-hover, rgba(255,255,255,.08)); }
      .mdz-action.primary { background: var(--dsw-alias-button-primary-fill, var(--dsw-alias-brand-primary)); color: var(--dsw-alias-label-primary-foreground, #fff); border-color: transparent; }
      .mdz-note { margin-top: 14px; font-size: 9.5px; line-height: 1.5; color: var(--dsw-alias-label-secondary); opacity: .7; }
      .mdz-toast {
        position: absolute; left: 50%; bottom: 54px; transform: translateX(-50%);
        max-width: calc(100% - 32px); padding: 6px 11px; border-radius: 8px;
        background: rgba(24,26,32,.94); color: #fff; font-size: 10.5px; white-space: nowrap;
        box-shadow: 0 5px 18px rgba(0,0,0,.25); pointer-events: none; z-index: 5;
      }
      @media (max-width: 700px) {
        .mdz-shell { right: 12px; bottom: 136px; }
        .mdz-panel { width: calc(100vw - 24px); right: 0; }
      }
    `

    function useLocale(ctx) {
      const [, setRevision] = useState(0)
      useEffect(() => {
        if (!ctx || !ctx.locale || typeof ctx.locale.subscribe !== 'function') return undefined
        return ctx.locale.subscribe(() => setRevision(value => value + 1))
      }, [ctx])
      return ctx && ctx.locale ? ctx.locale.bind(NS) : key => key
    }

    function request(path, options) {
      return fetch(path, Object.assign({ credentials: 'same-origin', cache: 'no-store' }, options || {}))
        .then(async response => {
          let payload = null
          try { payload = await response.json() } catch {}
          if (!response.ok) throw new Error((payload && payload.error) || `HTTP ${response.status}`)
          if (payload && payload.error) throw new Error(payload.error)
          return payload
        })
    }

    function postAction(action, extra) {
      return request(ACTION_URL, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(Object.assign({ action }, extra || {})),
      })
    }

    function Icon(props) {
      const name = props.name
      const common = {
        viewBox: '0 0 24 24',
        fill: 'none',
        stroke: 'currentColor',
        strokeWidth: 1.8,
        strokeLinecap: 'round',
        strokeLinejoin: 'round',
        'aria-hidden': 'true',
      }
      if (name === 'cards') {
        return h('svg', common,
          h('rect', { x: 4, y: 4, width: 16, height: 7, rx: 2.2, fill: 'currentColor', stroke: 'none', opacity: '.38' }),
          h('rect', { x: 3, y: 9, width: 18, height: 8, rx: 2.4, fill: 'currentColor', stroke: 'none', opacity: '.64' }),
          h('rect', { x: 2, y: 14, width: 20, height: 7, rx: 2.4, fill: 'currentColor', stroke: 'none' }))
      }
      if (name === 'search') {
        return h('svg', common, h('circle', { cx: 10.8, cy: 10.8, r: 6.2 }), h('path', { d: 'm16 16 4.2 4.2' }))
      }
      if (name === 'folder') {
        return h('svg', common, h('path', { d: 'M3.5 6.5a2 2 0 0 1 2-2h4l2 2h7a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z' }))
      }
      if (name === 'gear') {
        return h('svg', common, h('circle', { cx: 12, cy: 12, r: 3.1 }), h('path', { d: 'M19.4 15a1.7 1.7 0 0 0 .34 1.88l.06.06-2.86 2.86-.06-.06A1.7 1.7 0 0 0 15 19.4a1.7 1.7 0 0 0-1 .6 1.7 1.7 0 0 0-.4 1.1V21H9.6v-.09A1.7 1.7 0 0 0 8.5 19.4a1.7 1.7 0 0 0-1.88.34l-.06.06-2.86-2.86.06-.06A1.7 1.7 0 0 0 4.1 15a1.7 1.7 0 0 0-.6-1 1.7 1.7 0 0 0-1.1-.4H2.3V9.6h.09A1.7 1.7 0 0 0 4.1 8.5a1.7 1.7 0 0 0-.34-1.88l-.06-.06L6.56 3.7l.06.06A1.7 1.7 0 0 0 8.5 4.1a1.7 1.7 0 0 0 1-.6 1.7 1.7 0 0 0 .4-1.1V2.3h4v.09A1.7 1.7 0 0 0 15 4.1a1.7 1.7 0 0 0 1.88-.34l.06-.06 2.86 2.86-.06.06A1.7 1.7 0 0 0 19.4 8.5c.1.38.32.72.6 1 .3.27.69.4 1.1.4h.09v4h-.09a1.7 1.7 0 0 0-1.7 1.1z' }))
      }
      if (name === 'refresh') {
        return h('svg', common, h('path', { d: 'M20 6v5h-5' }), h('path', { d: 'M4 18v-5h5' }), h('path', { d: 'M6.1 9A7 7 0 0 1 18.8 6.8L20 11M4 13l1.2 4.2A7 7 0 0 0 17.9 15' }))
      }
      if (name === 'open') {
        return h('svg', common, h('path', { d: 'M14 4h6v6' }), h('path', { d: 'm20 4-9 9' }), h('path', { d: 'M19 14v4a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2h4' }))
      }
      if (name === 'file') {
        return h('svg', common, h('path', { d: 'M6 3.5h7l5 5v12H6z' }), h('path', { d: 'M13 3.5v5h5' }), h('path', { d: 'M9 13h6M9 16.5h4' }))
      }
      return h('svg', common, h('circle', { cx: 12, cy: 12, r: 8 }))
    }

    function LogoMark() {
      return h('div', { className: 'mdz-logo' }, h(Icon, { name: 'cards' }))
    }

    function InputBridge(props) {
      const actions = props.inputActions
      useEffect(() => {
        if (!actions || typeof actions.captureInsertion !== 'function' || typeof actions.insertText !== 'function') return undefined
        const handler = text => {
          try {
            const span = actions.captureInsertion()
            return actions.insertText(text, span) === true
          } catch {
            return false
          }
        }
        bridge.handler = handler
        return () => {
          if (bridge.handler === handler) bridge.handler = null
        }
      }, [actions])
      return null
    }

    function MemoryDock(props) {
      const { ctx } = props
      const t = useLocale(ctx)
      const [open, setOpen] = useState(false)
      const [settingsOpen, setSettingsOpen] = useState(false)
      const [state, setState] = useState(null)
      const [error, setError] = useState('')
      const [query, setQuery] = useState('')
      const [selected, setSelected] = useState('__all__')
      const [toast, setToast] = useState('')
      const [busy, setBusy] = useState(false)
      const rootRef = useRef(null)
      const toastTimer = useRef(0)

      const showToast = text => {
        setToast(text)
        if (toastTimer.current) clearTimeout(toastTimer.current)
        toastTimer.current = setTimeout(() => setToast(''), 1900)
      }

      const loadState = async silent => {
        try {
          const next = await request(STATE_URL)
          setState(next)
          setError('')
          return next
        } catch (e) {
          if (!silent) setError(e instanceof Error ? e.message : String(e))
          return null
        }
      }

      useEffect(() => {
        let disposed = false
        const tick = async () => {
          try {
            const next = await request(STATE_URL)
            if (disposed) return
            setState(next)
            setError('')
          } catch (e) {
            if (!disposed) setError(e instanceof Error ? e.message : String(e))
          }
        }
        tick()
        const timer = setInterval(tick, open ? 3000 : 12000)
        return () => { disposed = true; clearInterval(timer) }
      }, [open])

      useEffect(() => {
        if (!open) return undefined
        const onPointerDown = event => {
          if (rootRef.current && !rootRef.current.contains(event.target)) setOpen(false)
        }
        const onKeyDown = event => {
          if (event.key === 'Escape') {
            if (settingsOpen) setSettingsOpen(false)
            else setOpen(false)
          }
        }
        document.addEventListener('mousedown', onPointerDown)
        document.addEventListener('keydown', onKeyDown)
        return () => {
          document.removeEventListener('mousedown', onPointerDown)
          document.removeEventListener('keydown', onKeyDown)
        }
      }, [open, settingsOpen])

      useEffect(() => () => {
        if (toastTimer.current) clearTimeout(toastTimer.current)
      }, [])

      const categories = state && Array.isArray(state.categories) ? state.categories : []
      const allFiles = useMemo(() => categories.flatMap(category => category.files || []), [categories])
      const selectedFiles = selected === '__all__'
        ? allFiles
        : (categories.find(category => category.id === selected)?.files || [])
      const normalizedQuery = query.trim().toLowerCase()
      const visibleFiles = normalizedQuery
        ? selectedFiles.filter(file => `${file.title}\n${file.preview}\n${file.content || ''}\n${file.categoryName}\n${file.path}`.toLowerCase().includes(normalizedQuery))
        : selectedFiles

      const copyText = async text => {
        try {
          await navigator.clipboard.writeText(text)
          return true
        } catch {
          return false
        }
      }

      const insertMemory = async file => {
        if (!file.textual || typeof file.content !== 'string') {
          try {
            await postAction('open', { path: file.path })
            showToast(t('binary'))
          } catch {
            showToast(t('openError'))
          }
          return
        }
        const text = file.content
        const inserted = bridge.handler ? bridge.handler(text) : false
        if (inserted) {
          showToast(t('inserted'))
          return
        }
        const copied = await copyText(text)
        showToast(copied ? t('copied') : t('copyFailed'))
      }

      const startDrag = (event, file) => {
        if (!file.textual || typeof file.content !== 'string') {
          event.preventDefault()
          return
        }
        event.dataTransfer.setData('text/plain', file.content)
        event.dataTransfer.setData('text/markdown', file.content)
        event.dataTransfer.effectAllowed = 'copy'
      }

      const chooseFolder = async () => {
        if (busy) return
        setBusy(true)
        try {
          const result = await postAction('chooseFolder')
          if (result && result.state) setState(result.state)
          else await loadState(true)
          if (result && result.cancelled) return
          setSelected('__all__')
          showToast(t('saved'))
        } catch (e) {
          showToast(t('chooseFailed'))
        } finally {
          setBusy(false)
        }
      }

      const openFolder = async () => {
        try {
          await postAction('reveal')
          showToast(t('openFolder'))
        } catch {
          showToast(t('openError'))
        }
      }

      const openFile = async file => {
        try {
          await postAction('open', { path: file.path })
        } catch {
          showToast(t('openError'))
        }
      }

      const revealFile = async file => {
        try {
          await postAction('revealFile', { path: file.path })
        } catch {
          showToast(t('openError'))
        }
      }

      const countText = n => t('items') ? `${n} ${t('items')}` : String(n)

      const ball = h('button', {
        type: 'button',
        className: 'mdz-ball',
        title: t('tooltip'),
        'aria-label': t('tooltip'),
        onClick: () => { setOpen(value => !value); setSettingsOpen(false) },
      },
        h(Icon, { name: 'cards' }),
        state && state.count > 0 ? h('span', { className: 'mdz-badge' }, state.count > 99 ? '99+' : state.count) : null
      )

      const chips = h('div', { className: 'mdz-chips' },
        h('button', {
          type: 'button',
          className: 'mdz-chip' + (selected === '__all__' ? ' is-on' : ''),
          onClick: () => setSelected('__all__'),
        }, t('all'), h('span', { className: 'mdz-chip-count' }, allFiles.length)),
        categories.filter(category => category.files && category.files.length > 0).map(category =>
          h('button', {
            type: 'button',
            key: category.id,
            className: 'mdz-chip' + (selected === category.id ? ' is-on' : ''),
            onClick: () => setSelected(category.id),
            title: category.name,
          }, category.name, h('span', { className: 'mdz-chip-count' }, category.files.length))
        )
      )

      const empty = h('div', { className: 'mdz-empty' },
        h(Icon, { name: 'file' }),
        h('div', { className: 'mdz-empty-title' }, normalizedQuery ? t('noResults') : t('empty')),
        h('div', { className: 'mdz-empty-copy' }, normalizedQuery ? t('noResultsHint') : t('emptyHint'))
      )

      const cards = visibleFiles.map(file => h('div', {
        key: file.path,
        className: 'mdz-card',
        role: 'button',
        tabIndex: 0,
        draggable: file.textual === true,
        title: t('insertHint'),
        onClick: () => insertMemory(file),
        onKeyDown: event => {
          if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault()
            insertMemory(file)
          }
        },
        onDragStart: event => startDrag(event, file),
      },
        h('div', { className: 'mdz-card-icon' }, h(Icon, { name: 'file' })),
        h('div', { className: 'mdz-card-copy' },
          h('div', { className: 'mdz-card-title' }, file.title),
          h('div', { className: 'mdz-card-preview' }, file.preview),
          h('div', { className: 'mdz-card-meta' },
            h('span', null, file.categoryName || t('all')),
            h('span', { className: 'mdz-dot' }),
            h('span', null, `${(file.ext || 'file').toUpperCase()}${file.truncated ? ' · ' + t('truncated') : ''}`)
          )
        ),
        h('div', { className: 'mdz-card-actions' },
          h('button', {
            type: 'button',
            className: 'mdz-mini',
            title: t('openFile'),
            onClick: event => { event.stopPropagation(); openFile(file) },
          }, '↗'),
          h('button', {
            type: 'button',
            className: 'mdz-mini',
            title: t('revealFile'),
            onClick: event => { event.stopPropagation(); revealFile(file) },
          }, '⌕')
        )
      ))

      const settingsPanel = h('div', { className: 'mdz-settings' },
        h('div', { className: 'mdz-settings-title' }, t('workspace')),
        h('div', { className: 'mdz-settings-copy' }, t('folderHint')),
        h('div', { className: 'mdz-path' }, state ? state.workspaceDisplay : '—'),
        h('div', { className: 'mdz-button-row' },
          h('button', { type: 'button', className: 'mdz-action primary', onClick: chooseFolder, disabled: busy }, busy ? t('loading') : t('chooseFolder')),
          h('button', { type: 'button', className: 'mdz-action', onClick: openFolder }, t('openFolder')),
          h('button', { type: 'button', className: 'mdz-action', onClick: () => { setSettingsOpen(false); loadState() } }, t('back'))
        ),
        h('div', { className: 'mdz-note' }, '~/.dsh/memory-dock/settings.json')
      )

      const panel = open ? h('div', { className: 'mdz-panel', onClick: event => event.stopPropagation() },
        h('div', { className: 'mdz-head' },
          h(LogoMark),
          h('div', { className: 'mdz-headcopy' },
            h('div', { className: 'mdz-title' }, t('title')),
            h('div', { className: 'mdz-sub' }, t('subtitle'))
          ),
          h('button', {
            type: 'button',
            className: 'mdz-icon-btn',
            title: t('settings'),
            'aria-label': t('settings'),
            onClick: () => { setSettingsOpen(true); setOpen(true) },
          }, '⚙'),
          h('button', {
            type: 'button',
            className: 'mdz-icon-btn',
            title: t('close'),
            'aria-label': t('close'),
            onClick: () => setOpen(false),
          }, '×')
        ),
        settingsOpen ? settingsPanel : h(React.Fragment, null,
          h('label', { className: 'mdz-search' },
            h(Icon, { name: 'search' }),
            h('input', {
              value: query,
              onChange: event => setQuery(event.target.value),
              placeholder: t('search'),
              autoFocus: true,
              'aria-label': t('search'),
            })
          ),
          chips,
          h('div', { className: 'mdz-body' },
            error ? h('div', { className: 'mdz-empty' },
              h('div', { className: 'mdz-empty-title' }, t('error')),
              h('div', { className: 'mdz-empty-copy' }, error),
              h('div', { style: { marginTop: 10 } },
                h('button', { type: 'button', className: 'mdz-action', onClick: () => loadState() }, t('retry'))
              )
            ) : state === null ? h('div', { className: 'mdz-empty' }, h('div', { className: 'mdz-empty-copy' }, t('loading'))) : (visibleFiles.length ? cards : empty)
          )
        ),
        h('div', { className: 'mdz-foot' },
          h('div', { className: 'mdz-foot-path', title: state ? state.workspacePath : '' }, state ? state.workspaceDisplay : t('loading')),
          h('button', { type: 'button', className: 'mdz-foot-btn', onClick: () => loadState(), title: t('refresh') }, '↻'),
          h('button', { type: 'button', className: 'mdz-foot-btn', onClick: () => setSettingsOpen(value => !value), title: t('settings') }, '⚙')
        ),
        toast ? h('div', { className: 'mdz-toast' }, toast) : null
      ) : null

      return h('div', { className: 'mdz-shell', ref: rootRef },
        h('style', null, CSS),
        panel,
        ball
      )
    }

    return {
      inject: ['slots', 'locale'],
      apply(ctx) {
        ctx.effect(() => ctx.locale.register(NS, DICT), 'memory-dock dictionaries')
        const t = ctx.locale.bind(NS)
        ctx.slots.inject('shell.overlay', () => ctx.slots.register({
          name: 'shell.overlay',
          id: 'memory-dock.ball',
          order: 40,
          label: () => t('title'),
        }, props => h(MemoryDock, Object.assign({}, props, { ctx, t }))))
        ctx.slots.inject('conversation.input.overlay', () => ctx.slots.register({
          name: 'conversation.input.overlay',
          id: 'memory-dock.bridge',
          order: 40,
        }, InputBridge))
      },
    }
  },
})
