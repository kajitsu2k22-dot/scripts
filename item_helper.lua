local script = {}

--------------------------------------------------------------------------------
-- ITEM HELPER v3.1 — Помощник по сборке предметов
-- Анализирует вражеский пик, фазу игры и предлагает оптимальные предметы
-- Локализация: RU / EN / CN
-- author: Euphoria
-- Updated: 2026-02-22
-- Changes v3.0:
--   - Net worth analysis (team gold comparison via item values)
--   - Hero counter item suggestions
--   - Game tempo detection (ahead/even/behind)
--   - Updated neutral items database (2026 patch)
--   - Improved text visibility (larger font, better contrast)
-- Changes v3.1:
--   - Fixed item icon loading (Gleipnir, Scythe of Vyse)
--   - Fixed Net Worth calculation (ITEM_COSTS database)
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- LOCALIZATION
--------------------------------------------------------------------------------
local LANG = "en"
local _langWidget = nil
local _langLastCheck = 0

local L_STRINGS = {
    en = {
        title           = "ITEM HELPER",
        enemies         = "ENEMIES",
        threats         = "THREATS",
        recommended     = "RECOMMENDED",
        analyzing       = "Analyzing enemy team...",
        no_enemies      = "No enemies detected",
        owned           = "OWNED",
        early           = "EARLY",
        mid             = "MID",
        late            = "LATE",
        -- Tips
        tip_invis       = "!! Many invis — buy Dust/Sentries!",
        tip_magic       = "!! Heavy magic dmg — Pipe/BKB!",
        tip_heal        = "!! Much healing — Spirit Vessel!",
        tip_phys        = "!! Heavy phys dmg — Guard/AC!",
        tip_illusions   = "!! Illusions — Mjollnir/BF!",
        tip_disable     = "!! Heavy CC — BKB/Lotus!",
        -- Menu
        m_enable        = "Enable Helper",
        m_panel         = "Show Panel",
        m_auto          = "Auto Analyze",
        m_max           = "Max Suggestions",
        m_reasons       = "Show Reasons",
        m_threats       = "Show Threat Analysis",
        m_owned         = "Highlight Owned",
        m_scale         = "Panel Scale %",
        m_offx          = "Offset X",
        m_offy          = "Offset Y",
        m_opacity       = "Opacity %",
        m_side          = "Panel Side",
        m_left          = "Left",
        m_right         = "Right",
        m_visibility    = "Show Mode",
        m_vis_always    = "Always",
        m_vis_menu      = "Cheat Menu Only",
        m_vis_shop      = "Shop Only",
        m_vis_both      = "Menu or Shop",
    },
    ru = {
        title           = "ITEM HELPER",
        enemies         = "ВРАГИ",
        threats         = "УГРОЗЫ",
        recommended     = "РЕКОМЕНДАЦИИ",
        analyzing       = "Анализ вражеской команды...",
        no_enemies      = "Враги не обнаружены",
        owned           = "ЕСТЬ",
        early           = "РАННЯЯ",
        mid             = "СЕРЕДИНА",
        late            = "ПОЗДНЯЯ",
        tip_invis       = "!! Много инвизов — Dust/Sentries!",
        tip_magic       = "!! Много маг. урона — Pipe/BKB!",
        tip_heal        = "!! Много хила — Spirit Vessel!",
        tip_phys        = "!! Много физ. урона — Guard/AC!",
        tip_illusions   = "!! Иллюзии — Mjollnir/BF!",
        tip_disable     = "!! Много контроля — BKB/Lotus!",
        m_enable        = "Включить хелпер",
        m_panel         = "Показать панель",
        m_auto          = "Авто-анализ",
        m_max           = "Макс. предметов",
        m_reasons       = "Показать причины",
        m_threats       = "Показать анализ угроз",
        m_owned         = "Подсвечивать купленные",
        m_scale         = "Масштаб %",
        m_offx          = "Смещение X",
        m_offy          = "Смещение Y",
        m_opacity       = "Прозрачность %",
        m_side          = "Сторона панели",
        m_left          = "Слева",
        m_right         = "Справа",
        m_visibility    = "Режим показа",
        m_vis_always    = "Всегда",
        m_vis_menu      = "Только меню чита",
        m_vis_shop      = "Только магазин",
        m_vis_both      = "Меню или магазин",
    },
    cn = {
        title           = "物品助手",
        enemies         = "敌人",
        threats         = "威胁",
        recommended     = "推荐",
        analyzing       = "正在分析敌方阵容...",
        no_enemies      = "未检测到敌人",
        owned           = "已购买",
        early           = "前期",
        mid             = "中期",
        late            = "后期",
        tip_invis       = "!! 隐身较多 — 买粉/岗哨!",
        tip_magic       = "!! 魔法伤害高 — 笛子/BKB!",
        tip_heal        = "!! 大量回复 — 大勋章!",
        tip_phys        = "!! 物理伤害高 — 龙心/板甲!",
        tip_illusions   = "!! 幻象较多 — 电锤/战斧!",
        tip_disable     = "!! 大量控制 — BKB/莲花!",
        m_enable        = "启用助手",
        m_panel         = "显示面板",
        m_auto          = "自动分析",
        m_max           = "最大建议数",
        m_reasons       = "显示原因",
        m_threats       = "显示威胁分析",
        m_owned         = "高亮已买物品",
        m_scale         = "面板缩放 %",
        m_offx          = "X偏移",
        m_offy          = "Y偏移",
        m_opacity       = "透明度 %",
        m_side          = "面板位置",
        m_left          = "左",
        m_right         = "右",
        m_visibility    = "显示模式",
        m_vis_always    = "始终显示",
        m_vis_menu      = "仅作弊菜单",
        m_vis_shop      = "仅商店",
        m_vis_both      = "菜单或商店",
    },
}

-- Item reasons per language (key = item internal name)
local L_REASONS = {
    en = {
        item_magic_wand       = "Quick heal vs spell spam",
        item_bracer           = "HP and stats for early game",
        item_wraith_band      = "Stats for agi carries",
        item_null_talisman    = "Stats for int heroes",
        item_phase_boots      = "Armor + damage + speed",
        item_power_treads     = "Attack speed + stat switching",
        item_arcane_boots     = "Mana for the team",
        item_boots_of_bearing = "Attack + move speed aura for team",
        item_ghost            = "Protection from right-clicks",
        item_blade_mail       = "Damage reflection vs carries",
        item_vanguard         = "Damage block for melee heroes",
        item_crimson_guard    = "Team phys damage protection",
        item_assault          = "Armor aura + enemy armor reduction",
        item_shivas_guard     = "Armor + slow vs phys DPS",
        item_heavens_halberd  = "Disarm vs right-clickers",
        item_solar_crest      = "Buff ally / debuff enemy armor",
        item_pipe             = "Team magic barrier",
        item_glimmer_cape     = "Save ally + magic resistance",
        item_black_king_bar   = "Magic immunity — must have vs CC",
        item_spirit_vessel    = "45% heal reduction",
        item_monkey_king_bar  = "True Strike vs evasion",
        item_dust             = "Reveal invisible heroes",
        item_ward_sentry      = "Sentry ward for invis control",
        item_mjollnir         = "Lightning vs illusions/summons",
        item_battlefury       = "Cleave clears illusions + farm",
        item_radiance          = "Burn aura + miss vs illusions",
        item_maelstrom        = "Chain lightning vs unit clusters",
        item_blink            = "Mobility and initiation",
        item_force_staff      = "Escape from slows / reposition",
        item_hurricane_pike   = "Distance from melee + push away",
        item_lotus_orb        = "Dispel + reflect targeted spells",
        item_manta            = "Dispel + illusions for push/fight",
        item_sphere           = "Blocks one targeted spell",
        item_aeon_disk        = "Protection from instant kill",
        item_desolator        = "Armor reduction for phys damage",
        item_daedalus         = "Critical strike for late game",
        item_butterfly        = "Evasion + attack speed for agi carries",
        item_satanic          = "Lifesteal + active heal in fights",
        item_skadi            = "Slow + stats + heal reduction",
        item_abyssal_blade    = "Pierces BKB + bash",
        item_nullifier        = "Purge enemy buffs (Ghost, Glimmer)",
        item_bloodthorn       = "Silence + True Strike + crit",
        item_rod_of_atos      = "Root vs mobile heroes",
        item_orchid           = "Silence vs casters",
        item_sheepstick       = "Hex — strongest disable",
        item_scythe_of_vyse   = "Hex — strongest disable",
        item_ethereal_blade   = "Disarm + magic damage amp",
        item_refresher        = "Double ultimate in fights",
        item_heart            = "Huge HP pool for late game",
        item_overwhelming_blink = "Blink with AoE damage + slow",
        item_swift_blink      = "Blink with agility bonus",
        item_arcane_blink     = "Blink with cooldown reduction",
        item_mekansm          = "Team heal",
        item_guardian_greaves  = "Greaves: aura + dispel + heal",
        item_medallion_of_courage = "Armor reduction for fast kills",
        item_silver_edge      = "Break disables passives (Bristle, PA)",
        item_gungir           = "AoE root + lightning vs mobile/illusions",
        item_gungungir        = "AoE root + lightning vs mobile/illusions",
        item_harpoon          = "Pull to enemy for initiation",
        item_disperser        = "Strong self-dispel + enemy slow",
        item_witch_blade      = "Attack damage + slow for int heroes",
        item_pavise           = "Physical shield on ally",
        item_ultimate_scepter = "Hero ability upgrade",
        item_aghanims_shard   = "New ability or improvement",
        item_invis_sword      = "Invis for initiation + damage",
        item_veil_of_discord  = "Amplify team magic damage in area",
        item_kaya_and_sange   = "HP + spell amp for caster carries",
        item_sange_and_yasha  = "Stats + speed for agi/str carries",
        item_yasha_and_kaya   = "Speed + spell amp for hybrids",
        item_diffusal_blade   = "Mana burn + slow",
        item_bloodstone       = "Huge mana pool + spell lifesteal",
        item_cyclone          = "Self-dispel + interrupt channels",
        item_dagon            = "Magic nuke for finishing",
        item_octarine_core    = "25% CDR for casters",
        item_wind_waker       = "Save ally (Tornado + dispel)",
        item_travel_boots     = "TP to creeps for split-push",
        item_phylactery       = "Spell amp + HP for casters",
        item_holy_locket      = "Amplify healing + charges",
        item_hand_of_midas    = "Gold + XP acceleration",
    },
    ru = {
        item_magic_wand       = "Быстрый хил vs спама заклинаний",
        item_bracer           = "HP и статы на ранней стадии",
        item_wraith_band      = "Статы для agi-керри",
        item_null_talisman    = "Статы для int-героев",
        item_phase_boots      = "Броня + урон + скорость",
        item_power_treads     = "Атака + переключение статов",
        item_arcane_boots     = "Мана для команды",
        item_boots_of_bearing = "Аура скорости для команды",
        item_ghost            = "Защита от правой кнопки",
        item_blade_mail       = "Отражение урона vs керри",
        item_vanguard         = "Блок урона для ближнего боя",
        item_crimson_guard    = "Командная защита от физ. урона",
        item_assault          = "Аура брони + снижение вражеской",
        item_shivas_guard     = "Броня + замедление vs физ. ДПС",
        item_heavens_halberd  = "Разоружение vs правокликеров",
        item_solar_crest      = "Бафф союзника / дебафф брони",
        item_pipe             = "Командный щит от магии",
        item_glimmer_cape     = "Спасение союзника + маг. резист",
        item_black_king_bar   = "Иммунитет к магии — must have vs контроля",
        item_spirit_vessel    = "Снижение хила на 45%",
        item_monkey_king_bar  = "True Strike vs уклонения",
        item_dust             = "Обнаружение невидимых героев",
        item_ward_sentry      = "Сентри для контроля инвизов",
        item_mjollnir         = "Молния vs иллюзий/призывов",
        item_battlefury       = "Клив vs иллюзий + фарм",
        item_radiance          = "Аура урона + промах vs иллюзий",
        item_maelstrom        = "Молния vs скоплений юнитов",
        item_blink            = "Мобильность и инициация",
        item_force_staff      = "Спасение от слоу / позиционирование",
        item_hurricane_pike   = "Дистанция от ближников",
        item_lotus_orb        = "Диспел + отражение заклинаний",
        item_manta            = "Диспел + иллюзии для push/fight",
        item_sphere           = "Блок одного targeted заклинания",
        item_aeon_disk        = "Защита от моментального убийства",
        item_desolator        = "Снижение брони для физ. урона",
        item_daedalus         = "Критический урон для поздней",
        item_butterfly        = "Уклонение + скорость атаки",
        item_satanic          = "Вампиризм + активный хил",
        item_skadi            = "Замедление + статы + снижение хила",
        item_abyssal_blade    = "Пробивает BKB + bash",
        item_nullifier        = "Снимает баффы (Ghost, Glimmer, Aeon)",
        item_bloodthorn       = "Молчание + True Strike + крит",
        item_rod_of_atos      = "Рут vs мобильных героев",
        item_orchid           = "Молчание vs кастеров",
        item_sheepstick       = "Хекс — сильнейший дизейбл",
        item_scythe_of_vyse   = "Хекс — сильнейший дизейбл",
        item_ethereal_blade   = "Обезоружение + маг. усиление",
        item_refresher        = "Двойной ультимейт в драке",
        item_heart            = "Огромный запас HP для лейта",
        item_overwhelming_blink = "Блинк с AoE уроном + замедлением",
        item_swift_blink      = "Блинк с бонусом ловкости",
        item_arcane_blink     = "Блинк с уменьшением КД",
        item_mekansm          = "Командный хил",
        item_guardian_greaves  = "Грейвзы: аура + диспел + хил",
        item_medallion_of_courage = "Снижение брони для быстрых убийств",
        item_silver_edge      = "Break отключает пассивки (Bristle, PA)",
        item_gungir           = "AoE рут + молнии vs иллюзий",
        item_gungungir        = "AoE рут + молнии vs иллюзий",
        item_harpoon          = "Притягивание к врагу",
        item_disperser        = "Сильный диспел + замедление врагов",
        item_witch_blade      = "Урон + замедление для int-героев",
        item_pavise           = "Физический щит на союзника",
        item_ultimate_scepter = "Улучшение способностей героя",
        item_aghanims_shard   = "Новая способность или улучшение",
        item_invis_sword      = "Невидимость + урон для инициации",
        item_veil_of_discord  = "Усиление маг. урона в области",
        item_kaya_and_sange   = "HP + усиление заклинаний",
        item_sange_and_yasha  = "Статы + скорость для керри",
        item_yasha_and_kaya   = "Скорость + маг. усиление",
        item_diffusal_blade   = "Сжигание маны + замедление",
        item_bloodstone       = "Огромная мана + вампиризм заклинаний",
        item_cyclone          = "Диспел на себя + прерывание каналов",
        item_dagon            = "Магический нюк для добивания",
        item_octarine_core    = "Сокращение КД на 25% для кастеров",
        item_wind_waker       = "Сейв союзника (Торнадо + диспел)",
        item_travel_boots     = "ТП на крипов для сплит-пуша",
        item_phylactery       = "Усиление заклинаний + HP",
        item_holy_locket      = "Усиление хила + заряды",
        item_hand_of_midas    = "Ускорение золота и опыта",
    },
    cn = {
        item_magic_wand       = "对付技能骚扰的快速回复",
        item_bracer           = "前期生命值和属性",
        item_wraith_band      = "敏捷核心属性",
        item_null_talisman    = "智力英雄属性",
        item_phase_boots      = "护甲+攻击+速度",
        item_power_treads     = "攻速+属性切换",
        item_arcane_boots     = "团队法力值",
        item_boots_of_bearing = "团队攻速移速光环",
        item_ghost            = "防物理攻击",
        item_blade_mail       = "反弹伤害对抗核心",
        item_vanguard         = "近战伤害格挡",
        item_crimson_guard    = "团队物理防护",
        item_assault          = "护甲光环+降低敌方护甲",
        item_shivas_guard     = "护甲+减速对抗物理",
        item_heavens_halberd  = "缴械对抗右键英雄",
        item_solar_crest      = "增益友军/减甲敌人",
        item_pipe             = "团队魔法护盾",
        item_glimmer_cape     = "保护队友+魔抗",
        item_black_king_bar   = "魔法免疫 — 对抗控制必备",
        item_spirit_vessel    = "降低治疗45%",
        item_monkey_king_bar  = "真实打击对抗闪避",
        item_dust             = "显示隐身英雄",
        item_ward_sentry      = "岗哨守卫控制隐身",
        item_mjollnir         = "闪电对抗幻象/召唤物",
        item_battlefury       = "分裂清除幻象+打钱",
        item_radiance          = "灼烧光环+对抗幻象",
        item_maelstrom        = "闪电链对抗单位群",
        item_blink            = "机动性和先手",
        item_force_staff      = "逃脱减速/调整位置",
        item_hurricane_pike   = "拉开近战距离",
        item_lotus_orb        = "驱散+反射指向技能",
        item_manta            = "驱散+幻象推进/团战",
        item_sphere           = "格挡一个指向技能",
        item_aeon_disk        = "防止瞬间击杀",
        item_desolator        = "降甲增加物理伤害",
        item_daedalus         = "后期暴击伤害",
        item_butterfly        = "闪避+攻速",
        item_satanic          = "吸血+主动回复",
        item_skadi            = "减速+属性+降低回复",
        item_abyssal_blade    = "穿刺BKB+眩晕",
        item_nullifier        = "清除敌方增益效果",
        item_bloodthorn       = "沉默+真实打击+暴击",
        item_rod_of_atos      = "束缚对抗机动英雄",
        item_orchid           = "沉默对抗法师",
        item_scythe_of_vyse   = "变羊 — 最强控制",
        item_ethereal_blade   = "缴械+魔法增幅",
        item_refresher        = "团战双大招",
        item_heart            = "后期大量生命值",
        item_overwhelming_blink = "闪烁+范围伤害减速",
        item_swift_blink      = "闪烁+敏捷加成",
        item_arcane_blink     = "闪烁+冷却缩减",
        item_mekansm          = "团队治疗",
        item_guardian_greaves  = "卫士胫甲: 光环+驱散+治疗",
        item_medallion_of_courage = "降甲快速击杀",
        item_silver_edge      = "破隐+破除被动技能",
        item_gungungir        = "范围束缚+闪电",
        item_harpoon          = "拉向敌人先手",
        item_disperser        = "强驱散+减速敌人",
        item_witch_blade      = "智力英雄攻击减速",
        item_pavise           = "物理护盾保护队友",
        item_ultimate_scepter = "英雄技能升级",
        item_aghanims_shard   = "新技能或增强",
        item_invis_sword      = "隐身先手+伤害",
        item_veil_of_discord  = "增幅区域魔法伤害",
        item_kaya_and_sange   = "生命+技能增幅",
        item_sange_and_yasha  = "属性+速度",
        item_yasha_and_kaya   = "速度+技能增幅",
        item_diffusal_blade   = "燃烧法力+减速",
        item_bloodstone       = "大量法力+技能吸血",
        item_cyclone          = "自我驱散+打断施法",
        item_dagon            = "魔法爆发收割",
        item_octarine_core    = "法师25%冷却缩减",
        item_wind_waker       = "保护队友(龙卷风+驱散)",
        item_travel_boots     = "传送到小兵分推",
        item_phylactery       = "技能增幅+生命值",
        item_holy_locket      = "增强治疗效果+充能",
        item_hand_of_midas    = "加速金币和经验",
    },
}

