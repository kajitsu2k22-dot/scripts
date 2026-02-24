local script = {}

--------------------------------------------------------------------------------
-- ITEM HELPER — Помощник по сборке предметов
-- Анализирует вражеский пик, фазу игры и предлагает оптимальные предметы
-- Локализация: RU / EN / CN
-- author: Euphoria
-- Updated: 2026-02-24
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
        -- Game modes
        mode_unknown    = "UNKNOWN",
        mode_allpick    = "ALL PICK",
        mode_ranked     = "RANKED",
        mode_turbo      = "TURBO",
        mode_draft      = "DRAFT",
        mode_random     = "RANDOM",
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
        m_show_gold     = "Show Gold in Header",
        m_show_score_breakdown = "Show Score Breakdown",
        m_show_category_badges = "Show Category Badges",
        m_breakdown_chips = "Breakdown Chips",
        net_worth       = "NET WORTH",
        hero_counters   = "HERO COUNTERS",
        enemy_focus     = "ENEMY FOCUS",
        waiting_data    = "Waiting for data...",
        alive           = "ALIVE",
        dead            = "DEAD",
        gold_unknown    = "--",
        cat_must_have   = "MUST",
        cat_situational = "SIT",
        cat_luxury      = "LUX",
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
        -- Game modes
        mode_unknown    = "НЕИЗВЕСТНО",
        mode_allpick    = "ALL PICK",
        mode_ranked     = "RANKED",
        mode_turbo      = "TURBO",
        mode_draft      = "DRAFT",
        mode_random     = "RANDOM",
        -- Tips
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
        -- Game modes
        mode_unknown    = "未知",
        mode_allpick    = "全选",
        mode_ranked     = "天梯",
        mode_turbo      = "快速",
        mode_draft      = "征召",
        mode_random     = "随机",
        -- Tips
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

local L_UI_OVERRIDES = {
    en = {
        analyzing = "Scanning enemy draft...",
        no_enemies = "No enemies yet (demo/lobby: spawn bots to test)",
        waiting_data = "No data yet...",
        test_tryhero = "TRY HERO",
        test_lobby = "LOBBY",
        test_custom = "CUSTOM",
    },
    ru = {
        analyzing = "Сканю вражеский пик...",
        no_enemies = "Пока пусто (в демке/лобби заспавни ботов)",
        waiting_data = "Данных пока нет...",
        test_tryhero = "ОПРОБОВАТЬ",
        test_lobby = "ЛОББИ",
        test_custom = "КАСТОМ",
    },
    cn = {
        analyzing = "在看对面阵容...",
        no_enemies = "还没敌人（测试可在试玩/房间里生机器人）",
        waiting_data = "还没拿到数据...",
        test_tryhero = "试玩英雄",
        test_lobby = "房间",
        test_custom = "自定义",
    },
}

local L_REASON_SLANG = {
    en = {
        item_ghost = "Panic button vs right-click focus",
        item_cyclone = "Eul: self-dispel / setup / cancel channels",
        item_black_king_bar = "BKB so you can actually hit/cast",
        item_force_staff = "Force: save / reposition / break slows",
        item_glimmer_cape = "Glimmer save: magic resist + fade out",
        item_heavens_halberd = "Halberd shuts down right-click cores",
        item_spirit_vessel = "Vessel hard-cuts heal and regen",
        item_lotus_orb = "Lotus: self-dispel + bounce target spells",
        item_pipe = "Pipe vs heavy magic spam",
        item_hurricane_pike = "Pike for spacing vs melee jumpers",
        item_sphere = "Linken vs single-target catch",
        item_aeon_disk = "Aeon stops getting bursted 100-0",
        item_nullifier = "Nullifier removes save items (Ghost/Glimmer/Aeon)",
        item_orchid = "Orchid to shut up caster cores",
        item_rod_of_atos = "Atos root for mobile heroes",
        item_sheepstick = "Hex = best late hard catch",
        item_scythe_of_vyse = "Hex = best late hard catch",
        item_dust = "Dust if they keep juking in invis",
        item_ward_sentry = "Sentries for invis vision + deward",
        item_manta = "Manta to purge stuff and split lanes",
        item_blink = "Blink for jump/start or disengage",
        item_blade_mail = "Blademail punishes commit and burst",
        item_wind_waker = "Wind Waker save / reset / drag fight",
    },
    ru = {
        item_ghost = "Сэйв от райтклик фокуса",
        item_cyclone = "Еул: диспел с себя / сетап / сбить чейнел",
        item_black_king_bar = "BKB, чтобы тебя не держали и ты бил/кастил",
        item_force_staff = "Форс: сейв / репозишн / сбить слоу",
        item_glimmer_cape = "Глиммер: сейв, магрез и уйти в инвиз",
        item_heavens_halberd = "Алебарда выключает райтклик кора",
        item_spirit_vessel = "Вессел режет хил/реген очень сильно",
        item_lotus_orb = "Лотус: диспел с себя + вернуть таргет-спелл",
        item_pipe = "Пайп против магического спама/прокаста",
        item_hurricane_pike = "Пика для кайта милишников и прыгающих",
        item_sphere = "Линка против таргетного контроля",
        item_aeon_disk = "Аеон чтобы не лопаться за прокаст",
        item_nullifier = "Нуллик снимает сейвы (Ghost/Glimmer/Aeon)",
        item_orchid = "Орчид чтобы заткнуть кастера/мидера",
        item_rod_of_atos = "Атос: прибить мобильного героя",
        item_sheepstick = "Хекс — самый надёжный лейт-контроль",
        item_scythe_of_vyse = "Хекс — самый надёжный лейт-контроль",
        item_dust = "Даст, если они вечно уходят в инвиз",
        item_ward_sentry = "Сентри: вижен по инвизу + девард",
        item_manta = "Мантуха: снять гадость и сплитить",
        item_blink = "Блинк на врыв / инициацию / выход",
        item_blade_mail = "БМ наказывает за врыв и прокаст",
        item_wind_waker = "Виндвейкер: сейв / ресет / потянуть время",
    },
    cn = {
        item_ghost = "Ghost保命，顶住物理右键集火",
        item_cyclone = "吹风：给自己解状态 / 先手接控 / 打断读条",
        item_black_king_bar = "BKB开了才能站着打和放技能",
        item_force_staff = "推推保命/拉扯/断减速",
        item_glimmer_cape = "微光保人，魔抗+隐身拉扯",
        item_heavens_halberd = "天堂直接废右键大哥",
        item_spirit_vessel = "大骨灰狠砍回复和吸血",
        item_lotus_orb = "莲花：解状态，还能弹回单体技能",
        item_pipe = "笛子顶法系爆发和消耗",
        item_hurricane_pike = "大推推拉开身位打近战跳脸",
        item_sphere = "林肯防单点先手",
        item_aeon_disk = "永恒盘防被一套秒",
        item_nullifier = "否决拆救人装（Ghost/微光/Aeon）",
        item_orchid = "紫苑先手封嘴法核",
        item_rod_of_atos = "阿托斯拴住会跑的英雄",
        item_sheepstick = "羊刀=后期最稳硬控",
        item_scythe_of_vyse = "羊刀=后期最稳硬控",
        item_dust = "粉别省，对面老隐身就安排",
        item_ward_sentry = "真眼控隐身顺手反眼",
        item_manta = "分身斧解状态+带线拉扯",
        item_blink = "跳刀开团/先手/拉开都好用",
        item_blade_mail = "刃甲反打，谁冲你谁难受",
        item_wind_waker = "风杖鞋保人/拖时间/重置团战",
    },
}

local function L(key)
    local tbl = L_STRINGS[LANG] or L_STRINGS.en
    local ov = (L_UI_OVERRIDES[LANG] and L_UI_OVERRIDES[LANG][key])
        or (L_UI_OVERRIDES.en and L_UI_OVERRIDES.en[key])
    return ov or tbl[key] or L_STRINGS.en[key] or key
end

local function LR(itemName)
    local slangTbl = L_REASON_SLANG[LANG] or L_REASON_SLANG.en
    local slang = (slangTbl and slangTbl[itemName]) or (L_REASON_SLANG.en and L_REASON_SLANG.en[itemName])
    if slang and slang ~= "" then return slang end
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
-- GAME MODE DETECTION
--------------------------------------------------------------------------------
local GAME_MODE = {
    UNKNOWN = 0,
    ALL_PICK = 1,
    RANKED = 2,
    TURBO = 3,
    SINGLE_DRAFT = 4,
    ALL_RANDOM = 5,
    CAPTAINS_MODE = 6,
    ABILITY_DRAFT = 7,
}

