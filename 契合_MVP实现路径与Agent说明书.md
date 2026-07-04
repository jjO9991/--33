# 契合 MVP 实现路径与 Agent 工作说明书

生成日期：2026-07-04  
输入材料：`契合_PRD_v1.2_MVP 副本.docx`  
目标：基于 PRD 拆出可由多个 coding agent 执行的 MVP 实现路径，优先支持 iOS App Store 上线。

> 本说明书是产品与工程执行文档，不构成法律意见。涉及中国生成式 AI 备案、个人信息保护、电子签名、法律服务边界、免责条款等事项，必须由执业律师与合规负责人复核。

## 1. 核心判断

契合的 MVP 不应该做成“万能合同 AI”，而应该做成一个非常窄但可信的签字前工具：

**一句话 MVP：让普通租客 / 房东在手机上快速生成或审查房屋租赁合同，看到结论、风险、修改建议，并导出可交付文件。**

首版建议采用 **iOS-first + 服务端 AI/RAG**。原因：

- 用户场景是移动现场：拍照、文件导入、几分钟内判断。
- App Store 上线要求所有功能完整可用，首版不宜同时背上 Android / 小程序 / Web 的适配成本。
- 合同正文、身份证号、住址、电话、财产信息高度敏感，安全、隐私、合规、准确性不能砍。
- PRD 的“桌面双栏”原型在 iPhone 上要改成“文档预览 + 可收起底部面板 / 分段视图”，否则会拥挤。

## 2. MVP 范围切线

### P0 必做

1. 首页统一入口
   - 文本输入。
   - 上传 / 拍照入口。
   - 两个明确主按钮：`拟定合同`、`审核合同`。
   - 明示定位：合同辅助工具，不是律师服务。

2. 租赁合同拟定
   - 多轮对话收集字段。
   - 字段面板：出租方、承租方、地址、租期、租金、押金、付款周期、维修责任、提前解约、违约责任、其他约定。
   - 完整度进度。
   - 合同预览。
   - 缺失字段高亮。
   - 生成完整合同。
   - 导出 PDF / DOCX。

3. 租赁合同审查
   - 支持粘贴文本、拍照 / 相册图片、PDF、Word。
   - OCR / 文本抽取。
   - 选择用户立场：承租方、出租方、中立。
   - 风险识别：红 / 黄 / 绿，至少覆盖押金、租金调价、租期续租、维修责任、转租、提前退租、违约金、费用承担、争议管辖、霸王条款。
   - 风险卡片：风险标题、原文引用、白话解释、建议改法、依据来源。
   - 文档预览中的风险高亮。
   - 导出审查报告 PDF。

4. 合规与信任底座
   - 隐私政策 URL、用户协议 URL、支持 URL。
   - App 内可访问隐私政策。
   - 如果支持注册登录，必须支持 App 内注销 / 删除账号。
   - 合同正文默认不用于模型训练，不进入明文埋点。
   - 导出文件包含 AI 生成 / 辅助标识。
   - 第三方 SDK 清单、隐私清单、Privacy Manifest。
   - App Review demo mode 或 demo account。

5. 质量与观测
   - 生成首字返回 P90 <= 5s。
   - 生成完整合同 P90 <= 20s。
   - 审查报告 P90 <= 30s。
   - OCR P90 <= 8s / 页。
   - LLM 失败不得返回残缺法律结论。

### P1 延后

- 完整历史记录云同步。
- 版本比对。
- 到期 / 付款提醒。
- 订阅体系的复杂权益。
- 真人律师转介。
- 电子签 / 存证闭环。
- 商铺、数码租赁、以租代购、二手买卖、采购、服务合同。
- Android、小程序、Web。

### 明确不要做

- 不自称 `AI 律师`。
- 不承诺 `100% 准确`、`零风险`、`包赢`。
- 不把电子签名自建成闭环；后续只能接持牌第三方。
- 不上传明文合同到分析埋点。
- 不要求用户必须开启相机、相册、推送才能使用核心功能。