-- Neutral item reasons per language (Updated 2026)
local L_NEUTRAL_REASONS = {
    en = {
        -- Tier 1
        item_occult_bracelet    = "Mana + INT for spell casters",
        item_kobold_cup         = "Gold generation + luck for farm",
        item_chipped_vest       = "Reflect vs phys damage",
        item_polliwog_charm     = "Heal + mana sustain",
        item_dormant_curio      = "Stats + vision control",
        item_duelist_gloves     = "Lifesteal + AGI for sustain",
        item_weighted_dice      = "Luck + crit chance",
        item_ash_legion_shield  = "Block + armor vs phys",
        -- Tier 2
        item_essence_ring       = "Active HP + mana sustain",
        item_mana_draught       = "Mana sustain for casters",
        item_poor_mans_shield   = "Block vs right-clicks",
        item_searing_signet     = "Burn + magic amp",
        item_pogo_stick         = "Mobility + initiation",
        item_defiant_shell      = "Armor + save vs burst",
        -- Tier 3
        item_serrated_shiv      = "Armor reduction + bleed",
        item_gunpowder_gauntlets= "Burst damage + attack speed",
        item_whisper_of_the_dread= "Silence + magic burst",
        item_jidi_pollen_bag    = "Slow + heal + mana",
        item_psychic_headband   = "INT + mana + CDR",
        item_unrelenting_eye    = "Vision + true strike",
        -- Tier 4
        item_crippling_crossbow = "Slow + armor reduction",
        item_giant_maul         = "Burst + stun",
        item_rattlecage         = "Armor + reflect + fear",
        item_idol_of_screeauk   = "Save + dispel + magic resist",
        item_flayers_bota       = "Mobility + AGI + attack speed",
        item_metamorphic_mandible= "Stats + armor + HP",
        -- Tier 5
        item_desolator_2        = "Armor reduction for phys DPS",
        item_fallen_sky         = "Initiation + stun",
        item_demonicon          = "Summons for push",
        item_minotaur_horn      = "Stun + tankiness",
        item_spider_legs        = "Mobility + slow",
        item_riftshadow_prism   = "Magic amp + INT + mana",
        item_dezun_bloodrite    = "Heal + magic burst + anti-heal",
        item_divine_regalia     = "Stats + save + ultimate",
        -- Legacy items (for backwards compatibility)
        item_fairy_trinket      = "Sustain for supports",
        item_iron_talon         = "Farm acceleration for melee",
        item_mysterious_hat     = "Mana + magic burst for casters",
        item_ocean_heart        = "HP + mana sustain",
        item_ring_of_aquila     = "Armor + aura for agi heroes",
        item_keen_optic         = "Attack speed + vision",
        item_ninja_gear         = "Invis for initiation",
        item_possessed_mask     = "Lifesteal for sustain",
        item_prophet_twigs      = "Stats + tree vision",
        item_royal_jelly        = "HP + mana + ward",
        item_safety_bubble      = "Save vs burst damage",
        item_thief_cloth        = "Evasion + move speed",
        item_trusty_shovel      = "Gold + potential items",
        item_wicked_pocket_knife = "Armor reduction on attack",
        item_ceremonial_robe    = "HP + mana + magic resist",
        item_clever_apparatus   = "Mana + armor + cooldown",
        item_dragon_scale       = "Armor + burn aura",
        item_essence_booster    = "HP + mana sustain",
        item_flicker            = "Dispel + mobility",
        item_golem_gauntlets    = "HP + armor + slow",
        item_havoc_hammer       = "Armor reduction + initiation",
        item_imp_claw           = "Burst damage on attack",
        item_mind_breaker       = "Mana burn + int",
        item_orb_of_destruction = "Armor reduction + slow",
        item_quicksilver_amulet = "Attack speed + mobility",
        item_repair_kit         = "Armor + heal + save",
        item_spell_prism        = "CD reduction + magic amp",
        item_ballista           = "True strike + knockback",
        item_book_of_shadows    = "Save + invis + dispel",
        item_cloak_of_flames    = "Burn aura + armor",
        item_giants_ring        = "HP + aura radius",
        item_glimmerdark_shield = "Save + magic resist",
        item_harlequins_crest   = "Armor + attack speed + evasion",
        item_paladin_sword      = "Heal + lifesteal",
        item_panic_button       = "Save vs burst",
        item_timeless_relic     = "Magic amp + CD reduction",
        item_titan_sliver       = "HP + debuff reduction",
        item_ascetics_cap       = "HP + magic resist",
        item_bullwhip           = "Slow + mobility",
        item_carapace_of_qaldin = "Armor + reflect",
        item_demon_shredder     = "Cleave + attack speed",
        item_frozen_emblem      = "Armor + slow aura",
        item_illusionsts_cape   = "Illusion count + stats",
        item_pirate_hat         = "Gold + attack speed",
        item_princes_knife      = "Armor reduction + slow",
        item_psycho_mask        = "Lifesteal + fear",
        item_spy_gadget         = "Invis + vision",
        item_stormcrafter       = "Magic burst + mobility",
        item_the_leveller       = "Armor reduction + farm",
        item_twin_soul          = "Save + heal on death",
        item_apex               = "Attack speed + armor + agi",
        item_book_of_the_dead   = "Strong summons for push",
        item_excalibur          = "Damage + heal active",
        item_force_field        = "Team save vs burst",
        item_fusion_rune        = "Magic amp + spell burst",
        item_mirror_shield      = "Reflect vs magic",
        item_parasma            = "Magic burst + int",
        item_seer_stone         = "Vision + magic amp",
    },
    ru = {
        -- Tier 1
        item_occult_bracelet    = "Мана + INT для кастеров",
        item_kobold_cup         = "Золото + удача для фарма",
        item_chipped_vest       = "Отражение vs физ. урона",
        item_polliwog_charm     = "Хил + мана сустейн",
        item_dormant_curio      = "Статы + видение",
        item_duelist_gloves     = "Вампиризм + AGI для сустейна",
        item_weighted_dice      = "Удача + крит шанс",
        item_ash_legion_shield  = "Блок + броня vs физ",
        -- Tier 2
        item_essence_ring       = "Активный HP + мана сустейн",
        item_mana_draught       = "Мана сустейн для кастеров",
        item_poor_mans_shield   = "Блок vs правых кликов",
        item_searing_signet     = "Горение + усиление магии",
        item_pogo_stick         = "Мобильность + инициация",
        item_defiant_shell      = "Броня + сейв vs бёрста",
        -- Tier 3
        item_serrated_shiv      = "Снижение брони + кровотечение",
        item_gunpowder_gauntlets= "Бёрст урон + скорость атаки",
        item_whisper_of_the_dread= "Молчание + маг. урон",
        item_jidi_pollen_bag    = "Замедление + хил + мана",
        item_psychic_headband   = "INT + мана + КД",
        item_unrelenting_eye    = "Видение + верный удар",
        -- Tier 4
        item_crippling_crossbow = "Замедление + снижение брони",
        item_giant_maul         = "Бёрст + стан",
        item_rattlecage         = "Броня + отражение + страх",
        item_idol_of_screeauk   = "Сейв + диспел + маг. резист",
        item_flayers_bota       = "Мобильность + AGI + скорость атаки",
        item_metamorphic_mandible= "Статы + броня + HP",
        -- Tier 5
        item_desolator_2        = "Снижение брони для физ. урона",
        item_fallen_sky         = "Инициация + стан",
        item_demonicon          = "Саммоны для пуша",
        item_minotaur_horn      = "Стан + танковость",
        item_spider_legs        = "Мобильность + замедление",
        item_riftshadow_prism   = "Усиление магии + INT + мана",
        item_dezun_bloodrite    = "Хил + маг. бёрст + анти-хил",
        item_divine_regalia     = "Статы + сейв + ультимейт",
        -- Legacy items
        item_fairy_trinket      = "Сустейн для саппортов",
        item_iron_talon         = "Ускорение фарма для ближников",
        item_mysterious_hat     = "Мана + маг. урон для кастеров",
        item_ocean_heart        = "HP + мана сустейн",
        item_ring_of_aquila     = "Броня + аура для agi героев",
        item_keen_optic         = "Скорость атаки + видение",
        item_ninja_gear         = "Инвиз для инициации",
        item_possessed_mask     = "Вампиризм для сустейна",
        item_prophet_twigs      = "Статы + видение деревьев",
        item_royal_jelly        = "HP + мана + вард",
        item_safety_bubble      = "Спасение vs бёрста",
        item_thief_cloth        = "Уклонение + скорость",
        item_trusty_shovel      = "Золото + возможные предметы",
        item_wicked_pocket_knife = "Снижение брони при атаке",
        item_ceremonial_robe    = "HP + мана + маг. резист",
        item_clever_apparatus   = "Мана + броня + КД",
        item_dragon_scale       = "Броня + аура урона",
        item_essence_booster    = "HP + мана сустейн",
        item_flicker            = "Диспел + мобильность",
        item_golem_gauntlets    = "HP + броня + замедление",
        item_havoc_hammer       = "Снижение брони + инициация",
        item_imp_claw           = "Бёрст урон при атаке",
        item_mind_breaker       = "Сжигание маны + int",
        item_orb_of_destruction = "Снижение брони + замедление",
        item_quicksilver_amulet = "Скорость атаки + мобильность",
        item_repair_kit         = "Броня + хил + сейв",
        item_spell_prism        = "Сокращение КД + усиление магии",
        item_ballista           = "True strike + отталкивание",
        item_book_of_shadows    = "Сейв + инвиз + диспел",
        item_cloak_of_flames    = "Аура урона + броня",
        item_demonicon          = "Саммоны для пуша",
        item_giants_ring        = "HP + радиус ауры",
        item_glimmerdark_shield = "Сейв + маг. резист",
        item_harlequins_crest   = "Броня + скорость атаки + уклонение",
        item_paladin_sword      = "Хил + вампиризм",
        item_panic_button       = "Спасение vs бёрста",
        item_spider_legs        = "Мобильность + замедление",
        item_timeless_relic     = "Усиление магии + сокращение КД",
        item_titan_sliver       = "HP + снижение дебаффов",
        item_ascetics_cap       = "HP + маг. резист",
        item_bullwhip           = "Замедление + мобильность",
        item_carapace_of_qaldin = "Броня + отражение",
        item_demon_shredder     = "Клив + скорость атаки",
        item_frozen_emblem      = "Броня + аура замедления",
        item_illusionsts_cape   = "Количество иллюзий + статы",
        item_minotaur_horn      = "Стан + танковость",
        item_pirate_hat         = "Золото + скорость атаки",
        item_princes_knife      = "Снижение брони + замедление",
        item_psycho_mask        = "Вампиризм + страх",
        item_spy_gadget         = "Инвиз + видение",
        item_stormcrafter       = "Маг. бёрст + мобильность",
        item_the_leveller       = "Снижение брони + фарм",
        item_twin_soul          = "Сейв + хил при смерти",
        item_apex               = "Скорость атаки + броня + agi",
        item_book_of_the_dead   = "Сильные саммоны для пуша",
        item_excalibur          = "Урон + активный хил",
        item_force_field        = "Командный сейв vs бёрста",
        item_fusion_rune        = "Усиление магии + бёрст",
        item_mirror_shield      = "Отражение vs магии",
        item_parasma            = "Маг. бёрст + int",
        item_seer_stone         = "Видение + усиление магии",
    },
    cn = {
        item_fairy_trinket      = "辅助续航",
        item_iron_talon         = "近战打钱加速",
        item_mysterious_hat     = "法力+法术爆发",
        item_ocean_heart        = "生命+法力续航",
        item_poor_mans_shield   = "格挡物理攻击",
        item_ring_of_aquila     = "护甲+敏捷光环",
        item_chipped_vest       = "反弹物理伤害",
        item_essence_ring       = "主动生命+法力回复",
        item_keen_optic         = "攻速+视野",
        item_ninja_gear         = "隐身先手",
        item_possessed_mask     = "吸血续航",
        item_prophet_twigs      = "属性+树木视野",
        item_royal_jelly        = "生命+法力+守卫",
        item_safety_bubble      = "防止爆发伤害",
        item_thief_cloth        = "闪避+移速",
        item_trusty_shovel      = "金币+潜在物品",
        item_wicked_pocket_knife = "攻击减甲",
        item_ceremonial_robe    = "生命+法力+魔抗",
        item_clever_apparatus   = "法力+护甲+冷却",
        item_dragon_scale       = "护甲+灼烧光环",
        item_essence_booster    = "生命+法力续航",
        item_fallen_sky         = "先手+眩晕",
        item_flicker            = "驱散+机动",
        item_golem_gauntlets    = "生命+护甲+减速",
        item_havoc_hammer       = "减甲+先手",
        item_imp_claw           = "攻击爆发伤害",
        item_mind_breaker       = "烧蓝+智力",
        item_orb_of_destruction = "减甲+减速",
        item_quicksilver_amulet = "攻速+机动",
        item_repair_kit         = "护甲+治疗+保护",
        item_spell_prism        = "冷却缩减+法术增幅",
        item_ballista           = "必中+击退",
        item_book_of_shadows    = "保护+隐身+驱散",
        item_cloak_of_flames    = "灼烧光环+护甲",
        item_demonicon          = "召唤物推进",
        item_giants_ring        = "生命+光环范围",
        item_glimmerdark_shield = "保护+魔抗",
        item_harlequins_crest   = "护甲+攻速+闪避",
        item_paladin_sword      = "治疗+吸血",
        item_panic_button       = "防止爆发",
        item_spider_legs        = "机动+减速",
        item_timeless_relic     = "法术增幅+冷却缩减",
        item_titan_sliver       = "生命+减益减免",
        item_ascetics_cap       = "生命+魔抗",
        item_bullwhip           = "减速+机动",
        item_carapace_of_qaldin = "护甲+反弹",
        item_demon_shredder     = "分裂+攻速",
        item_frozen_emblem      = "护甲+减速光环",
        item_illusionsts_cape   = "幻象数量+属性",
        item_minotaur_horn      = "眩晕+肉度",
        item_pirate_hat         = "金币+攻速",
        item_princes_knife      = "减甲+减速",
        item_psycho_mask        = "吸血+恐惧",
        item_spy_gadget         = "隐身+视野",
        item_stormcrafter       = "法术爆发+机动",
        item_the_leveller       = "减甲+打钱",
        item_twin_soul          = "死亡时保护+治疗",
        item_apex               = "攻速+护甲+敏捷",
        item_book_of_the_dead   = "强力召唤物推进",
        item_excalibur          = "伤害+主动治疗",
        item_force_field        = "团队防爆发",
        item_fusion_rune        = "法术增幅+爆发",
        item_mirror_shield      = "反弹魔法",
        item_parasma            = "法术爆发+智力",
        item_seer_stone         = "视野+法术增幅",
    },
}

local function updateLang()
    local now = 0
    pcall(function() now = GameRules.GetGameTime() end)
    if now - _langLastCheck < 2.0 then return end
    _langLastCheck = now

    if not _langWidget then
        local ok, w = pcall(Menu.Find, "SettingsHidden", "", "", "", "Main", "Language")
        if ok and w then _langWidget = w end
    end

    if _langWidget then
        local ok, v = pcall(function() return _langWidget:Get() end)
        if ok and v ~= nil then
            if v == 1 then LANG = "ru"
            elseif v == 2 then LANG = "cn"
            else LANG = "en" end
        end
    end
end

local function L(key)
    local tbl = L_STRINGS[LANG] or L_STRINGS.en
    return tbl[key] or L_STRINGS.en[key] or key
end

local function LR(itemName)
    local tbl = L_REASONS[LANG] or L_REASONS.en
    local reason = tbl[itemName] or L_REASONS.en[itemName] or ""
    if reason ~= "" then return reason end
    -- Fallback to neutral item reasons
    local neutralTbl = L_NEUTRAL_REASONS[LANG] or L_NEUTRAL_REASONS.en
    return neutralTbl[itemName] or L_NEUTRAL_REASONS.en[itemName] or ""
end

