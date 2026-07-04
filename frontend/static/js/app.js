/**
 * 契合 · 合同 AI 助手 — 前端骨架脚本
 * 负责：侧边栏导航切换、视图切换、移动端菜单、快捷按钮路由。
 */

// ---------- 视图路由 ----------
const views = document.querySelectorAll('.view');
const navItems = document.querySelectorAll('.nav-item');
const topbarTitle = document.getElementById('topbarTitle');

const viewTitles = {
  home: '首页',
  history: '历史记录',
  templates: '合同模板',
  settings: '设置',
  'draft-flow': '拟定合同',
  'review-flow': '审核合同',
};

function switchView(viewName) {
  // 切换视图
  views.forEach((v) => {
    v.classList.toggle('view--active', v.dataset.view === viewName);
  });

  // 同步导航高亮
  navItems.forEach((item) => {
    item.classList.toggle('nav-item--active', item.dataset.view === viewName);
  });

  // 更新顶栏标题
  if (topbarTitle && viewTitles[viewName]) {
    topbarTitle.textContent = viewTitles[viewName];
  }

  // 滚动到顶部
  document.getElementById('contentArea').scrollTo({ top: 0, behavior: 'smooth' });

  // 移动端关闭侧边栏
  closeSidebar();
}

// 导航点击
navItems.forEach((item) => {
  item.addEventListener('click', (e) => {
    e.preventDefault();
    switchView(item.dataset.view);
  });
});

// 所有带 data-view 的按钮 / 链接
document.querySelectorAll('[data-view]').forEach((el) => {
  if (el.classList.contains('nav-item')) return; // 已处理
  el.addEventListener('click', (e) => {
    e.preventDefault();
    switchView(el.dataset.view);
  });
});

// ---------- 移动端侧边栏 ----------
const sidebar = document.querySelector('.sidebar');
const overlay = document.getElementById('sidebarOverlay');
const menuToggle = document.getElementById('menuToggle');

function openSidebar() {
  sidebar.classList.add('sidebar--open');
  overlay.classList.add('sidebar-overlay--active');
}

function closeSidebar() {
  sidebar.classList.remove('sidebar--open');
  overlay.classList.remove('sidebar-overlay--active');
}

menuToggle?.addEventListener('click', () => {
  sidebar.classList.contains('sidebar--open') ? closeSidebar() : openSidebar();
});

overlay?.addEventListener('click', closeSidebar);

// ---------- 新建合同按钮 ----------
document.getElementById('newChatBtn')?.addEventListener('click', () => {
  switchView('draft-flow');
});

// ---------- 键盘快捷键 ----------
document.addEventListener('keydown', (e) => {
  // Esc 关闭侧边栏
  if (e.key === 'Escape') closeSidebar();

  // Cmd/Ctrl + K 聚焦搜索
  if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
    e.preventDefault();
    document.querySelector('.sidebar__search input')?.focus();
  }
});

// ---------- 占位：后续接入 API ----------
window.QH = {
  apiBase: '/api/v1',
  // 后续在这里挂载 fetch 封装、SSE 流处理等
};

console.log('🚀 契合 · 前端骨架已就绪');