## 3. 推荐技术路径

### 3.1 客户端

建议：**SwiftUI 原生 iOS**。

理由：

- App Store 审核与系统权限文案更自然。
- 相机、文件、PDF 预览、分享、StoreKit 2、Sign in with Apple、App 内删除账号等能力更稳。
- 合同类产品需要可信、安静、原生的体验，少一点跨端 UI 的“壳感”。

客户端模块：

- `AppShell`：导航、主题、错误提示、网络状态。
- `Home`：统一输入、两个任务入口、最近任务轻量入口。
- `DraftContract`：对话收集、字段状态、合同预览、导出。
- `ReviewContract`：导入、OCR 进度、立场选择、风险报告。
- `DocumentPreview`：PDF/文本预览、风险 range 高亮、跳转定位。
- `AccountPrivacy`：登录、注销、隐私政策、数据删除。
- `Paywall`：如果首版收费，使用 StoreKit 2。
- `Telemetry`：只上报结构化行为，不上报合同正文。

### 3.2 服务端

建议：**FastAPI + PostgreSQL + Redis Queue + Object Storage + LLM Provider Adapter**。

原因：

- Python 适合 OCR、文档解析、RAG、PDF/DOCX 生成、评测流水线。
- FastAPI 对 coding agent 友好，接口契约清晰。
- 后续可拆服务，但 MVP 不要过早微服务化。

核心服务：

- `auth-service`：匿名设备、手机号 / Apple 登录、token、账号删除。
- `file-service`：上传、病毒扫描、文件类型识别、对象存储、短期 URL。
- `doc-extract-service`：PDF/DOCX/TXT/image 转 normalized text。
- `ocr-service`：图片 OCR；优先客户端 Vision 做预处理，服务端兜底。
- `draft-service`：字段抽取、模板填充、合同生成、完整性校验。
- `review-service`：条款切分、风险识别、RAG、引用校验、风险卡片。
- `export-service`：PDF/DOCX 生成、AI 标识、文件元数据。
- `billing-service`：额度、订阅、按次购买。
- `telemetry-service`：脱敏事件。

### 3.3 AI 架构

不要让一个大 prompt 从头做到尾。拆成可测试流水线：

1. 意图识别：`draft_contract` / `review_contract` / `other`.
2. 字段抽取：从用户自然语言中抽取租赁字段。
3. 缺失字段判断：返回 `missing_fields`。
4. 合同生成：基于模板和字段生成。
5. 合同完整性校验：必备条款检查。
6. 文档文本抽取 / OCR。
7. 条款切分。
8. 租赁风险规则召回。
9. RAG 检索法律依据。
10. 风险卡片生成。
11. 引用校验：没有依据的法律结论降级为“建议核实”，不能伪造法条。
12. 报告导出。

## 4. 数据模型草案

### 核心表

```text
users
- id
- apple_user_id
- phone_hash
- created_at
- deleted_at
- privacy_consent_version

devices
- id
- user_id nullable
- anonymous_device_id_hash
- platform
- created_at

sessions
- id
- user_id nullable
- device_id
- type: draft | review
- status: created | processing | completed | failed
- created_at
- updated_at

files
- id
- user_id nullable
- session_id
- type: image | pdf | docx | txt | export_pdf | export_docx
- storage_key
- sha256
- size_bytes
- retention_until
- created_at

lease_drafts
- id
- session_id
- fields_json
- missing_fields_json
- completeness_score
- contract_text
- version
- created_at
- updated_at

lease_reviews
- id
- session_id
- user_role: tenant | landlord | neutral
- extracted_text_ref
- ocr_confidence
- summary_json
- risk_items_json
- citation_check_status
- created_at

usage_events
- id
- user_id nullable
- device_id
- event_name
- properties_json_without_contract_text
- created_at

subscriptions
- id
- user_id
- apple_original_transaction_id
- status
- product_id
- expires_at
```