--------------------------------------------------------------------------------
-- HERO THREAT TAGS
--------------------------------------------------------------------------------
local HERO_TAGS = {
    -- ══════════════ Carry / Physical DPS ══════════════
    npc_dota_hero_antimage           = {"carry","magic_resist","mobility","mana_burn"},
    npc_dota_hero_phantom_assassin   = {"carry","phys_burst","crit","evasion"},
    npc_dota_hero_juggernaut         = {"carry","phys_dps","magic_immune","heal"},
    npc_dota_hero_faceless_void      = {"carry","chrono","phys_dps","evasion","mobility"},
    npc_dota_hero_terrorblade        = {"carry","phys_dps","illusions","push"},
    npc_dota_hero_spectre            = {"carry","global","phys_dps","tanky"},
    npc_dota_hero_phantom_lancer     = {"carry","illusions","phys_dps","mana_burn"},
    npc_dota_hero_medusa             = {"carry","phys_dps","tanky","split_shot"},
    npc_dota_hero_troll_warlord      = {"carry","phys_dps","bash","attack_speed"},
    npc_dota_hero_ursa               = {"carry","phys_burst","tanky"},
    npc_dota_hero_sven               = {"carry","phys_burst","stun","cleave"},
    npc_dota_hero_life_stealer       = {"carry","phys_dps","magic_immune","heal","slow"},
    npc_dota_hero_slark              = {"carry","phys_dps","purge","invis","mobility"},
    npc_dota_hero_monkey_king        = {"carry","phys_burst","stun","mobility"},
    npc_dota_hero_chaos_knight       = {"carry","phys_burst","illusions","stun"},
    npc_dota_hero_luna               = {"carry","phys_dps","push","magic_burst"},
    npc_dota_hero_drow_ranger        = {"carry","phys_dps","slow","ranged"},
    npc_dota_hero_morphling          = {"carry","phys_burst","magic_burst","mobility"},
    npc_dota_hero_naga_siren         = {"carry","illusions","push","disable"},
    npc_dota_hero_weaver             = {"carry","phys_dps","invis","mobility"},
    npc_dota_hero_riki               = {"carry","phys_dps","invis","silence"},
    npc_dota_hero_clinkz             = {"carry","phys_dps","invis","push"},
    npc_dota_hero_sniper             = {"carry","phys_dps","ranged","siege"},
    npc_dota_hero_templar_assassin   = {"carry","phys_burst","armor_reduce","invis"},
    npc_dota_hero_bloodseeker        = {"carry","phys_dps","heal","silence","rupture"},
    npc_dota_hero_lycan              = {"carry","phys_dps","push","summons"},
    npc_dota_hero_huskar             = {"carry","magic_resist","phys_dps","heal"},
    npc_dota_hero_alchemist          = {"carry","phys_dps","stun","tanky","farm"},
    npc_dota_hero_skeleton_king      = {"carry","phys_dps","stun","reincarnation"},
    npc_dota_hero_arc_warden         = {"carry","phys_dps","push","summons","ranged"},
    npc_dota_hero_lone_druid         = {"carry","phys_dps","push","summons"},
    npc_dota_hero_ember_spirit       = {"carry","magic_burst","mobility","cleave"},
    npc_dota_hero_gyrocopter         = {"carry","magic_burst","phys_dps","ranged"},
    npc_dota_hero_nevermore          = {"carry","phys_dps","magic_burst","armor_reduce"},
    npc_dota_hero_razor              = {"carry","phys_dps","tanky","armor_reduce","drain"},
    npc_dota_hero_viper              = {"carry","slow","magic_burst","break","tanky"},

    -- ══════════════ Magic Burst / Nukers ══════════════
    npc_dota_hero_invoker            = {"magic_burst","disable","global","versatile"},
    npc_dota_hero_storm_spirit       = {"magic_burst","mobility","disable"},
    npc_dota_hero_lina               = {"magic_burst","stun","phys_dps"},
    npc_dota_hero_zuus               = {"magic_burst","global","vision"},
    npc_dota_hero_tinker             = {"magic_burst","push","rearm"},
    npc_dota_hero_queenofpain        = {"magic_burst","mobility","silence"},
    npc_dota_hero_puck               = {"magic_burst","mobility","disable","silence"},
    npc_dota_hero_void_spirit        = {"magic_burst","mobility","disable"},
    npc_dota_hero_leshrac            = {"magic_burst","push","stun"},
    npc_dota_hero_death_prophet      = {"magic_burst","push","heal","silence"},
    npc_dota_hero_necrolyte          = {"magic_burst","heal","tanky","anti_heal"},
    npc_dota_hero_skywrath_mage      = {"magic_burst","silence","slow"},
    npc_dota_hero_pugna              = {"magic_burst","push","ward"},
    npc_dota_hero_dark_willow        = {"magic_burst","disable","fear"},
    npc_dota_hero_hoodwink           = {"magic_burst","disable","invis"},
    npc_dota_hero_muerta             = {"magic_burst","phys_dps","silence","invis"},
    npc_dota_hero_obsidian_destroyer = {"magic_burst","mana_burn","disable","int"},
    npc_dota_hero_phoenix            = {"magic_burst","heal","disable","slow"},
    npc_dota_hero_shredder           = {"magic_burst","tanky","pure_dmg"},
    npc_dota_hero_venomancer         = {"magic_burst","slow","push","summons"},

    -- ══════════════ Disable / Control ══════════════
    npc_dota_hero_lion               = {"disable","stun","hex","magic_burst","mana_burn"},
    npc_dota_hero_shadow_shaman      = {"disable","push","hex","stun"},
    npc_dota_hero_bane               = {"disable","pure_dmg","nightmare"},
    npc_dota_hero_enigma             = {"disable","black_hole","push","summons"},
    npc_dota_hero_tidehunter         = {"disable","tanky","armor_reduce"},
    npc_dota_hero_magnataur          = {"disable","empower","mobility"},
    npc_dota_hero_earthshaker        = {"disable","stun","magic_burst"},
    npc_dota_hero_sand_king          = {"disable","stun","magic_burst"},
    npc_dota_hero_elder_titan        = {"disable","armor_reduce","magic_resist_reduce"},
    npc_dota_hero_primal_beast       = {"disable","tanky","phys_dps","magic_burst"},
    npc_dota_hero_spirit_breaker     = {"disable","bash","global","mobility"},
    npc_dota_hero_axe                = {"disable","tanky","call"},
    npc_dota_hero_legion_commander   = {"disable","phys_dps","duel"},
    npc_dota_hero_doom_bringer       = {"disable","doom","tanky"},
    npc_dota_hero_batrider           = {"disable","mobility","magic_burst"},
    npc_dota_hero_mars               = {"disable","tanky","phys_burst"},
    npc_dota_hero_centaur            = {"disable","tanky","stun","global"},
    npc_dota_hero_slardar            = {"disable","armor_reduce","bash","phys_dps"},
    npc_dota_hero_brewmaster         = {"disable","tanky","evasion","summons"},
    npc_dota_hero_rattletrap         = {"disable","tanky","vision"},
    npc_dota_hero_nyx_assassin       = {"disable","invis","mana_burn","magic_burst"},
    npc_dota_hero_tusk               = {"disable","phys_burst","mobility","save"},
    npc_dota_hero_ringmaster         = {"disable","magic_burst","fear"},
    npc_dota_hero_beastmaster        = {"disable","push","summons","vision"},

    -- ══════════════ Support / Utility ══════════════
    npc_dota_hero_crystal_maiden     = {"magic_burst","disable","slow","mana"},
    npc_dota_hero_dazzle             = {"heal","save","armor"},
    npc_dota_hero_oracle             = {"heal","save","purge","magic_burst"},
    npc_dota_hero_omniknight         = {"heal","save","magic_immune","tanky"},
    npc_dota_hero_abaddon            = {"heal","save","purge","tanky"},
    npc_dota_hero_chen               = {"heal","push","summons","global"},
    npc_dota_hero_enchantress        = {"heal","slow","summons","pure_dmg"},
    npc_dota_hero_wisp               = {"heal","save","global","tether"},
    npc_dota_hero_witch_doctor       = {"heal","stun","magic_burst"},
    npc_dota_hero_warlock            = {"heal","disable","summons","magic_burst"},
    npc_dota_hero_jakiro             = {"magic_burst","push","slow","disable"},
    npc_dota_hero_disruptor          = {"disable","silence","magic_burst"},
    npc_dota_hero_winter_wyvern      = {"disable","save","magic_burst","slow"},
    npc_dota_hero_shadow_demon       = {"disable","purge","save","illusions"},
    npc_dota_hero_grimstroke         = {"disable","magic_burst","silence"},
    npc_dota_hero_snapfire           = {"disable","magic_burst","stun"},
    npc_dota_hero_marci              = {"disable","phys_burst","mobility","save"},
    npc_dota_hero_bounty_hunter      = {"invis","track","phys_burst","slow"},
    npc_dota_hero_keeper_of_the_light = {"magic_burst","heal","mana","push"},
    npc_dota_hero_dawnbreaker        = {"heal","stun","global","phys_dps"},

    -- ══════════════ Tanky / Initiators ══════════════
    npc_dota_hero_bristleback        = {"tanky","phys_dps","slow"},
    npc_dota_hero_dragon_knight      = {"tanky","stun","push"},
    npc_dota_hero_abyssal_underlord  = {"tanky","magic_burst","global","aura"},
    npc_dota_hero_night_stalker      = {"tanky","silence","phys_dps","vision"},
    npc_dota_hero_undying            = {"tanky","heal","slow","summons"},
    npc_dota_hero_ogre_magi          = {"tanky","stun","buff","magic_burst"},
    npc_dota_hero_treant             = {"tanky","heal","invis","global"},
    npc_dota_hero_pudge              = {"tanky","pure_dmg","disable"},

    -- ══════════════ Misc / Multi-role ══════════════
    npc_dota_hero_meepo              = {"carry","disable","magic_burst","summons"},
    npc_dota_hero_broodmother        = {"carry","push","summons","invis"},
    npc_dota_hero_visage             = {"magic_burst","summons","phys_dps"},
    npc_dota_hero_techies            = {"magic_burst","disable","mines"},
    npc_dota_hero_furion             = {"push","global","summons","phys_dps"},
    npc_dota_hero_vengefulspirit     = {"stun","save","armor_reduce","phys_dps"},
    npc_dota_hero_rubick             = {"disable","magic_burst","steal"},
    npc_dota_hero_silencer           = {"silence","magic_burst","global","mana_burn"},
    npc_dota_hero_ancient_apparition = {"magic_burst","global","anti_heal"},
    npc_dota_hero_lich               = {"magic_burst","slow","save"},
    npc_dota_hero_windrunner         = {"phys_dps","disable","evasion","magic_burst"},
    npc_dota_hero_mirana             = {"magic_burst","stun","invis","mobility"},
    npc_dota_hero_pangolier          = {"disable","phys_dps","mobility","evasion"},
    npc_dota_hero_dark_seer          = {"tanky","illusions","mobility","aura"},
    npc_dota_hero_earth_spirit       = {"disable","silence","magic_burst","mobility"},
    npc_dota_hero_kunkka             = {"phys_burst","disable","cleave"},
    npc_dota_hero_tiny               = {"phys_burst","stun","push","tanky"},
    npc_dota_hero_kez                = {"carry","phys_burst","mobility","invis"},
    npc_dota_hero_largo              = {"disable","magic_burst","tanky"},
}

--------------------------------------------------------------------------------
-- HERO ROLE SYSTEM (for hero-aware item scoring)
-- role: "carry", "mid", "offlane", "support", "hardsupport"
-- style: "phys" = physical DPS, "magic" = caster, "hybrid", "utility"
-- Items tagged with excluded_roles get heavy penalty when you play that role.
-- Items tagged with preferred_styles get bonus when hero matches.
--------------------------------------------------------------------------------
local HERO_ROLES = {
    -- ══════════ Carry (Pos 1) ══════════
    npc_dota_hero_antimage           = {role="carry",  style="phys"},
    npc_dota_hero_phantom_assassin   = {role="carry",  style="phys"},
    npc_dota_hero_juggernaut         = {role="carry",  style="phys"},
    npc_dota_hero_faceless_void      = {role="carry",  style="phys"},
    npc_dota_hero_terrorblade        = {role="carry",  style="phys"},
    npc_dota_hero_spectre            = {role="carry",  style="phys"},
    npc_dota_hero_phantom_lancer     = {role="carry",  style="phys"},
    npc_dota_hero_medusa             = {role="carry",  style="phys"},
    npc_dota_hero_troll_warlord      = {role="carry",  style="phys"},
    npc_dota_hero_ursa               = {role="carry",  style="phys"},
    npc_dota_hero_sven               = {role="carry",  style="phys"},
    npc_dota_hero_life_stealer       = {role="carry",  style="phys"},
    npc_dota_hero_slark              = {role="carry",  style="phys"},
    npc_dota_hero_monkey_king        = {role="carry",  style="phys"},
    npc_dota_hero_chaos_knight       = {role="carry",  style="phys"},
    npc_dota_hero_luna               = {role="carry",  style="phys"},
    npc_dota_hero_drow_ranger        = {role="carry",  style="phys"},
    npc_dota_hero_morphling          = {role="carry",  style="hybrid"},
    npc_dota_hero_naga_siren         = {role="carry",  style="phys"},
    npc_dota_hero_weaver             = {role="carry",  style="phys"},
    npc_dota_hero_riki               = {role="carry",  style="phys"},
    npc_dota_hero_clinkz             = {role="carry",  style="phys"},
    npc_dota_hero_sniper             = {role="carry",  style="phys"},
    npc_dota_hero_templar_assassin   = {role="carry",  style="phys"},
    npc_dota_hero_bloodseeker        = {role="carry",  style="phys"},
    npc_dota_hero_lycan              = {role="carry",  style="phys"},
    npc_dota_hero_huskar             = {role="carry",  style="phys"},
    npc_dota_hero_alchemist          = {role="carry",  style="phys"},
    npc_dota_hero_skeleton_king      = {role="carry",  style="phys"},
    npc_dota_hero_arc_warden         = {role="carry",  style="phys"},
    npc_dota_hero_lone_druid         = {role="carry",  style="phys"},
    npc_dota_hero_gyrocopter         = {role="carry",  style="hybrid"},
    npc_dota_hero_nevermore          = {role="carry",  style="hybrid"},
    npc_dota_hero_razor              = {role="carry",  style="hybrid"},
    npc_dota_hero_viper              = {role="carry",  style="hybrid"},
    npc_dota_hero_meepo              = {role="carry",  style="hybrid"},
    npc_dota_hero_broodmother        = {role="carry",  style="phys"},
    npc_dota_hero_kez                = {role="carry",  style="phys"},
    -- ══════════ Mid (Pos 2) ══════════
    npc_dota_hero_invoker            = {role="mid",    style="magic"},
    npc_dota_hero_storm_spirit       = {role="mid",    style="magic"},
    npc_dota_hero_ember_spirit       = {role="mid",    style="magic"},
    npc_dota_hero_lina               = {role="mid",    style="magic"},
    npc_dota_hero_zuus               = {role="mid",    style="magic"},
    npc_dota_hero_tinker             = {role="mid",    style="magic"},
    npc_dota_hero_queenofpain        = {role="mid",    style="magic"},
    npc_dota_hero_puck               = {role="mid",    style="magic"},
    npc_dota_hero_void_spirit        = {role="mid",    style="magic"},
    npc_dota_hero_leshrac            = {role="mid",    style="magic"},
    npc_dota_hero_death_prophet      = {role="mid",    style="magic"},
    npc_dota_hero_obsidian_destroyer = {role="mid",    style="magic"},
    npc_dota_hero_skywrath_mage      = {role="mid",    style="magic"},
    npc_dota_hero_muerta             = {role="mid",    style="hybrid"},
    npc_dota_hero_windrunner         = {role="mid",    style="hybrid"},
    -- ══════════ Offlane (Pos 3) ══════════
    npc_dota_hero_axe                = {role="offlane",style="utility"},
    npc_dota_hero_tidehunter         = {role="offlane",style="utility"},
    npc_dota_hero_bristleback        = {role="offlane",style="phys"},
    npc_dota_hero_centaur            = {role="offlane",style="utility"},
    npc_dota_hero_mars               = {role="offlane",style="utility"},
    npc_dota_hero_legion_commander   = {role="offlane",style="phys"},
    npc_dota_hero_doom_bringer       = {role="offlane",style="utility"},
    npc_dota_hero_sand_king          = {role="offlane",style="magic"},
    npc_dota_hero_slardar            = {role="offlane",style="utility"},
    npc_dota_hero_magnataur          = {role="offlane",style="utility"},
    npc_dota_hero_night_stalker      = {role="offlane",style="phys"},
    npc_dota_hero_primal_beast       = {role="offlane",style="utility"},
    npc_dota_hero_dragon_knight      = {role="offlane",style="hybrid"},
    npc_dota_hero_abyssal_underlord  = {role="offlane",style="utility"},
    npc_dota_hero_batrider           = {role="offlane",style="magic"},
    npc_dota_hero_brewmaster         = {role="offlane",style="utility"},
    npc_dota_hero_spirit_breaker     = {role="offlane",style="utility"},
    npc_dota_hero_dark_seer          = {role="offlane",style="utility"},
    npc_dota_hero_necrolyte          = {role="offlane",style="magic"},
    npc_dota_hero_undying            = {role="offlane",style="utility"},
    npc_dota_hero_pangolier          = {role="offlane",style="hybrid"},
    npc_dota_hero_earth_spirit       = {role="offlane",style="utility"},
    npc_dota_hero_pudge              = {role="offlane",style="utility"},
    npc_dota_hero_rattletrap         = {role="offlane",style="utility"},
    npc_dota_hero_shredder           = {role="offlane",style="magic"},
    npc_dota_hero_elder_titan        = {role="offlane",style="utility"},
    npc_dota_hero_phoenix            = {role="offlane",style="magic"},
    npc_dota_hero_ringmaster         = {role="offlane",style="magic"},
    npc_dota_hero_largo              = {role="offlane",style="magic"},
    npc_dota_hero_kunkka             = {role="offlane",style="hybrid"},
    npc_dota_hero_tiny               = {role="offlane",style="hybrid"},
    npc_dota_hero_beastmaster        = {role="offlane",style="utility"},
    -- ══════════ Support (Pos 4) ══════════
    npc_dota_hero_earthshaker        = {role="support",style="utility"},
    npc_dota_hero_tusk               = {role="support",style="utility"},
    npc_dota_hero_bounty_hunter      = {role="support",style="utility"},
    npc_dota_hero_nyx_assassin       = {role="support",style="utility"},
    npc_dota_hero_rubick             = {role="support",style="magic"},
    npc_dota_hero_mirana             = {role="support",style="magic"},
    npc_dota_hero_dark_willow        = {role="support",style="magic"},
    npc_dota_hero_hoodwink           = {role="support",style="magic"},
    npc_dota_hero_grimstroke         = {role="support",style="magic"},
    npc_dota_hero_snapfire           = {role="support",style="utility"},
    npc_dota_hero_marci              = {role="support",style="utility"},
    npc_dota_hero_vengefulspirit     = {role="support",style="utility"},
    npc_dota_hero_pugna              = {role="support",style="magic"},
    npc_dota_hero_disruptor          = {role="support",style="magic"},
    npc_dota_hero_shadow_demon       = {role="support",style="magic"},
    npc_dota_hero_furion             = {role="support",style="hybrid"},
    npc_dota_hero_techies            = {role="support",style="magic"},
    npc_dota_hero_jakiro             = {role="support",style="magic"},
    npc_dota_hero_silencer           = {role="support",style="magic"},
    npc_dota_hero_venomancer         = {role="support",style="magic"},
    npc_dota_hero_visage             = {role="support",style="hybrid"},
    -- ══════════ Hard Support (Pos 5) ══════════
    npc_dota_hero_crystal_maiden     = {role="hardsupport",style="magic"},
    npc_dota_hero_dazzle             = {role="hardsupport",style="utility"},
    npc_dota_hero_oracle             = {role="hardsupport",style="utility"},
    npc_dota_hero_omniknight         = {role="hardsupport",style="utility"},
    npc_dota_hero_abaddon            = {role="hardsupport",style="utility"},
    npc_dota_hero_chen               = {role="hardsupport",style="utility"},
    npc_dota_hero_enchantress        = {role="hardsupport",style="utility"},
    npc_dota_hero_wisp               = {role="hardsupport",style="utility"},
    npc_dota_hero_witch_doctor       = {role="hardsupport",style="magic"},
    npc_dota_hero_warlock            = {role="hardsupport",style="magic"},
    npc_dota_hero_winter_wyvern      = {role="hardsupport",style="magic"},
    npc_dota_hero_lich               = {role="hardsupport",style="magic"},
    npc_dota_hero_lion               = {role="hardsupport",style="magic"},
    npc_dota_hero_shadow_shaman      = {role="hardsupport",style="magic"},
    npc_dota_hero_bane               = {role="hardsupport",style="utility"},
    npc_dota_hero_enigma             = {role="hardsupport",style="utility"},
    npc_dota_hero_keeper_of_the_light = {role="hardsupport",style="magic"},
    npc_dota_hero_ogre_magi          = {role="hardsupport",style="utility"},
    npc_dota_hero_treant             = {role="hardsupport",style="utility"},
    npc_dota_hero_dawnbreaker        = {role="hardsupport",style="utility"},
    npc_dota_hero_ancient_apparition = {role="hardsupport",style="magic"},
}

