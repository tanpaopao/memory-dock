import { promises as fs } from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { spawn } from 'node:child_process'

export const name = 'memory-dock'
export const inject = ['webServer', 'connection', 'tools', 'directoryPickerController']

const DEFAULT_WORKSPACE = path.join(os.homedir(), 'Documents', '记忆坞')
const SETTINGS_DIR = path.join(process.env.DSH_HOME || path.join(os.homedir(), '.dsh'), 'memory-dock')
const SETTINGS_FILE = path.join(SETTINGS_DIR, 'settings.json')
const MAX_TEXT_BYTES = 256 * 1024
const TEXT_EXTENSIONS = new Set(['md', 'markdown', 'mdown', 'txt', 'text', 'json', 'jsonl', 'yaml', 'yml', 'csv', 'xml', 'plist', 'log', 'toml'])

const SEED = [
  ['01_身份', '身份底稿.md', `# 身份底稿

- 称呼：YG
- 常用语言：简体中文
- 时区：Asia/Shanghai
- 回答偏好：直接、具体、先给结论，再给步骤。

> 这是一张示例记忆卡。点击插入输入框，或拖到 AI 对话框作为上下文。
`],
  ['02_偏好', '沟通与输出偏好.md', `# 沟通与输出偏好

- 默认用简体中文回答。
- 少寒暄，先执行，再说明结果。
- 代码、命令、日志保留原文。
- 长任务先列计划，再逐步完成。
`],
  ['03_项目', '项目上下文.md', `# 项目上下文

- 项目名称：［填写项目名］
- 当前目标：［一句话描述］
- 技术栈：［例如 Swift / Python / TypeScript］
- 关键约束：［截止时间、风格、环境限制］
- 相关目录：［本地路径］
`],
  ['04_写作', '写作风格.md', `# 写作风格

- 语气：专业、克制、有判断。
- 段落短，信息密度高。
- 避免套话和空泛总结。
- 重点内容优先用列表或表格呈现。
`],
  ['05_模板', '记忆卡模板.md', `# 记忆卡模板

## 适用场景
［这张记忆卡在什么任务中使用］

## 背景
［必要背景，不写无关信息］

## 规则
1. ［规则一］
2. ［规则二］

## 示例
［输入 → 期望输出］
`],
]

const runtime = {
  workspacePath: '',
}

function expandHome(input) {
  const value = String(input || '').trim()
  if (!value) return ''
  if (value === '~') return os.homedir()
  if (value.startsWith('~/')) return path.join(os.homedir(), value.slice(2))
  return path.resolve(value)
}

function displayHome(input) {
  const home = os.homedir()
  return input === home || input.startsWith(home + path.sep) ? '~' + input.slice(home.length) : input
}

function normalizeExtension(fileName) {
  return path.extname(fileName).slice(1).toLowerCase()
}

function isTextual(fileName) {
  return TEXT_EXTENSIONS.has(normalizeExtension(fileName))
}

async function loadSettings() {
  try {
    const raw = await fs.readFile(SETTINGS_FILE, 'utf8')
    const parsed = JSON.parse(raw)
    if (parsed && typeof parsed.workspacePath === 'string' && parsed.workspacePath.trim()) {
      return parsed
    }
  } catch {
    // Missing settings is the normal first-run state.
  }
  return {}
}

async function saveSettings(next) {
  await fs.mkdir(SETTINGS_DIR, { recursive: true })
  await fs.writeFile(SETTINGS_FILE, JSON.stringify(next, null, 2) + '\n', 'utf8')
}

async function ensureWorkspace(root) {
  await fs.mkdir(root, { recursive: true })
  const entries = (await fs.readdir(root)).filter(name => !name.startsWith('.'))
  if (entries.length > 0) return
  for (const [folder, filename, content] of SEED) {
    const dir = path.join(root, folder)
    await fs.mkdir(dir, { recursive: true })
    await fs.writeFile(path.join(dir, filename), content, 'utf8')
  }
}