### 风险卡片 JSON

```json
{
  "risk_id": "risk_001",
  "level": "red",
  "type": "deposit_refund",
  "title": "押金退还条件不清",
  "quote": "合同原文中的风险句子",
  "plain_explanation": "这句话对你不利，因为房东可以用模糊理由拖延退押金。",
  "suggested_revision": "租赁期满且房屋及附属设施无异常损坏时，出租方应在3个工作日内无息退还押金。",
  "citations": [
    {
      "source_type": "law",
      "title": "民法典 合同编 租赁合同相关条款",
      "url_or_ref": "internal_knowledge_base_ref",
      "verified": true
    }
  ],
  "highlight_range": {
    "start": 120,
    "end": 168
  },
  "needs_lawyer": false
}
```

## 5. 前端设计建议

### 5.1 设计原则

- 产品不是营销页，第一屏就是工具。
- 视觉语言要“可信、冷静、可读”，不要做成花哨 AI 聊天 App。
- 每个 AI 结论都要有三个层次：结论、白话解释、依据 / 边界。
- 租赁合同现场决策很急，主流程必须少分叉。
- 不要把“免责”藏在小字里，应变成可信任的 UI：例如“这是合同辅助审查，不替代律师；高风险事项建议咨询专业人士”。

### 5.2 首页

建议布局：

- 顶部：`契合` + 小字 `签字前，先看一遍`。
- 中部：一个大输入框，placeholder：`描述你的合同需求，或上传需要审核的合同`。
- 输入框左侧：`+`，打开菜单：拍照、相册、文件、粘贴文本。
- 输入框右侧：发送按钮。语音输入可以后置，未完成前不要出现。
- 下方两个主操作：
  - `拟定租赁合同`
  - `审核租赁合同`
- 底部信任条：
  - `合同内容默认不用于训练`
  - `支持删除数据`
  - `非律师服务`

### 5.3 拟定合同页

iPhone 不建议照搬双栏。建议：

- 顶部：步骤条 `信息收集 -> 预览 -> 导出`。
- 主区：聊天式字段收集。
- 下方固定输入框。
- 右上角或底部浮层：`字段完整度 8/12`。
- 点击完整度进入字段表单。
- 合同预览用 `草稿 / 字段` 分段控件切换。
- 未填字段用柔和黄色标记；已确认字段用绿色点，不要大面积绿色背景。
- 生成按钮只有字段最低完整度达标后激活。

关键文案：

- `还差 4 项就能生成可用草稿`
- `押金退还、维修责任、提前退租会影响真实风险，建议补齐`
- `生成的是辅助合同文本，请在签署前自行确认或咨询专业人士`

### 5.4 审核合同页

建议流程：

1. 选择输入方式：拍照、上传文件、粘贴文本。
2. 选择立场：我是承租方 / 出租方 / 中立看看。
3. 上传后展示处理进度：`识别文字 -> 切分条款 -> 检查风险 -> 生成报告`。
4. 结果页默认展示“能不能签”的摘要，而不是先展示长文。

结果页结构：

- 顶部结论：
  - `建议先谈 3 处再签`
  - `发现 2 个高风险、4 个需确认`
- 中部：文档预览，风险处有红 / 橙标记。
- 底部 sheet：风险卡片列表。
- 卡片详情：
  - 原文
  - 为什么有风险
  - 建议怎么改
  - 依据
  - `复制修改建议`
  - `标记有用 / 无用`

### 5.5 视觉规范

- 字体：iOS 使用系统字体，正文 15-17pt，合同正文可 14-15pt，但要支持动态字体。
- 圆角：工具界面控制在 8-12，不要所有东西都大圆角。
- 主色：深青 / 墨绿适合“可信合同助手”；风险色只用于风险，不做品牌主色。
- 风险色：
  - 红：高风险 / 不建议直接签。
  - 橙：需谈判 / 需确认。
  - 绿：未发现明显问题。