local MODE_PHASE_MULTIPLIERS = {
    [GAME_MODE.UNKNOWN] = {early = 1.0, mid = 1.0, late = 1.0},
    [GAME_MODE.ALL_PICK] = {early = 1.0, mid = 1.0, late = 1.0},
    [GAME_MODE.RANKED]   = {early = 1.1, mid = 1.0, late = 0.9},  -- More competitive
    [GAME_MODE.TURBO]    = {early = 0.6, mid = 0.8, late = 1.2},  -- Faster game, skip early items
    [GAME_MODE.SINGLE_DRAFT] = {early = 1.0, mid = 1.0, late = 1.0},
    [GAME_MODE.ALL_RANDOM]   = {early = 1.0, mid = 1.0, late = 1.0},
    [GAME_MODE.CAPTAINS_MODE] = {early = 1.1, mid = 1.0, late = 0.9},
    [GAME_MODE.ABILITY_DRAFT] = {early = 0.8, mid = 1.0, late = 1.1},
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
-- HERO SPECIFIC ITEMS (предметы для конкретных героев)
-- good_items: предметы которые особенно хороши на этом герое (бонус score)
-- bad_items: предметы которые плохи на этом герое (штраф score)
-- Это позволяет учитывать специфику героя, например BF на Arc Warden - плохая идея
--------------------------------------------------------------------------------
local HERO_SPECIFIC_ITEMS = {
    -- ══════════════ Carry Heroes ══════════════
    npc_dota_hero_arc_warden = {
        good_items = {
            "item_mjollnir", "item_butterfly", "item_satanic", "item_skadi",
            "item_monkey_king_bar", "item_black_king_bar", "item_blink",
            "item_swift_blink", "item_nullifier", "item_abyssal_blade",
            "item_diffusal_blade", "item_manta", "item_disperser"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_vanguard", "item_heart", "item_blade_mail"
        },
        reason_good = "Arc Warden uses Tempest Double to duplicate items",
        reason_bad = "BF/Radiance don't work with Tempest Double"
    },
    npc_dota_hero_phantom_lancer = {
        good_items = {
            "item_diffusal_blade", "item_manta", "item_butterfly", "item_satanic",
            "item_skadi", "item_abyssal_blade", "item_disperser", "item_heart"
        },
        bad_items = {
            "item_battlefury", "item_mjollnir", "item_radiance",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Illusions benefit from these items",
        reason_bad = "BF/Mjollnir/Radiance don't work on illusions"
    },
    npc_dota_hero_terrorblade = {
        good_items = {
            "item_satanic", "item_butterfly", "item_skadi", "item_manta",
            "item_heart", "item_black_king_bar", "item_disperser"
        },
        bad_items = {
            "item_battlefury", "item_mjollnir", "item_radiance",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Illusions and metamorphosis synergy",
        reason_bad = "BF/Mjollnir don't work on illusions"
    },
    npc_dota_hero_naga_siren = {
        good_items = {
            "item_diffusal_blade", "item_manta", "item_butterfly", "item_heart",
            "item_skadi", "item_radiance", "item_disperser"
        },
        bad_items = {
            "item_battlefury", "item_mjollnir", "item_desolator",
            "item_monkey_king_bar"
        },
        reason_good = "Illusions push and fight",
        reason_bad = "BF/Mjollnir don't work on illusions"
    },
    npc_dota_hero_chaos_knight = {
        good_items = {
            "item_armlet", "item_heart", "item_satanic", "item_skadi",
            "item_abyssal_blade", "item_manta", "item_black_king_bar"
        },
        bad_items = {
            "item_battlefury", "item_mjollnir", "item_radiance",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Illusions get full stats from items",
        reason_bad = "BF/Mjollnir don't work on illusions"
    },
    npc_dota_hero_meepo = {
        good_items = {
            "item_power_treads", "item_aghanims_scepter", "item_blink",
            "item_ether_sword", "item_sheepstick", "item_octarine_core",
            "item_witch_blade", "item_assault"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_heart", "item_satanic"
        },
        reason_good = "All Meepos benefit from stats",
        reason_bad = "BF/Radiance only work on main Meepo"
    },
    npc_dota_hero_antiimage = {
        good_items = {
            "item_battlefury", "item_manta", "item_blink", "item_abyssal_blade",
            "item_skadi", "item_satanic", "item_butterfly", "item_black_king_bar"
        },
        bad_items = {
            "item_hand_of_midas", "item_radiance", "item_mjollnir"
        },
        reason_good = "Classic AM build with BF farm",
        reason_bad = "Midas too slow, Radiance/Mjollnir not optimal"
    },
    npc_dota_hero_spectre = {
        good_items = {
            "item_radiance", "item_blade_mail", "item_heart", "item_skadi",
            "item_spirit_vessel", "item_crimson_guard", "item_shivas_guard"
        },
        bad_items = {
            "item_battlefury", "item_hand_of_midas", "item_desolator",
            "item_monkey_king_bar"
        },
        reason_good = "Radiance + Haunt is devastating",
        reason_bad = "BF doesn't help Spectre's playstyle"
    },
    npc_dota_hero_faceless_void = {
        good_items = {
            "item_mask_of_madness", "item_maelstrom", "item_mjollnir",
            "item_black_king_bar", "item_butterfly", "item_satanic",
            "item_abyssal_blade", "item_monkey_king_bar"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Attack speed + Chronosphere synergy",
        reason_bad = "BF/Radiance don't fit Void's burst style"
    },
    npc_dota_hero_juggernaut = {
        good_items = {
            "item_battlefury", "item_mask_of_madness", "item_manta",
            "item_black_king_bar", "item_satanic", "item_butterfly",
            "item_abyssal_blade", "item_swift_blink"
        },
        bad_items = {
            "item_radiance", "item_hand_of_midas"
        },
        reason_good = "BF for farm + Omnislash synergy",
        reason_bad = "Radiance doesn't fit Jugg's style"
    },
    npc_dota_hero_ursa = {
        good_items = {
            "item_blink", "item_black_king_bar", "item_satanic", "item_skadi",
            "item_abyssal_blade", "item_butterfly", "item_aghanims_scepter"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Blink + BKB for burst damage",
        reason_bad = "BF/Radiance don't help Ursa's burst"
    },
    npc_dota_hero_slark = {
        good_items = {
            "item_silver_edge", "item_sange_and_yasha", "item_skadi",
            "item_blink", "item_black_king_bar", "item_abyssal_blade",
            "item_butterfly", "item_satanic"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Mobility + stat stealing synergy",
        reason_bad = "BF/Radiance reveal Slark's position"
    },
    npc_dota_hero_weaver = {
        good_items = {
            "item_desolator", "item_black_king_bar", "item_silver_edge",
            "item_butterfly", "item_manta", "item_monkey_king_bar",
            "item_abyssal_blade"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Deso + Geminate Attack burst",
        reason_bad = "BF/Radiance don't fit Weaver's hit-and-run"
    },
    npc_dota_hero_clinkz = {
        good_items = {
            "item_desolator", "item_silver_edge", "item_black_king_bar",
            "item_butterfly", "item_satanic", "item_monkey_king_bar",
            "item_abyssal_blade", "item_hurricane_pike"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Burst + Strafe synergy",
        reason_bad = "BF/Radiance reveal Clinkz"
    },
    npc_dota_hero_templar_assassin = {
        good_items = {
            "item_desolator", "item_blink", "item_black_king_bar",
            "item_butterfly", "item_satanic", "item_monkey_king_bar",
            "item_abyssal_blade", "item_swift_blink"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Deso + Refraction burst",
        reason_bad = "BF/Radiance don't fit TA's burst style"
    },
    npc_dota_hero_sniper = {
        good_items = {
            "item_mask_of_madness", "item_maelstrom", "item_mjollnir",
            "item_black_king_bar", "item_satanic", "item_butterfly",
            "item_skadi", "item_hurricane_pike", "item_monkey_king_bar"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_blink"
        },
        reason_good = "Range + attack speed synergy",
        reason_bad = "BF/Radiance don't fit Sniper's range"
    },
    npc_dota_hero_drow_ranger = {
        good_items = {
            "item_mask_of_madness", "item_maelstrom", "item_mjollnir",
            "item_black_king_bar", "item_satanic", "item_butterfly",
            "item_skadi", "item_hurricane_pike", "item_monkey_king_bar",
            "item_silver_edge"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_blink"
        },
        reason_good = "Glaives + attack speed synergy",
        reason_bad = "BF/Radiance don't fit Drow's range"
    },
    npc_dota_hero_medusa = {
        good_items = {
            "item_mask_of_madness", "item_maelstrom", "item_mjollnir",
            "item_skadi", "item_butterfly", "item_satanic", "item_black_king_bar",
            "item_monkey_king_bar", "item_heart"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_desolator",
            "item_diffusal_blade"
        },
        reason_good = "Mana + attack speed for Stone Gaze",
        reason_bad = "BF/Deso don't fit Medusa's split shot"
    },
    npc_dota_hero_luna = {
        good_items = {
            "item_mask_of_madness", "item_maelstrom", "item_mjollnir",
            "item_black_king_bar", "item_satanic", "item_butterfly",
            "item_skadi", "item_monkey_king_bar", "item_hurricane_pike"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_desolator"
        },
        reason_good = "Glaives + Eclipse synergy",
        reason_bad = "BF doesn't work with Glaives"
    },
    npc_dota_hero_sven = {
        good_items = {
            "item_mask_of_madness", "item_blink", "item_black_king_bar",
            "item_satanic", "item_abyssal_blade", "item_swift_blink",
            "item_monkey_king_bar", "item_assault"
        },
        bad_items = {
            "item_radiance", "item_hand_of_midas", "item_mjollnir"
        },
        reason_good = "Blink + God's Strength burst",
        reason_bad = "Radiance doesn't fit Sven's burst"
    },
    npc_dota_hero_troll_warlord = {
        good_items = {
            "item_mask_of_madness", "item_black_king_bar", "item_satanic",
            "item_butterfly", "item_skadi", "item_abyssal_blade",
            "item_monkey_king_bar", "item_silver_edge"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Attack speed + bash synergy",
        reason_bad = "BF/Radiance don't fit Troll's fight style"
    },
    npc_dota_hero_life_stealer = {
        good_items = {
            "item_desolator", "item_sange_and_yasha", "item_black_king_bar",
            "item_satanic", "item_skadi", "item_abyssal_blade",
            "item_monkey_king_bar", "item_silver_edge"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Lifesteal + Rage synergy",
        reason_bad = "BF/Radiance don't fit LS's style"
    },
    npc_dota_hero_huskar = {
        good_items = {
            "item_armlet", "item_black_king_bar", "item_satanic", "item_skadi",
            "item_heart", "item_heavens_halberd", "item_spirit_vessel"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir", "item_monkey_king_bar"
        },
        reason_good = "Armlet + Berserker's Blood synergy",
        reason_bad = "BF/Radiance don't fit Huskar's magic damage"
    },
    npc_dota_hero_bloodseeker = {
        good_items = {
            "item_maelstrom", "item_mjollnir", "item_black_king_bar",
            "item_sange_and_yasha", "item_butterfly", "item_satanic",
            "item_monkey_king_bar", "item_abyssal_blade"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Attack speed + Blood Rite synergy",
        reason_bad = "BF doesn't fit BS's chase style"
    },
    npc_dota_hero_broodmother = {
        good_items = {
            "item_soul_ring", "item_black_king_bar", "item_butterfly",
            "item_satanic", "item_skadi", "item_monkey_king_bar",
            "item_abyssal_blade", "item_assault"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Spiderlings + lifesteal synergy",
        reason_bad = "BF doesn't help Brood's spider army"
    },
    npc_dota_hero_lycan = {
        good_items = {
            "item_vladmir", "item_black_king_bar", "item_assault",
            "item_abyssal_blade", "item_satanic", "item_monkey_king_bar",
            "item_desolator"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Wolves + Shapeshift synergy",
        reason_bad = "BF doesn't help Lycan's summons"
    },
    npc_dota_hero_lone_druid = {
        good_items = {
            "item_soul_ring", "item_black_king_bar", "item_assault",
            "item_butterfly", "item_satanic", "item_monkey_king_bar",
            "item_abyssal_blade", "item_skadi"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Spirit Bear + items synergy",
        reason_bad = "BF doesn't help Spirit Bear"
    },
    -- ══════════════ Mid Heroes ══════════════
    npc_dota_hero_invoker = {
        good_items = {
            "item_aghanims_scepter", "item_black_king_bar", "item_blink",
            "item_octarine_core", "item_sheepstick", "item_refresher",
            "item_arcane_blink", "item_sphere"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Spell amp + CDR for Invoker",
        reason_bad = "Right-click items don't fit Invoker"
    },
    npc_dota_hero_storm_spirit = {
        good_items = {
            "item_bloodstone", "item_black_king_bar", "item_sheepstick",
            "item_octarine_core", "item_sphere", "item_arcane_blink",
            "item_orchid", "item_shivas_guard"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Mana + spell amp for Ball Lightning",
        reason_bad = "Right-click items don't fit Storm"
    },
    npc_dota_hero_ember_spirit = {
        good_items = {
            "item_battlefury", "item_black_king_bar", "item_maelstrom",
            "item_mjollnir", "item_sheepstick", "item_blink",
            "item_swift_blink", "item_satanic"
        },
        bad_items = {
            "item_radiance", "item_hand_of_midas", "item_desolator"
        },
        reason_good = "BF + Sleight of Fist synergy",
        reason_bad = "Radiance doesn't fit Ember's style"
    },
    npc_dota_hero_tinker = {
        good_items = {
            "item_blink", "item_aether_lens", "item_sheepstick",
            "item_octarine_core", "item_dagon", "item_ethereal_blade",
            "item_arcane_blink", "item_sphere"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Rearm + active items synergy",
        reason_bad = "Right-click items don't fit Tinker"
    },
    npc_dota_hero_zuus = {
        good_items = {
            "item_aether_lens", "item_octarine_core", "item_sheepstick",
            "item_refresher", "item_aghanims_scepter", "item_dagon",
            "item_ethereal_blade", "item_kaya_and_sange"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_blink"
        },
        reason_good = "Spell amp + global presence",
        reason_bad = "Right-click items don't fit Zeus"
    },
    npc_dota_hero_puck = {
        good_items = {
            "item_blink", "item_aether_lens", "item_octarine_core",
            "item_sheepstick", "item_sphere", "item_arcane_blink",
            "item_gungir", "item_wind_waker"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Mobility + spell amp for Puck",
        reason_bad = "Right-click items don't fit Puck"
    },
    npc_dota_hero_queenofpain = {
        good_items = {
            "item_blink", "item_aether_lens", "item_octarine_core",
            "item_sheepstick", "item_sphere", "item_arcane_blink",
            "item_orchid", "item_dagon"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Blink + spell burst synergy",
        reason_bad = "Right-click items don't fit QoP"
    },
    npc_dota_hero_lina = {
        good_items = {
            "item_aether_lens", "item_octarine_core", "item_sheepstick",
            "item_sphere", "item_black_king_bar", "item_agonys_scepter",
            "item_dagon", "item_kaya_and_sange"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Spell amp + Laguna Blade burst",
        reason_bad = "BF doesn't fit Lina's magic burst"
    },
    npc_dota_hero_leshrac = {
        good_items = {
            "item_bloodstone", "item_black_king_bar", "item_octarine_core",
            "item_sheepstick", "item_sphere", "item_shivas_guard",
            "item_kaya_and_sange"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator"
        },
        reason_good = "Mana + spell amp for Leshrac",
        reason_bad = "Right-click items don't fit Leshrac"
    },
    npc_dota_hero_void_spirit = {
        good_items = {
            "item_blink", "item_aether_lens", "item_octarine_core",
            "item_sheepstick", "item_sphere", "item_arcane_blink",
            "item_kaya_and_sange", "item_shivas_guard"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Mobility + spell amp for Void Spirit",
        reason_bad = "Right-click items don't fit Void Spirit"
    },
    npc_dota_hero_obsidian_destroyer = {
        good_items = {
            "item_aether_lens", "item_octarine_core", "item_sheepstick",
            "item_sphere", "item_black_king_bar", "item_aghanims_scepter",
            "item_refresher", "item_wind_waker"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_mjollnir"
        },
        reason_good = "Int + spell amp for Arcane Orb",
        reason_bad = "Attack speed items don't scale with Arcane Orb"
    },
    -- ══════════════ Offlane Heroes ══════════════
    npc_dota_hero_axe = {
        good_items = {
            "item_vanguard", "item_blink", "item_blade_mail", "item_black_king_bar",
            "item_shivas_guard", "item_heart", "item_overwhelming_blink",
            "item_crimson_guard"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Tank + Counter Helix synergy",
        reason_bad = "DPS items don't fit Axe's tank role"
    },
    npc_dota_hero_tidehunter = {
        good_items = {
            "item_vanguard", "item_pipe", "item_crimson_guard", "item_shivas_guard",
            "item_heart", "item_blink", "item_refresher", "item_aghanims_scepter"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Tank + Ravage initiation",
        reason_bad = "DPS items don't fit Tide's tank role"
    },
    npc_dota_hero_bristleback = {
        good_items = {
            "item_vanguard", "item_blade_mail", "item_crimson_guard",
            "item_shivas_guard", "item_heart", "item_spirit_vessel",
            "item_holy_locket", "item_aghanims_scepter"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Tank + Quill Spray synergy",
        reason_bad = "DPS items don't fit BB's tank role"
    },
    npc_dota_hero_mars = {
        good_items = {
            "item_vanguard", "item_blink", "item_black_king_bar",
            "item_shivas_guard", "item_heart", "item_overwhelming_blink",
            "item_desolator", "item_assault"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_mjollnir"
        },
        reason_good = "Initiation + Arena synergy",
        reason_bad = "BF doesn't fit Mars's spell-based style"
    },
    npc_dota_hero_centaur = {
        good_items = {
            "item_vanguard", "item_blink", "item_blade_mail", "item_black_king_bar",
            "item_heart", "item_overwhelming_blink", "item_shivas_guard"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Tank + Double Edge synergy",
        reason_bad = "DPS items don't fit Centaur's tank role"
    },
    npc_dota_hero_legion_commander = {
        good_items = {
            "item_vanguard", "item_blink", "item_blade_mail", "item_black_king_bar",
            "item_desolator", "item_abyssal_blade", "item_overwhelming_blink",
            "item_assault"
        },
        bad_items = {
            "item_radiance", "item_hand_of_midas", "item_mjollnir"
        },
        reason_good = "Blink + Duel damage stacking",
        reason_bad = "Radiance doesn't fit LC's duel style"
    },
    npc_dota_hero_doom_bringer = {
        good_items = {
            "item_vanguard", "item_blink", "item_shivas_guard", "item_heart",
            "item_overwhelming_blink", "item_refresher", "item_aghanims_scepter"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Tank + Doom disable",
        reason_bad = "DPS items don't fit Doom's utility role"
    },
    npc_dota_hero_sand_king = {
        good_items = {
            "item_blink", "item_black_king_bar", "item_shivas_guard",
            "item_heart", "item_overwhelming_blink", "item_refresher",
            "item_aghanims_scepter"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Blink + Epicenter initiation",
        reason_bad = "DPS items don't fit SK's initiator role"
    },
    npc_dota_hero_dark_seer = {
        good_items = {
            "item_vanguard", "item_blink", "item_shivas_guard", "item_heart",
            "item_refresher", "item_aghanims_scepter", "item_octarine_core"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Tank + Wall of Replica synergy",
        reason_bad = "DPS items don't fit DS's utility role"
    },
    npc_dota_hero_batrider = {
        good_items = {
            "item_blink", "item_black_king_bar", "item_shivas_guard",
            "item_heart", "item_overwhelming_blink", "item_sphere",
            "item_force_staff"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar"
        },
        reason_good = "Blink + Lasso initiation",
        reason_bad = "DPS items don't fit Batrider's initiator role"
    },
    npc_dota_hero_pangolier = {
        good_items = {
            "item_maelstrom", "item_mjollnir", "item_black_king_bar",
            "item_blink", "item_satanic", "item_abyssal_blade",
            "item_swift_blink", "item_monkey_king_bar"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas"
        },
        reason_good = "Attack speed + Rolling Thunder synergy",
        reason_bad = "BF doesn't fit Pangolier's style"
    },
    -- ══════════════ Support Heroes ══════════════
    npc_dota_hero_lion = {
        good_items = {
            "item_aether_lens", "item_blink", "item_aghanims_scepter",
            "item_octarine_core", "item_dagon", "item_sphere",
            "item_arcane_blink"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Spell amp + Finger burst",
        reason_bad = "DPS items don't fit Lion's support role"
    },
    npc_dota_hero_shadow_shaman = {
        good_items = {
            "item_aether_lens", "item_blink", "item_aghanims_scepter",
            "item_octarine_core", "item_refresher", "item_sphere",
            "item_arcane_blink"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Spell amp + Wards push",
        reason_bad = "DPS items don't fit Shaman's support role"
    },
    npc_dota_hero_crystal_maiden = {
        good_items = {
            "item_aether_lens", "item_blink", "item_black_king_bar",
            "item_aghanims_scepter", "item_octarine_core", "item_sphere",
            "item_glimmer_cape"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Spell amp + Freezing Field",
        reason_bad = "DPS items don't fit CM's support role"
    },
    npc_dota_hero_dazzle = {
        good_items = {
            "item_aether_lens", "item_glimmer_cape", "item_force_staff",
            "item_aghanims_scepter", "item_octarine_core", "item_sphere",
            "item_holy_locket"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Heal amp + save items",
        reason_bad = "DPS items don't fit Dazzle's support role"
    },
    npc_dota_hero_oracle = {
        good_items = {
            "item_aether_lens", "item_glimmer_cape", "item_force_staff",
            "item_aghanims_scepter", "item_octarine_core", "item_sphere",
            "item_holy_locket", "item_wind_waker"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Heal amp + save items",
        reason_bad = "DPS items don't fit Oracle's support role"
    },
    npc_dota_hero_witch_doctor = {
        good_items = {
            "item_aether_lens", "item_glimmer_cape", "item_black_king_bar",
            "item_aghanims_scepter", "item_octarine_core", "item_sphere",
            "item_dagon"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Spell amp + Death Ward",
        reason_bad = "DPS items don't fit WD's support role"
    },
    npc_dota_hero_warlock = {
        good_items = {
            "item_aether_lens", "item_glimmer_cape", "item_aghanims_scepter",
            "item_octarine_core", "item_refresher", "item_sphere"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Spell amp + Golem push",
        reason_bad = "DPS items don't fit Warlock's support role"
    },
    npc_dota_hero_ancient_apparition = {
        good_items = {
            "item_aether_lens", "item_aghanims_scepter", "item_octarine_core",
            "item_sphere", "item_shivas_guard", "item_wind_waker"
        },
        bad_items = {
            "item_battlefury", "item_radiance", "item_hand_of_midas",
            "item_desolator", "item_monkey_king_bar", "item_satanic"
        },
        reason_good = "Spell amp + Ice Blast global",
        reason_bad = "DPS items don't fit AA's support role"
    },
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
    -- Prefer live game data when available; fallback to local table for aliases/undocumented cases.
    local ok, liveCost = pcall(GameRules.GetItemCost, itemName)
    if ok and liveCost and liveCost > 0 then return liveCost end
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

local ITEM_LOOKUP = {}
for _, item in ipairs(ITEM_DB) do
    ITEM_LOOKUP[item.name] = item
end

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
    local analysisTab = mainTab:Create("Analysis")
    local panelTab = mainTab:Create("Panel")
    local dataTab = mainTab:Create("Data/Filters")
    local debugTab = mainTab:Create("Debug")

    UI.enabled       = analysisTab:Switch("Enable Helper", true, "\u{f00c}")
    UI.autoAnalyze   = analysisTab:Switch("Auto Analyze", true)
    UI.maxItems      = analysisTab:Slider("Max Suggestions", 3, 10, 6, "%d")
    UI.showReasons   = analysisTab:Switch("Show Reasons", true)
    UI.showThreats   = analysisTab:Switch("Show Threat Analysis", true)
    UI.trackEnemyItems = analysisTab:Switch("Track Enemy Items", true)
    UI.showHeroCounters = analysisTab:Switch("Show Hero Counters", true)
    UI.showNetWorth   = analysisTab:Switch("Show Net Worth Analysis", true)
    UI.showEnemyFocus = analysisTab:Switch("Show Enemy Focus Rows", true)
    UI.enemyFocusRows = analysisTab:Slider("Enemy Focus Rows", 1, 6, 3, "%d")
    UI.showNeutrals  = analysisTab:Switch("Show Neutral Items", true)

    UI.showPanel     = panelTab:Switch("Show Panel", true)
    UI.showOwned     = panelTab:Switch("Highlight Owned", true)
    UI.showGoldHeader = panelTab:Switch("Show Gold in Header", true)
    UI.scale      = panelTab:Slider("Panel Scale %", 60, 150, 100, "%d")
    UI.offX       = panelTab:Slider("Offset X", -800, 800, 0, "%d")
    UI.offY       = panelTab:Slider("Offset Y", -600, 600, 0, "%d")
    UI.opacity    = panelTab:Slider("Opacity %", 20, 100, 85, "%d")
    UI.panelSide  = panelTab:Combo("Panel Side", {"Left", "Right"}, 0)
    UI.visMode    = panelTab:Combo("Show Mode", {"Always", "Cheat Menu Only", "Shop Only", "Menu or Shop"}, 0)

    UI.enemyFilterMode = dataTab:Combo("Enemy Filter Mode",
        {"Use All Enemies", "Only Selected", "Exclude Selected"}, 0)
    UI.enemyFilterMode:ToolTip("Control whether analysis uses every detected enemy, only heroes you pick below, or excludes them.")
    UI.enemyFilterList = dataTab:MultiSelect("Filter Enemy Heroes", {}, false)
    UI.enemyFilterList:ToolTip("Icons appear once enemy heroes are detected. Toggle heroes to focus on or remove from analysis.")

    UI.showCategoryBadges = debugTab:Switch("Show Category Badges", true)
    UI.showScoreBreakdown = debugTab:Switch("Show Score Breakdown", true)
    UI.breakdownChipCount = debugTab:Slider("Breakdown Chips", 1, 4, 2, "%d")
    UI.showScoreBreakdown:ToolTip("Shows compact scoring contribution chips on item cards.")
    UI.showCategoryBadges:ToolTip("Shows MUST / SITUATIONAL / LUXURY category on item cards.")
    UI.showGoldHeader:ToolTip("Disable if local gold reading is incorrect on your build.")
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
    enemyFilterSnapshot = {},  -- cached order for MultiSelect updates
    enemyFocus      = {},
    activeEnemyCount = 0,
    myGold          = 0,
    myGoldKnown     = false,
    rawGameModeId   = -1,
    playerCount     = 0,
    testContextKind = nil, -- "tryhero" | "lobby" | "custom" | nil
    myHeroName      = "",
    gamePhase       = PHASE_EARLY,
    gameMode        = GAME_MODE.UNKNOWN,  -- Current game mode
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
    clickRegions     = {},      -- interactive item card regions
    hoveredRegion    = nil,     -- current hovered click region
    panelVisible     = false,   -- last panel draw visibility state
    panelRect        = nil,     -- last panel bounds for hit-tests
}

--------------------------------------------------------------------------------
-- FONTS
--------------------------------------------------------------------------------
local FC = {}
local fontsReady = false

local function getFont(sz)
    sz = math.max(8, math.floor(sz))
    if FC[sz] then return FC[sz] end
    local flags = Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS or nil

    -- Prefer legacy API used by this script/build first, then try Render v2.
    local ok, f = pcall(function()
        if Render.LoadFont then
            return Render.LoadFont("Inter", flags, 500)
        end
    end)
    if ok and f then FC[sz] = f; fontsReady = true; return f end

    ok, f = pcall(function()
        if Render.CreateFont then
            local weight = (Enum.FontWeight and Enum.FontWeight.NORMAL) or 400
            return Render.CreateFont("Inter", sz, weight, flags)
        end
    end)
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

-- Detect game mode from GameRules
local function detectGameMode()
    local ok, mode = pcall(GameRules.GetGameMode)
    if not ok or not mode then return GAME_MODE.UNKNOWN end
    
    -- Game mode IDs from Dota 2
    local GAME_MODE_IDS = {
        [0] = GAME_MODE.UNKNOWN,       -- None
        [1] = GAME_MODE.ALL_PICK,      -- All Pick
        [2] = GAME_MODE.CAPTAINS_MODE, -- Captain's Mode
        [3] = GAME_MODE.SINGLE_DRAFT,  -- Single Draft
        [4] = GAME_MODE.ALL_RANDOM,    -- All Random
        [5] = GAME_MODE.UNKNOWN,       -- Random Draft (treated as normal)
        [6] = GAME_MODE.UNKNOWN,       -- Intro
        [7] = GAME_MODE.UNKNOWN,       -- Diretide
        [8] = GAME_MODE.UNKNOWN,       -- Reverse Captain's Mode
        [9] = GAME_MODE.UNKNOWN,       -- Greeviling
        [10] = GAME_MODE.UNKNOWN,      -- Tutorial
        [11] = GAME_MODE.UNKNOWN,      -- Mid Only
        [12] = GAME_MODE.UNKNOWN,      -- Least Played
        [13] = GAME_MODE.UNKNOWN,      -- Limited Heroes
        [14] = GAME_MODE.UNKNOWN,      -- Compendium Matchmaking
        [15] = GAME_MODE.UNKNOWN,      -- Custom
        [16] = GAME_MODE.CAPTAINS_MODE,-- Captain's Draft
        [17] = GAME_MODE.UNKNOWN,      -- Balanced Draft
        [18] = GAME_MODE.ABILITY_DRAFT,-- Ability Draft
        [19] = GAME_MODE.UNKNOWN,      -- Event
        [20] = GAME_MODE.ALL_RANDOM,   -- All Random Death Match
        [21] = GAME_MODE.TURBO,        -- Turbo Mode (1vs1 Mid but also used for Turbo)
        [22] = GAME_MODE.TURBO,        -- Turbo Mode
        [23] = GAME_MODE.UNKNOWN,      -- Mutation
    }
    
    local detectedMode = GAME_MODE_IDS[mode] or GAME_MODE.UNKNOWN
    
    -- Check for Turbo specifically via console variable or game rules
    local ok2, isTurbo = pcall(GameRules.IsTurboMode)
    if ok2 and isTurbo then
        return GAME_MODE.TURBO
    end
    
    -- Check for Ranked via IsRankedMatch
    local ok3, isRanked = pcall(GameRules.IsRankedMatch)
    if ok3 and isRanked then
        return GAME_MODE.RANKED
    end
    
    return detectedMode
end

local function prettyHero(name)
    local n = name:gsub("npc_dota_hero_", ""):gsub("_", " ")
    n = n:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end)
    if #n > 16 then n = n:sub(1, 14) .. ".." end
    return n
end

local function screenSz()
    local ok, r = pcall(function()
        if Render.ScreenSize then return Render.ScreenSize() end
        if Render.GetScreenSize then return Render.GetScreenSize() end
        if Engine.GetScreenSize then return Engine.GetScreenSize() end
    end)
    if ok and r then
        if type(r) == "userdata" or type(r) == "table" then return r.x or 1920, r.y or 1080 end
    end
    return 1920, 1080
end

local function safeStatic(tbl, method, ...)
    if not tbl then return nil end
    local okLookup, fn = pcall(function() return tbl[method] end)
    if not okLookup or not fn then return nil end
    local ok, r = pcall(fn, ...)
    return ok and r or nil
end

local function safeMethod(obj, method, ...)
    if not obj then return nil end
    local okLookup, fn = pcall(function() return obj[method] end)
    if not okLookup or not fn then return nil end

    -- Prefer regular method call with self, then fall back to bindings that don't expect self.
    local ok, r = pcall(fn, obj, ...)
    if ok then return r end

    ok, r = pcall(fn, ...)
    return ok and r or nil
end

local function numOrNil(v)
    if v == nil then return nil end
    if type(v) == "number" then return v end
    local ok, n = pcall(tonumber, v)
    if ok then return n end
    return nil
end

local function findPlayerByID(playerID)
    if not playerID or playerID < 0 then return nil end
    local allPlayers = safeStatic(Players, "GetAll")
    if allPlayers then
        for _, p in ipairs(allPlayers) do
            local pid = safeMethod(p, "GetPlayerID") or safeStatic(Player, "GetPlayerID", p)
            if pid == playerID then
                return p
            end
        end
    end
    return nil
end

local function getLocalPlayerObject()
    local p = safeStatic(Players, "GetLocal")
    if p then return p end
    p = safeStatic(Player, "GetLocal")
    if p then return p end

    local me = safeStatic(Heroes, "GetLocal")
    if not me then return nil end
    p = safeMethod(me, "GetPlayer")
    if p then return p end
    local playerID = safeMethod(me, "GetPlayerID")
    if playerID and playerID >= 0 then
        return findPlayerByID(playerID)
    end
    return nil
end

local function getPlayerCurrentGold(player)
    if not player then return nil end

    local g = numOrNil(safeMethod(player, "GetGold")) or numOrNil(safeStatic(Player, "GetGold", player))
    if g and g >= 0 then return g end

    local rg = numOrNil(safeMethod(player, "GetReliableGold")) or numOrNil(safeStatic(Player, "GetReliableGold", player))
    local ug = numOrNil(safeMethod(player, "GetUnreliableGold")) or numOrNil(safeStatic(Player, "GetUnreliableGold", player))
    if rg and ug then
        local s = rg + ug
        if s >= 0 then return s end
    end

    local tg = numOrNil(safeMethod(player, "GetTotalGold")) or numOrNil(safeStatic(Player, "GetTotalGold", player))
    if tg and tg >= 0 then return tg end

    return nil
end

local function getHeroCurrentGold(hero)
    if not hero then return nil end
    local g = numOrNil(safeMethod(hero, "GetGold")) or numOrNil(safeStatic(Heroes, "GetGold", hero))
    if g and g >= 0 then return g end
    local rg = numOrNil(safeMethod(hero, "GetReliableGold")) or numOrNil(safeStatic(Heroes, "GetReliableGold", hero))
    local ug = numOrNil(safeMethod(hero, "GetUnreliableGold")) or numOrNil(safeStatic(Heroes, "GetUnreliableGold", hero))
    if rg and ug then
        local s = rg + ug
        if s >= 0 then return s end
    end
    return nil
end

local function refreshMyGold()
    local p = getLocalPlayerObject()
    local g = getPlayerCurrentGold(p)
    if g == nil then
        g = getHeroCurrentGold(safeStatic(Heroes, "GetLocal"))
    end
    if g ~= nil then
        S.myGold = g
        S.myGoldKnown = true
        return g
    end
    S.myGoldKnown = false
    return S.myGold or 0
end

local function refreshRuntimeTestContext()
    local modeId = numOrNil(safeStatic(GameRules, "GetGameMode"))
    local playerCount = numOrNil(safeStatic(Players, "Count"))
    if playerCount == nil then
        local all = safeStatic(Players, "GetAll")
        if all then playerCount = #all end
    end
    local localPlayer = getLocalPlayerObject()
    local localHero = (localPlayer and safeMethod(localPlayer, "GetHero")) or safeStatic(Heroes, "GetLocal")

    S.rawGameModeId = modeId or -1
    S.playerCount = playerCount or 0
    S.testContextKind = nil

    -- Heuristic: "Try Hero" and most sandbox lobbies run as custom mode (15).
    if modeId == 15 then
        if localHero and (not playerCount or playerCount <= 1) then
            S.testContextKind = "tryhero"
        elseif playerCount and playerCount > 1 then
            S.testContextKind = "lobby"
        else
            S.testContextKind = "custom"
        end
    end
end

local function StyleColor(style, key, alphaOverride)
    if not style then return col(200, 200, 200, alphaOverride or 255) end
    local c = style[key]
    if not c then return col(200, 200, 200, alphaOverride or 255) end
    return Color(c.r or 200, c.g or 200, c.b or 200, alphaOverride or c.a or 255)
end

local function getEnemyFilterValue(name)
    if not UI.enemyFilterList or not UI.enemyFilterList.Get then return nil end
    local ok, val = pcall(function() return UI.enemyFilterList:Get(name) end)
    if ok then return val end
    return nil
end

local function shouldIncludeEnemy(name)
    local mode = sg(UI.enemyFilterMode, 0)
    if mode == 0 or not UI.enemyFilterList then return true end
    local selected = getEnemyFilterValue(name)
    if mode == 1 then
        return selected == true
    elseif mode == 2 then
        return selected ~= true
    end
    return true
end

local function refreshEnemyFilterList()
    if not UI.enemyFilterList or not UI.enemyFilterList.Update then return end
    if #S.enemyHeroes == 0 then
        S.enemyFilterSnapshot = {}
        UI.enemyFilterList:Update({}, true)
        return
    end

    local names = {}
    for _, enemy in ipairs(S.enemyHeroes) do
        table.insert(names, enemy.name)
    end

    local changed = #names ~= #S.enemyFilterSnapshot
    if not changed then
        for i, name in ipairs(names) do
            if name ~= S.enemyFilterSnapshot[i] then
                changed = true
                break
            end
        end
    end

    if not changed then return end

    local entries = {}
    for _, name in ipairs(names) do
        local icon = "panorama/images/heroes/icons/" .. name .. "_png.vtex_c"
        local defaultOn = getEnemyFilterValue(name)
        if defaultOn == nil then defaultOn = false end
        table.insert(entries, {name, icon, defaultOn})
    end

    UI.enemyFilterList:Update(entries, true)
    S.enemyFilterSnapshot = names
end

local function buildTagCounts(tags)
    local counts = {}
    if not tags then return counts end
    for _, tag in ipairs(tags) do
        counts[tag] = (counts[tag] or 0) + 1
    end
    return counts
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

local function shortText(txt, limit)
    txt = txt or ""
    if #txt <= limit then return txt end
    return txt:sub(1, math.max(1, limit - 2)) .. ".."
end

local tSz

local function shortTextByWidth(sz, txt, maxW)
    txt = tostring(txt or "")
    if txt == "" then return txt end
    if maxW <= 6 then return "" end
    if tSz(sz, txt).x <= maxW then return txt end

    local suffix = ".."
    local out = txt
    while #out > 1 and tSz(sz, out .. suffix).x > maxW do
        out = out:sub(1, #out - 1)
    end
    if out == "" then return suffix end
    return out .. suffix
end

local function applyRolePenalty(score, itemName, myRole, myStyle)
    if score <= 0 then return score end
    if not myRole and not myStyle then return score end
    local penalty = ITEM_ROLE_PENALTY[itemName]
    if not penalty then return score end
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
        score = math.max(1, math.floor(score * 0.15))
    end
    return score
end

local function itemHasTag(itemDef, tag)
    if not itemDef.tags then return false end
    for _, t in ipairs(itemDef.tags) do
        if t == tag then return true end
    end
    return false
end

local function stylePreferenceBonus(itemDef, ctx)
    if not itemDef.tags or not ctx then return 0 end
    local bonus = 0
    local tags = itemDef.tags
    local role = ctx.myRole
    local style = ctx.myStyle

    if style == "phys" and (tableContains(tags, "phys_dps") or tableContains(tags, "attack_speed")) then
        bonus = bonus + 2
    elseif style == "magic" and (tableContains(tags, "magic_burst") or tableContains(tags, "magic_amp") or tableContains(tags, "mana")) then
        bonus = bonus + 2
    elseif style == "utility" and (tableContains(tags, "team") or tableContains(tags, "save") or tableContains(tags, "dispel")) then
        bonus = bonus + 2
    elseif style == "hybrid" and (tableContains(tags, "phys_dps") and tableContains(tags, "magic_burst")) then
        bonus = bonus + 2
    end

    if role == "support" or role == "hardsupport" then
        if tableContains(tags, "team") or tableContains(tags, "save") or tableContains(tags, "heal") then
            bonus = bonus + 2
        end
    elseif role == "carry" and (tableContains(tags, "phys_dps") or tableContains(tags, "farm")) then
        bonus = bonus + 1
    end

    return bonus
end

local function applyHeroSpecificAdjust(score, heroName, itemName)
    if score <= 0 then return score end
    local spec = HERO_SPECIFIC_ITEMS[heroName]
    if not spec then return score end
    if spec.good_items then
        for _, good in ipairs(spec.good_items) do
            if good == itemName then
                score = score + 10
                break
            end
        end
    end
    if spec.bad_items then
        for _, bad in ipairs(spec.bad_items) do
            if bad == itemName then
                score = math.max(1, math.floor(score * 0.1))
                break
            end
        end
    end
    return score
end

local function computeItemScore(itemDef, ctx, withBreakdown)
    if not itemDef or not ctx then return 0, nil end
    if not tableContains(itemDef.phase, ctx.phase) then return 0, nil end
    if ctx.ownedItems and ctx.ownedItems[itemDef.name] then return -1, nil end

    local enemyTags = ctx.enemyTags or {}
    local score = 0
    local breakMap = withBreakdown and {} or nil

    local function addBreak(key, delta)
        if not breakMap or not key or not delta or delta == 0 then return end
        delta = math.floor(delta)
        if delta == 0 then return end
        breakMap[key] = (breakMap[key] or 0) + delta
    end

    if itemDef.triggers then
        for _, tr in ipairs(itemDef.triggers) do
            local cnt = enemyTags[tr] or 0
            if cnt > 0 then
                local d = cnt * 4
                score = score + d
                addBreak("trigger:" .. tr, d)
            end
        end
    end

    for _, rule in ipairs(COUNTER_RULES) do
        local totalEnemyTags = 0
        local matched = true
        for _, rTag in ipairs(rule.tags) do
            local cnt = enemyTags[rTag] or 0
            if cnt <= 0 then matched = false; break end
            totalEnemyTags = totalEnemyTags + cnt
        end
        if matched then
            local itemMatch = countMatches(itemDef.tags or {}, rule.suggest)
            if itemMatch > 0 then
                local d = itemMatch * rule.weight * math.max(1, totalEnemyTags)
                score = score + d
                addBreak("counter_rules", d)
            end
        end
    end

    if score > 0 and ctx.myGoldKnown and ctx.myGold and ctx.myGold >= itemDef.cost then
        score = score + 2
        addBreak("affordable", 2)
    end

    do
        local before = score
        score = applyRolePenalty(score, itemDef.name, ctx.myRole, ctx.myStyle)
        addBreak("role_penalty", score - before)
    end

    do
        local d = stylePreferenceBonus(itemDef, ctx)
        if d ~= 0 then
            score = score + d
            addBreak("style_bonus", d)
        end
    end

    if ctx.trackEnemyItems and ctx.enemyItemCounts then
        local counts = ctx.enemyItemCounts
        local bkbCount = counts["item_black_king_bar"] or 0
        if bkbCount > 0 and (itemDef.name == "item_nullifier" or itemDef.name == "item_abyssal_blade") then
            local d = bkbCount * 8
            score = score + d
            addBreak("enemy_item:bkb", d)
        end
        local linkenCount = counts["item_sphere"] or 0
        if linkenCount > 0 and itemDef.tags and tableContains(itemDef.tags, "disable") then
            local d = linkenCount * 4
            score = score + d
            addBreak("enemy_item:linkens", d)
        end
        local aeonCount = counts["item_aeon_disk"] or 0
        if aeonCount > 0 and itemDef.name == "item_nullifier" then
            local d = aeonCount * 6
            score = score + d
            addBreak("enemy_item:aeon", d)
        end
        local ghostCount = counts["item_ghost"] or 0
        if ghostCount > 0 and (itemDef.name == "item_ethereal_blade" or itemDef.name == "item_nullifier") then
            local d = ghostCount * 5
            score = score + d
            addBreak("enemy_item:ghost", d)
        end
        local glimmerCount = counts["item_glimmer_cape"] or 0
        if glimmerCount > 0 and (itemDef.name == "item_dust" or itemDef.name == "item_nullifier") then
            local d = glimmerCount * 4
            score = score + d
            addBreak("enemy_item:glimmer", d)
        end
        local bladeMailCount = counts["item_blade_mail"] or 0
        if bladeMailCount > 0 and itemDef.tags and (tableContains(itemDef.tags, "lifesteal") or tableContains(itemDef.tags, "vs_phys")) then
            local d = bladeMailCount * 3
            score = score + d
            addBreak("enemy_item:blademail", d)
        end
    end

    if ctx.showNetWorth and ctx.gameTempo then
        local before = score
        if ctx.gameTempo == "ahead" and itemDef.cost >= 4000 and itemHasTag(itemDef, "phys_dps") then
            score = score + 3
        elseif ctx.gameTempo == "behind" then
            if itemDef.cost < 3000 and (itemHasTag(itemDef, "vs_phys") or itemHasTag(itemDef, "vs_magic") or itemHasTag(itemDef, "save")) then
                score = score + 4
            end
            if itemDef.cost >= 5000 then
                score = math.max(1, math.floor(score * 0.5))
            end
        end
        addBreak("tempo", score - before)
    end

    local modeMultipliers = MODE_PHASE_MULTIPLIERS[ctx.gameMode or GAME_MODE.UNKNOWN] or MODE_PHASE_MULTIPLIERS[GAME_MODE.UNKNOWN]
    local phaseKey = ctx.phase == PHASE_EARLY and "early" or (ctx.phase == PHASE_MID and "mid" or "late")
    local multiplier = modeMultipliers[phaseKey] or 1.0

    do
        local before = score
        if ctx.gameMode == GAME_MODE.TURBO then
            if itemDef.cost < 1500 and tableContains(itemDef.phase, PHASE_EARLY) and not tableContains(itemDef.phase, PHASE_MID) then
                score = math.max(1, math.floor(score * 0.3))
            end
            if itemDef.cost >= 3000 then
                score = score + 3
            end
        elseif ctx.gameMode == GAME_MODE.RANKED and itemDef.cost >= 2000 and itemDef.cost <= 5000 then
            score = score + 1
        end
        addBreak("mode_adjust", score - before)
    end

    do
        local before = score
        score = math.floor(score * multiplier)
        addBreak("phase_mult", score - before)
    end

    do
        local before = score
        score = applyHeroSpecificAdjust(score, ctx.heroName, itemDef.name)
        addBreak("hero_specific", score - before)
    end

    if not breakMap then
        return score, nil
    end

    local breakdown = {}
    for key, delta in pairs(breakMap) do
        if delta ~= 0 then
            table.insert(breakdown, {key = key, delta = delta})
        end
    end
    table.sort(breakdown, function(a, b)
        local aa = math.abs(a.delta or 0)
        local bb = math.abs(b.delta or 0)
        if aa ~= bb then return aa > bb end
        if (a.delta or 0) ~= (b.delta or 0) then return (a.delta or 0) > (b.delta or 0) end
        return tostring(a.key) < tostring(b.key)
    end)
    table.insert(breakdown, {key = "final", delta = score})
    return score, breakdown
end

local function sumBreakdownPrefix(breakdown, prefix)
    local total = 0
    for _, entry in ipairs(breakdown or {}) do
        local k = tostring(entry.key or "")
        if k:find(prefix, 1, true) == 1 and (entry.delta or 0) > 0 then
            total = total + (entry.delta or 0)
        end
    end
    return total
end

local function breakdownKeyLabel(key)
    if not key then return "" end
    if key == "counter_rules" then return "counter rules" end
    if key == "affordable" then return "affordable" end
    if key == "role_penalty" then return "role penalty" end
    if key == "style_bonus" then return "hero style" end
    if key == "tempo" then return "tempo" end
    if key == "mode_adjust" then return "mode" end
    if key == "phase_mult" then return "phase" end
    if key == "hero_specific" then return "hero fit" end
    if key == "enemy_item:bkb" then return "vs BKB" end
    if key == "enemy_item:linkens" then return "vs Linken" end
    if key == "enemy_item:aeon" then return "vs Aeon" end
    if key == "enemy_item:ghost" then return "vs Ghost" end
    if key == "enemy_item:glimmer" then return "vs Glimmer" end
    if key == "enemy_item:blademail" then return "vs BM" end
    if key:find("trigger:", 1, true) == 1 then
        return key:sub(9):gsub("_", " ")
    end
    return tostring(key):gsub("_", " ")
end

local function classifySuggestionCategory(itemDef, score, breakdown)
    if not itemDef then return "situational" end

    local defensive = itemHasTag(itemDef, "save") or itemHasTag(itemDef, "dispel")
        or itemHasTag(itemDef, "vs_magic") or itemHasTag(itemDef, "vs_phys")
        or itemHasTag(itemDef, "block_spell")
    local triggerPower = sumBreakdownPrefix(breakdown, "trigger:")
    local counterPower = sumBreakdownPrefix(breakdown, "counter_rules")
    local enemyItemPower = sumBreakdownPrefix(breakdown, "enemy_item:")

    if defensive and (score >= 10 or triggerPower >= 8 or enemyItemPower >= 6) then
        return "must_have"
    end
    if (counterPower + enemyItemPower) >= 10 and score >= 9 then
        return "must_have"
    end

    local luxury = itemDef.cost >= 4500 and (
        itemHasTag(itemDef, "phys_dps") or itemHasTag(itemDef, "magic_burst")
        or itemHasTag(itemDef, "crit") or itemHasTag(itemDef, "attack_speed")
        or itemHasTag(itemDef, "farm")
    )
    if luxury then
        return "luxury"
    end
    return "situational"
end

local function buildSuggestionMeta(itemDef, ctx, score, breakdown)
    breakdown = breakdown or {{key = "final", delta = score}}

    local highlights = {}
    for _, entry in ipairs(breakdown) do
        if entry.key ~= "final" and (entry.delta or 0) ~= 0 then
            table.insert(highlights, {
                key = entry.key,
                delta = entry.delta,
                label = breakdownKeyLabel(entry.key),
            })
        end
    end
    table.sort(highlights, function(a, b)
        local ap = (a.delta or 0) > 0
        local bp = (b.delta or 0) > 0
        if ap ~= bp then return ap end
        local aa = math.abs(a.delta or 0)
        local bb = math.abs(b.delta or 0)
        if aa ~= bb then return aa > bb end
        return tostring(a.label) < tostring(b.label)
    end)

    local topReasons = {}
    for _, h in ipairs(highlights) do
        if (h.delta or 0) > 0 and h.label and h.label ~= "" then
            table.insert(topReasons, h.label)
            if #topReasons >= 3 then break end
        end
    end
    if #topReasons == 0 then
        local reason = itemDef and LR(itemDef.name) or ""
        if reason ~= "" then table.insert(topReasons, reason) end
    end

    return {
        category = classifySuggestionCategory(itemDef, score, breakdown),
        breakdown = breakdown,
        breakdownHighlights = highlights,
        topReasons = topReasons,
    }
end

local function buildEnemyFocusData(ctxTemplate)
    local focusEntries = {}
    for _, enemy in ipairs(S.enemyHeroes) do
        if enemy.included then
            local ctx = {}
            for k, v in pairs(ctxTemplate) do ctx[k] = v end
            ctx.enemyTags = enemy.tagCounts or {}
            ctx.enemyItemCounts = enemy.itemCounts or {}

            local scored = {}
            local function addScore(itemName, value, reason)
                local itemDef = ITEM_LOOKUP[itemName]
                if not itemDef then return end
                if ctx.ownedItems and ctx.ownedItems[itemName] then return end
                local entry = scored[itemName]
                if not entry then
                    entry = {item = itemDef, score = 0, reasons = {}}
                    scored[itemName] = entry
                end
                entry.score = entry.score + value
                if reason and reason ~= "" then
                    table.insert(entry.reasons, reason)
                end
            end

            local counterData = HERO_COUNTERS[enemy.name]
            if counterData and counterData.items then
                for _, itemName in ipairs(counterData.items) do
                    addScore(itemName, 30, counterData.reason or "Direct counter")
                end
            end

            for _, itemDef in ipairs(ITEM_DB) do
                local s = computeItemScore(itemDef, ctx)
                if s > 0 then
                    addScore(itemDef.name, s)
                end
            end

            local rankedItems = {}
            for _, entry in pairs(scored) do
                local reason = (#entry.reasons > 0) and entry.reasons[1] or LR(entry.item.name)
                table.insert(rankedItems, {
                    item = entry.item,
                    score = entry.score,
                    reason = reason,
                })
            end
            table.sort(rankedItems, function(a, b)
                if a.score ~= b.score then return a.score > b.score end
                return a.item.cost > b.item.cost
            end)

            local basePriority = #(HERO_TAGS[enemy.name] or {})
            if counterData then basePriority = basePriority + 10 end

            table.insert(focusEntries, {
                enemy = enemy,
                display = prettyHero(enemy.name),
                items = rankedItems,
                priority = basePriority,
            })
        end
    end
    table.sort(focusEntries, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return (a.enemy.level or 0) > (b.enemy.level or 0)
    end)
    return focusEntries
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
    local pos = V(F(x), F(y))
    local size = V(F(w), F(h))
    local ok = pcall(function()
        -- Legacy signature used by original script (pos, endPos, color, rounding, flags)
        Render.FilledRect(pos, V(F(x+w), F(y+h)), c, rnd or 0, Enum.DrawFlags.RoundCornersAll)
    end)
    if not ok then
        pcall(Render.FilledRect, pos, size, c, rnd or 0)
    end
end

local function dBorder(x, y, w, h, c, rnd, t)
    local pos = V(F(x), F(y))
    local size = V(F(w), F(h))
    local ok = pcall(function()
        if Render.Rect then
            Render.Rect(pos, V(F(x+w), F(y+h)), c, rnd or 0, Enum.DrawFlags.RoundCornersAll, t or 1)
        elseif Render.OutlineRect then
            Render.OutlineRect(pos, size, c, rnd or 0, t or 1)
        end
    end)
    if not ok and Render.OutlineRect then
        pcall(Render.OutlineRect, pos, size, c, rnd or 0, t or 1)
    end
end

local function dText(sz, txt, x, y, c)
    local f = getFont(sz); if not f then return end
    txt = tostring(txt)
    local pos = V(F(x), F(y))
    local ok = pcall(function()
        -- Legacy signature used by original script/build.
        Render.Text(f, sz, txt, pos, c)
    end)
    if not ok then
        pcall(Render.Text, f, pos, txt, c)
    end
end

--------------------------------------------------------------------------------
-- TEXT SIZE CACHE
--------------------------------------------------------------------------------
local textSizeCache = {}
local TEXT_CACHE_MAX_SIZE = 500  -- Limit cache size to prevent memory bloat
local textSizeCacheCount = 0
local clearTextCache

tSz = function(sz, txt)
    local key = sz .. "_" .. tostring(txt)
    local cached = textSizeCache[key]
    if cached then return cached end
    
    local f = getFont(sz)
    local result
    if not f then 
        result = {x = sz * #tostring(txt) * 0.55, y = sz}
    else
        local ok, r1, r2 = pcall(function()
            if Render.TextSize then
                return Render.TextSize(f, sz, tostring(txt))
            end
            if Render.GetTextSize then
                return Render.GetTextSize(f, tostring(txt))
            end
        end)
        if ok and r1 then
            if type(r1) == "number" then
                result = {x = r1, y = r2 or sz}
            elseif type(r1) == "table" or type(r1) == "userdata" then
                result = {x = r1.x or 0, y = r1.y or sz}
            end
        end
        if not result then
            result = {x = sz * #tostring(txt) * 0.55, y = sz}
        end
    end
    
    -- Limit cache size
    if textSizeCacheCount >= TEXT_CACHE_MAX_SIZE then
        clearTextCache()
    end
    if textSizeCache[key] == nil then
        textSizeCache[key] = result
        textSizeCacheCount = textSizeCacheCount + 1
    end
    
    return result
end

clearTextCache = function()
    textSizeCache = {}
    textSizeCacheCount = 0
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
    local pos = V(F(x), F(y))
    local size = V(F(w), F(h))
    local ok = pcall(function()
        Render.Blur(pos, V(F(x+w), F(y+h)), 1.0, 1.0, 0, Enum.DrawFlags.None)
    end)
    if not ok then
        pcall(Render.Blur, pos, size, 1.0)
    end
end

local function wrapTextLines(sz, txt, maxW)
    txt = tostring(txt or "")
    if txt == "" or maxW <= 0 then return {} end
    local words = {}
    for word in txt:gmatch("%S+") do table.insert(words, word) end
    if #words == 0 then return {} end

    local lines = {}
    local line = ""
    for _, word in ipairs(words) do
        local test = (line == "") and word or (line .. " " .. word)
        if tSz(sz, test).x > maxW and line ~= "" then
            table.insert(lines, line)
            line = word
        else
            line = test
        end
    end
    if line ~= "" then table.insert(lines, line) end
    return lines
end

local function clearClickRegions()
    S.clickRegions = {}
    S.hoveredRegion = nil
end

local function registerClickRegion(x, y, w, h, itemName, section, priorityIndex, enabled)
    if not itemName or w <= 0 or h <= 0 then return end
    table.insert(S.clickRegions, {
        x = x, y = y, w = w, h = h,
        itemName = itemName,
        section = section or "main",
        priorityIndex = priorityIndex or 0,
        enabled = (enabled ~= false),
    })
end

local function getCursorPos2D()
    local pos = safeStatic(Engine, "GetCursorPos")
    if not pos and Engine.GetCursorPos then
        local ok, p = pcall(Engine.GetCursorPos)
        if ok then pos = p end
    end
    if pos and (type(pos) == "userdata" or type(pos) == "table") then
        return pos.x or 0, pos.y or 0
    end
    return nil, nil
end

local function pointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and y >= ry and x <= (rx + rw) and y <= (ry + rh)
end

local function findClickRegionAt(x, y)
    for i = #S.clickRegions, 1, -1 do
        local r = S.clickRegions[i]
        local inside = false
        if r then
            if x and y then
                inside = pointInRect(x, y, r.x, r.y, r.w, r.h)
            end
            if not inside and Input and Input.IsCursorInRect then
                inside = (safeStatic(Input, "IsCursorInRect", r.x, r.y, r.w, r.h) == true)
            end
        end
        if inside then
            return r
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- ANALYSIS ENGINE
--------------------------------------------------------------------------------
local function analyzeEnemyTeam()
    local me = Heroes.GetLocal()
    if not me then return end

    local myTeam = safeStatic(Entity, "GetTeamNum", me)
    if not myTeam then return end

    -- Detect game mode (only once per game)
    if S.gameMode == GAME_MODE.UNKNOWN then
        S.gameMode = detectGameMode()
    end

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
        
        local heroes = Heroes.GetAll()
        if not heroes or #heroes == 0 then
            Log.Write("[ItemHelper] No heroes found")
            return
        end
        
        for _, hero in ipairs(heroes) do
            if hero and Entity.IsEntity(hero) then
                local team = safeStatic(Entity, "GetTeamNum", hero)
                local totalGold = 0
                
                -- Prefer hero-owned player object (documented) and fall back to player id path.
                local player = safeMethod(hero, "GetPlayer")
                if not player then
                    local playerID = safeMethod(hero, "GetPlayerID")
                    if playerID and playerID >= 0 then
                        player = findPlayerByID(playerID)
                    end
                end
                if player then
                    local gold = safeMethod(player, "GetGold") or safeStatic(Player, "GetGold", player)
                    if gold and gold > 0 then
                        totalGold = totalGold + gold
                    end
                end
                
                -- Item net worth approximation from inventory value.
                local itemValue = 0
                local itemCount = 0
                for i = 0, 8 do
                    local item = safeStatic(NPC, "GetItemByIndex", hero, i)
                    if item then
                        local cost = safeMethod(item, "GetCost")
                        if not cost or cost <= 0 then
                            local itemName = safeMethod(item, "GetName") or safeStatic(Ability, "GetName", item)
                            cost = GetItemCost(itemName)
                        end
                        if cost > 0 then
                            itemValue = itemValue + cost
                            itemCount = itemCount + 1
                        end
                    end
                end
                -- Neutral item (slot 16)
                local neutralItem = safeStatic(NPC, "GetItemByIndex", hero, 16)
                if neutralItem then
                    local nCost = safeMethod(neutralItem, "GetCost")
                    if not nCost or nCost <= 0 then
                        local nName = safeMethod(neutralItem, "GetName") or safeStatic(Ability, "GetName", neutralItem)
                        nCost = GetItemCost(nName)
                    end
                    itemValue = itemValue + (nCost and nCost > 0 and nCost or 1000)
                    itemCount = itemCount + 1
                end
                
                totalGold = totalGold + itemValue
                
                if team == myTeam then
                    myTeamNW = myTeamNW + totalGold
                else
                    enemyTeamNW = enemyTeamNW + totalGold
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
    local myPlayer = getLocalPlayerObject()
    local gold = getPlayerCurrentGold(myPlayer)
    if gold == nil then
        gold = getHeroCurrentGold(me)
    end
    if gold ~= nil then
        S.myGold = gold
        S.myGoldKnown = true
    else
        if not myPlayer then
            S.myGold = 0
        end
        S.myGoldKnown = false
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
    S.enemyFocus = {}
    S.activeEnemyCount = 0
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
                    tags = HERO_TAGS[name] or {},
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
            end
        end
        ::continue::
    end

    -- Apply enemy filters
    S.enemyTags = {}
    for _, enemy in ipairs(S.enemyHeroes) do
        enemy.included = shouldIncludeEnemy(enemy.name)
        if enemy.included then
            S.activeEnemyCount = S.activeEnemyCount + 1
            for _, tag in ipairs(enemy.tags or {}) do
                S.enemyTags[tag] = (S.enemyTags[tag] or 0) + 1
            end
        end
        enemy.tagCounts = buildTagCounts(enemy.tags)
        enemy.itemCounts = {}
        for itemName, _ in pairs(enemy.items) do
            enemy.itemCounts[itemName] = 1
        end
    end

    refreshEnemyFilterList()

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
            if enemy.included then
            local counterData = HERO_COUNTERS[enemy.name]
            if counterData then
                for _, itemName in ipairs(counterData.items) do
                    if not S.ownedItems[itemName] then
                        counterScore[itemName] = (counterScore[itemName] or 0) + 1
                    end
                end
            end
            end
        end
        -- Convert to sorted table
        for itemName, score in pairs(counterScore) do
            local counterData = nil
            -- Find reason from HERO_COUNTERS among filtered enemies
            for _, enemy in ipairs(S.enemyHeroes) do
                if enemy.included then
                    local cd = HERO_COUNTERS[enemy.name]
                    if cd and tableContains(cd.items, itemName) then
                        counterData = cd
                        break
                    end
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
    local ctx = {
        phase = S.gamePhase,
        ownedItems = S.ownedItems,
        enemyTags = S.enemyTags,
        enemyItemCounts = S.enemyItemCounts,
        myGold = S.myGold,
        myGoldKnown = S.myGoldKnown,
        myRole = myRole,
        myStyle = myStyle,
        gameMode = S.gameMode,
        gameTempo = S.gameTempo,
        showNetWorth = sg(UI.showNetWorth, true),
        heroName = S.myHeroName,
        trackEnemyItems = sg(UI.trackEnemyItems, true),
    }

    if sg(UI.showEnemyFocus, true) then
        S.enemyFocus = buildEnemyFocusData(ctx)
    else
        S.enemyFocus = {}
    end

    local scored = {}
    for _, itemDef in ipairs(ITEM_DB) do
        local s, breakdown = computeItemScore(itemDef, ctx, true)
        if s > 0 then
            local meta = buildSuggestionMeta(itemDef, ctx, s, breakdown)
            table.insert(scored, {
                item = itemDef,
                score = s,
                category = meta.category,
                breakdown = meta.breakdown,
                breakdownHighlights = meta.breakdownHighlights,
                topReasons = meta.topReasons,
            })
        end
    end
    table.sort(scored, function(a, b)
        if a.category ~= b.category then
            local prio = {must_have = 3, situational = 2, luxury = 1}
            return (prio[a.category] or 0) > (prio[b.category] or 0)
        end
        if a.score ~= b.score then return a.score > b.score end
        return (a.item.cost or 0) > (b.item.cost or 0)
    end)

    S.suggestions = {}
    local maxItems = sg(UI.maxItems, 6)
    local addedNames = {}
    for _, entry in ipairs(scored) do
        if #S.suggestions >= maxItems then break end
        if not addedNames[entry.item.name] then
            addedNames[entry.item.name] = true
            table.insert(S.suggestions, {
                item = entry.item,
                score = entry.score,
                category = entry.category or "situational",
                breakdown = entry.breakdown or {{key = "final", delta = entry.score}},
                breakdownHighlights = entry.breakdownHighlights or {},
                topReasons = entry.topReasons or {},
            })
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

    -- Game mode badge (new)
    local modeKeys = {
        [GAME_MODE.UNKNOWN] = "mode_unknown",
        [GAME_MODE.ALL_PICK] = "mode_allpick",
        [GAME_MODE.RANKED] = "mode_ranked",
        [GAME_MODE.TURBO] = "mode_turbo",
        [GAME_MODE.SINGLE_DRAFT] = "mode_draft",
        [GAME_MODE.ALL_RANDOM] = "mode_random",
        [GAME_MODE.CAPTAINS_MODE] = "mode_draft",
        [GAME_MODE.ABILITY_DRAFT] = "mode_draft",
    }
    local modeColors = {
        [GAME_MODE.UNKNOWN] = {100, 100, 100},
        [GAME_MODE.ALL_PICK] = {80, 180, 220},
        [GAME_MODE.RANKED] = {255, 180, 60},
        [GAME_MODE.TURBO] = {255, 100, 150},
        [GAME_MODE.SINGLE_DRAFT] = {150, 120, 200},
        [GAME_MODE.ALL_RANDOM] = {120, 200, 150},
        [GAME_MODE.CAPTAINS_MODE] = {200, 150, 100},
        [GAME_MODE.ABILITY_DRAFT] = {180, 100, 200},
    }
    local mc = modeColors[S.gameMode] or {100, 100, 100}
    local mName = L(modeKeys[S.gameMode] or "mode_unknown")
    local ms = tSz(8, mName)
    dRect(x + 8, y + 28, ms.x + 8, 14, col(mc[1], mc[2], mc[3], F(alpha * 0.15)), 3)
    dText(8, mName, x + 12, y + 29, col(mc[1], mc[2], mc[3], F(alpha * 0.85)))

    -- Test context badge (lobby / Try Hero custom sandbox)
    if S.testContextKind then
        local tKey = (S.testContextKind == "tryhero" and "test_tryhero")
            or (S.testContextKind == "lobby" and "test_lobby")
            or "test_custom"
        local tTxt = L(tKey)
        local ts = tSz(7, tTxt)
        local tx = x + 8 + ms.x + 16
        local tw = ts.x + 8
        dRect(tx, y + 29, tw, 12, col(255, 170, 60, F(alpha * 0.16)), 3)
        dText(7, tTxt, tx + 4, y + 30, col(255, 190, 90, F(alpha * 0.85)))
    end

    -- Phase badge
    local phaseKeys = {[PHASE_EARLY]="early", [PHASE_MID]="mid", [PHASE_LATE]="late"}
    local phaseColors = {[PHASE_EARLY]={80,220,120}, [PHASE_MID]={255,200,60}, [PHASE_LATE]={255,90,70}}
    local pc = phaseColors[S.gamePhase]
    local pName = L(phaseKeys[S.gamePhase])
    local ps = tSz(10, pName)
    local bx = x + w - ps.x - 14
    dRect(bx, y + 10, ps.x + 10, 18, col(pc[1], pc[2], pc[3], F(alpha * 0.15)), 4)
    dText(10, pName, bx + 5, y + 12, col(pc[1], pc[2], pc[3], F(alpha * 0.9)))

    -- Gold (optional; some builds may report incorrect value)
    if sg(UI.showGoldHeader, true) then
        local goldTxt = (S.myGoldKnown and (F(S.myGold) .. "g")) or L("gold_unknown")
        local goldSz = tSz(9, goldTxt)
        local goldColor = S.myGoldKnown and col(255, 215, 0, F(alpha * 0.7)) or colA(TC.dim, alpha * 0.65)
        dText(9, goldTxt, x + w - goldSz.x - 8, y + 30, goldColor)
    end

    dRect(x + 4, y + CFG.HEADER_H - 1, w - 8, 1, colA(TC.dim, alpha * 0.2), 0)
    return CFG.HEADER_H
end

--------------------------------------------------------------------------------
-- DRAW: ENEMY HEROES SECTION
--------------------------------------------------------------------------------
local function drawEnemySection(x, y, w, alpha)
    local curY = y
    local acc = TC.accent
    local enemyTitle = L("enemies")
    if S.activeEnemyCount > 0 and S.activeEnemyCount < #S.enemyHeroes then
        enemyTitle = enemyTitle .. " (" .. S.activeEnemyCount .. "/" .. #S.enemyHeroes .. ")"
    end
    dText(10, enemyTitle, x + 4, curY, colA(acc, alpha * 0.9))
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
    dText(9, L("net_worth"), x + 4, curY, col(150, 150, 150, F(alpha * 0.7)))
    curY = curY + 14
    
    -- If no data yet, show placeholder
    if totalNW == 0 then
        dText(8, L("waiting_data"), x + 4, curY + 2, col(100, 100, 100, F(alpha * 0.5)))
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
    dText(10, L("hero_counters"), x + 4, curY, col(255, 100, 100, F(alpha * 0.9)))
    local hcTitleW = tSz(10, L("hero_counters")).x
    dRect(x + 8 + hcTitleW, curY + 7, math.max(0, w - hcTitleW - 16), 1, colA(TC.dim, alpha * 0.14), 0)
    curY = curY + 16

    -- Draw compact counter items
    local maxCounters = 5
    for i, counter in ipairs(S.heroCounterSuggestions) do
        if i > maxCounters then break end

        local item = counter.item
        local owned = sg(UI.showOwned, true) and S.ownedItems[item]
        local canAfford = S.myGoldKnown and S.myGold >= GetItemCost(item)

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
        local nameC
        if owned then
            nameC = col(80, 200, 120, F(alpha * 0.7))
        elseif canAfford then
            nameC = col(255, 215, 0, F(alpha * 0.9))
        else
            nameC = colA(TC.text, alpha)
        end
        dText(9, displayName, x + 28, curY + 3, nameC)

        -- Counter score badge
        local scoreTxt = "x" .. counter.score
        local scoreSz = tSz(7, scoreTxt)
        local scoreBg = canAfford and {255, 215, 0} or {255, 80, 80}
        local scoreFg = canAfford and {255, 225, 120} or {255, 100, 100}
        dRect(x + w - scoreSz.x - 8, curY + 4, scoreSz.x + 4, 12, col(scoreBg[1], scoreBg[2], scoreBg[3], F(alpha * 0.2)), 2)
        dText(7, scoreTxt, x + w - scoreSz.x - 6, curY + 5, col(scoreFg[1], scoreFg[2], scoreFg[3], F(alpha * 0.85)))

        registerClickRegion(x, curY, w, h, item, "hero_counter", i, true)

        curY = curY + h + 2
    end

    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: ENEMY FOCUS SECTION
--------------------------------------------------------------------------------
local function drawEnemyFocus(x, y, w, alpha)
    if not sg(UI.showEnemyFocus, true) then return 0 end
    if not S.enemyFocus or #S.enemyFocus == 0 then return 0 end

    local rows = clamp(sg(UI.enemyFocusRows, 3), 1, 6)
    local curY = y
    dText(10, L("enemy_focus"), x + 4, curY, col(255, 150, 90, F(alpha * 0.9)))
    local efTitleW = tSz(10, L("enemy_focus")).x
    dRect(x + 8 + efTitleW, curY + 7, math.max(0, w - efTitleW - 16), 1, colA(TC.dim, alpha * 0.14), 0)
    curY = curY + 16

    for i = 1, math.min(rows, #S.enemyFocus) do
        local entry = S.enemyFocus[i]
        local enemy = entry.enemy
        local rowH = 30
        dRect(x, curY, w, rowH, col(18, 20, 30, F(alpha * 0.25)), 5)

        local icon = heroIcon(enemy.name)
        if icon then
            dImg(icon, x + 4, curY + 4, 20, 20, col(255, 255, 255, F(alpha * 0.9)), 3)
        else
            dText(10, "?", x + 10, curY + 6, colA(TC.dim, alpha * 0.5))
        end

        local aliveC = enemy.alive and col(120, 220, 160, F(alpha * 0.8)) or col(220, 100, 100, F(alpha * 0.8))
        local leftX = x + 28
        local rightW = math.max(145, F(w * 0.52))
        local rightX = x + w - rightW - 6
        local leftW = math.max(32, rightX - leftX - 8)
        dText(10, shortTextByWidth(10, entry.display, leftW), leftX, curY + 4, colA(TC.text, alpha * 0.95))
        dText(8, shortTextByWidth(8, enemy.alive and L("alive") or L("dead"), leftW), leftX, curY + 17, aliveC)

        if entry.items and #entry.items > 0 then
            local best = entry.items[1]
            local reason = best.reason ~= "" and best.reason or LR(best.item.name)
            local canAffordBest = S.myGoldKnown and S.myGold >= (best.item.cost or 0)
            dText(9, shortTextByWidth(9, reason, rightW), rightX, curY + 4, colA(TC.dim, alpha * 0.8))
            local bestC = canAffordBest and col(255, 215, 0, F(alpha * 0.9)) or colA(TC.accent, alpha * 0.9)
            dText(10, shortTextByWidth(10, best.item.display, rightW), rightX, curY + 16, bestC)
            registerClickRegion(x, curY, w, rowH, best.item.name, "enemy_focus", i, true)
        end

        curY = curY + rowH + 2
    end
    return curY - y
end

--------------------------------------------------------------------------------
-- DRAW: ITEM SUGGESTION CARD
--------------------------------------------------------------------------------
local CATEGORY_VIS = {
    must_have = {labelKey = "cat_must_have", color = {255, 116, 104}},
    situational = {labelKey = "cat_situational", color = {85, 170, 255}},
    luxury = {labelKey = "cat_luxury", color = {255, 205, 95}},
}

local function getCategoryVis(cat)
    return CATEGORY_VIS[cat or "situational"] or CATEGORY_VIS.situational
end

local function getBreakdownChips(suggestion)
    if not sg(UI.showScoreBreakdown, true) then return {} end
    local maxChips = clamp(sg(UI.breakdownChipCount, 2), 1, 4)
    local chips = {}
    for _, h in ipairs(suggestion.breakdownHighlights or {}) do
        if (h.delta or 0) ~= 0 and h.label and h.label ~= "" then
            local sign = (h.delta or 0) > 0 and "+" or ""
            local txt = sign .. tostring(h.delta) .. " " .. shortText(h.label, 14)
            table.insert(chips, {
                text = txt,
                delta = h.delta or 0,
                label = h.label,
            })
            if #chips >= maxChips then break end
        end
    end
    return chips
end

local function buildItemCardLayout(suggestion, w)
    local item = suggestion.item
    local nameXOffset = 26 + 26 + 8
    local textAreaW = w - nameXOffset - 6
    local h = 20
    local reasonLines = {}
    local breakdownChips = getBreakdownChips(suggestion)
    local showCategory = sg(UI.showCategoryBadges, true)

    if showCategory then
        h = h + 13
    end

    if sg(UI.showReasons, true) then
        local reason = LR(item.name)
        if reason == "" and suggestion.topReasons and #suggestion.topReasons > 0 then
            reason = table.concat(suggestion.topReasons, " • ")
        end
        if reason ~= "" then
            reasonLines = wrapTextLines(10, reason, textAreaW)
            if #reasonLines > 0 then
                h = h + #reasonLines * 13 + 2
            end
        end
    end

    if #breakdownChips > 0 then
        h = h + 14
    end

    local hasTriggers = false
    if item.triggers then
        for _, tr in ipairs(item.triggers) do
            if S.enemyTags[tr] and S.enemyTags[tr] > 0 then
                hasTriggers = true
                break
            end
        end
    end
    if hasTriggers then h = h + 14 end
    h = math.max(h, showCategory and 44 or 36)

    return {
        h = h,
        nameXOffset = nameXOffset,
        textAreaW = textAreaW,
        reasonLines = reasonLines,
        breakdownChips = breakdownChips,
        showCategory = showCategory,
        hasTriggers = hasTriggers,
    }
end

local function drawItemCard(x, y, w, suggestion, idx, alpha)
    local item = suggestion.item
    local acc = TC.accent
    local owned = sg(UI.showOwned, true) and S.ownedItems[item.name]
    local canAfford = S.myGoldKnown and S.myGold >= item.cost
    local layout = buildItemCardLayout(suggestion, w)

    local nameX = x + layout.nameXOffset
    local textAreaW = layout.textAreaW
    local h = layout.h
    local reasonLines = layout.reasonLines
    local breakdownChips = layout.breakdownChips
    local showCategory = layout.showCategory
    local hasTriggers = layout.hasTriggers
    local categoryVis = getCategoryVis(suggestion.category)

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

    -- Top-right badges (score + cost) for cleaner alignment
    local costTxt = owned and L("owned") or (item.cost .. "g")
    local scoreTxt = "S " .. tostring(suggestion.score or 0)
    local costSz = tSz(8, costTxt)
    local scoreSz = tSz(8, scoreTxt)
    local costBadgeW = costSz.x + 8
    local scoreBadgeW = scoreSz.x + 8
    local badgeGap = 4
    local costBx = x + w - costBadgeW - 6
    local scoreBx = costBx - scoreBadgeW - badgeGap
    local badgeY = y + 4

    local scoreC = categoryVis.color
    dRect(scoreBx, badgeY, scoreBadgeW, 12, col(scoreC[1], scoreC[2], scoreC[3], F(alpha * 0.14)), 3)
    dText(8, scoreTxt, scoreBx + 4, badgeY + 1, col(scoreC[1], scoreC[2], scoreC[3], F(alpha * 0.9)))

    local costC
    if owned then costC = col(80, 200, 120, F(alpha * 0.65))
    elseif canAfford then costC = col(255, 215, 0, F(alpha * 0.85))
    else costC = col(150, 85, 85, F(alpha * 0.7)) end
    dRect(costBx, badgeY, costBadgeW, 12, col(costC.r, costC.g, costC.b, F(alpha * 0.10)), 3)
    dText(8, costTxt, costBx + 4, badgeY + 1, costC)

    -- Item name
    local nameC
    if owned then
        nameC = col(80, 200, 120, F(alpha * 0.7))
    elseif canAfford then
        nameC = col(255, 215, 0, F(alpha * 0.95))
    else
        nameC = colA(TC.text, alpha)
    end
    local nameMaxW = math.max(40, scoreBx - nameX - 6)
    dText(11, shortTextByWidth(11, item.display, nameMaxW), nameX, y + 4, nameC)

    local curTextY = y + 20
    if showCategory then
        local catTxt = L(categoryVis.labelKey)
        local catSz = tSz(7, catTxt)
        local catW = catSz.x + 8
        dRect(nameX, curTextY, catW, 11, col(categoryVis.color[1], categoryVis.color[2], categoryVis.color[3], F(alpha * 0.14)), 3)
        dText(7, catTxt, nameX + 4, curTextY + 1, col(categoryVis.color[1], categoryVis.color[2], categoryVis.color[3], F(alpha * 0.85)))
        curTextY = curTextY + 13
    end

    -- Reason text (multi-line)
    for _, rLine in ipairs(reasonLines) do
        dText(10, rLine, nameX, curTextY, colA(TC.text, alpha * 0.85))
        curTextY = curTextY + 13
    end

    -- Score breakdown chips (compact transparency)
    if #breakdownChips > 0 then
        local chipX = nameX
        local chipY = curTextY
        local maxRight = x + w - 4
        for _, chip in ipairs(breakdownChips) do
            local chipText = chip.text
            local chipSz = tSz(7, chipText)
            local chipW = chipSz.x + 6
            if chipX + chipW > maxRight then break end
            local pos = (chip.delta or 0) >= 0
            local cc = pos and {92, 205, 140} or {235, 120, 120}
            dRect(chipX, chipY, chipW, 11, col(cc[1], cc[2], cc[3], F(alpha * 0.10)), 3)
            dText(7, chipText, chipX + 3, chipY + 1, col(cc[1], cc[2], cc[3], F(alpha * 0.78)))
            chipX = chipX + chipW + 3
        end
        curTextY = curTextY + 14
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

    registerClickRegion(x, y, w, h, item.name, "main", idx, true)

    return h
end

--------------------------------------------------------------------------------
-- DRAW: SUGGESTIONS SECTION
--------------------------------------------------------------------------------
local function drawSuggestions(x, y, w, alpha)
    local curY = y
    dText(10, L("recommended"), x + 4, curY, colA(TC.accent, alpha * 0.9))
    local recTitleW = tSz(10, L("recommended")).x
    dRect(x + 8 + recTitleW, curY + 7, math.max(0, w - recTitleW - 16), 1, colA(TC.dim, alpha * 0.14), 0)
    if #S.suggestions > 0 then
        local counts = {must_have = 0, situational = 0, luxury = 0}
        for _, sug in ipairs(S.suggestions) do
            counts[sug.category or "situational"] = (counts[sug.category or "situational"] or 0) + 1
        end
        local bx = x + w - 4
        for _, cat in ipairs({"luxury", "situational", "must_have"}) do
            local cnt = counts[cat] or 0
            if cnt > 0 then
                local vis = getCategoryVis(cat)
                local txt = L(vis.labelKey) .. " " .. cnt
                local ts = tSz(7, txt)
                local bw = ts.x + 8
                bx = bx - bw
                dRect(bx, curY + 1, bw, 11, col(vis.color[1], vis.color[2], vis.color[3], F(alpha * 0.12)), 3)
                dText(7, txt, bx + 4, curY + 2, col(vis.color[1], vis.color[2], vis.color[3], F(alpha * 0.8)))
                bx = bx - 3
            end
        end
    end
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
        local owned = sg(UI.showOwned, true) and S.ownedItems[item.name]
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

        registerClickRegion(x, curY, w, h, item.name, "neutral", i, true)

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
        local lines = wrapTextLines(9, tip, w - 12)
        local tipH = #lines * 13 + 6
        dRect(x + 2, curY, w - 4, tipH, col(tipC[1], tipC[2], tipC[3], F(alpha * 0.06)), 4)
        for _, ln in ipairs(lines) do
            dText(9, ln, x + 8, curY + 3, col(tipC[1], tipC[2], tipC[3], F(alpha * 0.65)))
            curY = curY + 13
        end
        curY = curY + 4
    end

    dText(8, "v3.2", x + w - 26, curY, col(40, 44, 60, F(alpha * 0.25)))
    curY = curY + 12
    return curY - y
end

--------------------------------------------------------------------------------
-- PANEL MEASURE / OVERLAYS
--------------------------------------------------------------------------------
local function getFooterTipData()
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
    return tip, tipC
end

local function measureEnemySectionHeight(w)
    local h = 16 + 24 + 6
    if sg(UI.showThreats, true) and #S.threatCounts > 0 then
        local tagRowY = 0
        local tagX = 4
        local shown = 0
        local maxRight = w - 4
        for _, tc in ipairs(S.threatCounts) do
            if shown >= 10 then break end
            if tc.count > 0 then
                local txt = tc.tag:upper()
                if tc.count > 1 then txt = txt .. " x" .. tc.count end
                local tagW = tSz(8, txt).x + 10
                if tagX + tagW > maxRight and tagX > 4 then
                    tagX = 4
                    tagRowY = tagRowY + 17
                end
                tagX = tagX + tagW + 3
                shown = shown + 1
            end
        end
        h = h + 14 + tagRowY + 19
    end
    h = h + 6 -- separator spacing
    return h
end

local function measureNetWorthBarHeight()
    if not sg(UI.showNetWorth, true) then return 0 end
    local totalNW = S.myTeamNetWorth + S.enemyTeamNetWorth
    if totalNW == 0 then return 24 end
    return 32
end

local function measureHeroCountersHeight()
    if not sg(UI.showHeroCounters, true) then return 0 end
    if #S.heroCounterSuggestions == 0 then return 0 end
    return 16 + math.min(#S.heroCounterSuggestions, 5) * 22
end

local function measureEnemyFocusHeight()
    if not sg(UI.showEnemyFocus, true) then return 0 end
    if not S.enemyFocus or #S.enemyFocus == 0 then return 0 end
    local rows = clamp(sg(UI.enemyFocusRows, 3), 1, 6)
    return 16 + math.min(rows, #S.enemyFocus) * 32
end

local function measureSuggestionsHeight(w)
    local h = 18
    if #S.suggestions == 0 then
        return h + 18
    end
    for _, sug in ipairs(S.suggestions) do
        h = h + buildItemCardLayout(sug, w).h + 3
    end
    return h
end

local function measureNeutralSectionHeight()
    if not sg(UI.showNeutrals, true) then return 0 end
    if S.neutralTier == 0 or #S.neutralSuggestions == 0 then return 0 end
    return 6 + 16 + (#S.neutralSuggestions * 24)
end

local function measureFooterHeight(w)
    local h = 6
    local tip = getFooterTipData()
    if tip then
        local lines = wrapTextLines(9, tip, w - 12)
        h = h + (#lines * 13) + 4
    end
    h = h + 12
    return h
end

local function measurePanelHeight(innerW)
    local contentH = CFG.PAD
    contentH = contentH + CFG.HEADER_H + 4
    contentH = contentH + measureEnemySectionHeight(innerW)
    contentH = contentH + measureNetWorthBarHeight()
    contentH = contentH + measureHeroCountersHeight()
    contentH = contentH + measureEnemyFocusHeight()
    contentH = contentH + measureSuggestionsHeight(innerW)
    contentH = contentH + measureNeutralSectionHeight()
    contentH = contentH + measureFooterHeight(innerW)
    return F(contentH)
end

local function drawHoverOverlay()
    local cx, cy = getCursorPos2D()
    S.hoveredRegion = findClickRegionAt(cx, cy)

    local hover = S.hoveredRegion
    if hover then
        dRect(hover.x, hover.y, hover.w, hover.h, col(255, 255, 255, 12), 5)
        dBorder(hover.x, hover.y, hover.w, hover.h, col(255, 255, 255, 46), 5, 1)
    end
end

--------------------------------------------------------------------------------
-- DRAW: MAIN PANEL
--------------------------------------------------------------------------------
local function drawPanel()
    if not shouldShowPanel() then
        S.panelVisible = false
        S.panelRect = nil
        clearClickRegions()
        return
    end
    syncThemeColors()

    local sw, sh = screenSz()
    local scale = clamp(sg(UI.scale, 100), 60, 150) / 100
    local opac = clamp(sg(UI.opacity, 85), 20, 100) / 100
    local offX = clamp(sg(UI.offX, 0), -800, 800)
    local offY = clamp(sg(UI.offY, 0), -600, 600)
    local panelSide = sg(UI.panelSide, 0)
    local pw = F(CFG.PW * scale)

    local innerW = pw - CFG.PAD * 2
    local ph = measurePanelHeight(innerW)
    local px, py
    if panelSide == 0 then px = CFG.MARGIN + offX
    else px = sw - pw - CFG.MARGIN + offX end
    py = CFG.MARGIN + 80 + offY
    px = clamp(px, 4, sw - pw - 4)
    py = clamp(py, 4, sh - ph - 4)

    local alpha = 255 * opac
    if alpha < 2 then
        S.panelVisible = false
        S.panelRect = nil
        clearClickRegions()
        return
    end

    clearClickRegions()

    dBlur(px, py, pw, ph)
    local themeBg = TC.bg
    dRect(px, py, pw, ph, col(themeBg.r, themeBg.g, themeBg.b, F(210 * alpha / 255)), CFG.ROUNDING)
    local bdrC = TC.border
    dBorder(px, py, pw, ph, col(bdrC.r, bdrC.g, bdrC.b, F(40 * alpha / 255)), CFG.ROUNDING, 1)

    local curY = py + CFG.PAD
    local clipPushed = false -- disabled on this build: some Render variants accept PushClip but clip everything incorrectly

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
    local focusH = drawEnemyFocus(px + CFG.PAD, curY, innerW, alpha)
    curY = curY + focusH
    local sH = drawSuggestions(px + CFG.PAD, curY, innerW, alpha)
    curY = curY + sH
    local nH = drawNeutralSection(px + CFG.PAD, curY, innerW, alpha)
    curY = curY + nH
    drawFooter(px + CFG.PAD, curY, innerW, alpha)
    if clipPushed and Render.PopClip then pcall(Render.PopClip) end

    S.panelVisible = true
    S.panelRect = {x = px, y = py, w = pw, h = ph}
    drawHoverOverlay()
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
        refreshRuntimeTestContext()
        refreshMyGold()

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
        if not sg(UI.enabled, true) then
            S.panelVisible = false
            S.panelRect = nil
            clearClickRegions()
            return
        end
        if not sg(UI.showPanel, true) then
            S.panelVisible = false
            S.panelRect = nil
            clearClickRegions()
            return
        end

        local inGame = false
        pcall(function() inGame = Engine.IsInGame() end)
        if not inGame then
            S.panelVisible = false
            S.panelRect = nil
            clearClickRegions()
            return
        end

        local now = gt()
        if S.lastFrame > 0 then S.dt = clamp(now - S.lastFrame, 0.001, 0.1) end
        S.lastFrame = now
        S.pulseTime = S.pulseTime + S.dt
        drawPanel()
    end)
    if not ok and err then
        S.panelVisible = false
        S.panelRect = nil
        clearClickRegions()
        print("[ItemHelper] Draw: " .. tostring(err))
    end
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
    S.myGoldKnown = false
    S.rawGameModeId = -1
    S.playerCount = 0
    S.testContextKind = nil
    S.myHeroName = ""
    S.gamePhase = PHASE_EARLY
    S.gameMode = GAME_MODE.UNKNOWN
    S.neutralTier = 0
    S.lastAnalysis = 0
    S.heroIcons = {}
    S.itemIcons = {}
    S.clickRegions = {}
    S.hoveredRegion = nil
    S.panelVisible = false
    S.panelRect = nil
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