-- Items that are BAD for certain roles (heavy score penalty).
-- carry/mid with "phys" style shouldn't buy support/utility items that waste a slot.
-- support/hardsupport shouldn't buy expensive DPS items.
local ITEM_ROLE_PENALTY = {
    -- Support/utility items bad for phys carries (slot waste)
    item_pavise          = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_mekansm         = {bad_roles={"carry","mid"}},
    item_guardian_greaves = {bad_roles={"carry","mid"}},
    item_holy_locket     = {bad_roles={"carry","mid"}},
    item_glimmer_cape    = {bad_roles={"carry"}},
    item_force_staff     = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_medallion_of_courage = {bad_roles={"carry","mid"}},
    item_solar_crest     = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_rod_of_atos     = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_veil_of_discord = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_arcane_boots    = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_pipe            = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_crimson_guard   = {bad_roles={"carry","mid"}, bad_styles={"magic"}},
    item_spirit_vessel   = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_cyclone         = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_ghost           = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_lotus_orb       = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_blade_mail      = {bad_styles={"magic"}},
    -- Expensive DPS items bad for hard supports
    item_daedalus        = {bad_roles={"hardsupport","support"}},
    item_butterfly       = {bad_roles={"hardsupport","support"}},
    item_satanic         = {bad_roles={"hardsupport","support"}},
    item_battlefury      = {bad_roles={"hardsupport","support"}, bad_styles={"magic"}},
    item_desolator       = {bad_roles={"hardsupport","support"}},
    item_mjollnir        = {bad_roles={"hardsupport"}},
    item_skadi           = {bad_roles={"hardsupport"}},
    item_abyssal_blade   = {bad_roles={"hardsupport","support"}},
    item_nullifier       = {bad_roles={"hardsupport","support"}},
    item_bloodthorn      = {bad_roles={"hardsupport"}},
    item_silver_edge     = {bad_roles={"hardsupport"}},
    item_diffusal_blade  = {bad_roles={"hardsupport"}, bad_styles={"magic"}},
    item_monkey_king_bar = {bad_roles={"hardsupport","support"}},
    item_radiance        = {bad_roles={"hardsupport","support"}},
    item_refresher       = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_hand_of_midas   = {bad_roles={"hardsupport","support"}},
    item_harpoon         = {bad_roles={"hardsupport","support"}},
    item_heart           = {bad_roles={"hardsupport","support"}},
    item_overwhelming_blink = {bad_roles={"hardsupport","support"}},
    item_swift_blink     = {bad_roles={"hardsupport","support"}, bad_styles={"magic"}},
    item_arcane_blink    = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_dagon           = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_ethereal_blade  = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_vanguard        = {bad_roles={"carry"}, bad_styles={"magic"}},
    item_bloodstone      = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_octarine_core   = {bad_roles={"carry"}, bad_styles={"phys"}},
    item_kaya_and_sange  = {bad_styles={"phys"}},
    item_yasha_and_kaya  = {bad_styles={"phys"}},
    item_witch_blade     = {bad_roles={"hardsupport"}},
    item_phylactery      = {bad_roles={"carry"}, bad_styles={"phys"}},
}

--------------------------------------------------------------------------------
-- HERO COUNTER ITEMS (предметы против конкретных героев)
--------------------------------------------------------------------------------
local HERO_COUNTERS = {
    -- Anti-escape / Anti-invis
    npc_dota_hero_spectre = {
        items = {"item_spirit_vessel", "item_heavens_halberd", "item_nullifier", "item_radiance"},
        reason = "Anti-heal + disarm vs low HP"
    },
    npc_dota_hero_medusa = {
        items = {"item_nullifier", "item_silver_edge", "item_abyssal_blade"},
        reason = "Break + disable vs mana shield"
    },
    npc_dota_hero_bristleback = {
        items = {"item_silver_edge", "item_abyssal_blade", "item_heavens_halberd"},
        reason = "Break passive + disarm"
    },
    npc_dota_hero_phantom_assassin = {
        items = {"item_monkey_king_bar", "item_heavens_halberd", "item_spirit_vessel"},
        reason = "True strike + disarm + anti-heal"
    },
    npc_dota_hero_juggernaut = {
        items = {"item_heavens_halberd", "item_abyssal_blade", "item_spirit_vessel"},
        reason = "Disarm vs omnislash + anti-heal"
    },
    npc_dota_hero_faceless_void = {
        items = {"item_aeon_disk", "item_sphere", "item_heavens_halberd"},
        reason = "Save from chrono + disarm"
    },
    npc_dota_hero_terrorblade = {
        items = {"item_spirit_vessel", "item_heavens_halberd", "item_nullifier"},
        reason = "Anti-heal + disarm vs illusions"
    },
    npc_dota_hero_slark = {
        items = {"item_heavens_halberd", "item_nullifier", "item_spirit_vessel"},
        reason = "Disarm + anti-heal vs agility steal"
    },
    npc_dota_hero_weaver = {
        items = {"item_nullifier", "item_spirit_vessel", "item_heavens_halberd"},
        reason = "Prevent escape + anti-heal"
    },
    npc_dota_hero_antimage = {
        items = {"item_nullifier", "item_heavens_halberd", "item_spirit_vessel"},
        reason = "Prevent blink escape + anti-heal"
    },
    -- Anti-blink / Anti-initiation
    npc_dota_hero_magnataur = {
        items = {"item_sphere", "item_aeon_disk", "item_heavens_halberd"},
        reason = "Block RP + disarm after"
    },
    npc_dota_hero_tidehunter = {
        items = {"item_sphere", "item_aeon_disk", "item_heavens_halberd"},
        reason = "Block ravage + disarm"
    },
    npc_dota_hero_enigma = {
        items = {"item_sphere", "item_aeon_disk", "item_nullifier"},
        reason = "Block black hole + purge"
    },
    npc_dota_hero_legion_commander = {
        items = {"item_sphere", "item_heavens_halberd", "item_spirit_vessel"},
        reason = "Block duel + disarm"
    },
    npc_dota_hero_axe = {
        items = {"item_heavens_halberd", "item_spirit_vessel", "item_blade_mail"},
        reason = "Disarm + anti-heal vs counter helix"
    },
    -- Anti-summon / Anti-illusions
    npc_dota_hero_phantom_lancer = {
        items = {"item_mjollnir", "item_radiance", "item_abyssal_blade"},
        reason = "AOE clear + bash vs illusions"
    },
    npc_dota_hero_naga_siren = {
        items = {"item_mjollnir", "item_radiance", "item_nullifier"},
        reason = "AOE vs illusions + purge"
    },
    npc_dota_hero_chaos_knight = {
        items = {"item_mjollnir", "item_heavens_halberd", "item_abyssal_blade"},
        reason = "AOE + disarm vs illusions"
    },
    npc_dota_hero_lycan = {
        items = {"item_mjollnir", "item_heavens_halberd", "item_assault"},
        reason = "AOE + armor vs wolves"
    },
    npc_dota_hero_broodmother = {
        items = {"item_mjollnir", "item_radiance", "item_nullifier"},
        reason = "AOE clear + purge spiders"
    },
    npc_dota_hero_furion = {
        items = {"item_mjollnir", "item_radiance", "item_assault"},
        reason = "AOE vs treants"
    },
    npc_dota_hero_warlock = {
        items = {"item_spirit_vessel", "item_mjollnir", "item_heavens_halberd"},
        reason = "Anti-heal + AOE vs golem"
    },
    npc_dota_hero_beastmaster = {
        items = {"item_mjollnir", "item_heavens_halberd", "item_assault"},
        reason = "AOE + armor vs hawk + boar"
    },
    -- Anti-magic burst
    npc_dota_hero_lina = {
        items = {"item_pipe", "item_black_king_bar", "item_sphere"},
        reason = "Magic defense + spell block"
    },
    npc_dota_hero_zuus = {
        items = {"item_pipe", "item_black_king_bar", "item_sphere"},
        reason = "Magic defense vs global ult"
    },
    npc_dota_hero_invoker = {
        items = {"item_black_king_bar", "item_sphere", "item_nullifier"},
        reason = "Magic immunity + purge"
    },
    npc_dota_hero_lion = {
        items = {"item_sphere", "item_aeon_disk", "item_black_king_bar"},
        reason = "Block hex + finger"
    },
    npc_dota_hero_shadow_shaman = {
        items = {"item_sphere", "item_aeon_disk", "item_black_king_bar"},
        reason = "Block hex + shackles"
    },
    npc_dota_hero_skywrath_mage = {
        items = {"item_pipe", "item_black_king_bar", "item_sphere"},
        reason = "Magic defense vs ult"
    },
    -- Anti-sustain
    npc_dota_hero_dragon_knight = {
        items = {"item_spirit_vessel", "item_heavens_halberd", "item_assault"},
        reason = "Anti-heal + armor reduction"
    },
    npc_dota_hero_alchemist = {
        items = {"item_spirit_vessel", "item_heavens_halberd", "item_nullifier"},
        reason = "Anti-heal + disarm"
    },
    npc_dota_hero_huskar = {
        items = {"item_spirit_vessel", "item_heavens_halberd", "item_nullifier"},
        reason = "Anti-heal + disarm"
    },
    npc_dota_hero_necrolyte = {
        items = {"item_spirit_vessel", "item_heavens_halberd", "item_nullifier"},
        reason = "Anti-heal + purge"
    },
    npc_dota_hero_omniknight = {
        items = {"item_spirit_vessel", "item_nullifier", "item_silver_edge"},
        reason = "Anti-heal + break"
    },
    npc_dota_hero_chen = {
        items = {"item_spirit_vessel", "item_mjollnir", "item_nullifier"},
        reason = "Anti-heal + AOE vs creeps"
    },
    npc_dota_hero_dazzle = {
        items = {"item_spirit_vessel", "item_nullifier", "item_silver_edge"},
        reason = "Anti-heal + break vs save"
    },
    npc_dota_hero_witch_doctor = {
        items = {"item_spirit_vessel", "item_black_king_bar", "item_sphere"},
        reason = "Anti-heal + magic immunity"
    },
    -- Anti-carry late game
    npc_dota_hero_sven = {
        items = {"item_heavens_halberd", "item_assault", "item_spirit_vessel"},
        reason = "Disarm + armor vs god strength"
    },
    npc_dota_hero_troll_warlord = {
        items = {"item_heavens_halberd", "item_spirit_vessel", "item_nullifier"},
        reason = "Disarm + anti-heal"
    },
    npc_dota_hero_ursa = {
        items = {"item_heavens_halberd", "item_spirit_vessel", "item_blade_mail"},
        reason = "Disarm + reflect fury swipes"
    },
    npc_dota_hero_luna = {
        items = {"item_heavens_halberd", "item_assault", "item_black_king_bar"},
        reason = "Disarm + armor vs glaives"
    },
    npc_dota_hero_sniper = {
        items = {"item_blink", "item_black_king_bar", "item_nullifier"},
        reason = "Gap close + magic immunity"
    },
    npc_dota_hero_drow_ranger = {
        items = {"item_blink", "item_black_king_bar", "item_heavens_halberd"},
        reason = "Gap close + disarm"
    },
}

--------------------------------------------------------------------------------
-- ITEM DATABASE (partial for net worth calculation)
--------------------------------------------------------------------------------
local ITEM_COSTS = {
    -- Boots
    item_boots = 500, item_phase_boots = 1500, item_power_treads = 1400,
    item_arcane_boots = 1300, item_travel_boots = 2500, item_travel_boots_2 = 2000,
    item_boots_of_bearing = 4125,
    -- Basic items
    item_magic_wand = 450, item_magic_stick = 200, item_bracer = 505,
    item_wraith_band = 505, item_null_talisman = 505, item_belt_of_strength = 450,
    item_boots_of_elves = 450, item_robe = 450, item_circlet = 155, item_crown = 450,
    item_ogre_axe = 1000, item_blade_of_alacrity = 1000, item_staff_of_wizardry = 1000,
    -- Weapons
    item_broadsword = 1000, item_claymore = 1350, item_mithril_hammer = 1600,
    item_blades_of_attack = 450, item_quarterstaff = 875, item_javelin = 900,
    item_blight_stone = 300, item_orb_of_venom = 275,
    -- Armor
    item_chainmail = 550, item_platemail = 1400, item_helm_of_iron_will = 975,
    item_ring_of_protection = 175, item_buckler = 200, item_vanguard = 1700,
    item_crimson_guard = 3600, item_assault = 5125, item_shivas_guard = 5175,
    -- Accessories
    item_blink = 2250, item_force_staff = 2200, item_ultimate_scepter = 4200,
    item_aghanims_shard = 1400, item_black_king_bar = 4050, item_sphere = 4600,
    item_aeon_disk = 3000, item_lotus_orb = 3850, item_linkens = 4600,
    -- Damage
    item_daedalus = 5150, item_demon_edge = 2200, item_eagle = 2800, item_reaver = 2800,
    item_mystic_staff = 2700, item_hyperstone = 2000, item_talisman_of_evasion = 1300,
    item_relic = 3800, item_sacred_relic = 3800,
    -- Specific items
    item_mjollnir = 5600, item_radiance = 5150, item_heart = 5000, item_tarrasque = 5000,
    item_butterfly = 4975, item_satanic = 5050, item_skadi = 5300, item_eye_of_skadi = 5300,
    item_abyssal_blade = 6250, item_nullifier = 4725, item_bloodthorn = 6800,
    item_silver_edge = 5450, item_diffusal_blade = 2500, item_diffusal_blade_2 = 2500,
    item_sheepstick = 5675, item_scythe_of_vyse = 5675, item_gungir = 5500, item_gleipnir = 5500,
    item_pipe = 3475, item_crimson_guard = 3600, item_heavens_halberd = 3550,
    item_solar_crest = 2625, item_manta = 4600, item_disperser = 5300,
    item_cyclone = 2725, item_euls = 2725, item_wind_waker = 5150,
    item_desolator = 3500, item_monkey_king_bar = 4975, item_spirit_vessel = 2980,
    item_urnd = 2980, item_guardian_greaves = 4950, item_refresher = 5000,
    item_refresher_orb = 5000, item_overwhelming_blink = 6800, item_swift_blink = 6800,
    item_arcane_blink = 6800, item_hurricane_pike = 4450, item_orchid = 3475,
    item_orchid_malevolence = 3475, item_ethereal_blade = 4650, item_rod_of_atos = 2750,
    item_pavise = 1100, item_holy_locket = 2350, item_witch_blade = 2600,
    item_veil_of_discord = 1525, item_kaya_and_sange = 4100, item_sange_and_yasha = 4100,
    item_yasha_and_kaya = 4100, item_invis_sword = 3000, item_shadow_blade = 3000,
    item_bloodstone = 4600, item_octarine_core = 5275, item_phylactery = 2400,
    item_hand_of_midas = 2200, item_harpoon = 4700, item_dagon = 2850,
    item_necronomicon = 2400, item_medallion = 1025, item_solar = 2625,
    item_vladmir = 2450, item_vladmirs_offering = 2450, item_mekansm = 1775,
    item_tranquil_boots = 925, item_glimmer = 1950, item_glimmer_cape = 1950,
    item_aether_lens = 2275, item_drum = 1650, item_headdress = 600,
    item_buckler = 200, item_ring_of_basilius = 425, item_basilius = 425,
}

-- Function to get item cost from database
local function GetItemCost(itemName)
    if not itemName then return 0 end
    -- Try our cost database first
    local cost = ITEM_COSTS[itemName]
    if cost then return cost end
    return 0
end

--------------------------------------------------------------------------------
-- GAME-PHASE DETECTION
--------------------------------------------------------------------------------
local PHASE_EARLY = 1
local PHASE_MID   = 2
local PHASE_LATE  = 3