- 避免大面积紫蓝渐变、AI 感光效、装饰球。
- 图标用 SF Symbols，例如 `doc.text`, `camera`, `square.and.arrow.up`, `exclamationmark.triangle`, `checkmark.shield`。

### 5.6 必备状态

- 空状态：没有上传合同、没有草稿、没有风险。
- 处理中：长任务进度，超过 10s 给文案解释。
- 失败：OCR 失败、文件过大、模型超时、引用校验失败。
- 部分失败：可以展示文本抽取成功但风险分析失败；不能展示残缺法律结论。
- 弱网：上传重试、后台任务恢复。
- 权限拒绝：提供文件上传 / 粘贴文本替代路径。

## 6. Agent 分工

### Agent A：产品范围与验收负责人

目标：维护 MVP 切线，防止范围膨胀。

交付：

- `docs/mvp_scope.md`
- `docs/acceptance_criteria.md`
- `docs/copywriting.md`

验收：

- 每个 P0 功能有明确用户价值、输入、输出、失败状态。
- P1 / 非 MVP 明确列入 backlog。
- 所有“律师 / 法律意见 / 准确率”相关文案经过合规降风险。

### Agent B：iOS 客户端负责人

目标：实现 App Store 可提交的 iOS MVP。

交付：

- SwiftUI App shell。
- 首页。
- 拟定合同流程。
- 审核合同流程。
- 文件 / 拍照 / 粘贴输入。
- PDF 预览、风险高亮、导出分享。
- 隐私、账号删除、支持页面入口。

验收：

- 真机跑通。
- 不依赖 mock 才能完成核心流程。
- 所有系统权限 purpose string 明确说明用途。
- 相机 / 相册权限拒绝后仍可上传文件或粘贴文本。

### Agent C：后端 API 负责人

目标：提供稳定、可观测、可替换模型的服务端。

交付：

- FastAPI 项目。
- OpenAPI 文档。
- 文件上传与对象存储。
- 会话、草稿、审查结果、导出文件。
- 幂等、限流、错误码。
- 日志脱敏。

验收：

- 客户端不直接调用 LLM。
- API 错误可被前端转成用户可理解状态。
- 合同正文不出现在普通日志和埋点中。

### Agent D：AI / RAG / 法规知识负责人

目标：让合同生成与审查可解释、可评测、可迭代。

交付：

- 租赁字段 schema。
- 租赁合同模板。
- 必检风险清单。
- 风险规则库。
- RAG 检索接口。
- 引用校验。
- AI eval 样本集。

验收：

- 高风险项没有依据时不得输出确定性法律结论。
- 风险卡片必须包含原文、白话解释、建议改法、依据状态。
- 至少 50 份样本合同完成离线评测；上线前建议扩到 200 份并由律师抽检。

### Agent E：合规 / App Store 上架负责人

目标：确保 App Store 审核材料和隐私合规闭环。

交付：

- 隐私政策。
- 用户协议。
- App Store Review Notes。
- App Privacy Nutrition Label 填报清单。
- Privacy Manifest / required reason API 检查。
- 第三方 SDK 清单。
- Demo account / demo mode。
- 账号删除流程。

验收：

- App 内可访问隐私政策。
- App Store Connect 元数据完整。
- 如果使用订阅或按次付费，必须走 StoreKit / IAP。
- 提供审核账号或完整 demo mode。

### Agent F：QA / 发布负责人

目标：让首版不会因为崩溃、残缺、隐私、支付、权限被拒。

交付：

- 测试计划。
- 真机测试矩阵。
- TestFlight 检查清单。
- AI 质量回归报告。
- App Store 提审清单。

验收：

- P0 全流程真机录像。
- 弱网、权限拒绝、文件异常、LLM 超时、IAP 恢复购买均测试。
- Crash-free 达到内部标准后再提审。

