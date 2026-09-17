#!/usr/bin/env bash
# Brotato (Godot) 冒烟测试全量入口
#
# 用法:
#   bash tests/run_all.sh
#   GODOT_BIN="/path/to/Godot_v4.x-stable_win64_console.exe" bash tests/run_all.sh
#
# 说明：从项目根目录逐个运行 tests/*.gd 冒烟测试并汇总结果。
# 每个测试会自行 print 形如 XXX_SMOKE_PASS 的标记，并以退出码表明成败。
# 本脚本刻意只使用 bash 内建能力（不依赖 grep/head/dirname 等外部命令），
# 以便在 Windows Git Bash 等精简环境中也能运行。

set -u

case "$0" in
	*/*) script_dir="${0%/*}" ;;
	*)   script_dir="." ;;
esac
PROJECT_DIR="$(cd "$script_dir/.." && pwd)"
cd "$PROJECT_DIR" || exit 1

# Godot 可执行文件：优先环境变量，其次常见路径
if [ -z "${GODOT_BIN:-}" ]; then
	for candidate in \
		"G:/AICoder/Brotato/godot-4.6.1-clean/Godot_v4.6.1-stable_win64_console.exe" \
		"../godot-4.6.1-clean/Godot_v4.6.1-stable_win64_console.exe"
	do
		if [ -f "$candidate" ]; then
			GODOT_BIN="$candidate"
			break
		fi
	done
fi

if [ -z "${GODOT_BIN:-}" ] || [ ! -f "$GODOT_BIN" ]; then
	echo "找不到 Godot 可执行文件。请用 GODOT_BIN 环境变量指定，例如：" >&2
	echo "  GODOT_BIN='/c/Godot/Godot_v4.6.1-stable_win64_console.exe' bash tests/run_all.sh" >&2
	exit 2
fi

TESTS="
boss_mechanics_smoke
brotato_data_catalog_smoke
camera_arena_smoke
character_stat_unit_smoke
combat_target_validity_smoke
danger_model_smoke
effects_pool_scene_change_smoke
elemental_boss_smoke
enemy_pool_idle_state_smoke
enemy_wave_table_smoke
level_up_catalog_smoke
phase1_main_scene_smoke
phase1_rules_smoke
phase2_loot_weapon_smoke
phase_d1_weapon_catalog_smoke
phase_d2_character_runtime_smoke
phase_d4_catalog_item_runtime_smoke
weapon_special_rules_smoke
weapon_stat_contribution_smoke
weapon_pierce_rules_smoke
weapon_on_hit_effects_smoke
weapon_bounce_rules_smoke
weapon_cooldown_growth_smoke
weapon_misc_rules_smoke
weapon_remove_by_tier_smoke
ranged_weapon_context_smoke
upgrade_panel_layout_smoke
"

echo "Godot:   $GODOT_BIN"
echo "项目:    $PROJECT_DIR"

# 新增带 class_name 的脚本后，Godot 需要先扫描一次项目才会把全局类名写进
# .godot/global_script_class_cache.cfg。跳过这一步的话，任何引用该类的脚本都会解析失败，
# 症状是一大片互不相关的「Invalid access to property ... on a base object of type ...」
# （因为挂在节点上的脚本压根没加载），极难定位。这里先静默扫一次，把坑挡在测试之前。
# 需要跳过时设 SKIP_IMPORT=1（例如连续跑很多次、确认没有新增类名时）。
if [ "${SKIP_IMPORT:-0}" != "1" ]; then
	"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1
fi
echo

passed=0
failed=0
failed_names=""

for name in $TESTS; do
	if [ ! -f "tests/$name.gd" ]; then
		printf '%-42s %s\n' "$name" "SKIP (文件不存在)"
		continue
	fi
	output="$("$GODOT_BIN" --headless --path . --script "res://tests/$name.gd" 2>&1)"
	code=$?

	# 从输出中提取 *_PASS / *_FAIL 标记（不借助 grep）
	tag=""
	while IFS= read -r line; do
		case "$line" in
			*_SMOKE_PASS*|*_SMOKE_FAIL*|*_PASS*|*_FAIL*) tag="${line%% *}" ; break ;;
		esac
	done <<< "$output"
	tag="${tag%$'\r'}"
	tag="${tag%:}"
	[ -z "$tag" ] && tag="(无标记)"

	if [ "$code" -eq 0 ]; then
		passed=$((passed + 1))
		printf '%-42s %s  %s\n' "$name" "PASS" "$tag"
	else
		failed=$((failed + 1))
		failed_names="$failed_names $name"
		printf '%-42s %s  %s\n' "$name" "FAIL" "$tag"
		# 回显前若干条断言失败明细
		shown=0
		while IFS= read -r line; do
			case "$line" in
				"  - "*)
					printf '%s\n' "$line"
					shown=$((shown + 1))
					[ "$shown" -ge 15 ] && break
					;;
			esac
		done <<< "$output"
	fi
done

echo
echo "结果: PASS=$passed FAIL=$failed"
if [ "$failed" -gt 0 ]; then
	echo "失败用例:$failed_names"
	exit 1
fi
echo "全部通过。"