async function readPrefix(filePath, maxBytes = MAX_TEXT_BYTES) {
  const info = await fs.stat(filePath)
  const wanted = Math.min(info.size, maxBytes)
  const fh = await fs.open(filePath, 'r')
  try {
    const buffer = Buffer.alloc(wanted)
    const result = await fh.read(buffer, 0, wanted, 0)
    return {
      text: buffer.subarray(0, result.bytesRead).toString('utf8'),
      size: info.size,
      truncated: info.size > result.bytesRead,
    }
  } finally {
    await fh.close()
  }
}

function parseMemory(raw, fallbackTitle) {
  let text = String(raw || '')
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
  const lines = text.split('\n')

  if (lines[0]?.trim() === '---') {
    const end = lines.findIndex((line, index) => index > 0 && line.trim() === '---')
    if (end > 0) text = lines.slice(end + 1).join('\n')
  }

  const contentLines = text.split('\n')
  let title = ''
  let headingIndex = -1
  for (let i = 0; i < Math.min(contentLines.length, 20); i += 1) {
    const line = contentLines[i].trim()
    if (!line) continue
    if (line.startsWith('#')) {
      title = line.replace(/^#+\s*/, '').trim()
      headingIndex = i
      break
    }
  }

  const body = contentLines.slice(headingIndex >= 0 ? headingIndex + 1 : 0).join(' ')
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/[#>*_`[\]()~-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()

  return {
    title: title || fallbackTitle,
    preview: body.slice(0, 220) || '空白记忆卡',
  }
}

async function scanFiles(directory, categoryId, categoryName, root) {
  let entries
  try {
    entries = await fs.readdir(directory, { withFileTypes: true })
  } catch {
    return []
  }

  const files = []
  for (const entry of entries) {
    if (!entry.isFile() || entry.name.startsWith('.') || entry.name === 'Icon\r') continue
    const filePath = path.join(directory, entry.name)
    let info
    try {
      info = await fs.stat(filePath)
    } catch {
      continue
    }
    const ext = normalizeExtension(entry.name)
    const textual = isTextual(entry.name)
    let content = null
    let truncated = false
    let parsed = { title: path.basename(entry.name, path.extname(entry.name)), preview: `${ext ? ext.toUpperCase() : '文件'} 文件` }
    if (textual) {
      try {
        const read = await readPrefix(filePath)
        content = read.text
        truncated = read.truncated
        parsed = parseMemory(read.text, parsed.title)
      } catch {
        parsed.preview = '无法读取内容'
      }
    } else {
      parsed.preview = `${ext ? ext.toUpperCase() : '二进'} 文件 · 点击打开`
    }

    files.push({
      path: path.relative(root, filePath).split(path.sep).join('/'),
      categoryId,
      categoryName,
      title: parsed.title,
      preview: parsed.preview,
      ext,
      size: info.size,
      modifiedAt: info.mtime.toISOString(),
      textual,
      truncated,
      content,
    })
  }

  files.sort((a, b) => new Date(b.modifiedAt).getTime() - new Date(a.modifiedAt).getTime())
  return files
}

async function buildState({ includeContent = true } = {}) {
  const root = runtime.workspacePath
  const base = {
    workspacePath: root,
    workspaceDisplay: displayHome(root),
    categories: [],
    count: 0,
    generatedAt: new Date().toISOString(),
  }
  try {
    const dirs = (await fs.readdir(root, { withFileTypes: true }))
      .filter(entry => entry.isDirectory() && !entry.name.startsWith('.'))
      .map(entry => entry.name)
      .sort((a, b) => a.localeCompare(b, 'zh-CN', { numeric: true }))

    const categories = []
    let count = 0
    for (const name of dirs) {
      const files = await scanFiles(path.join(root, name), name, name, root)
      count += files.length
      categories.push({ id: name, name, files })
    }
    const rootFiles = await scanFiles(root, '__root__', '未分类', root)
    if (rootFiles.length > 0) categories.push({ id: '__root__', name: '未分类', files: rootFiles })
    count += rootFiles.length

    base.categories = includeContent ? categories : categories.map(category => ({
      ...category,
      files: category.files.map(({ content, ...rest }) => rest),
    }))
    base.count = count
    return base
  } catch (error) {
    base.error = error instanceof Error ? error.message : String(error)
    return base
  }
}

function resolveMemoryPath(relativePath) {
  const root = runtime.workspacePath
  const target = path.resolve(root, String(relativePath || ''))
  if (target !== root && !target.startsWith(root + path.sep)) {
    throw new Error('记忆路径不在工作区内')
  }
  return target
}

function launchPath(target, reveal = false) {
  const platform = process.platform
  let command
  let args
  if (platform === 'darwin') {
    command = '/usr/bin/open'
    args = reveal ? ['-R', target] : [target]
  } else if (platform === 'win32') {
    command = 'explorer.exe'
    args = reveal ? ['/select,', target] : [target]
  } else {
    command = 'xdg-open'
    args = [reveal ? path.dirname(target) : target]
  }
  const child = spawn(command, args, { detached: true, stdio: 'ignore' })
  child.unref()
}

async function setWorkspace(nextPath) {
  const resolved = expandHome(nextPath)
  if (!resolved) throw new Error('工作区路径为空')
  const info = await fs.stat(resolved).catch(() => null)
  if (!info || !info.isDirectory()) throw new Error('选择的路径不是文件夹')
  await ensureWorkspace(resolved)
  runtime.workspacePath = resolved
  await saveSettings({ workspacePath: resolved })
  return buildState()
}

function formatState(state) {
  if (state.error) return `记忆坞读取失败：${state.error}\n工作区：${state.workspaceDisplay}`
  const lines = [`记忆坞：${state.workspaceDisplay}（${state.count} 张记忆卡）`]
  for (const category of state.categories) {
    lines.push(`\n${category.name}（${category.files.length}）`)
    for (const file of category.files) {
      lines.push(`- ${file.title}  [${file.path}]${file.truncated ? '（已截断）' : ''}`)
    }
  }
  return lines.join('\n')
}

async function searchMemories(query) {
  const needle = String(query || '').trim().toLowerCase()
  if (!needle) throw new Error('搜索关键词为空')
  const state = await buildState()
  const hits = []
  for (const category of state.categories) {
    for (const file of category.files) {
      const haystack = `${file.title}\n${file.preview}\n${file.content || ''}`.toLowerCase()
      const index = haystack.indexOf(needle)
      if (index < 0) continue
      const source = `${file.title}\n${file.content || file.preview}`
      const sourceIndex = source.toLowerCase().indexOf(needle)
      const start = Math.max(0, sourceIndex - 70)
      const excerpt = source.slice(start, start + 210).replace(/\s+/g, ' ').trim()
      hits.push(`- ${file.title}  [${file.path}]\n  ${excerpt}`)
    }
  }
  return hits.length ? `搜索 “${query}” 命中 ${hits.length} 张：\n\n${hits.join('\n\n')}` : `搜索 “${query}” 没有命中。`
}

async function readMemory(relativePath) {
  const target = resolveMemoryPath(relativePath)
  const info = await fs.stat(target).catch(() => null)
  if (!info || !info.isFile()) throw new Error('记忆文件不存在')
  if (!isTextual(target)) return `二进制文件：${relativePath}\n大小：${info.size} bytes\n可点击“打开”用默认应用查看。`
  const read = await readPrefix(target, 1024 * 1024)
  return `${read.text}${read.truncated ? '\n\n[内容已截断]' : ''}`
}

function registerTool(ctx) {
  const tool = {
    name: 'memory_dock',
    description: 'Use the user’s local Memory Dock workspace. List memory cards, search them, or read one before answering tasks that depend on personal preferences, project context, or writing style.',
    parameters: {
      action: {
        type: 'string',
        required: true,
        enum: ['list', 'search', 'read'],
        description: 'list = show all cards; search = find by text; read = read one card by its relative path.',
      },
      query: {
        type: 'string',
        description: 'Search query. Required when action is search.',
      },
      path: {
        type: 'string',
        description: 'Relative memory path from list/search output. Required when action is read.',
      },
    },
    output: {
      schema: { type: 'string' },
      render: (_args, value) => [{ type: 'text', text: value }],
    },
    async execute(args) {
      if (args.action === 'list') return formatState(await buildState())
      if (args.action === 'search') return searchMemories(args.query)
      if (args.action === 'read') return readMemory(args.path)
      throw new Error(`Unknown memory_dock action: ${args.action}`)
    },
  }
  ctx.effect(() => ctx.tools.register(tool), 'memory-dock tool')
}

function rejectRequest(ctx, req, res) {
  const connection = ctx.get('connection')
  if (!connection) return false
  let rejection
  try {
    rejection = connection.requestRejection({ headers: req.headers })
  } catch {
    rejection = 403
  }
  if (rejection) {
    res.statusCode = rejection
    res.end()
    return true
  }
  return false
}

function sendJson(res, status, payload) {
  res.statusCode = status
  res.setHeader('content-type', 'application/json; charset=utf-8')
  res.setHeader('cache-control', 'no-store')
  res.end(JSON.stringify(payload))
}

async function readJsonBody(req, limit = 64 * 1024) {
  const chunks = []
  let size = 0
  for await (const chunk of req) {
    size += chunk.byteLength
    if (size > limit) {
      req.resume()
      throw new Error('请求体过大')
    }
    chunks.push(chunk)
  }
  if (chunks.length === 0) return {}
  return JSON.parse(Buffer.concat(chunks, size).toString('utf8'))
}

async function handleAction(ctx, body) {
  const action = body && body.action
  if (action === 'setWorkspace') {
    const next = await setWorkspace(body.path)
    return { ok: true, state: next }
  }
  if (action === 'chooseFolder') {
    const controller = new AbortController()
    const selected = await ctx.directoryPickerController.pick(controller.signal)
    if (!selected) return { ok: true, cancelled: true, state: await buildState() }
    const next = await setWorkspace(selected)
    return { ok: true, state: next }
  }
  if (action === 'reveal') {
    launchPath(runtime.workspacePath)
    return { ok: true }
  }
  if (action === 'open') {
    const target = resolveMemoryPath(body.path)
    launchPath(target)
    return { ok: true }
  }
  if (action === 'revealFile') {
    const target = resolveMemoryPath(body.path)
    launchPath(target, true)
    return { ok: true }
  }
  if (action === 'refresh') {
    return { ok: true, state: await buildState() }
  }
  throw new Error(`Unknown memory-dock action: ${action}`)
}

export async function apply(ctx, config) {
  const settings = await loadSettings()
  const preferred = expandHome(config?.workspacePath || settings.workspacePath || DEFAULT_WORKSPACE)
  runtime.workspacePath = preferred
  await ensureWorkspace(preferred)
  try {
    await saveSettings({ workspacePath: preferred })
  } catch (error) {
    console.warn('[memory-dock] Cannot persist settings:', error)
  }

  ctx.effect(() => ctx.webServer.register({
    kind: 'exact',
    path: '/memory-dock/api/state',
    handler: async (req, res) => {
      if (rejectRequest(ctx, req, res)) return
      if (req.method !== 'GET') {
        res.statusCode = 405
        res.setHeader('allow', 'GET')
        res.end()
        return
      }
      sendJson(res, 200, await buildState())
    },
  }), 'memory-dock state route')

  ctx.effect(() => ctx.webServer.register({
    kind: 'exact',
    path: '/memory-dock/api/action',
    handler: async (req, res) => {
      if (rejectRequest(ctx, req, res)) return
      if (req.method !== 'POST') {
        res.statusCode = 405
        res.setHeader('allow', 'POST')
        res.end()
        return
      }
      try {
        const body = await readJsonBody(req)
        sendJson(res, 200, await handleAction(ctx, body))
      } catch (error) {
        sendJson(res, 400, { ok: false, error: error instanceof Error ? error.message : String(error) })
      }
    },
  }), 'memory-dock action route')

  registerTool(ctx)
}