## 7. 原子化任务路径

### Phase 0：决策与仓库基线

| ID | 任务 | 交付物 | 依赖 | 验收 |
| --- | --- | --- | --- | --- |
| 0.1 | 冻结 MVP 范围 | `docs/mvp_scope.md` | PRD | P0/P1/不做边界明确 |
| 0.2 | 建 monorepo | `ios/`, `api/`, `docs/` | 0.1 | 本地能启动 iOS 与 API |
| 0.3 | 定义 API contract | `docs/api_contract.md`, OpenAPI 初版 | 0.1 | 前后端可并行 |
| 0.4 | 定义风险与字段 schema | `docs/schemas/*.json` | 0.1 | 字段、风险卡片、报告结构固定 |
| 0.5 | 合规文案底稿 | `docs/legal_copy.md` | 0.1 | 不出现 AI 律师、100% 准确等高风险表述 |

### Phase 1：iOS 可点击骨架

| ID | 任务 | 交付物 | 依赖 | 验收 |
| --- | --- | --- | --- | --- |
| 1.1 | SwiftUI App shell | 首页、导航、主题 | 0.2 | 真机可启动 |
| 1.2 | 设计 token | Color, Typography, Spacing | 1.1 | 三个核心页一致 |
| 1.3 | 首页输入与入口 | Home view | 1.1 | 可进入拟定 / 审核 |
| 1.4 | 权限与文件导入壳 | camera/photo/files/text | 1.1 | 权限拒绝有替代路径 |
| 1.5 | 错误 / loading 组件 | shared components | 1.1 | 所有异步页可复用 |

### Phase 2：后端基础

| ID | 任务 | 交付物 | 依赖 | 验收 |
| --- | --- | --- | --- | --- |
| 2.1 | FastAPI skeleton | `/health`, OpenAPI | 0.2 | 部署环境可健康检查 |
| 2.2 | DB migration | users/sessions/files/reviews/drafts | 0.4 | migration 可重复执行 |
| 2.3 | 文件上传 | `/files/upload` | 2.1 | 支持图片/PDF/DOCX，限制大小 |
| 2.4 | 会话 API | `/sessions` | 2.2 | 创建、查询、失败状态 |
| 2.5 | 脱敏日志 | middleware | 2.1 | 合同正文不进日志 |

### Phase 3：拟定合同闭环

| ID | 任务 | 交付物 | 依赖 | 验收 |
| --- | --- | --- | --- | --- |
| 3.1 | 租赁字段 schema | JSON schema | 0.4 | 覆盖 PRD P0 字段 |
| 3.2 | 字段抽取 API | `/draft/extract-fields` | 3.1 | 自然语言能抽取租金、押金、租期 |
| 3.3 | 缺失字段 API | `/draft/missing-fields` | 3.1 | 返回缺失字段和追问文案 |
| 3.4 | 合同模板 | 模板 + 变量 | 3.1 | 生成文本结构完整 |
| 3.5 | 生成 API | `/draft/generate` | 3.2-3.4 | 流式首字 <= 5s |
| 3.6 | iOS 字段面板 | 完整度、编辑、确认 | 1.3, 3.2 | 字段变更同步预览 |
| 3.7 | iOS 合同预览 | 草稿视图 | 3.5 | 未填字段可见 |
| 3.8 | 导出 DOCX/PDF | `/exports/draft` | 3.5 | 文件含 AI 标识 |

### Phase 4：审核合同闭环

