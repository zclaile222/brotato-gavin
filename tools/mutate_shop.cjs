// 变异注入工具
//
// 🔴 为什么要有这个文件（2026-09-17 一次失败得**静默**的变异验证）：
//   我用 `node -e "s.replace('x', 'y\ttreturn 232.0')"` 注入变异。两个问题叠在一起：
//     ① bash 双引号把 `\n` 变成了字面 `/n`（我确实需要的是真换行）；
//     ② 而且把 `return` 直接塞在 `func ...:` 的下一行、与函数体同级缩进 ——
//        GDScript 报 `Unexpected "Indent" in class body`，**整个脚本不加载**。
//   后果链条：脚本编译失败 → shop 退化成裸 CanvasLayer（没有 open/_build_* 等任何方法）
//   → 套件报「拿不到 player / Nonexistent function 'open'」。我把这个红**误读成
//   「变异被捕获」**，差点据此宣布测试有效。
//
//   教训：**变异必须先自证合法**。判据是「Godot 能解析这个文件」，
//   而不是「套件报红了」—— 后者在脚本坏掉时也会红，且红的原因与被测行为无关。
//   所以本工具的 inject 之后必须紧跟一次编译自检，编译不过就立刻 restore 并作废本次验证。
//
// 用法：
//   node tools/mutate_shop.cjs inject <kind>
//   node tools/mutate_shop.cjs restore
//   node tools/mutate_shop.cjs check
const fs = require('fs');

const ROOT = 'G:/ClaudeCode/Godot/brotato-gavin';
const SHOP = ROOT + '/scripts/Shop.gd';
const BAK = ROOT + '/scripts/Shop.gd.mutation.bak';
const MARK = 'TEMP-MUTATION';

// 每个变异必须**类型合法、缩进正确**（即替换后文件仍可解析）。
// anchor 是完整的一段原文，replacement 是等价的合法片段 —— 不做「插一行 return」这种
// 会破坏结构的注入。
const MUTATIONS = {
	// 行高不再从卡片推导，而是写死一个常数 —— 这正是我踩过三次的那个坑
	// （「手算行高」与「卡片声明高度」两个独立数字，迟早分叉）。
	// ⚠️ 注意：改「函数末尾的兜底 return」是**无效变异** ——
	// 有卡片时函数在循环里就已经 return 了（实测 340），末尾那行根本走不到。
	// 变异的必须是循环里那个真正的 return。
	'row-height-hardcoded': {
		desc: '行高写死 232（不再读卡片声明值 → 与卡片 340 分叉）',
		anchor: '\t\t\tif card is Control and (card as Control).custom_minimum_size.y > 0.0:\n\t\t\t\treturn (card as Control).custom_minimum_size.y',
		replacement: '\t\t\tif card is Control and (card as Control).custom_minimum_size.y > 0.0:\n\t\t\t\treturn 232.0  # ' + MARK,
	},
	// 行高写死 400（比卡片大 → 必然侵入下面的动态区）
	'row-height-400': {
		desc: '行高写死 400（> 卡片 340 → ItemRow 应盖住 UpgradeScroll）',
		anchor: '\t\t\tif card is Control and (card as Control).custom_minimum_size.y > 0.0:\n\t\t\t\treturn (card as Control).custom_minimum_size.y',
		replacement: '\t\t\tif card is Control and (card as Control).custom_minimum_size.y > 0.0:\n\t\t\t\treturn 400.0  # ' + MARK,
	},
	// 面板高度非幂等（每次调用都往上加）
	'panel-non-idempotent': {
		desc: '面板高度改成「当前值 + 内容」→ 非幂等，每次调用都膨胀',
		anchor: '\tif panel_h > panel_c.offset_bottom - panel_c.offset_top:\n\t\tpanel_c.offset_bottom = panel_c.offset_top + panel_h',
		replacement: '\tpanel_c.offset_bottom = panel_c.offset_bottom + panel_h  # ' + MARK,
	},
	// 动态区域不布局（回到最初「塌在 (0,0) 宽 0」的缺陷）
	'no-area-layout': {
		desc: '两个动态区域不做布局（宽度 0 = 内容完全不可见）',
		anchor: '\tarea.offset_left = _LAYOUT_MARGIN\n\tarea.offset_right = ($Panel as Control).size.x - _LAYOUT_MARGIN',
		replacement: '\tpass  # ' + MARK,
	},
	// 动态区固定排在面板顶部（回到「写死 top 坐标」的形态）
	'area-top-fixed': {
		desc: '两个动态区固定排在面板顶部 → 必然与 ItemRow 重叠',
		anchor: '\tvar upgrade_top: float = _LAYOUT_TOP + _LAYOUT_TITLE_H + _LAYOUT_GAP + _item_row_height() + _LAYOUT_GAP',
		replacement: '\tvar upgrade_top: float = _LAYOUT_TOP  # ' + MARK,
	},
	// 🔴 判据⑦ 的专属变异（2026-09-16）：内容容器不撑满 ScrollContainer 宽度。
	// 这是「31 个套件全绿但玩家看不见内容」的真实成因 ——
	// ScrollContainer 按子节点 minimum 摆放，缺 SIZE_EXPAND_FILL 时
	// sell_vbox 只有 239 宽（区域 1200），条目挤成左侧窄柱，视觉上整块区域像空的。
	// 判据①~⑥ 全部只测**容器外框**，对这个缺陷完全免疫 —— 所以必须有这一条。
	'content-no-expand': {
		desc: '内容容器不撑满区域宽（ScrollContainer 按 minimum 摆放 → 条目挤在左侧窄柱）',
		anchor: '\tsell_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL',
		replacement: '\tpass  # ' + MARK,
	},
	'upgrade-no-expand': {
		desc: '合成区内容容器不撑满区域宽（同上，覆盖 UpgradeScroll 那一路）',
		anchor: '\tupgrade_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL',
		replacement: '\tpass  # ' + MARK,
	},
};