--------------------------------------------------------------------------------
-- ITEM DATABASE
--------------------------------------------------------------------------------
local ITEM_DB = {
    -- ═══════════════════════ EARLY GAME ═══════════════════════
    {name="item_magic_wand",     display="Magic Wand",       cost=450,   phase={1,2},     tags={"sustain","vs_spam"}},
    {name="item_bracer",         display="Bracer",            cost=505,   phase={1},       tags={"hp","phys_def"}},
    {name="item_wraith_band",    display="Wraith Band",       cost=505,   phase={1},       tags={"agi","phys_dps"}},
    {name="item_null_talisman",  display="Null Talisman",     cost=505,   phase={1},       tags={"int","magic_dps"}},
    -- Boots
    {name="item_phase_boots",    display="Phase Boots",       cost=1500,  phase={1,2},     tags={"mobility","phys_dps","armor"}},
    {name="item_power_treads",   display="Power Treads",      cost=1400,  phase={1,2},     tags={"attack_speed","stats","sustain"}},
    {name="item_arcane_boots",   display="Arcane Boots",      cost=1300,  phase={1,2},     tags={"mana","team_utility"}},
    {name="item_boots_of_bearing",display="Boots of Bearing", cost=4125,  phase={2,3},     tags={"aura","team_utility","attack_speed"}},
    {name="item_travel_boots",   display="Boots of Travel",   cost=2500,  phase={2,3},     tags={"mobility","push","global"}},
    -- ═══════════════════════ CORE / MID GAME ══════════════════
    -- Physical defense
    {name="item_ghost",          display="Ghost Scepter",    cost=1500,   phase={1,2},     tags={"vs_phys","save"}},
    {name="item_blade_mail",     display="Blade Mail",       cost=2100,   phase={1,2},     tags={"vs_phys","vs_burst","armor","reflect"},
     triggers={"carry","phys_burst","phys_dps"}},
    {name="item_vanguard",       display="Vanguard",         cost=1700,   phase={1,2},     tags={"hp","block","tanky"}},
    {name="item_pavise",         display="Pavise",           cost=1100,   phase={1,2},     tags={"vs_phys","save","armor"},
     triggers={"phys_dps","phys_burst"}},
    {name="item_crimson_guard",  display="Crimson Guard",    cost=3600,   phase={2,3},     tags={"vs_phys","team","block","armor"},
     triggers={"phys_dps","summons","illusions","push"}},
    {name="item_assault",        display="Assault Cuirass",  cost=5125,   phase={2,3},     tags={"armor","attack_speed","aura","vs_phys"},
     triggers={"phys_dps","carry","armor_reduce"}},
    {name="item_shivas_guard",   display="Shiva's Guard",    cost=5175,   phase={2,3},     tags={"armor","vs_phys","slow","int"},
     triggers={"phys_dps","carry","heal","attack_speed"}},
    {name="item_heavens_halberd",display="Heaven's Halberd", cost=3550,   phase={2,3},     tags={"vs_phys","disarm","evasion","hp"},
     triggers={"carry","phys_dps","phys_burst"}},
    {name="item_solar_crest",    display="Solar Crest",      cost=2625,   phase={1,2},     tags={"armor","vs_phys","buff","debuff"}},
    -- Magical defense
    {name="item_pipe",           display="Pipe of Insight",  cost=3475,   phase={2,3},     tags={"vs_magic","team","magic_resist","barrier"},
     triggers={"magic_burst"}},
    {name="item_glimmer_cape",   display="Glimmer Cape",     cost=1950,   phase={1,2},     tags={"vs_magic","save","invis"},
     triggers={"magic_burst","disable"}},
    {name="item_black_king_bar", display="BKB",              cost=4050,   phase={2,3},     tags={"vs_magic","magic_immune","vs_disable"},
     triggers={"disable","stun","silence","hex","magic_burst","doom"}},
    -- Anti-heal
    {name="item_spirit_vessel",  display="Spirit Vessel",    cost=2980,   phase={1,2},     tags={"anti_heal","hp","move_speed"},
     triggers={"heal","save","tanky"}},
    -- Anti-evasion
    {name="item_monkey_king_bar",display="MKB",              cost=4975,   phase={2,3},     tags={"vs_evasion","phys_dps","attack"},
     triggers={"evasion"}},
    -- Anti-invis
    {name="item_dust",           display="Dust of Appearance",cost=80,    phase={1,2,3},   tags={"vs_invis","detection"},
     triggers={"invis"}},
    {name="item_ward_sentry",    display="Sentry Ward",      cost=50,     phase={1,2,3},   tags={"vs_invis","detection"},
     triggers={"invis"}},
    -- Anti-illusions & summons
    {name="item_mjollnir",       display="Mjollnir",         cost=5600,   phase={2,3},     tags={"vs_illusions","attack_speed","phys_dps","cleave"},
     triggers={"illusions","summons","push"}},
    {name="item_battlefury",     display="Battle Fury",      cost=4100,   phase={1,2},     tags={"vs_illusions","cleave","farm","phys_dps"},
     triggers={"illusions","summons"}},
    {name="item_radiance",       display="Radiance",         cost=5150,   phase={2,3},     tags={"vs_illusions","burn","miss","farm"},
     triggers={"illusions","summons","invis"}},
    {name="item_maelstrom",      display="Maelstrom",        cost=2700,   phase={1,2},     tags={"vs_illusions","attack_speed","farm"},
     triggers={"illusions","summons"}},
    {name="item_gungir",         display="Gleipnir",         cost=5500,   phase={2,3},     tags={"root","vs_illusions","attack_speed","phys_dps"},
     triggers={"mobility","illusions","invis"}},
    -- Mobility
    {name="item_blink",          display="Blink Dagger",     cost=2250,   phase={1,2,3},   tags={"mobility","initiation"}},
    {name="item_force_staff",    display="Force Staff",      cost=2200,   phase={1,2},     tags={"mobility","save","vs_slow"},
     triggers={"slow","root"}},
    {name="item_hurricane_pike", display="Hurricane Pike",   cost=4450,   phase={2,3},     tags={"mobility","save","vs_melee","ranged"}},
    {name="item_harpoon",        display="Harpoon",          cost=4700,   phase={2,3},     tags={"initiation","gap_close","stats"}},
    -- Dispel / Purge
    {name="item_lotus_orb",      display="Lotus Orb",        cost=3850,   phase={2,3},     tags={"dispel","reflect","armor","mana"},
     triggers={"disable","stun","hex","silence","doom"}},
    {name="item_manta",          display="Manta Style",      cost=4600,   phase={2,3},     tags={"dispel","illusions","stats","phys_dps"},
     triggers={"silence","slow","root"}},
    {name="item_disperser",      display="Disperser",        cost=5300,   phase={2,3},     tags={"dispel","mobility","agi","slow"},
     triggers={"silence","slow","root","disable"}},
    {name="item_cyclone",        display="Eul's Scepter",    cost=2725,   phase={1,2},     tags={"dispel","mana","mobility","disable"},
     triggers={"silence","slow","disable"}},
    -- Protection
    {name="item_sphere",         display="Linken's Sphere",  cost=4600,   phase={2,3},     tags={"block_spell","save","stats"},
     triggers={"disable","hex","doom","duel","black_hole"}},
    {name="item_aeon_disk",      display="Aeon Disk",        cost=3000,   phase={2,3},     tags={"save","vs_burst","dispel"},
     triggers={"phys_burst","magic_burst","chrono","black_hole"}},
    {name="item_wind_waker",     display="Wind Waker",       cost=5150,   phase={2,3},     tags={"save","dispel","mobility","mana"},
     triggers={"disable","chrono","black_hole"}},
    -- Damage items
    {name="item_desolator",      display="Desolator",        cost=3500,   phase={2},       tags={"armor_reduce","phys_dps"}},
    {name="item_daedalus",       display="Daedalus",         cost=5150,   phase={2,3},     tags={"crit","phys_dps"}},
    {name="item_butterfly",      display="Butterfly",        cost=4975,   phase={3},       tags={"evasion","attack_speed","agi","phys_dps"}},
    {name="item_satanic",        display="Satanic",          cost=5050,   phase={3},       tags={"lifesteal","hp","save","phys_dps"}},
    {name="item_skadi",          display="Eye of Skadi",     cost=5300,   phase={3},       tags={"slow","stats","hp","anti_heal"},
     triggers={"heal","tanky","mobility"}},
    {name="item_abyssal_blade",  display="Abyssal Blade",    cost=6250,   phase={3},       tags={"stun","bash","vs_bkb","phys_dps","block"},
     triggers={"magic_immune","carry"}},
    {name="item_nullifier",      display="Nullifier",        cost=4725,   phase={3},       tags={"dispel","vs_save","phys_dps"},
     triggers={"save","invis","evasion"}},
    {name="item_bloodthorn",     display="Bloodthorn",       cost=6800,   phase={3},       tags={"silence","crit","vs_evasion","attack_speed"},
     triggers={"evasion","mobility","magic_burst"}},
    {name="item_silver_edge",    display="Silver Edge",      cost=5450,   phase={2,3},     tags={"invis","break","phys_dps"},
     triggers={"tanky","evasion"}},
    {name="item_diffusal_blade", display="Diffusal Blade",   cost=2500,   phase={1,2},     tags={"mana_burn","slow","agi","phys_dps"},
     triggers={"mana_burn"}},
    -- Utility / Mixed
    {name="item_rod_of_atos",    display="Rod of Atos",      cost=2750,   phase={1,2},     tags={"root","hp","int"},
     triggers={"mobility","invis"}},
    {name="item_orchid",         display="Orchid Malevolence",cost=3475,   phase={2},       tags={"silence","mana","attack_speed"},
     triggers={"magic_burst","mobility","versatile"}},
    {name="item_sheepstick",     display="Scythe of Vyse",    cost=5675,   phase={3},       tags={"hex","disable","mana","int"},
     triggers={"carry","magic_immune","mobility"}},
    {name="item_ethereal_blade", display="Ethereal Blade",   cost=4650,   phase={2,3},     tags={"vs_phys","magic_amp","save","agi"}},
    {name="item_refresher",      display="Refresher Orb",    cost=5000,   phase={3},       tags={"refresh","ultimate"}},
    {name="item_heart",          display="Heart of Tarrasque",cost=5000,  phase={3},       tags={"hp","tanky","regen"},
     triggers={"phys_dps","magic_burst"}},
    {name="item_overwhelming_blink", display="Overwhelming Blink", cost=6800, phase={3},   tags={"mobility","slow","str","initiation"}},
    {name="item_swift_blink",    display="Swift Blink",      cost=6800,   phase={3},       tags={"mobility","agi","attack_speed"}},
    {name="item_arcane_blink",   display="Arcane Blink",     cost=6800,   phase={3},       tags={"mobility","int","cd_reduction"}},
    {name="item_witch_blade",    display="Witch Blade",      cost=2600,   phase={1,2},     tags={"int","phys_dps","slow","armor"}},
    {name="item_veil_of_discord",display="Veil of Discord",  cost=1525,   phase={1,2},     tags={"magic_amp","int","armor"}},
    {name="item_kaya_and_sange", display="Kaya and Sange",   cost=4100,   phase={2,3},     tags={"hp","int","magic_amp","slow"}},
    {name="item_sange_and_yasha",display="Sange and Yasha",  cost=4100,   phase={2,3},     tags={"hp","agi","mobility","slow"}},
    {name="item_yasha_and_kaya", display="Yasha and Kaya",   cost=4100,   phase={2,3},     tags={"agi","int","magic_amp","mobility"}},
    {name="item_invis_sword",    display="Shadow Blade",     cost=3000,   phase={1,2},     tags={"invis","phys_dps","initiation"}},
    -- Support items
    {name="item_mekansm",        display="Mekansm",          cost=1775,   phase={1,2},     tags={"heal","team","armor"}},
    {name="item_guardian_greaves",display="Guardian Greaves", cost=4950,   phase={2,3},     tags={"heal","team","dispel","armor","mana"},
     triggers={"disable","silence"}},
    {name="item_medallion_of_courage", display="Medallion",  cost=1025,   phase={1},       tags={"armor","armor_reduce"}},
    {name="item_holy_locket",    display="Holy Locket",      cost=2350,   phase={1,2},     tags={"heal","hp","save"}},
    {name="item_ultimate_scepter",display="Aghanim's Scepter",cost=4200, phase={2,3},     tags={"ultimate","stats"}},
    {name="item_aghanims_shard", display="Aghanim's Shard",  cost=1400,  phase={2,3},     tags={"ultimate","ability"}},
    {name="item_bloodstone",     display="Bloodstone",       cost=4600,   phase={2,3},     tags={"hp","mana","spell_lifesteal","int"}},
    {name="item_dagon",          display="Dagon",            cost=2850,   phase={1,2},     tags={"magic_burst","int"}},
    {name="item_octarine_core",  display="Octarine Core",    cost=5275,   phase={3},       tags={"cd_reduction","hp","mana","int"}},
    {name="item_phylactery",     display="Phylactery",       cost=2400,   phase={1,2},     tags={"magic_burst","hp","int"}},
    {name="item_hand_of_midas",  display="Hand of Midas",    cost=2200,   phase={1},       tags={"farm","attack_speed"}},
}

--------------------------------------------------------------------------------
-- NEUTRAL ITEMS DATABASE (Updated for current patch - 2026)
-- Source: assets/data/neutral_items.json
--------------------------------------------------------------------------------
local NEUTRAL_DB = {
    -- Tier 1 (5:00+)
    {name="item_occult_bracelet",    display="Occult Bracelet",    tier=1, tags={"mana","int","magic_burst"}},
    {name="item_kobold_cup",         display="Kobold Cup",         tier=1, tags={"gold","farm","luck"}},
    {name="item_chipped_vest",       display="Chipped Vest",       tier=1, tags={"armor","reflect","vs_phys"}},
    {name="item_polliwog_charm",     display="Polliwog Charm",     tier=1, tags={"heal","mana","sustain"}},
    {name="item_dormant_curio",      display="Dormant Curio",      tier=1, tags={"stats","vision"}},
    {name="item_duelist_gloves",     display="Duelist Gloves",     tier=1, tags={"lifesteal","phys_dps","agi"}},
    {name="item_weighted_dice",      display="Weighted Dice",      tier=1, tags={"luck","gold","crit"}},
    {name="item_ash_legion_shield",  display="Ash Legion Shield",  tier=1, tags={"block","armor","vs_phys"}},
    -- Tier 2 (15:00+)
    {name="item_essence_ring",       display="Essence Ring",       tier=2, tags={"hp","mana","sustain"}},
    {name="item_mana_draught",       display="Mana Draught",       tier=2, tags={"mana","sustain","int"}},
    {name="item_poor_mans_shield",   display="Poor Man's Shield",  tier=2, tags={"block","vs_phys","agi"}},
    {name="item_searing_signet",     display="Searing Signet",     tier=2, tags={"burn","magic_amp","int"}},
    {name="item_pogo_stick",         display="Pogo Stick",         tier=2, tags={"mobility","initiation"}},
    {name="item_defiant_shell",      display="Defiant Shell",      tier=2, tags={"armor","save","vs_phys"}},
    -- Tier 3 (25:00+)
    {name="item_serrated_shiv",      display="Serrated Shiv",      tier=3, tags={"armor_reduce","phys_dps","bleed"}},
    {name="item_gunpowder_gauntlets",display="Gunpowder Gauntlets",tier=3, tags={"phys_burst","attack_speed","aoe"}},
    {name="item_whisper_of_the_dread", display="Whisper of the Dread", tier=3, tags={"silence","magic_burst","int"}},
    {name="item_jidi_pollen_bag",    display="Jidi Pollen Bag",    tier=3, tags={"slow","heal","mana"}},
    {name="item_psychic_headband",   display="Psychic Headband",   tier=3, tags={"int","mana","cd_reduction"}},
    {name="item_unrelenting_eye",    display="Unrelenting Eye",    tier=3, tags={"vision","attack_speed","true_strike"}},
    -- Tier 4 (35:00+)
    {name="item_crippling_crossbow", display="Crippling Crossbow", tier=4, tags={"slow","phys_dps","armor_reduce"}},
    {name="item_giant_maul",         display="Giant Maul",         tier=4, tags={"phys_burst","stun","str"}},
    {name="item_rattlecage",         display="Rattlecage",         tier=4, tags={"armor","reflect","fear"}},
    {name="item_idol_of_screeauk",   display="Idol of Scree'auk",  tier=4, tags={"save","dispel","magic_resist"}},
    {name="item_flayers_bota",       display="Flayer's Bota",      tier=4, tags={"mobility","agi","attack_speed"}},
    {name="item_metamorphic_mandible", display="Metamorphic Mandible", tier=4, tags={"stats","armor","hp"}},
    -- Tier 5 (60:00+)
    {name="item_desolator_2",        display="Desolator 2",        tier=5, tags={"armor_reduce","phys_dps"}},
    {name="item_fallen_sky",         display="Fallen Sky",         tier=5, tags={"initiation","stun","phys_burst"}},
    {name="item_demonicon",          display="Demonicon",          tier=5, tags={"summons","push","magic_burst"}},
    {name="item_minotaur_horn",      display="Minotaur Horn",      tier=5, tags={"stun","tanky","initiation"}},
    {name="item_spider_legs",        display="Spider Legs",        tier=5, tags={"mobility","slow","initiation"}},
    {name="item_riftshadow_prism",   display="Riftshadow Prism",   tier=5, tags={"magic_amp","int","mana"}},
    {name="item_dezun_bloodrite",    display="Dezun Bloodrite",    tier=5, tags={"heal","magic_burst","anti_heal"}},
    {name="item_divine_regalia",     display="Divine Regalia",     tier=5, tags={"stats","save","ultimate"}},
}

--------------------------------------------------------------------------------
-- COUNTER-LOGIC
--------------------------------------------------------------------------------
local COUNTER_RULES = {
    {tags={"phys_dps","carry"},        weight=3, suggest={"vs_phys","armor","block"}},
    {tags={"phys_burst"},              weight=4, suggest={"vs_phys","vs_burst","save","armor"}},
    {tags={"attack_speed"},            weight=2, suggest={"vs_phys","armor","slow"}},
    {tags={"magic_burst"},             weight=4, suggest={"vs_magic","magic_resist","vs_disable"}},
    {tags={"pure_dmg"},                weight=3, suggest={"hp","save","tanky"}},
    {tags={"disable","stun"},          weight=3, suggest={"vs_disable","dispel","save"}},
    {tags={"hex"},                     weight=5, suggest={"vs_disable","dispel","block_spell"}},
    {tags={"silence"},                 weight=3, suggest={"dispel"}},
    {tags={"doom"},                    weight=5, suggest={"block_spell","save"}},
    {tags={"root"},                    weight=2, suggest={"dispel","mobility"}},
    {tags={"fear"},                    weight=3, suggest={"vs_disable","dispel","save"}},
    {tags={"invis"},                   weight=4, suggest={"vs_invis","detection"}},
    {tags={"illusions"},               weight=3, suggest={"vs_illusions","cleave"}},
    {tags={"summons"},                 weight=2, suggest={"vs_illusions","cleave"}},
    {tags={"mobility"},                weight=2, suggest={"root","slow","disable"}},
    {tags={"evasion"},                 weight=4, suggest={"vs_evasion","break"}},
    {tags={"heal","save"},             weight=3, suggest={"anti_heal"}},
    {tags={"heal"},                    weight=2, suggest={"anti_heal"}},
    {tags={"carry","phys_dps"},        weight=2, suggest={"disarm","vs_phys","armor"}},
    {tags={"magic_immune"},            weight=2, suggest={"vs_bkb","disable"}},
    {tags={"mana_burn"},               weight=2, suggest={"mana","sustain","hp"}},
    {tags={"global"},                  weight=2, suggest={"hp","tanky","save"}},
    {tags={"break"},                   weight=2, suggest={"dispel","save"}},
    {tags={"anti_heal"},               weight=2, suggest={"dispel","hp"}},
    {tags={"chrono"},                  weight=5, suggest={"save","vs_burst","block_spell"}},
    {tags={"black_hole"},              weight=5, suggest={"save","vs_burst","block_spell"}},
    {tags={"duel"},                    weight=4, suggest={"save","block_spell"}},
    {tags={"reincarnation"},           weight=1, suggest={"anti_heal","slow"}},
    {tags={"rupture"},                 weight=2, suggest={"dispel","save"}},
    {tags={"drain"},                   weight=2, suggest={"mobility","save"}},
    {tags={"push"},                    weight=2, suggest={"vs_illusions","cleave","team"}},
    {tags={"armor_reduce"},            weight=2, suggest={"armor","vs_phys"}},
    {tags={"track"},                   weight=2, suggest={"dispel","vs_invis"}},
    {tags={"slow"},                    weight=2, suggest={"dispel","mobility"}},
}

--------------------------------------------------------------------------------
-- MENU
--------------------------------------------------------------------------------
local UI = {}