| ID | 任务 | 交付物 | 依赖 | 验收 |
| --- | --- | --- | --- | --- |
| 4.1 | 文本抽取 | PDF/DOCX/TXT/image normalize | 2.3 | 返回 normalized text |
| 4.2 | OCR 兜底 | image OCR | 4.1 | 单页 P90 <= 8s |
| 4.3 | 条款切分 | clause parser | 4.1 | 每段有 index/range |
| 4.4 | 租赁风险规则库 | rules yaml/json | 0.4 | 覆盖必检风险点 |
| 4.5 | RAG 检索 | legal retrieval | 4.4 | 返回来源和版本 |
| 4.6 | 风险识别 API | `/review/analyze` | 4.3-4.5 | 输出风险卡片 JSON |
| 4.7 | 引用校验 | citation verifier | 4.6 | 杜撰法条被拦截 |
| 4.8 | iOS 上传/立场页 | upload + role | 1.4 | 三种立场可传入 API |
| 4.9 | iOS 风险结果页 | preview + bottom sheet | 4.6 | 点击风险跳转原文 |
| 4.10 | 审查报告导出 | `/exports/review` | 4.6 | PDF 含摘要、风险、标识 |

### Phase 5：账号、隐私、商业化

| ID | 任务 | 交付物 | 依赖 | 验收 |
| --- | --- | --- | --- | --- |
| 5.1 | 游客模式 | anonymous device session | 2.4 | 不登录可试用核心流程 |
| 5.2 | Sign in with Apple | auth | 5.1 | 登录后绑定历史 |
| 5.3 | 账号删除 | App 内删除入口 + API | 5.2 | 删除后数据按政策清理 |
| 5.4 | 隐私中心 | UI + URLs | 5.1 | 隐私政策、协议、数据删除可访问 |
| 5.5 | 额度系统 | free quota | 2.4 | 超额触发 paywall |
| 5.6 | StoreKit 2 | subscription/pay-per-use | 5.5 | 恢复购买可用 |

### Phase 6：埋点与质量评测

| ID | 任务 | 交付物 | 依赖 | 验收 |
| --- | --- | --- | --- | --- |
| 6.1 | 事件 schema | telemetry spec | 0.4 | 不含合同正文 |
| 6.2 | 客户端埋点 | app_launch, funnel events | 6.1 | 可在后台看漏斗 |
| 6.3 | 后端性能指标 | latency/error/llm/ocr | 2.5 | 有告警阈值 |
| 6.4 | AI eval 样本 | 50+ 租赁合同样本 | 4.4 | 记录漏检和误报 |
| 6.5 | 用户反馈闭环 | 有用/无用/纠错 | 4.9 | 风险卡片可反馈 |

### Phase 7：App Store 提审

| ID | 任务 | 交付物 | 依赖 | 验收 |
| --- | --- | --- | --- | --- |
| 7.1 | App metadata | 名称、副标题、描述、关键词 | P0 完成 | 无绝对化法律承诺 |
| 7.2 | 截图与预览 | 6.7/6.9 英寸截图 | UI 完成 | 展示真实核心流程 |
| 7.3 | Privacy Nutrition Label | 数据类型清单 | 5.x, 6.x | 与实际 SDK/API 一致 |
| 7.4 | Privacy Manifest 检查 | manifest + SDK signatures | 5.x | required reason API 合法 |
| 7.5 | Review Notes | 审核说明、demo account | 全功能 | 后端可用，账号可登录 |
| 7.6 | TestFlight 回归 | 测试报告 | 全功能 | 崩溃、权限、IAP、删除账号通过 |
| 7.7 | 提审 | App Store Connect | 7.1-7.6 | 无占位功能，无 mock 数据伪装 |

## 8. 给 Agent 的通用工作规则

每个 agent 开工前必须读取：

1. `docs/mvp_scope.md`
2. `docs/api_contract.md`
3. `docs/schemas/`
4. `docs/legal_copy.md`
5. 本说明书

通用规则：

- 只做分配给自己的 ID，不顺手扩范围。
- 所有新接口必须写 OpenAPI。
- 所有 AI 输出必须有结构化 JSON schema。
- 所有错误都要有用户可理解文案。
- 不得在日志、埋点、崩溃上报里记录合同全文、身份证、住址、电话。
- 涉及导出文件，必须包含 AI 辅助 / 生成标识。
- 涉及付费，必须走 IAP / StoreKit；不得在 App 内引导绕开 App Store 购买，除非按具体地区规则和 entitlement 单独设计。
- 涉及登录，必须提供 App 内删除账号。