function read() { return fs.readFileSync(SHOP, 'utf8'); }
function write(s) { fs.writeFileSync(SHOP, s, 'utf8'); }
function marks(s) { return (s.match(new RegExp(MARK, 'g')) || []).length; }
function badEscapes(s) { return (s.match(/\/n\/t|\\n\\t/g) || []).length; }

// 🔴 CRLF：本仓库的 .gd 是 CRLF 行尾。anchor 里写的是 `\n`，
// 直接 `split(anchor)` 会**一次都匹配不上**（实测 anchor 出现 0 次），
// 而不是报语法错 —— 表现为「注入工具说找不到锚点」，很容易误以为文本写错。
// 统一把两侧都归一成 `\n` 再比对，注入后再按原文件的换行风格写回。
function nl(s) { return s.replace(/\r\n/g, '\n'); }
function withNl(text, usesCrlf) { return usesCrlf ? text.replace(/\n/g, '\r\n') : text; }

const argv = process.argv.slice(2);
const mode = argv[0];
const kind = argv[1];

if (mode === 'inject') {
	const m = MUTATIONS[kind];
	if (!m) { console.error('未知变异: ' + kind); process.exit(2); }
	const raw = read();
	const usesCrlf = raw.includes('\r\n');
	const src = nl(raw);
	if (marks(src) > 0) { console.error('已存在变异，先 restore'); process.exit(2); }
	const anchor = nl(m.anchor);
	const replacement = nl(m.replacement);
	const n = src.split(anchor).length - 1;
	if (n !== 1) { console.error('anchor 出现 ' + n + ' 次（要求恰好 1 次），拒绝注入'); process.exit(2); }
	fs.writeFileSync(BAK, raw, 'utf8');
	const out = src.replace(anchor, replacement);
	if (marks(out) !== 1) { console.error('注入后 marker 数异常'); process.exit(2); }
	if (badEscapes(out) > badEscapes(src)) { console.error('注入产物含字面转义序列，中止'); process.exit(2); }
	write(withNl(out, usesCrlf));
	console.log('INJECTED ' + kind + ' :: ' + m.desc + '（换行风格 ' + (usesCrlf ? 'CRLF' : 'LF') + '）');
	process.exit(0);
}

if (mode === 'restore') {
	if (!fs.existsSync(BAK)) { console.error('无备份文件可恢复'); process.exit(2); }
	write(fs.readFileSync(BAK, 'utf8'));
	fs.unlinkSync(BAK);
	const after = read();
	const residual = marks(after);
	console.log('RESTORED 残留 marker=' + residual + '  bytes=' + after.length);
	process.exit(residual === 0 ? 0 : 1);
}

if (mode === 'check') {
	const s = read();
	console.log('TEMP-MUTATION=' + marks(s) + '  bytes=' + s.length + '  bak=' + fs.existsSync(BAK));
	process.exit(0);
}

console.error('用法: node tools/mutate_shop.cjs inject <kind> | restore | check');
console.error('可选 kind: ' + Object.keys(MUTATIONS).join(', '));
process.exit(2);
