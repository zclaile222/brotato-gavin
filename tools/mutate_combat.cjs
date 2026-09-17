// 战斗侧变异注入工具（配套 tests/combat_stale_enemy_reference_smoke.gd）
//
// 与 mutate_shop.cjs 同一套契约与坑（见那个文件的头部注释）：**变异必须先自证合法**，
// 编译不过时套件也会报红，而那个红与被测行为无关。
// 由 tools/run_mutation.cjs 驱动，它会强制做一次编译自检。
//
// 用法：
//   node tools/mutate_combat.cjs inject <kind>
//   node tools/mutate_combat.cjs restore
//   node tools/mutate_combat.cjs check
const fs = require('fs');

const ROOT = 'G:/ClaudeCode/Godot/brotato-gavin';
const TARGET = ROOT + '/scripts/PlayerCombat.gd';
const BAK = ROOT + '/scripts/PlayerCombat.gd.mutation.bak';
const MARK = 'TEMP-MUTATION';

const MUTATIONS = {
	// 🔴 主变异：撤销「开火前剪掉已释放引用」。
	// 这是 2026-09-17 Boss 战闪退（previously freed）的直接修复点。
	// 期望：套件报红，并复现出与玩家相同的 SCRIPT ERROR。
	'no-prune': {
		desc: '撤掉 _live_enemies() 的剪枝（回到「缓存可能含已释放引用」）',
		anchor:
			'func _live_enemies() -> Array:\n' +
			'\tvar i: int = _cached_enemies.size() - 1\n' +
			'\twhile i >= 0:\n' +
			'\t\tif not is_instance_valid(_cached_enemies[i]):\n' +
			'\t\t\t_cached_enemies.remove_at(i)\n' +
			'\t\ti -= 1\n' +
			'\treturn _cached_enemies',
		replacement: 'func _live_enemies() -> Array:\n\treturn _cached_enemies  # ' + MARK,
	},
	// 等价但走另一条线：不调用 _live_enemies()，直接读原始缓存。
	// 它证明「测试锁定的是 fire_weapon 的行为，而不是某个函数名存在」。
	'fire-use-raw-cache': {
		desc: 'fire_weapon 直接读原始缓存（绕过剪枝）',
		anchor: '\tvar nearby = _live_enemies()',
		replacement: '\tvar nearby = _cached_enemies  # ' + MARK,
	},
};

function read() { return fs.readFileSync(TARGET, 'utf8'); }
function write(s) { fs.writeFileSync(TARGET, s, 'utf8'); }
function marks(s) { return (s.match(new RegExp(MARK, 'g')) || []).length; }
function badEscapes(s) { return (s.match(/\/n\/t|\\n\\t/g) || []).length; }

// 🔴 本仓库 .gd 是 CRLF。anchor 里写的是 `\n`，不归一化会一次都匹配不上，
// 表现为「找不到锚点」而不是语法错，极易误以为文本写错（mutate_shop.cjs 踩过）。
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

console.error('用法: node tools/mutate_combat.cjs inject <kind> | restore | check');
console.error('可选 kind: ' + Object.keys(MUTATIONS).join(', '));
process.exit(2);