function script.OnScriptsLoaded()
    local tab = Menu.Create("General", "Main", "Item Helper")
    tab:Icon("\u{f085}")
    local mainTab = tab:Create("Settings")
    local featTab = mainTab:Create("Features")
    UI.enabled       = featTab:Switch("Enable Helper", true, "\u{f00c}")
    UI.showPanel     = featTab:Switch("Show Panel", true)
    UI.autoAnalyze   = featTab:Switch("Auto Analyze", true)
    UI.maxItems      = featTab:Slider("Max Suggestions", 3, 10, 6, "%d")
    UI.showReasons   = featTab:Switch("Show Reasons", true)
    UI.showThreats   = featTab:Switch("Show Threat Analysis", true)
    UI.showOwned     = featTab:Switch("Highlight Owned", true)
    UI.showNeutrals  = featTab:Switch("Show Neutral Items", true)
    UI.trackEnemyItems = featTab:Switch("Track Enemy Items", true)
    UI.showHeroCounters = featTab:Switch("Show Hero Counters", true)
    UI.showNetWorth   = featTab:Switch("Show Net Worth Analysis", true)
    local visTab = mainTab:Create("Visual")
    UI.scale      = visTab:Slider("Panel Scale %", 60, 150, 100, "%d")
    UI.offX       = visTab:Slider("Offset X", -800, 800, 0, "%d")
    UI.offY       = visTab:Slider("Offset Y", -600, 600, 0, "%d")
    UI.opacity    = visTab:Slider("Opacity %", 20, 100, 85, "%d")
    UI.panelSide  = visTab:Combo("Panel Side", {"Left", "Right"}, 0)
    UI.visMode    = featTab:Combo("Show Mode", {"Always", "Cheat Menu Only", "Shop Only", "Menu or Shop"}, 0)
end

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------
local S = {
    enemyHeroes     = {},
    enemyTags       = {},
    threatCounts    = {},
    suggestions     = {},
    neutralSuggestions = {},
    ownedItems      = {},
    enemyItems      = {},      -- Items owned by enemies
    enemyItemCounts = {},      -- Count of specific items among enemies
    myGold          = 0,
    myHeroName      = "",
    gamePhase       = PHASE_EARLY,
    neutralTier     = 0,       -- Current neutral tier available
    lastAnalysis    = 0,
    heroIcons       = {},
    itemIcons       = {},
    lastFrame       = 0,
    dt              = 0.016,
    pulseTime       = 0,
    initialized     = false,
    totalNetWorth   = 0,
    -- Net worth analysis
    myTeamNetWorth  = 0,
    enemyTeamNetWorth = 0,
    netWorthDiff    = 0,       -- Positive = we're leading
    gameTempo       = "even",  -- "ahead", "even", "behind"
    -- Hero counter suggestions
    heroCounterSuggestions = {},
}

--------------------------------------------------------------------------------
-- FONTS
--------------------------------------------------------------------------------
local FC = {}
local fontsReady = false

local function getFont(sz)
    sz = math.max(8, math.floor(sz))
    if FC[sz] then return FC[sz] end
    local ok, f = pcall(Render.LoadFont, "Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
    if ok and f then FC[sz] = f; fontsReady = true; return f end
    return nil
end

local function initFonts()
    if fontsReady then return end
    for _, s in ipairs({8,9,10,11,12,14,16}) do getFont(s) end
end

--------------------------------------------------------------------------------
-- UTILS
--------------------------------------------------------------------------------
local F = math.floor
local V = Vec2

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function col(r, g, b, a) return Color(r, g, b, F(clamp(a or 255, 0, 255))) end
local function colA(c, a) return Color(c.r, c.g, c.b, F(clamp(a, 0, 255))) end

local function sg(widget, fallback)
    local ok, v = pcall(function() return widget:Get() end)
    if ok and v ~= nil then return v end
    return fallback
end

local function gt()
    local ok, v = pcall(GameRules.GetGameTime); return ok and v or 0
end
local function gst()
    local ok, v = pcall(GameRules.GetGameStartTime); return ok and v or 0
end

local function prettyHero(name)
    local n = name:gsub("npc_dota_hero_", ""):gsub("_", " ")
    n = n:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end)
    if #n > 16 then n = n:sub(1, 14) .. ".." end
    return n
end

local function screenSz()
    local ok, r = pcall(Render.ScreenSize)
    if ok and r then
        if type(r) == "userdata" or type(r) == "table" then return r.x or 1920, r.y or 1080 end
    end
    return 1920, 1080
end

local function safeStatic(tbl, method, ...)
    local fn = tbl and tbl[method]
    if not fn then return nil end
    local ok, r = pcall(fn, ...)
    return ok and r or nil
end

local function StyleColor(style, key, alphaOverride)
    if not style then return col(200, 200, 200, alphaOverride or 255) end
    local c = style[key]
    if not c then return col(200, 200, 200, alphaOverride or 255) end
    return Color(c.r or 200, c.g or 200, c.b or 200, alphaOverride or c.a or 255)
end

local function tableContains(tbl, val)
    for _, v in ipairs(tbl) do if v == val then return true end end
    return false
end

local function countMatches(tbl, vals)
    local c = 0
    for _, v in ipairs(vals) do if tableContains(tbl, v) then c = c + 1 end end
    return c
end

--------------------------------------------------------------------------------
-- IMAGE CACHE
--------------------------------------------------------------------------------
local function cacheImg(tbl, key, path)
    if tbl[key] ~= nil then return tbl[key] end
    local ok, h = pcall(Render.LoadImage, path)
    if ok and h then tbl[key] = h; return h end
    tbl[key] = false
    return nil
end

local function heroIcon(name)
    local v = S.heroIcons[name]
    if v then return v ~= false and v or nil end
    return cacheImg(S.heroIcons, name, "panorama/images/heroes/icons/" .. name .. "_png.vtex_c")
end

local function itemIcon(name)
    local v = S.itemIcons[name]
    if v then return v ~= false and v or nil end
    
    -- Remove item_ prefix for icon path
    local iconName = name:gsub("item_", "")
    local path = "panorama/images/items/" .. iconName .. "_png.vtex_c"
    
    -- Try to load icon
    return cacheImg(S.itemIcons, name, path)
end

--------------------------------------------------------------------------------
-- DRAW PRIMITIVES
--------------------------------------------------------------------------------
local function dRect(x, y, w, h, c, rnd)
    Render.FilledRect(V(F(x), F(y)), V(F(x+w), F(y+h)), c, rnd or 0, Enum.DrawFlags.RoundCornersAll)
end

local function dBorder(x, y, w, h, c, rnd, t)
    Render.Rect(V(F(x), F(y)), V(F(x+w), F(y+h)), c, rnd or 0, Enum.DrawFlags.RoundCornersAll, t or 1)
end

local function dText(sz, txt, x, y, c)
    local f = getFont(sz); if not f then return end
    Render.Text(f, sz, tostring(txt), V(F(x), F(y)), c)
end

--------------------------------------------------------------------------------
-- TEXT SIZE CACHE
--------------------------------------------------------------------------------
local textSizeCache = {}
local TEXT_CACHE_MAX_SIZE = 500  -- Limit cache size to prevent memory bloat