## 9. 可直接派发的 Agent Prompt

### iOS Agent Prompt

```text
你负责实现契合 iOS MVP。请先读取 docs/mvp_scope.md、docs/api_contract.md、docs/schemas、docs/legal_copy.md。只实现 P0。

目标：SwiftUI 原生 iOS，完成首页、拟定租赁合同、审核租赁合同、文件/拍照/粘贴输入、结果预览、风险卡片、导出分享、隐私中心、账号删除入口。

硬性要求：
- 不出现未实现按钮。
- 相机/相册权限拒绝后仍可用文件或粘贴文本。
- 合同正文和风险卡片必须支持动态字体，不得在小屏重叠。
- 审查结果默认先展示结论摘要，再展示风险列表。
- 所有法律/AI 文案使用 docs/legal_copy.md，不得自创“AI 律师”“100%准确”等表达。
- 提供真机测试说明和截图。
```

### Backend Agent Prompt

```text
你负责契合 MVP 后端。请先读取 docs/api_contract.md、docs/schemas、docs/mvp_scope.md。使用 FastAPI + PostgreSQL，保持单体服务但模块化。

目标：实现会话、文件上传、文本抽取、拟定合同、审核合同、导出、匿名设备、登录绑定、账号删除、额度、脱敏日志。

硬性要求：
- 客户端不得直连 LLM。
- 所有接口有 OpenAPI schema。
- 合同正文不得进入普通日志、埋点、错误上报。
- LLM/OCR 超时必须返回明确失败，不得生成残缺法律结论。
- 所有导出文件写入 AI 辅助/生成标识。
```

### AI/RAG Agent Prompt

```text
你负责契合 MVP 的 AI 与知识库。请先读取 docs/schemas、docs/mvp_scope.md、PRD 中租赁必检风险点。

目标：实现租赁合同字段抽取、缺失字段追问、合同生成模板、合同条款切分、风险识别、RAG 检索、引用校验、风险卡片 JSON。

硬性要求：
- 输出必须符合 JSON schema。
- 不得伪造法条、判例、法规来源。
- 没有依据的结论必须降级为“建议核实/建议咨询专业人士”。
- 风险卡片必须包括：原文、白话解释、建议改法、依据、是否建议律师介入。
- 建立至少 50 份样本的离线评测集。
```

### App Store / Compliance Agent Prompt

```text
你负责契合 iOS MVP 的 App Store 与合规提审材料。请读取 docs/legal_copy.md、docs/mvp_scope.md，并核对 Apple 官方最新要求。

目标：产出隐私政策、用户协议、App Review Notes、Privacy Nutrition Label 填报清单、Privacy Manifest 检查、第三方 SDK 清单、demo account/demo mode、账号删除验收说明。

硬性要求：
- App 内和 App Store metadata 都要有隐私政策链接。
- 如果支持账号创建，必须支持 App 内删除账号。
- 如果有订阅/按次购买，必须使用 StoreKit/IAP。
- 所有营销文案不得承诺替代律师、100%准确、零风险。
- 提交前确认后端服务可供 Apple 审核访问。
```

## 10. QA 清单

### 功能测试

- 首页输入“帮我拟一份北京租房合同，月租 5000，押一付三”。
- 系统追问缺失字段。
- 手动补齐字段。
- 生成合同。
- 修改押金 / 违约金。
- 导出 PDF / DOCX。
- 上传一份 PDF 租赁合同。
- 上传一张拍照合同。
- 粘贴一段合同文本。
- 选择承租方立场。
- 查看风险摘要。
- 展开风险卡片。
- 点击风险卡片跳转原文。
- 导出审查报告。

### 异常测试

