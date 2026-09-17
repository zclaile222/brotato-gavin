// 变异验证驱动器：注入 → 编译自检 → 跑套件 → 恢复 → 报结论
//
// 🔴「编译自检」这一步是关键，不能省：
//    脚本编译不过时套件**也会报红**，但那个红与「变异被捕获」毫无关系 ——
//    被测脚本压根没加载（shop 退化成裸 CanvasLayer，没有任何方法）。
//    2026-09-17 我就把这个红误读成「变异被捕获」，差点宣布测试有效。
//    所以本驱动器在跑套件**之前**先确认变异代码能被 Godot 解析，
//    解析不过就立刻 restore、把本次验证标记为「无效」而不是「通过」。
//
// 用法：node tools/run_mutation.cjs <kind> [res://tests/xxx.gd] [变异器.cjs] [被变异脚本.gd]
//   后两个参数可选，默认走商店那一路（保持既有调用方式不变）。
//   战斗侧示例：node tools/run_mutation.cjs no-prune \
//                 res://tests/combat_stale_enemy_reference_smoke.gd \
//                 tools/mutate_combat.cjs scripts/PlayerCombat.gd
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = 'G:/ClaudeCode/Godot/brotato-gavin';
const GODOT = 'G:/AICoder/Brotato/godot-4.6.1-clean/Godot_v4.6.1-stable_win64_console.exe';
// 变异器模块与其**被变异的目标脚本**（目标只用于最后的残留校验）。
// 默认是商店那一路；换一路时由命令行第 4/5 个参数指定。
const MUTATOR = path.join(ROOT, process.argv[4] || 'tools/mutate_shop.cjs');
const TARGET = path.join(ROOT, process.argv[5] || 'scripts/Shop.gd');

const kind = process.argv[2];
const suite = process.argv[3] || 'res://tests/shop_layout_smoke.gd';

function godot(args) {
	const r = spawnSync(GODOT, args, { cwd: ROOT, encoding: 'utf8', timeout: 180000 });
	return { code: r.status, out: (r.stdout || '') + (r.stderr || '') };
}
function mutator(...args) {
	return spawnSync(process.execPath, [MUTATOR, ...args], { encoding: 'utf8' });
}
function say(s) { console.log(s); }

// ── 0. 前置：基线必须是干净的（没有残留变异）
const pre = mutator('check');
if (!/TEMP-MUTATION=0/.test(pre.stdout || '')) {
	console.error('前置失败：工作区已有变异残留，先 restore。' + pre.stdout);
	process.exit(2);
}

// ── 1. 注入
const inj = mutator('inject', kind);
if (inj.status !== 0) { console.error('注入失败: ' + (inj.stderr || inj.stdout)); process.exit(2); }
say(inj.stdout.trim());

// ── 2. 编译自检（关键步骤）
const imp = godot(['--headless', '--path', '.', '--import']);
const compileErrors = imp.out.split(/\r?\n/).filter(x => /Parse Error|Failed to load script/.test(x));
if (compileErrors.length > 0) {
	say('!! 编译自检未通过 —— 变异代码本身非法，本次验证【作废】：');
	say(compileErrors.slice(0, 4).join('\n'));
	const r = mutator('restore');
	say((r.stdout || r.stderr).trim());
	say('结论：无效验证（既不是通过，也不是「变异被捕获」）');
	process.exit(3);
}
say('编译自检：通过（变异代码合法可解析）');

// ── 3. 跑套件
const res = godot(['--headless', '--path', '.', '--script', suite]);
const verdict = res.out.split(/\r?\n/).find(x => /SMOKE_FAIL|SMOKE_PASS/.test(x)) || '(无判定行)';
say('套件退出码=' + res.code);
say('套件判定：' + verdict.trim());

// ── 4. 恢复 + 残留校验
const rst = mutator('restore');
say((rst.stdout || rst.stderr).trim());
const residual = (fs.readFileSync(TARGET, 'utf8').match(/TEMP-MUTATION/g) || []).length;
say('残留 marker=' + residual);

if (residual !== 0) {
	say('!! 恢复未清干净，工作区处于污染状态，必须手工处理');
	process.exit(4);
}
say(res.code === 1 ? '==> 变异被捕获（套件按预期报红）' : '==> 变异未被捕获（套件仍绿 —— 判据有缺口）');
process.exit(res.code === 1 ? 0 : 1);