local function tSz(sz, txt)
    local key = sz .. "_" .. tostring(txt)
    local cached = textSizeCache[key]
    if cached then return cached end
    
    local f = getFont(sz)
    local result
    if not f then 
        result = {x = sz * #tostring(txt) * 0.55, y = sz}
    else
        local ok, r = pcall(Render.TextSize, f, sz, tostring(txt))
        if ok and r then result = r
        else result = {x = sz * #tostring(txt) * 0.55, y = sz} end
    end
    
    -- Limit cache size
    if #textSizeCache < TEXT_CACHE_MAX_SIZE then
        textSizeCache[key] = result
    end
    
    return result
end

local function clearTextCache()
    textSizeCache = {}
end

local function dLine(x1, y1, x2, y2, c, t)
    Render.Line(V(F(x1), F(y1)), V(F(x2), F(y2)), c, t or 1)
end

local function dCircle(x, y, r, c)
    Render.FilledCircle(V(F(x), F(y)), r, c)
end

local function dImg(img, x, y, w, h, c, rnd)
    Render.Image(img, V(F(x), F(y)), V(w, h), c, rnd or 0)
end

local function dBlur(x, y, w, h)
    Render.Blur(V(F(x), F(y)), V(F(x+w), F(y+h)), 1.0, 1.0, 0, Enum.DrawFlags.None)
end

--------------------------------------------------------------------------------
-- ANALYSIS ENGINE
--------------------------------------------------------------------------------
local function analyzeEnemyTeam()
    local me = Heroes.GetLocal()
    if not me then return end

    local myTeam = safeStatic(Entity, "GetTeamNum", me)
    if not myTeam then return end

    -- Game phase
    local gameTime = gt() - gst()
    if gameTime < 0 then gameTime = 0 end
    if gameTime < 840 then S.gamePhase = PHASE_EARLY
    elseif gameTime < 1800 then S.gamePhase = PHASE_MID
    else S.gamePhase = PHASE_LATE end

    -- Determine neutral tier based on game time (updated for current patch)
    if gameTime < 300 then S.neutralTier = 0       -- No neutrals yet
    elseif gameTime < 900 then S.neutralTier = 1   -- Tier 1: 5-15 min
    elseif gameTime < 1500 then S.neutralTier = 2  -- Tier 2: 15-25 min
    elseif gameTime < 2100 then S.neutralTier = 3  -- Tier 3: 25-35 min
    elseif gameTime < 3600 then S.neutralTier = 4  -- Tier 4: 35-60 min
    else S.neutralTier = 5 end                     -- Tier 5: 60+ min

    -- Net worth analysis (via item values + gold)
    if sg(UI.showNetWorth, true) then
        local myTeamNW = 0
        local enemyTeamNW = 0
        local debugInfo = ""
        local heroCount = 0
        
        local heroes = Heroes.GetAll()
        if not heroes or #heroes == 0 then
            Log.Write("[ItemHelper] No heroes found")
            return
        end
        
        for _, hero in ipairs(heroes) do
            if hero and Entity.IsEntity(hero) then
                heroCount = heroCount + 1
                local team = safeStatic(Entity, "GetTeamNum", hero)
                local unitName = safeStatic(NPC, "GetUnitName", hero) or "unknown"
                local totalGold = 0
                
                -- Method 1: Try to get gold from Player
                local playerID = safeStatic(Hero, "GetPlayerID", hero)
                if playerID and playerID >= 0 then
                    local player = Players.Get(playerID)
                    if player then
                        local gold = safeStatic(Player, "GetGold", player)
                        if gold and gold > 0 then
                            totalGold = totalGold + gold
                        end
                    end
                end
                
                -- Method 2: Calculate from item values using our database
                local itemValue = 0
                local itemCount = 0
                for i = 0, 8 do
                    local item = safeStatic(NPC, "GetItemByIndex", hero, i)
                    if item then
                        local itemName = safeStatic(Ability, "GetName", item)
                        local cost = GetItemCost(itemName)
                        if cost > 0 then
                            itemValue = itemValue + cost
                            itemCount = itemCount + 1
                        end
                    end
                end
                -- Neutral item (slot 16)
                local neutralItem = safeStatic(NPC, "GetItemByIndex", hero, 16)
                if neutralItem then
                    itemValue = itemValue + 1000
                    itemCount = itemCount + 1
                end
                
                totalGold = totalGold + itemValue
                
                if team == myTeam then
                    myTeamNW = myTeamNW + totalGold
                else
                    enemyTeamNW = enemyTeamNW + totalGold
                end
                
                if totalGold > 0 then
                    debugInfo = debugInfo .. unitName .. "(T" .. team .. ")=G" .. (totalGold - itemValue) .. "+I" .. itemValue .. "[" .. itemCount .. "items] "
                end
            end
        end
        
        S.myTeamNetWorth = myTeamNW
        S.enemyTeamNetWorth = enemyTeamNW
        S.netWorthDiff = myTeamNW - enemyTeamNW

        -- Determine game tempo
        local diffPercent = enemyTeamNW > 0 and (S.netWorthDiff / enemyTeamNW) or 0
        if diffPercent > 0.15 then S.gameTempo = "ahead"
        elseif diffPercent < -0.15 then S.gameTempo = "behind"
        else S.gameTempo = "even" end
    end

    -- My gold & hero name
    local myPlayer = safeStatic(Heroes, "GetPlayerID", me)
    if myPlayer then
        local gold = safeStatic(Player, "GetGold", myPlayer)
        if gold then S.myGold = gold end
    end
    S.myHeroName = safeStatic(NPC, "GetUnitName", me) or ""

    -- Own items (including neutral slot)
    S.ownedItems = {}
    for i = 0, 8 do
        local item = safeStatic(NPC, "GetItemByIndex", me, i)
        if item then
            local iName = safeStatic(Ability, "GetName", item)
            if iName then S.ownedItems[iName] = true end
        end
    end
    -- Check neutral slot (slot 16)
    local neutralItem = safeStatic(NPC, "GetItemByIndex", me, 16)
    if neutralItem then
        local nName = safeStatic(Ability, "GetName", neutralItem)
        if nName then S.ownedItems[nName] = true end
    end

    -- Enemies (filter out illusions, clones, tempest doubles; deduplicate by name)
    S.enemyHeroes = {}
    S.enemyTags = {}
    S.enemyItems = {}
    S.enemyItemCounts = {}
    local heroes = Heroes.GetAll()
    if not heroes then return end

    local seenNames = {}
    for _, hero in ipairs(heroes) do
        local team = safeStatic(Entity, "GetTeamNum", hero)
        if team and team ~= myTeam then
            -- Skip illusions, clones (MK ult), tempest doubles (Arc Warden)
            local isIllusion = safeStatic(NPC, "IsIllusion", hero)
            if isIllusion then goto continue end
            local isClone = safeStatic(NPC, "IsClone", hero)
            if isClone then goto continue end
            local isTempest = safeStatic(NPC, "IsTempestDouble", hero)
            if isTempest then goto continue end

            local name = safeStatic(NPC, "GetUnitName", hero) or ""
            if name ~= "" and not seenNames[name] then
                seenNames[name] = true
                local alive = safeStatic(Entity, "IsAlive", hero)
                local level = safeStatic(NPC, "GetCurrentLevel", hero) or 0

                local enemyData = {
                    name  = name,
                    alive = alive ~= false,
                    level = level,
                    items = {},
                }

                -- Track enemy items if enabled
                if sg(UI.trackEnemyItems, true) then
                    for i = 0, 8 do
                        local item = safeStatic(NPC, "GetItemByIndex", hero, i)
                        if item then
                            local iName = safeStatic(Ability, "GetName", item)
                            if iName then
                                enemyData.items[iName] = true
                                S.enemyItems[iName] = (S.enemyItems[iName] or 0) + 1
                                S.enemyItemCounts[iName] = (S.enemyItemCounts[iName] or 0) + 1
                            end
                        end
                    end
                    -- Check neutral slot
                    local neutralItem = safeStatic(NPC, "GetItemByIndex", hero, 16)
                    if neutralItem then
                        local nName = safeStatic(Ability, "GetName", neutralItem)
                        if nName then
                            enemyData.items[nName] = true
                            S.enemyItems[nName] = (S.enemyItems[nName] or 0) + 1
                        end
                    end
                end

                table.insert(S.enemyHeroes, enemyData)

                local tags = HERO_TAGS[name]
                if tags then
                    for _, tag in ipairs(tags) do
                        S.enemyTags[tag] = (S.enemyTags[tag] or 0) + 1
                    end
                end
            end
        end
        ::continue::
    end

    -- Sort threat counts
    S.threatCounts = {}
    for tag, count in pairs(S.enemyTags) do
        table.insert(S.threatCounts, {tag = tag, count = count})
    end
    table.sort(S.threatCounts, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.tag < b.tag
    end)

    -- Hero counter suggestions
    S.heroCounterSuggestions = {}
    if sg(UI.showHeroCounters, true) then
        local counterScore = {}
        for _, enemy in ipairs(S.enemyHeroes) do
            local counterData = HERO_COUNTERS[enemy.name]
            if counterData then
                for _, itemName in ipairs(counterData.items) do
                    if not S.ownedItems[itemName] then
                        counterScore[itemName] = (counterScore[itemName] or 0) + 1
                    end
                end
            end
        end
        -- Convert to sorted table
        for itemName, score in pairs(counterScore) do
            local counterData = nil
            -- Find reason from HERO_COUNTERS
            for _, enemy in ipairs(S.enemyHeroes) do
                local cd = HERO_COUNTERS[enemy.name]
                if cd and tableContains(cd.items, itemName) then
                    counterData = cd
                    break
                end
            end
            table.insert(S.heroCounterSuggestions, {
                item = itemName,
                score = score,
                reason = counterData and counterData.reason or "Counter pick"
            })
        end
        table.sort(S.heroCounterSuggestions, function(a, b) return a.score > b.score end)
    end

    -- Resolve my hero role/style for hero-aware scoring
    local myRole = nil
    local myStyle = nil
    local myRoleInfo = HERO_ROLES[S.myHeroName]
    if myRoleInfo then
        myRole = myRoleInfo.role
        myStyle = myRoleInfo.style
    end

    -- Score items
    local function scoreItem(itemDef)
        if not tableContains(itemDef.phase, S.gamePhase) then return 0 end
        if S.ownedItems[itemDef.name] then return -1 end
        local score = 0
        -- Trigger-based scoring
        if itemDef.triggers then
            for _, tr in ipairs(itemDef.triggers) do
                local cnt = S.enemyTags[tr] or 0
                if cnt > 0 then score = score + cnt * 4 end
            end
        end
        -- Counter-rule scoring
        for _, rule in ipairs(COUNTER_RULES) do
            local ruleMatch = 0
            for _, rTag in ipairs(rule.tags) do
                if S.enemyTags[rTag] and S.enemyTags[rTag] > 0 then
                    ruleMatch = ruleMatch + 1
                end
            end
            if ruleMatch >= #rule.tags then
                local itemMatch = countMatches(itemDef.tags, rule.suggest)
                if itemMatch > 0 then
                    local totalEnemyTags = 0
                    for _, rTag in ipairs(rule.tags) do
                        totalEnemyTags = totalEnemyTags + (S.enemyTags[rTag] or 0)
                    end
                    score = score + itemMatch * rule.weight * totalEnemyTags
                end
            end
        end
        -- Cost efficiency bonus
        if score > 0 and S.myGold >= itemDef.cost then
            score = score + 2
        end
        -- Hero-aware role/style penalty: penalize items bad for my hero
        if score > 0 and (myRole or myStyle) then
            local penalty = ITEM_ROLE_PENALTY[itemDef.name]
            if penalty then
                local penalized = false
                -- Check role mismatch
                if penalty.bad_roles and myRole then
                    for _, br in ipairs(penalty.bad_roles) do
                        if br == myRole then penalized = true; break end
                    end
                end
                -- Check style mismatch
                if not penalized and penalty.bad_styles and myStyle then
                    for _, bs in ipairs(penalty.bad_styles) do
                        if bs == myStyle then penalized = true; break end
                    end
                end
                if penalized then
                    score = math.max(1, math.floor(score * 0.15))
                end
            end
        end
        -- Enemy item counter scoring
        if sg(UI.trackEnemyItems, true) then
            -- BKB on enemies -> suggest Nullifier/Abyssal
            if S.enemyItemCounts["item_black_king_bar"] and S.enemyItemCounts["item_black_king_bar"] > 0 then
                if itemDef.name == "item_nullifier" or itemDef.name == "item_abyssal_blade" then
                    score = score + S.enemyItemCounts["item_black_king_bar"] * 8
                end
            end
            -- Linken/Aeon Disk on enemies -> suggest second disable or pop item
            if S.enemyItemCounts["item_sphere"] and S.enemyItemCounts["item_sphere"] > 0 then
                if itemDef.tags and tableContains(itemDef.tags, "disable") then
                    score = score + S.enemyItemCounts["item_sphere"] * 4
                end
            end
            if S.enemyItemCounts["item_aeon_disk"] and S.enemyItemCounts["item_aeon_disk"] > 0 then
                if itemDef.name == "item_nullifier" then
                    score = score + S.enemyItemCounts["item_aeon_disk"] * 6
                end
            end
            -- Ghost Scepter on enemies -> suggest Ethereal/Nullifier
            if S.enemyItemCounts["item_ghost"] and S.enemyItemCounts["item_ghost"] > 0 then
                if itemDef.name == "item_ethereal_blade" or itemDef.name == "item_nullifier" then
                    score = score + S.enemyItemCounts["item_ghost"] * 5
                end
            end
            -- Glimmer Cape on enemies -> suggest Dust/Nullifier
            if S.enemyItemCounts["item_glimmer_cape"] and S.enemyItemCounts["item_glimmer_cape"] > 0 then
                if itemDef.name == "item_dust" or itemDef.name == "item_nullifier" then
                    score = score + S.enemyItemCounts["item_glimmer_cape"] * 4
                end
            end
            -- Blade Mail on enemies -> suggest lifesteal/ranged counter
            if S.enemyItemCounts["item_blade_mail"] and S.enemyItemCounts["item_blade_mail"] > 0 then
                if itemDef.tags and (tableContains(itemDef.tags, "lifesteal") or tableContains(itemDef.tags, "vs_phys")) then
                    score = score + S.enemyItemCounts["item_blade_mail"] * 3
                end
            end
        end
        -- Game Tempo scoring (net worth analysis)
        if sg(UI.showNetWorth, true) and S.gameTempo ~= "even" then
            if S.gameTempo == "ahead" then
                -- Leading: suggest luxury items
                if itemDef.cost >= 4000 and tableContains(itemDef.tags, "phys_dps") then
                    score = score + 3
                end
            elseif S.gameTempo == "behind" then
                -- Losing: suggest cheaper defensive items
                if itemDef.cost < 3000 and (tableContains(itemDef.tags, "vs_phys") or tableContains(itemDef.tags, "vs_magic") or tableContains(itemDef.tags, "save")) then
                    score = score + 4
                end
                -- Penalty for expensive items when behind
                if itemDef.cost >= 5000 then
                    score = math.max(1, math.floor(score * 0.5))
                end
            end
        end
        return score
    end

    local scored = {}
    for _, itemDef in ipairs(ITEM_DB) do
        local s = scoreItem(itemDef)
        if s > 0 then table.insert(scored, {item = itemDef, score = s}) end
    end
    table.sort(scored, function(a, b) return a.score > b.score end)

    S.suggestions = {}
    local maxItems = sg(UI.maxItems, 6)
    local addedNames = {}
    for _, entry in ipairs(scored) do
        if #S.suggestions >= maxItems then break end
        if not addedNames[entry.item.name] then
            addedNames[entry.item.name] = true
            table.insert(S.suggestions, {item = entry.item, score = entry.score})
        end
    end

    -- Score neutral items
    if sg(UI.showNeutrals, true) and S.neutralTier > 0 then
        local function scoreNeutralItem(itemDef)
            if itemDef.tier > S.neutralTier then return 0 end
            if S.ownedItems[itemDef.name] then return -1 end
            local score = 0
            -- Trigger-based scoring
            if itemDef.tags then
                for _, tag in ipairs(itemDef.tags) do
                    local cnt = S.enemyTags[tag] or 0
                    if cnt > 0 then score = score + cnt * 2 end
                end
            end
            -- Counter-rule scoring for neutrals
            for _, rule in ipairs(COUNTER_RULES) do
                local ruleMatch = 0
                for _, rTag in ipairs(rule.tags) do
                    if S.enemyTags[rTag] and S.enemyTags[rTag] > 0 then
                        ruleMatch = ruleMatch + 1
                    end
                end
                if ruleMatch >= #rule.tags then
                    local itemMatch = countMatches(itemDef.tags, rule.suggest)
                    if itemMatch > 0 then
                        score = score + itemMatch * rule.weight * 0.5
                    end
                end
            end
            -- Prefer higher tier items if available
            score = score + (itemDef.tier * 2)
            -- Role/style penalty for neutrals
            if score > 0 and (myRole or myStyle) then
                local penalty = ITEM_ROLE_PENALTY[itemDef.name]
                if penalty then
                    local penalized = false
                    if penalty.bad_roles and myRole then
                        for _, br in ipairs(penalty.bad_roles) do
                            if br == myRole then penalized = true; break end
                        end
                    end
                    if not penalized and penalty.bad_styles and myStyle then
                        for _, bs in ipairs(penalty.bad_styles) do
                            if bs == myStyle then penalized = true; break end
                        end
                    end
                    if penalized then
                        score = math.max(1, math.floor(score * 0.3))
                    end
                end
            end
            return score
        end

        local neutralScored = {}
        for _, itemDef in ipairs(NEUTRAL_DB) do
            local s = scoreNeutralItem(itemDef)
            if s > 0 then table.insert(neutralScored, {item = itemDef, score = s}) end
        end
        table.sort(neutralScored, function(a, b) return a.score > b.score end)

        S.neutralSuggestions = {}
        local maxNeutrals = 3
        for _, entry in ipairs(neutralScored) do
            if #S.neutralSuggestions >= maxNeutrals then break end
            table.insert(S.neutralSuggestions, {item = entry.item, score = entry.score})
        end
    end
end

--------------------------------------------------------------------------------
-- DRAW: THREAT TAG
--------------------------------------------------------------------------------
local THREAT_TAG_COLORS = {
    carry       = {255, 80, 80},
    phys_dps    = {255, 130, 50},
    phys_burst  = {255, 80, 50},
    magic_burst = {120, 80, 255},
    disable     = {255, 220, 50},
    stun        = {255, 200, 50},
    hex         = {200, 80, 255},
    silence     = {80, 130, 255},
    heal        = {80, 220, 100},
    save        = {80, 200, 180},
    invis       = {180, 180, 220},
    illusions   = {200, 150, 255},
    summons     = {150, 180, 130},
    mobility    = {80, 200, 255},
    evasion     = {180, 255, 80},
    tanky       = {160, 160, 180},
    slow        = {100, 150, 255},
    global      = {255, 180, 100},
    push        = {200, 180, 100},
    mana_burn   = {50, 100, 255},
    magic_immune= {255, 200, 80},
    doom        = {255, 50, 50},
    pure_dmg    = {255, 220, 220},
    armor_reduce= {200, 130, 50},
    anti_heal   = {255, 100, 100},
    root        = {100, 200, 100},
    fear        = {200, 100, 200},
    break_tag   = {200, 150, 100},
}

local function getTTagColor(tag)
    return THREAT_TAG_COLORS[tag] or {150, 150, 150}
end

local function drawThreatTag(x, y, tag, count, alpha, maxW)
    local tc = getTTagColor(tag)
    local txt = tag:upper()
    if count > 1 then txt = txt .. " x" .. count end
    local tw = tSz(8, txt)
    local w = tw.x + 10
    local h = 15
    if maxW and (x + w) > maxW then return 0, true end
    dRect(x, y, w, h, col(tc[1], tc[2], tc[3], F(alpha * 0.2)), 3)
    dText(8, txt, x + 5, y + 2, col(tc[1], tc[2], tc[3], F(alpha * 0.85)))
    return w + 3, false
end

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local CFG = {
    PW          = 310,
    MARGIN      = 12,
    PAD         = 10,
    ROUNDING    = 8,
    HEADER_H    = 40,
    ANALYSIS_CD = 2.0,
}

--------------------------------------------------------------------------------
-- THEME COLOR CACHE
--------------------------------------------------------------------------------
local TC = {
    bg       = col(12, 14, 26, 220),
    border   = col(40, 45, 65, 80),
    text     = col(235, 238, 255, 255),
    accent   = col(0, 200, 150, 255),
    dim      = col(100, 105, 120, 180),
    lastSync = 0,
}

local function syncThemeColors()
    local now = gt()
    if now - TC.lastSync < 0.5 then return end
    TC.lastSync = now
    local ok, style = pcall(Menu.Style)
    if not ok or not style then return end
    TC.bg     = StyleColor(style, "additional_background", 220)
    TC.border = StyleColor(style, "outline", 80)
    TC.text   = StyleColor(style, "primary_first_tab_text", 255)
    TC.accent = StyleColor(style, "primary", 255)
    TC.dim    = StyleColor(style, "slider_background", 180)
end

--------------------------------------------------------------------------------
-- PANORAMA / VISIBILITY
--------------------------------------------------------------------------------
local _shopCache       = false
local _shopCacheT      = 0
local _shopPanel       = nil
local _panelSearchDone = false

-- Find shop panel (id=shop, type=DOTAHUDShop)
local function findShopPanel()
    if _panelSearchDone then return _shopPanel end
    _panelSearchDone = true
    -- Direct search by ID
    local ok, p = pcall(Panorama.GetPanelByName, "shop", false)
    if ok and p then _shopPanel = p; return p end
    -- Fallback: traverse from HUD root
    local ok2, hud = pcall(Panorama.GetPanelByName, "Hud", false)
    if ok2 and hud then
        local ok3, sp = pcall(hud.FindChildTraverse, hud, "shop")
        if ok3 and sp then _shopPanel = sp; return sp end
    end
    return nil
end

local function isShopOpen()
    local now = gt()
    if now - _shopCacheT < 0.15 then return _shopCache end
    _shopCacheT = now

    -- Shop panel has CSS class "ShopOpen" when open, "ShopClosing" when closed
    local sp = findShopPanel()
    if sp then
        local ok, has = pcall(sp.HasClass, sp, "ShopOpen")
        if ok then
            _shopCache = (has == true)
            return _shopCache
        end
    end

    _shopCache = false
    return false
end

local function isCheatMenuOpen()
    local ok, v = pcall(Menu.Opened)
    return ok and v == true
end

-- visMode: 0=Always, 1=Cheat Menu Only, 2=Shop Only, 3=Menu or Shop
local function shouldShowPanel()
    local mode = sg(UI.visMode, 0)
    if mode == 0 then
        return true
    elseif mode == 1 then
        return isCheatMenuOpen()
    elseif mode == 2 then
        return isShopOpen()
    elseif mode == 3 then
        return isCheatMenuOpen() or isShopOpen()
    end
    return true
end

--------------------------------------------------------------------------------
-- DRAW: HEADER
--------------------------------------------------------------------------------
local function drawHeader(x, y, w, alpha)
    local acc = TC.accent
    local textC = colA(TC.text, alpha)
    dRect(x, y, w, 2, colA(acc, alpha * 0.8), 0)
    dText(14, L("title"), x + 8, y + 10, textC)

    -- Phase badge
    local phaseKeys = {[PHASE_EARLY]="early", [PHASE_MID]="mid", [PHASE_LATE]="late"}
    local phaseColors = {[PHASE_EARLY]={80,220,120}, [PHASE_MID]={255,200,60}, [PHASE_LATE]={255,90,70}}
    local pc = phaseColors[S.gamePhase]
    local pName = L(phaseKeys[S.gamePhase])
    local ps = tSz(10, pName)
    local bx = x + w - ps.x - 14
    dRect(bx, y + 10, ps.x + 10, 18, col(pc[1], pc[2], pc[3], F(alpha * 0.15)), 4)
    dText(10, pName, bx + 5, y + 12, col(pc[1], pc[2], pc[3], F(alpha * 0.9)))

    -- Gold
    local goldTxt = F(S.myGold) .. "g"
    local goldSz = tSz(9, goldTxt)
    dText(9, goldTxt, x + w - goldSz.x - 8, y + 30, col(255, 215, 0, F(alpha * 0.7)))

    dRect(x + 4, y + CFG.HEADER_H - 1, w - 8, 1, colA(TC.dim, alpha * 0.2), 0)
    return CFG.HEADER_H
end

--------------------------------------------------------------------------------
-- DRAW: ENEMY HEROES SECTION
--------------------------------------------------------------------------------
local function drawEnemySection(x, y, w, alpha)
    local curY = y
    local acc = TC.accent
    dText(10, L("enemies"), x + 4, curY, colA(acc, alpha * 0.9))
    curY = curY + 16

    local iconSz = 24
    local gap = 3
    local ix = x + 4

    for _, enemy in ipairs(S.enemyHeroes) do
        local icon = heroIcon(enemy.name)
        local iA = enemy.alive and alpha or (alpha * 0.3)
        dRect(ix, curY, iconSz, iconSz, col(20, 22, 36, F(iA * 0.7)), 4)
        if icon then
            dImg(icon, ix, curY, iconSz, iconSz, col(255, 255, 255, F(iA)), 4)
        else
            dText(12, "?", ix + 7, curY + 4, col(70, 75, 100, F(iA)))
        end
        if enemy.level > 0 then
            local lt = tostring(enemy.level)
            local lsz = tSz(7, lt)
            dRect(ix + iconSz - lsz.x - 2, curY + iconSz - 10, lsz.x + 3, 10,
                  col(0, 0, 0, F(iA * 0.8)), 2)
            dText(7, lt, ix + iconSz - lsz.x, curY + iconSz - 9, col(255, 255, 255, F(iA)))
        end
        if not enemy.alive then
            local cx2, cy2 = ix + iconSz / 2, curY + iconSz / 2
            local sz = iconSz * 0.22
            dLine(cx2 - sz, cy2 - sz, cx2 + sz, cy2 + sz, col(255, 50, 50, F(alpha * 0.7)), 2)
            dLine(cx2 + sz, cy2 - sz, cx2 - sz, cy2 + sz, col(255, 50, 50, F(alpha * 0.7)), 2)
        end
        ix = ix + iconSz + gap
        if ix > x + w - iconSz then break end
    end
    curY = curY + iconSz + 6

    -- Threat tags
    if sg(UI.showThreats, true) and #S.threatCounts > 0 then
        dText(9, L("threats"), x + 4, curY, col(180, 150, 80, F(alpha * 0.8)))
        curY = curY + 14
        local tagX = x + 4
        local maxRight = x + w - 4
        local maxTags = 10
        local shown = 0
        for _, tc in ipairs(S.threatCounts) do
            if shown >= maxTags then break end
            if tc.count > 0 then
                local tw, needWrap = drawThreatTag(tagX, curY, tc.tag, tc.count, alpha, maxRight)
                if needWrap then
                    tagX = x + 4
                    curY = curY + 17
                    tw, needWrap = drawThreatTag(tagX, curY, tc.tag, tc.count, alpha, maxRight)
                end
                if tw > 0 then tagX = tagX + tw; shown = shown + 1 end
            end
        end
        curY = curY + 19
    end

    dRect(x + 4, curY, w - 8, 1, colA(TC.dim, alpha * 0.15), 0)
    curY = curY + 6
    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: NET WORTH BAR
--------------------------------------------------------------------------------
local function drawNetWorthBar(x, y, w, alpha)
    if not sg(UI.showNetWorth, true) then return 0 end
    -- Always show if enabled, even with 0 values (for debugging)
    
    local curY = y
    local totalNW = S.myTeamNetWorth + S.enemyTeamNetWorth
    
    -- Title
    dText(9, "NET WORTH", x + 4, curY, col(150, 150, 150, F(alpha * 0.7)))
    curY = curY + 14
    
    -- If no data yet, show placeholder
    if totalNW == 0 then
        dText(8, "Waiting for data...", x + 4, curY + 2, col(100, 100, 100, F(alpha * 0.5)))
        return 24
    end

    local myPercent = S.myTeamNetWorth / totalNW
    local diff = S.netWorthDiff

    -- Bar
    local barH = 8
    local barW = w - 8
    local myW = F(barW * myPercent)

    -- Background
    dRect(x + 4, curY, barW, barH, col(30, 30, 40, F(alpha * 0.5)), 2)

    -- Our team (green)
    if myW > 0 then
        dRect(x + 4, curY, myW, barH, col(60, 180, 80, F(alpha * 0.7)), 2)
    end

    -- Enemy team (red)
    local enemyW = barW - myW
    if enemyW > 0 then
        dRect(x + 4 + myW, curY, enemyW, barH, col(180, 60, 60, F(alpha * 0.7)), 2)
    end

    -- Diff text
    local diffTxt = diff >= 0 and "+" .. F(diff) or F(diff)
    local diffColor = diff >= 0 and {80, 200, 80} or {200, 80, 80}
    local diffSz = tSz(8, diffTxt)
    dText(8, diffTxt, x + 4 + F(barW / 2) - F(diffSz.x / 2), curY - 1, col(diffColor[1], diffColor[2], diffColor[3], F(alpha * 0.9)))

    -- Tempo badge
    local tempoColors = {
        ahead = {80, 200, 80},
        even = {150, 150, 150},
        behind = {200, 80, 80}
    }
    local tempoTxt = S.gameTempo:upper()
    local tempoSz = tSz(7, tempoTxt)
    local tc = tempoColors[S.gameTempo] or {150, 150, 150}
    dRect(x + w - tempoSz.x - 10, curY - 1, tempoSz.x + 6, 12, col(tc[1], tc[2], tc[3], F(alpha * 0.15)), 2)
    dText(7, tempoTxt, x + w - tempoSz.x - 7, curY, col(tc[1], tc[2], tc[3], F(alpha * 0.8)))

    curY = curY + barH + 10
    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: HERO COUNTERS SECTION
--------------------------------------------------------------------------------
local function drawHeroCounters(x, y, w, alpha)
    if not sg(UI.showHeroCounters, true) then return 0 end
    if #S.heroCounterSuggestions == 0 then return 0 end

    local curY = y
    dText(10, "HERO COUNTERS", x + 4, curY, col(255, 100, 100, F(alpha * 0.9)))
    curY = curY + 16

    -- Draw compact counter items
    local maxCounters = 5
    for i, counter in ipairs(S.heroCounterSuggestions) do
        if i > maxCounters then break end

        local item = counter.item
        local owned = S.ownedItems[item]
        local canAfford = S.myGold >= (Item.GetCost and Item.GetCost(item) or 0)

        -- Find item display name
        local displayName = item:gsub("item_", ""):gsub("_", " ")
        for _, itemDef in ipairs(ITEM_DB) do
            if itemDef.name == item then
                displayName = itemDef.display
                break
            end
        end

        local h = 20
        local bgA = F(alpha * 0.25)
        if owned then
            dRect(x, curY, w, h, col(18, 35, 25, bgA), 4)
        else
            dRect(x, curY, w, h, col(16, 18, 30, bgA), 4)
        end

        -- Counter indicator line (red)
        dRect(x, curY + 3, 2, h - 6, col(255, 80, 80, F(alpha * 0.7)), 1)

        -- Item icon
        local iconSz = 18
        local iconX = x + 6
        local iconY = curY + 2
        local iImg = itemIcon(item)
        dRect(iconX, iconY, iconSz, iconSz, col(22, 25, 40, F(alpha * 0.4)), 3)
        if iImg then
            dImg(iImg, iconX, iconY, iconSz, iconSz, col(255, 255, 255, F(alpha * (owned and 0.4 or 1))), 3)
        else
            local firstChar = displayName:sub(1, 1)
            dText(9, firstChar, iconX + 5, iconY + 3, colA(TC.dim, alpha * 0.5))
        end

        -- Item name
        local nameC = owned and col(80, 200, 120, F(alpha * 0.7)) or colA(TC.text, alpha)
        dText(9, displayName, x + 28, curY + 3, nameC)

        -- Counter score badge
        local scoreTxt = "x" .. counter.score
        local scoreSz = tSz(7, scoreTxt)
        dRect(x + w - scoreSz.x - 8, curY + 4, scoreSz.x + 4, 12, col(255, 80, 80, F(alpha * 0.2)), 2)
        dText(7, scoreTxt, x + w - scoreSz.x - 6, curY + 5, col(255, 100, 100, F(alpha * 0.8)))

        curY = curY + h + 2
    end

    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: ITEM SUGGESTION CARD
--------------------------------------------------------------------------------
local function drawItemCard(x, y, w, suggestion, idx, alpha)
    local item = suggestion.item
    local acc = TC.accent
    local owned = S.ownedItems[item.name]
    local canAfford = S.myGold >= item.cost

    local nameX = x + 26 + 26 + 8
    local textAreaW = w - (nameX - x) - 6
    local h = 20

    -- Reason text wrapping - Improved visibility with larger font
    local reasonLines = {}
    if sg(UI.showReasons, true) then
        local reason = LR(item.name)
        if reason ~= "" then
            local words = {}
            for word in reason:gmatch("%S+") do table.insert(words, word) end
            local line = ""
            for _, word in ipairs(words) do
                local test = line == "" and word or (line .. " " .. word)
                local testW = tSz(10, test)
                if testW.x > textAreaW and line ~= "" then
                    table.insert(reasonLines, line)
                    line = word
                else
                    line = test
                end
            end
            if line ~= "" then table.insert(reasonLines, line) end
            h = h + #reasonLines * 13 + 2
        end
    end

    -- Trigger tags
    local hasTriggers = false
    if item.triggers then
        for _, tr in ipairs(item.triggers) do
            if S.enemyTags[tr] and S.enemyTags[tr] > 0 then hasTriggers = true; break end
        end
    end
    if hasTriggers then h = h + 14 end
    h = math.max(h, 36)

    -- Card background
    local bgA = F(alpha * 0.35)
    if owned then
        dRect(x, y, w, h, col(18, 35, 25, bgA), 6)
    else
        dRect(x, y, w, h, col(16, 18, 30, bgA), 6)
    end

    -- Left accent line
    if owned then
        dRect(x, y + 3, 2, h - 6, col(50, 200, 100, F(alpha * 0.7)), 1)
    elseif canAfford then
        dRect(x, y + 3, 2, h - 6, colA(acc, alpha * 0.5), 1)
    else
        dRect(x, y + 3, 2, h - 6, colA(TC.dim, alpha * 0.2), 1)
    end

    -- Priority number
    local numC = idx <= 2 and colA(acc, alpha * 0.9) or colA(TC.dim, alpha * 0.55)
    dText(10, "#" .. idx, x + 6, y + 4, numC)

    -- Item icon
    local iconSz = 26
    local iconX = x + 26
    local iconY = y + F((math.min(h, 46) - iconSz) / 2)
    local iImg = itemIcon(item.name)
    dRect(iconX, iconY, iconSz, iconSz, col(22, 25, 40, F(alpha * 0.5)), 4)
    if iImg then
        dImg(iImg, iconX, iconY, iconSz, iconSz, col(255, 255, 255, F(alpha * (owned and 0.4 or 1))), 4)
    else
        -- Show first letter if icon not loaded
        local firstChar = item.display:sub(1, 1)
        dText(10, firstChar, iconX + 8, iconY + 6, colA(TC.dim, alpha * 0.5))
    end

    -- Item name
    local nameC = owned and col(80, 200, 120, F(alpha * 0.7)) or colA(TC.text, alpha)
    dText(11, item.display, nameX, y + 4, nameC)

    -- Cost / Owned
    local costTxt = owned and L("owned") or (item.cost .. "g")
    local costC
    if owned then costC = col(80, 200, 120, F(alpha * 0.55))
    elseif canAfford then costC = col(255, 215, 0, F(alpha * 0.8))
    else costC = col(150, 85, 85, F(alpha * 0.6)) end
    local costSz = tSz(9, costTxt)
    dText(9, costTxt, x + w - costSz.x - 6, y + 5, costC)

    -- Reason text (multi-line) - Improved visibility
    local curTextY = y + 20
    for _, rLine in ipairs(reasonLines) do
        dText(10, rLine, nameX, curTextY, colA(TC.text, alpha * 0.85))
        curTextY = curTextY + 13
    end

    -- Trigger tags
    if hasTriggers then
        local tagX = nameX
        local tagY = curTextY + 1
        local shownTags = 0
        for _, tr in ipairs(item.triggers) do
            if shownTags >= 3 then break end
            if S.enemyTags[tr] and S.enemyTags[tr] > 0 then
                local tc = getTTagColor(tr)
                local tt = tr:upper()
                local tts = tSz(7, tt)
                local tw = tts.x + 6
                if tagX + tw > x + w - 4 then break end
                dRect(tagX, tagY, tw, 11, col(tc[1], tc[2], tc[3], F(alpha * 0.12)), 3)
                dText(7, tt, tagX + 3, tagY + 1, col(tc[1], tc[2], tc[3], F(alpha * 0.5)))
                tagX = tagX + tw + 2
                shownTags = shownTags + 1
            end
        end
    end

    return h
end

--------------------------------------------------------------------------------
-- DRAW: SUGGESTIONS SECTION
--------------------------------------------------------------------------------
local function drawSuggestions(x, y, w, alpha)
    local curY = y
    dText(10, L("recommended"), x + 4, curY, colA(TC.accent, alpha * 0.9))
    curY = curY + 18

    if #S.suggestions == 0 then
        dText(9, L("analyzing"), x + 4, curY, colA(TC.dim, alpha * 0.4))
        curY = curY + 18
        return curY - y
    end

    for i, sug in ipairs(S.suggestions) do
        local cardH = drawItemCard(x, curY, w, sug, i, alpha)
        curY = curY + cardH + 3
    end
    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: NEUTRAL ITEMS SECTION
--------------------------------------------------------------------------------
local NEUTRAL_TIER_COLORS = {
    [1] = {120, 200, 120},  -- Green
    [2] = {100, 180, 255},  -- Blue
    [3] = {200, 120, 255},  -- Purple
    [4] = {255, 180, 80},   -- Orange
    [5] = {255, 100, 100},  -- Red
}

local function drawNeutralSection(x, y, w, alpha)
    if not sg(UI.showNeutrals, true) then return 0 end
    if S.neutralTier == 0 then return 0 end
    if #S.neutralSuggestions == 0 then return 0 end

    local curY = y
    local tierC = NEUTRAL_TIER_COLORS[S.neutralTier] or {150, 150, 150}
    
    -- Section header with tier indicator
    dRect(x + 4, curY, w - 8, 1, colA(TC.dim, alpha * 0.15), 0)
    curY = curY + 6
    
    local tierText = "NEUTRAL T" .. S.neutralTier
    dText(10, tierText, x + 4, curY, col(tierC[1], tierC[2], tierC[3], F(alpha * 0.9)))
    curY = curY + 16

    -- Neutral item cards (compact version)
    for i, sug in ipairs(S.neutralSuggestions) do
        local item = sug.item
        local owned = S.ownedItems[item.name]
        local tierItemC = NEUTRAL_TIER_COLORS[item.tier] or {150, 150, 150}
        
        local h = 22
        local bgA = F(alpha * 0.25)
        if owned then
            dRect(x, curY, w, h, col(18, 35, 25, bgA), 4)
        else
            dRect(x, curY, w, h, col(16, 18, 30, bgA), 4)
        end

        -- Tier indicator line
        dRect(x, curY + 3, 2, h - 6, col(tierItemC[1], tierItemC[2], tierItemC[3], F(alpha * 0.6)), 1)

        -- Item icon
        local iconSz = 18
        local iconX = x + 6
        local iconY = curY + 2
        local iImg = itemIcon(item.name)
        dRect(iconX, iconY, iconSz, iconSz, col(22, 25, 40, F(alpha * 0.4)), 3)
        if iImg then
            dImg(iImg, iconX, iconY, iconSz, iconSz, col(255, 255, 255, F(alpha * (owned and 0.4 or 1))), 3)
        else
            -- Show first letter if icon not loaded
            local firstChar = item.display:sub(1, 1)
            dText(9, firstChar, iconX + 5, iconY + 3, colA(TC.dim, alpha * 0.5))
        end

        -- Item name
        local nameC = owned and col(80, 200, 120, F(alpha * 0.7)) or colA(TC.text, alpha)
        dText(9, item.display, x + 28, curY + 3, nameC)

        -- Tier badge
        local tierBadge = "T" .. item.tier
        local tierBadgeSz = tSz(7, tierBadge)
        dRect(x + w - tierBadgeSz.x - 10, curY + 5, tierBadgeSz.x + 6, 12, col(tierItemC[1], tierItemC[2], tierItemC[3], F(alpha * 0.15)), 2)
        dText(7, tierBadge, x + w - tierBadgeSz.x - 7, curY + 6, col(tierItemC[1], tierItemC[2], tierItemC[3], F(alpha * 0.7)))

        curY = curY + h + 2
    end

    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: FOOTER
--------------------------------------------------------------------------------
local function drawFooter(x, y, w, alpha)
    local curY = y
    dRect(x + 4, curY, w - 8, 1, colA(TC.dim, alpha * 0.15), 0)
    curY = curY + 6

    local tip, tipC = nil, {150, 158, 185}
    if S.enemyTags["invis"] and S.enemyTags["invis"] >= 2 then
        tip = L("tip_invis"); tipC = {255, 200, 80}
    elseif S.enemyTags["magic_burst"] and S.enemyTags["magic_burst"] >= 3 then
        tip = L("tip_magic"); tipC = {120, 80, 255}
    elseif S.enemyTags["heal"] and S.enemyTags["heal"] >= 2 then
        tip = L("tip_heal"); tipC = {80, 220, 120}
    elseif S.enemyTags["phys_dps"] and S.enemyTags["phys_dps"] >= 3 then
        tip = L("tip_phys"); tipC = {255, 130, 50}
    elseif S.enemyTags["illusions"] and S.enemyTags["illusions"] >= 2 then
        tip = L("tip_illusions"); tipC = {200, 150, 255}
    elseif S.enemyTags["disable"] and S.enemyTags["disable"] >= 3 then
        tip = L("tip_disable"); tipC = {255, 220, 50}
    end

    if tip then
        -- Word-wrap footer tip too
        local maxW = w - 12
        local words = {}
        for word in tip:gmatch("%S+") do table.insert(words, word) end
        local lines = {}
        local line = ""
        for _, word in ipairs(words) do
            local test = line == "" and word or (line .. " " .. word)
            if tSz(9, test).x > maxW and line ~= "" then
                table.insert(lines, line); line = word
            else line = test end
        end
        if line ~= "" then table.insert(lines, line) end
        local tipH = #lines * 13 + 6
        dRect(x + 2, curY, w - 4, tipH, col(tipC[1], tipC[2], tipC[3], F(alpha * 0.06)), 4)
        for _, ln in ipairs(lines) do
            dText(9, ln, x + 8, curY + 3, col(tipC[1], tipC[2], tipC[3], F(alpha * 0.65)))
            curY = curY + 13
        end
        curY = curY + 4
    end

    dText(8, "v2.0", x + w - 26, curY, col(40, 44, 60, F(alpha * 0.25)))
    curY = curY + 12
    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: MAIN PANEL
--------------------------------------------------------------------------------
local function drawPanel()
    if not shouldShowPanel() then return end
    syncThemeColors()

    local sw, sh = screenSz()
    local scale = clamp(sg(UI.scale, 100), 60, 150) / 100
    local opac = clamp(sg(UI.opacity, 85), 20, 100) / 100
    local offX = clamp(sg(UI.offX, 0), -800, 800)
    local offY = clamp(sg(UI.offY, 0), -600, 600)
    local panelSide = sg(UI.panelSide, 0)
    local pw = F(CFG.PW * scale)

    -- Dynamic height estimate
    local contentH = CFG.HEADER_H + CFG.PAD
    local enemyH = 16 + 24 + 6
    if sg(UI.showThreats, true) and #S.threatCounts > 0 then
        local tagsPerRow = math.max(1, F((pw - 16) / 60))
        local tagRows = math.ceil(math.min(#S.threatCounts, 10) / tagsPerRow)
        enemyH = enemyH + 14 + tagRows * 17 + 19
    end
    contentH = contentH + enemyH + 6
    -- Add net worth bar height
    if sg(UI.showNetWorth, true) then
        contentH = contentH + 36
    end
    -- Add hero counters height
    if sg(UI.showHeroCounters, true) and #S.heroCounterSuggestions > 0 then
        contentH = contentH + 18 + math.min(#S.heroCounterSuggestions, 5) * 22
    end
    local numSugs = math.min(#S.suggestions, sg(UI.maxItems, 6))
    contentH = contentH + 18 + numSugs * 52
    -- Add neutral items section height
    if sg(UI.showNeutrals, true) and S.neutralTier > 0 and #S.neutralSuggestions > 0 then
        contentH = contentH + 24 + #S.neutralSuggestions * 24
    end
    contentH = contentH + 40  -- Footer

    local ph = F(contentH * scale)
    local px, py
    if panelSide == 0 then px = CFG.MARGIN + offX
    else px = sw - pw - CFG.MARGIN + offX end
    py = CFG.MARGIN + 80 + offY
    px = clamp(px, 4, sw - pw - 4)
    py = clamp(py, 4, sh - ph - 4)

    local alpha = 255 * opac
    if alpha < 2 then return end

    dBlur(px, py, pw, ph)
    local themeBg = TC.bg
    dRect(px, py, pw, ph, col(themeBg.r, themeBg.g, themeBg.b, F(210 * alpha / 255)), CFG.ROUNDING)
    local bdrC = TC.border
    dBorder(px, py, pw, ph, col(bdrC.r, bdrC.g, bdrC.b, F(40 * alpha / 255)), CFG.ROUNDING, 1)

    local innerW = pw - CFG.PAD * 2
    local curY = py + CFG.PAD

    local hH = drawHeader(px + CFG.PAD, curY, innerW, alpha)
    curY = curY + hH + 4
    local eH = drawEnemySection(px + CFG.PAD, curY, innerW, alpha)
    curY = curY + eH
    -- Draw net worth bar
    if sg(UI.showNetWorth, true) then
        local nwH = drawNetWorthBar(px + CFG.PAD, curY, innerW, alpha)
        curY = curY + nwH
    end
    -- Draw hero counters
    if sg(UI.showHeroCounters, true) then
        local hcH = drawHeroCounters(px + CFG.PAD, curY, innerW, alpha)
        curY = curY + hcH
    end
    local sH = drawSuggestions(px + CFG.PAD, curY, innerW, alpha)
    curY = curY + sH
    local nH = drawNeutralSection(px + CFG.PAD, curY, innerW, alpha)
    curY = curY + nH
    drawFooter(px + CFG.PAD, curY, innerW, alpha)
end

--------------------------------------------------------------------------------
-- CALLBACKS
--------------------------------------------------------------------------------
function script.OnUpdate()
    local ok, err = pcall(function()
        if not sg(UI.enabled, true) then return end
        local inGame = false
        pcall(function() inGame = Engine.IsInGame() end)
        if not inGame then return end

        initFonts()
        updateLang()

        if sg(UI.autoAnalyze, true) then
            local now = gt()
            if now - S.lastAnalysis >= CFG.ANALYSIS_CD then
                S.lastAnalysis = now
                analyzeEnemyTeam()
            end
        end
    end)
    if not ok and err then print("[ItemHelper] Update: " .. tostring(err)) end
end

function script.OnDraw()
    local ok, err = pcall(function()
        if not fontsReady then initFonts() end
        if not sg(UI.enabled, true) then return end
        if not sg(UI.showPanel, true) then return end

        local inGame = false
        pcall(function() inGame = Engine.IsInGame() end)
        if not inGame then return end

        local now = gt()
        if S.lastFrame > 0 then S.dt = clamp(now - S.lastFrame, 0.001, 0.1) end
        S.lastFrame = now
        S.pulseTime = S.pulseTime + S.dt
        drawPanel()
    end)
    if not ok and err then print("[ItemHelper] Draw: " .. tostring(err)) end
end

function script.OnGameEnd()
    S.enemyHeroes = {}
    S.enemyTags = {}
    S.threatCounts = {}
    S.suggestions = {}
    S.neutralSuggestions = {}
    S.ownedItems = {}
    S.enemyItems = {}
    S.enemyItemCounts = {}
    S.myGold = 0
    S.myHeroName = ""
    S.gamePhase = PHASE_EARLY
    S.neutralTier = 0
    S.lastAnalysis = 0
    S.heroIcons = {}
    S.itemIcons = {}
    S.lastFrame = 0
    S.dt = 0.016
    S.pulseTime = 0
    S.totalNetWorth = 0
    -- Reset net worth analysis
    S.myTeamNetWorth = 0
    S.enemyTeamNetWorth = 0
    S.netWorthDiff = 0
    S.gameTempo = "even"
    -- Reset hero counters
    S.heroCounterSuggestions = {}
    -- Reset shop detection state
    _shopCache = false
    _shopCacheT = 0
    _shopPanel = nil
    _panelSearchDone = false
    -- Clear text size cache
    clearTextCache()
end

return script