- 相机权限拒绝。
- 相册权限拒绝。
- 文件过大。
- 空白图片。
- OCR 置信度低。
- LLM 超时。
- 网络中断。
- 重复点击生成 / 审查。
- 退出 App 后恢复任务。
- 删除账号。
- 恢复购买。

### 合规测试

- 隐私政策入口可访问。
- 支持 URL 可访问。
- 删除账号入口可访问。
- App Privacy Label 与实际采集一致。
- SDK 清单与 Privacy Manifest 一致。
- 导出文件含 AI 标识。
- 审查结果含“仅供参考，不替代律师”。
- App Review demo account 可完整跑通。

### AI 质量测试

上线前最低要求：

- 50 份租赁样本离线测试。
- 每份包含人工标注的必检风险点。
- 核心必检项漏检率目标 < 5%，上线前由律师抽检确认。
- 法条引用准确率目标 >= 95%。
- 杜撰引用为 0 容忍。

## 11. App Store 上线注意事项

截至 2026-07-04 核对 Apple 官方文档，首版需要特别注意：

- App Review 要求提审前测试崩溃和 bug，确保 metadata 完整准确，账号功能要提供 demo account 或完整 demo mode，并保持后端服务可访问。
- 如果解锁高级功能、订阅、深度报告、按次购买等数字服务，通常必须使用 In-App Purchase / StoreKit。
- 如果使用第三方登录，需符合 Apple 登录服务规则；如果只用自有账号系统则按自有登录处理。
- 如果 App 支持账号创建，必须在 App 内提供账号删除。
- 所有 App 都需要 App Store Connect metadata 和 App 内可访问的隐私政策。
- App Privacy Details 需要披露自身和第三方 SDK 收集的数据；即便数据只用于 App 功能，也要按 Apple 分类填写。
- 使用 required reason API 或常用第三方 SDK 时，需要 Privacy Manifest、approved reasons，二进制 SDK 还要注意签名要求。
- Push Notification 不应承载敏感合同信息，也不应成为核心功能必需条件。

## 12. 首版里程碑建议

### 第 1 周：能点通

- 冻结 MVP 范围。
- 建仓库和 API contract。
- SwiftUI 三页骨架。
- 后端健康检查、会话、上传。
- AI schema 与租赁字段 schema。

### 第 2 周：能生成

- 字段抽取。
- 缺失字段追问。
- 租赁模板生成。
- iOS 字段完整度和草稿预览。
- PDF/DOCX 导出第一版。

### 第 3 周：能审核

- 文件文本抽取。
- OCR。
- 条款切分。
- 风险规则库。
- RAG 与引用校验。
- 风险卡片 UI。

### 第 4 周：能提测

- 隐私中心、账号删除、demo mode。
- StoreKit / 额度，如首版收费。
- 埋点与性能监控。
- AI eval 50 份。
- TestFlight 内测。

### 第 5 周：能提审

- 修复 TestFlight 问题。
- 完成 App Store metadata、截图、隐私标签、Review Notes。
- 完成律师 / 合规复核。
- 提交 App Store Review。

## 13. 关键开放决策

提工前必须定下来：

1. 首版是否只上 iOS，还是同时做 Android。建议只上 iOS。
2. 首版是否收费。建议先免费额度 + 隐藏复杂订阅，除非商业验证必须收费。
3. 是否需要登录。建议游客可试用，登录只用于保存历史、额度、付费。
4. 数据存储区域。若面向中国用户，合同与个人信息建议境内存储并完成相应备案。
5. 是否已经具备生成式 AI 服务备案、算法备案、ICP、隐私政策主体、支持邮箱、法人开发者账号。
6. 租赁法规知识库来源和授权方式。
7. 上线国家 / 地区。不同地区隐私、支付、AI 合规口径会影响提审材料。

## 14. 官方参考

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple Privacy updates for App Store submissions](https://developer.apple.com/news/?id=3d8a9yyh)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)

