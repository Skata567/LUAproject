import json

def get_lua_str():
    return """local M = { races = {}, classes = {} }

-- ===== RACES (11) =====
M.races.dragonkin = {
    tier1 = {
        {id="r_dr_1", name="용의 피", desc="최대 HP +30", type="passive", statBonus={maxHp=30}},
        {id="r_dr_2", name="발톱 연마", desc="참격 대미지 +15%", type="passive", statBonus={slashDmgMult=0.15}},
        {id="r_dr_3", name="불씨 뿜기", desc="단일 대상 화염 데미지", type="active", cooldown=5, attackScale=1.5, element="fire"}
    },
    tier2 = {
        {id="r_dr_4", name="두꺼운 비늘", desc="방어력 +5, 화염 저항 +30%", type="passive", statBonus={def=5}, resist={fire=0.3}},
        {id="r_dr_5", name="용의 위압", desc="적 공격력 감소", type="active", cooldown=12, aoeRadius=3, debuff="atk_down"},
        {id="r_dr_6", name="화염의 숨결", desc="강력한 화염 피해", type="active", cooldown=10, attackScale=2.0, element="fire", aoeRadius=2}
    },
    tier3 = {
        {id="r_dr_7", name="고룡의 지혜", desc="STR +5, INT +5", type="passive", statBonus={str=5, int=5}},
        {id="r_dr_8", name="불타는 갑옷", desc="반사 데미지", type="passive", statBonus={thorns=10}},
        {id="r_dr_9", name="용인화", desc="5턴간 스탯 폭발", type="active", cooldown=35, buff="dragon_form"}
    }
}

M.races.fae = {
    tier1 = {
        {id="r_fa_1", name="바람 걸음", desc="회피 +10", type="passive", statBonus={ev=10}},
        {id="r_fa_2", name="마력 친화", desc="최대 마나 +15", type="passive", statBonus={maxMana=15}},
        {id="r_fa_3", name="요정의 장난", desc="단일 적 혼란", type="active", cooldown=6, debuff="confuse", range=4}
    },
    tier2 = {
        {id="r_fa_4", name="자연의 보호", desc="모든 저항 +10%", type="passive", resist={fire=0.1, ice=0.1, poison=0.1, lightning=0.1}},
        {id="r_fa_5", name="날갯짓", desc="다음 이동 딜레이 0", type="active", cooldown=8, buff="fast_move"},
        {id="r_fa_6", name="빛나는 가루", desc="주변 적 명중률 감소", type="active", cooldown=12, aoeRadius=3, debuff="blind"}
    },
    tier3 = {
        {id="r_fa_7", name="요정왕의 축복", desc="DEX +5, INT +5", type="passive", statBonus={dex=5, int=5}},
        {id="r_fa_8", name="환영", desc="피격 시 20% 확률로 무시", type="passive", statBonus={dodgeChance=20}},
        {id="r_fa_9", name="요정의 환상", desc="광역 기절 및 아군 회피 버프", type="active", cooldown=30, buff="fae_glimmer", aoeRadius=4, debuff="stun"}
    }
}

M.races.gnome = {
    tier1 = {
        {id="r_gn_1", name="땜장이", desc="DEX +3", type="passive", statBonus={dex=3}},
        {id="r_gn_2", name="절연체", desc="번개 저항 +25%", type="passive", resist={lightning=0.25}},
        {id="r_gn_3", name="소형 폭탄", desc="단일 화염 피해", type="active", cooldown=4, attackScale=1.2, element="fire", range=5}
    },
    tier2 = {
        {id="r_gn_4", name="기계 공학", desc="모든 원거리 피해 +15%", type="passive", statBonus={rangedDmgMult=0.15}},
        {id="r_gn_5", name="기계팔", desc="STR +3, 공격력 +5", type="passive", statBonus={str=3, atk=5}},
        {id="r_gn_6", name="독가스 탄", desc="광역 독 피해", type="active", cooldown=10, aoeRadius=2, element="poison", debuff="poison"}
    },
    tier3 = {
        {id="r_gn_7", name="마도 공학자", desc="INT +6, DEX +4", type="passive", statBonus={int=6, dex=4}},
        {id="r_gn_8", name="동력 충전", desc="턴마다 마나 2 추가 회복", type="passive", statBonus={mpRegen=2}},
        {id="r_gn_9", name="EMP 수류탄", desc="광역 번개 피해 및 방어력 대폭 감소", type="active", cooldown=25, aoeRadius=3, element="lightning", debuff="def_down"}
    }
}

M.races.kobold_p = {
    tier1 = {
        {id="r_kb_1", name="터널 시야", desc="암흑 시야 +2", type="passive", statBonus={fov=2}},
        {id="r_kb_2", name="치명적 약점", desc="치명타 데미지 배율 +0.3x", type="passive", statBonus={critMult=0.3}},
        {id="r_kb_3", name="물어뜯기", desc="단일 근접 출혈 공격", type="active", cooldown=5, attackScale=1.3, debuff="bleed"}
    },
    tier2 = {
        {id="r_kb_4", name="독 면역", desc="독 저항 +40%", type="passive", resist={poison=0.4}},
        {id="r_kb_5", name="민첩한 도주", desc="HP 30% 이하 시 회피 +20", type="passive", statBonus={lowHpEv=20}},
        {id="r_kb_6", name="비열한 함정", desc="밟으면 기절하는 덫 설치", type="active", cooldown=12, action="spawn_trap"}
    },
    tier3 = {
        {id="r_kb_7", name="교활한 포식자", desc="DEX +6, STR +4", type="passive", statBonus={dex=6, str=4}},
        {id="r_kb_8", name="다중 공격", desc="기본 공격 시 10% 확률로 2회 공격", type="passive", statBonus={doubleHit=10}},
        {id="r_kb_9", name="뒤통수 치기", desc="은신 및 다음 타격 확정 치명타", type="active", cooldown=30, buff="stealth_crit"}
    }
}

M.races.angelborn = {
    tier1 = {
        {id="r_an_1", name="성스러운 빛", desc="신성 저항 +30%", type="passive", resist={holy=0.3}},
        {id="r_an_2", name="축복받은 육신", desc="최대 HP +20", type="passive", statBonus={maxHp=20}},
        {id="r_an_3", name="치유의 손", desc="단일 대상 HP 회복", type="active", cooldown=8, heal=20, range=4}
    },
    tier2 = {
        {id="r_an_4", name="신의 사자", desc="신성 데미지 +20%", type="passive", statBonus={holyDmgMult=0.2}},
        {id="r_an_5", name="정화", desc="모든 상태이상 해제", type="active", cooldown=15, action="cleanse"},
        {id="r_an_6", name="빛의 창", desc="원거리 신성 피해", type="active", cooldown=6, attackScale=1.8, element="holy", range=6}
    },
    tier3 = {
        {id="r_an_7", name="대천사의 권능", desc="INT +7, CON +3", type="passive", statBonus={int=7, con=3}},
        {id="r_an_8", name="부활의 불꽃", desc="사망 시 1회 부활 (HP 50%)", type="passive", statBonus={resurrect=1}},
        {id="r_an_9", name="신의 축복", desc="아군 전체 모든 디버프 해제 및 체력 회복", type="active", cooldown=40, action="party_heal_cleanse"}
    }
}

M.races.demonborn = {
    tier1 = {
        {id="r_de_1", name="지옥불", desc="화염 저항 +30%", type="passive", resist={fire=0.3}},
        {id="r_de_2", name="마족의 힘", desc="STR +3", type="passive", statBonus={str=3}},
        {id="r_de_3", name="어둠의 칼날", desc="근접 암흑 피해", type="active", cooldown=5, attackScale=1.5, element="poison"}
    },
    tier2 = {
        {id="r_de_4", name="파괴 본능", desc="치명타 확률 +15%", type="passive", statBonus={critChance=15}},
        {id="r_de_5", name="공포의 외침", desc="광역 공포 디버프", type="active", cooldown=12, aoeRadius=3, debuff="fear"},
        {id="r_de_6", name="지옥의 사슬", desc="적을 끌어오고 속박", type="active", cooldown=10, range=5, debuff="root", action="pull"}
    },
    tier3 = {
        {id="r_de_7", name="마왕의 후계자", desc="STR +6, INT +4", type="passive", statBonus={str=6, int=4}},
        {id="r_de_8", name="피의 갈증", desc="가한 피해의 10% 흡혈", type="passive", statBonus={lifesteal=10}},
        {id="r_de_9", name="마왕의 피", desc="5턴간 피해의 50% 흡혈 버프", type="active", cooldown=35, buff="mega_lifesteal"}
    }
}

M.races.lizardfolk = {
    tier1 = {
        {id="r_lz_1", name="늪지 생존술", desc="독 면역", type="passive", resist={poison=1.0}},
        {id="r_lz_2", name="단단한 비늘", desc="방어력 +3", type="passive", statBonus={def=3}},
        {id="r_lz_3", name="꼬리치기", desc="단일 근접 적 넉백", type="active", cooldown=6, attackScale=1.2, action="knockback"}
    },
    tier2 = {
        {id="r_lz_4", name="야성의 회복력", desc="자연 회복량 +2", type="passive", statBonus={hpRegen=2}},
        {id="r_lz_5", name="수중 호흡", desc="얼음 저항 +20%", type="passive", resist={ice=0.2}},
        {id="r_lz_6", name="맹독 뱉기", desc="원거리 독 피해", type="active", cooldown=5, attackScale=1.4, element="poison", range=4}
    },
    tier3 = {
        {id="r_lz_7", name="고대 파충류", desc="CON +7, STR +3", type="passive", statBonus={con=7, str=3}},
        {id="r_lz_8", name="포식자", desc="적 처치 시 HP 10 회복", type="passive", statBonus={healOnKill=10}},
        {id="r_lz_9", name="맹독의 피", desc="피격 시 공격자에게 강력한 독 반사 버프", type="active", cooldown=30, buff="poison_thorns"}
    }
}

M.races.merfolk = {
    tier1 = {
        {id="r_mf_1", name="물의 축복", desc="얼음 저항 +30%", type="passive", resist={ice=0.3}},
        {id="r_mf_2", name="유연한 몸", desc="회피 +5", type="passive", statBonus={ev=5}},
        {id="r_mf_3", name="물대포", desc="원거리 얼음 피해", type="active", cooldown=4, attackScale=1.3, element="ice", range=5}
    },
    tier2 = {
        {id="r_mf_4", name="마력의 흐름", desc="INT +4", type="passive", statBonus={int=4}},
        {id="r_mf_5", name="회복의 물방울", desc="아군 단일 상태이상 제거", type="active", cooldown=8, action="cleanse", range=4},
        {id="r_mf_6", name="얼음 방패", desc="3턴간 방어력 대폭 증가", type="active", cooldown=15, buff="ice_shield"}
    },
    tier3 = {
        {id="r_mf_7", name="심해의 지배자", desc="INT +6, DEX +4", type="passive", statBonus={int=6, dex=4}},
        {id="r_mf_8", name="동결", desc="얼음 공격 시 15% 확률로 적 빙결", type="passive", statBonus={freezeHit=15}},
        {id="r_mf_9", name="해일", desc="광역 얼음 데미지 및 적 턴 지연", type="active", cooldown=35, aoeRadius=4, element="ice", debuff="stun"}
    }
}

M.races.golem_p = {
    tier1 = {
        {id="r_gl_1", name="바위 몸뚱이", desc="최대 HP +40", type="passive", statBonus={maxHp=40}},
        {id="r_gl_2", name="무감각", desc="독, 출혈 면역", type="passive", resist={poison=1.0, bleed=1.0}},
        {id="r_gl_3", name="돌주먹", desc="근접 강타", type="active", cooldown=5, attackScale=1.6, element="strike"}
    },
    tier2 = {
        {id="r_gl_4", name="룬 각인", desc="방어력 +6", type="passive", statBonus={def=6}},
        {id="r_gl_5", name="마법 흡수", desc="마법 저항 +15%", type="passive", statBonus={magicResist=0.15}},
        {id="r_gl_6", name="강제 보호", desc="주변 적을 도발", type="active", cooldown=15, aoeRadius=3, debuff="taunt"}
    },
    tier3 = {
        {id="r_gl_7", name="대지의 심장", desc="CON +10", type="passive", statBonus={con=10}},
        {id="r_gl_8", name="육중함", desc="넉백 무시", type="passive", statBonus={knockbackResist=100}},
        {id="r_gl_9", name="지진", desc="발을 굴러 광역 데미지 및 기절", type="active", cooldown=30, aoeRadius=3, element="strike", debuff="stun"}
    }
}

M.races.shadowkin = {
    tier1 = {
        {id="r_sh_1", name="어둠의 시야", desc="시야 반경 +3", type="passive", statBonus={fov=3}},
        {id="r_sh_2", name="그림자 숨기", desc="회피 +15", type="passive", statBonus={ev=15}},
        {id="r_sh_3", name="그림자 일격", desc="단일 적에게 방어 무시 암흑 피해", type="active", cooldown=6, attackScale=1.2, element="poison"}
    },
    tier2 = {
        {id="r_sh_4", name="치명적인 그림자", desc="치명타 데미지 배율 +0.5x", type="passive", statBonus={critMult=0.5}},
        {id="r_sh_5", name="장막", desc="3턴간 회피율 대폭 상승 버프", type="active", cooldown=12, buff="shadow_step"},
        {id="r_sh_6", name="시야 차단", desc="주변 적 명중률 0으로 만듦", type="active", cooldown=15, aoeRadius=2, debuff="blind"}
    },
    tier3 = {
        {id="r_sh_7", name="그림자 군주", desc="DEX +8, STR +2", type="passive", statBonus={dex=8, str=2}},
        {id="r_sh_8", name="흡수", desc="적 처치 시 쿨타임 1 감소", type="passive", statBonus={cdReductionOnKill=1}},
        {id="r_sh_9", name="그림자 분신", desc="피격 무효화를 3회 제공하는 분신 생성", type="active", cooldown=40, buff="shadow_clone_3"}
    }
}

M.races.sylph = {
    tier1 = {
        {id="r_sy_1", name="바람의 발걸음", desc="회피 +10", type="passive", statBonus={ev=10}},
        {id="r_sy_2", name="폭풍 저항", desc="번개 저항 +30%", type="passive", resist={lightning=0.3}},
        {id="r_sy_3", name="돌풍", desc="적을 밀쳐냄", type="active", cooldown=5, attackScale=1.0, action="knockback", range=4}
    },
    tier2 = {
        {id="r_sy_4", name="날카로운 바람", desc="관통 데미지 +15%", type="passive", statBonus={pierceDmgMult=0.15}},
        {id="r_sy_5", name="바람의 인도", desc="명중률 +20", type="passive", statBonus={accuracy=20}},
        {id="r_sy_6", name="연쇄 번개", desc="광역 번개 피해", type="active", cooldown=8, aoeRadius=2, element="lightning", attackScale=1.5}
    },
    tier3 = {
        {id="r_sy_7", name="바람의 군주", desc="DEX +7, INT +3", type="passive", statBonus={dex=7, int=3}},
        {id="r_sy_8", name="잔상", desc="항상 15% 확률로 공격 회피", type="passive", statBonus={dodgeChance=15}},
        {id="r_sy_9", name="순풍", desc="파티 전체의 이동 및 공격 딜레이 완전 제거 1턴", type="active", cooldown=35, buff="party_haste"}
    }
}

-- ===== CLASSES (15) =====
M.classes.priest = {
    tier1 = {
        {id="c_pr_1", name="굳건한 믿음", desc="최대 HP +15, 방어력 +2", type="passive", statBonus={maxHp=15, def=2}},
        {id="c_pr_2", name="신성한 오라", desc="매 턴 체력 회복", type="passive", statBonus={hpRegen=2}},
        {id="c_pr_3", name="치유의 손길", desc="단일 대상 체력 회복", type="active", cooldown=4, heal=25, range=4}
    },
    tier2 = {
        {id="c_pr_4", name="정화", desc="독, 출혈 등 상태이상 면역", type="passive", resist={poison=1.0, bleed=1.0}},
        {id="c_pr_5", name="권능", desc="회복 스킬 계수 +50%", type="passive", statBonus={healMult=0.5}},
        {id="c_pr_6", name="심판의 빛", desc="신성 데미지 + 방어력 감소", type="active", cooldown=8, attackScale=1.5, element="holy", debuff="def_down", range=5}
    },
    tier3 = {
        {id="c_pr_7", name="대천사의 가호", desc="INT +10, 신성 피해량 +30%", type="passive", statBonus={int=10, holyDmgMult=0.3}},
        {id="c_pr_8", name="빛의 기둥", desc="광역 신성 데미지 및 아군 회복", type="active", cooldown=15, aoeRadius=3, element="holy", attackScale=2.0, heal=30},
        {id="c_pr_9", name="부활의 기도", desc="사망한 아군 동료 1명을 HP 50%로 부활", type="active", cooldown=50, action="resurrect_companion"}
    }
}

M.classes.berserker = {
    tier1 = {
        {id="c_be_1", name="끓는 피", desc="최대 HP +25", type="passive", statBonus={maxHp=25}},
        {id="c_be_2", name="거친 일격", desc="타격/참격 대미지 +10%", type="passive", statBonus={meleeDmgMult=0.1}},
        {id="c_be_3", name="도약 공격", desc="적에게 도약하여 피해 (사거리 4)", type="active", cooldown=8, attackScale=1.5, range=4, dash=true}
    },
    tier2 = {
        {id="c_be_4", name="학살", desc="치명타 데미지 배율 +0.5x", type="passive", statBonus={critMult=0.5}},
        {id="c_be_5", name="광기의 피", desc="HP가 낮을수록 공격력 증가", type="passive", statBonus={rage=30}},
        {id="c_be_6", name="회전 베기", desc="주변 모든 적에게 큰 피해", type="active", cooldown=10, aoeRadius=1, attackScale=1.8, element="slash"}
    },
    tier3 = {
        {id="c_be_7", name="전투광", desc="STR +10", type="passive", statBonus={str=10}},
        {id="c_be_8", name="광전사의 흡혈", desc="적 처치 시 체력 15% 회복", type="passive", statBonus={healOnKill=15}},
        {id="c_be_9", name="불사", desc="3턴간 HP가 1 이하로 떨어지지 않음", type="active", cooldown=40, buff="undying"}
    }
}

M.classes.cryomancer = {
    tier1 = {
        {id="c_cr_1", name="얼음 친화", desc="얼음 공격력 +15%", type="passive", statBonus={iceDmgMult=0.15}},
        {id="c_cr_2", name="냉기 방패", desc="방어력 +3", type="passive", statBonus={def=3}},
        {id="c_cr_3", name="얼음 송곳", desc="단일 얼음 피해", type="active", cooldown=3, attackScale=1.3, element="ice", range=6}
    },
    tier2 = {
        {id="c_cr_4", name="극한의 추위", desc="적을 얼릴 확률 +15%", type="passive", statBonus={freezeHit=15}},
        {id="c_cr_5", name="빙벽", desc="일시적으로 방어력 극대화", type="active", cooldown=15, buff="ice_wall"},
        {id="c_cr_6", name="서리 폭발", desc="광역 얼음 데미지", type="active", cooldown=10, aoeRadius=2, attackScale=1.6, element="ice"}
    },
    tier3 = {
        {id="c_cr_7", name="서리의 군주", desc="INT +8, CON +2", type="passive", statBonus={int=8, con=2}},
        {id="c_cr_8", name="절대 영도", desc="얼음 저항 100%", type="passive", resist={ice=1.0}},
        {id="c_cr_9", name="눈보라", desc="화면 전체 광역 빙결 및 지속 데미지", type="active", cooldown=30, aoeRadius=8, attackScale=2.5, element="ice", debuff="stun"}
    }
}

M.classes.stormcaller = {
    tier1 = {
        {id="c_sc_1", name="정전기", desc="번개 공격력 +15%", type="passive", statBonus={lightningDmgMult=0.15}},
        {id="c_sc_2", name="번개 걸음", desc="이동 속도 및 회피 +5", type="passive", statBonus={ev=5, speed=5}},
        {id="c_sc_3", name="전기 충격", desc="단일 대상 번개 피해 및 스턴", type="active", cooldown=6, attackScale=1.2, element="lightning", range=5, debuff="stun"}
    },
    tier2 = {
        {id="c_sc_4", name="과부하", desc="치명타 확률 +20%", type="passive", statBonus={critChance=20}},
        {id="c_sc_5", name="번개 폭풍", desc="주변 무작위 적 번개 타격", type="active", cooldown=12, aoeRadius=3, attackScale=1.8, element="lightning"},
        {id="c_sc_6", name="순간 이동", desc="원하는 위치로 순간 이동", type="active", cooldown=15, action="teleport", range=6}
    },
    tier3 = {
        {id="c_sc_7", name="폭풍의 지배자", desc="INT +9, DEX +1", type="passive", statBonus={int=9, dex=1}},
        {id="c_sc_8", name="폭풍의 눈", desc="번개 피해 시 10% 확률로 쿨타임 초기화", type="passive", statBonus={cdResetOnHit=10}},
        {id="c_sc_9", name="뇌우 소환", desc="매 턴 무작위 적에게 번개 타격 5턴", type="active", cooldown=35, buff="thunderstorm"}
    }
}

M.classes.pyromancer = {
    tier1 = {
        {id="c_py_1", name="화염 지식", desc="화염 공격력 +20%", type="passive", statBonus={fireDmgMult=0.2}},
        {id="c_py_2", name="열기", desc="주변 적에게 미세한 지속 데미지", type="passive", statBonus={fireAura=1}},
        {id="c_py_3", name="파이어볼", desc="단일 대상 강력한 화염 폭발", type="active", cooldown=4, attackScale=1.6, element="fire", range=6}
    },
    tier2 = {
        {id="c_py_4", name="방화광", desc="치명타 데미지 배율 +0.4x", type="passive", statBonus={critMult=0.4}},
        {id="c_py_5", name="화염 장벽", desc="화염 광역 피해 및 넉백", type="active", cooldown=12, aoeRadius=2, attackScale=1.5, element="fire", action="knockback"},
        {id="c_py_6", name="소각", desc="단일 대상 화염 극한 피해", type="active", cooldown=10, attackScale=3.0, element="fire", range=5}
    },
    tier3 = {
        {id="c_py_7", name="화염의 화신", desc="INT +10, 화염 저항 100%", type="passive", statBonus={int=10}, resist={fire=1.0}},
        {id="c_py_8", name="잔불", desc="적 처치 시 마나 5 회복", type="passive", statBonus={mpOnKill=5}},
        {id="c_py_9", name="대폭발", desc="스스로 30% 피해를 입으며 맵 전체 괴멸적 데미지", type="active", cooldown=40, aoeRadius=8, attackScale=5.0, element="fire", action="self_damage_30"}
    }
}

M.classes.necromancer = {
    tier1 = {
        {id="c_ne_1", name="죽음의 지식", desc="독 공격력 +15%", type="passive", statBonus={poisonDmgMult=0.15}},
        {id="c_ne_2", name="시체 활용", desc="적 처치 시 HP 5 회복", type="passive", statBonus={healOnKill=5}},
        {id="c_ne_3", name="영혼 화살", desc="단일 대상 암흑 피해 및 흡혈", type="active", cooldown=5, attackScale=1.3, element="poison", healScale=0.5, range=5}
    },
    tier2 = {
        {id="c_ne_4", name="어둠의 오라", desc="주변 적 방어력 저하", type="passive", statBonus={auraDefDown=2}},
        {id="c_ne_5", name="뼈 갑옷", desc="방어력 +5, 물리 저항 +10%", type="passive", statBonus={def=5, physResist=0.1}},
        {id="c_ne_6", name="해골 소환", desc="해골 전사 1마리 소환", type="active", cooldown=20, summon="skeleton"}
    },
    tier3 = {
        {id="c_ne_7", name="리치 왕", desc="INT +8, CON +2", type="passive", statBonus={int=8, con=2}},
        {id="c_ne_8", name="영혼 수확", desc="가한 피해의 20% 흡혈", type="passive", statBonus={lifesteal=20}},
        {id="c_ne_9", name="죽음의 군대", desc="강화된 해골 3마리 즉시 소환", type="active", cooldown=50, summon="skeleton_3"}
    }
}

M.classes.monk = {
    tier1 = {
        {id="c_mo_1", name="무술 연마", desc="타격 대미지 +15%", type="passive", statBonus={strikeDmgMult=0.15}},
        {id="c_mo_2", name="날렵함", desc="회피 +10", type="passive", statBonus={ev=10}},
        {id="c_mo_3", name="연타", desc="단일 대상 2번 타격", type="active", cooldown=6, attackScale=1.0, element="strike", action="double_strike"}
    },
    tier2 = {
        {id="c_mo_4", name="기 집중", desc="최대 마나 +20", type="passive", statBonus={maxMana=20}},
        {id="c_mo_5", name="회피 반격", desc="회피 성공 시 반격 데미지", type="passive", statBonus={counterAttack=50}},
        {id="c_mo_6", name="기공파", desc="원거리 타격 데미지", type="active", cooldown=5, attackScale=1.5, element="strike", range=5}
    },
    tier3 = {
        {id="c_mo_7", name="달인", desc="STR +4, DEX +6", type="passive", statBonus={str=4, dex=6}},
        {id="c_mo_8", name="무념무상", desc="상태이상 면역", type="passive", resist={poison=1.0, bleed=1.0, stun=1.0}},
        {id="c_mo_9", name="천수관음", desc="다음 턴에 무조건 4연속 공격", type="active", cooldown=35, buff="quad_strike"}
    }
}

M.classes.samurai = {
    tier1 = {
        {id="c_sa_1", name="검도", desc="참격 대미지 +20%", type="passive", statBonus={slashDmgMult=0.2}},
        {id="c_sa_2", name="집중", desc="명중률 +15", type="passive", statBonus={accuracy=15}},
        {id="c_sa_3", name="발도술", desc="빠른 선제 공격", type="active", cooldown=4, attackScale=1.4, element="slash"}
    },
    tier2 = {
        {id="c_sa_4", name="치명적인 베기", desc="치명타 확률 +15%", type="passive", statBonus={critChance=15}},
        {id="c_sa_5", name="명경지수", desc="방어력 +3, 회피 +5", type="passive", statBonus={def=3, ev=5}},
        {id="c_sa_6", name="반격 자세", desc="1턴간 무조건 반격", type="active", cooldown=15, buff="counter_stance"}
    },
    tier3 = {
        {id="c_sa_7", name="검호", desc="STR +6, DEX +4", type="passive", statBonus={str=6, dex=4}},
        {id="c_sa_8", name="일격필살", desc="치명타 시 데미지 배율 +1.0x", type="passive", statBonus={critMult=1.0}},
        {id="c_sa_9", name="일섬", desc="적 방어력 0 간주, 초강력 단일 베기", type="active", cooldown=30, attackScale=3.5, element="slash", action="ignore_def"}
    }
}

M.classes.alchemist = {
    tier1 = {
        {id="c_al_1", name="독성 지식", desc="독 공격력 +20%", type="passive", statBonus={poisonDmgMult=0.2}},
        {id="c_al_2", name="포션 숙련", desc="포션 회복량 50% 증가", type="passive", statBonus={potionEff=50}},
        {id="c_al_3", name="산성 플라스크", desc="단일 대상 독 피해 및 방어력 감소", type="active", cooldown=5, attackScale=1.4, element="poison", range=5, debuff="def_down"}
    },
    tier2 = {
        {id="c_al_4", name="독 면역", desc="독 저항 100%", type="passive", resist={poison=1.0}},
        {id="c_al_5", name="수류탄 투척", desc="광역 화염 피해", type="active", cooldown=8, aoeRadius=2, attackScale=1.5, element="fire", range=4},
        {id="c_al_6", name="회복 물약 투척", desc="아군 단일 체력 회복", type="active", cooldown=10, heal=30, range=4}
    },
    tier3 = {
        {id="c_al_7", name="연금술 마스터", desc="INT +6, DEX +4", type="passive", statBonus={int=6, dex=4}},
        {id="c_al_8", name="돌연변이", desc="최대 HP +40", type="passive", statBonus={maxHp=40}},
        {id="c_al_9", name="맹독 플라스크", desc="광역 독 및 적 체력회복 불가 디버프", type="active", cooldown=25, aoeRadius=3, attackScale=2.0, element="poison", debuff="heal_block"}
    }
}

M.classes.druid = {
    tier1 = {
        {id="c_dr_1", name="자연의 힘", desc="최대 HP +20", type="passive", statBonus={maxHp=20}},
        {id="c_dr_2", name="재생", desc="턴마다 HP 2 회복", type="passive", statBonus={hpRegen=2}},
        {id="c_dr_3", name="자연의 치유", desc="단일 아군 회복", type="active", cooldown=5, heal=25, range=5}
    },
    tier2 = {
        {id="c_dr_4", name="가시 덩굴", desc="적 속박 및 지속 피해", type="active", cooldown=10, range=4, debuff="root"},
        {id="c_dr_5", name="자연의 방패", desc="마법 저항 +20%", type="passive", statBonus={magicResist=0.2}},
        {id="c_dr_6", name="독안개", desc="광역 독 피해", type="active", cooldown=12, aoeRadius=2, element="poison", attackScale=1.5}
    },
    tier3 = {
        {id="c_dr_7", name="대드루이드", desc="INT +5, CON +5", type="passive", statBonus={int=5, con=5}},
        {id="c_dr_8", name="야생의 본능", desc="회피 +15, 명중 +15", type="passive", statBonus={ev=15, accuracy=15}},
        {id="c_dr_9", name="곰 변신", desc="5턴간 체력/방어력/공격력 극대화, 근접만 가능", type="active", cooldown=40, buff="bear_form"}
    }
}

M.classes.warlock = {
    tier1 = {
        {id="c_wa_1", name="흑마술", desc="마법 공격력 +15%", type="passive", statBonus={magicDmgMult=0.15}},
        {id="c_wa_2", name="마나 착취", desc="적 처치 시 마나 10 회복", type="passive", statBonus={mpOnKill=10}},
        {id="c_wa_3", name="저주", desc="적 공격력 및 방어력 감소", type="active", cooldown=8, range=5, debuff="curse"}
    },
    tier2 = {
        {id="c_wa_4", name="어둠의 계약", desc="최대 마나 +30, 마나 회복 +2", type="passive", statBonus={maxMana=30, mpRegen=2}},
        {id="c_wa_5", name="고통의 일격", desc="단일 대상 강력한 암흑 피해", type="active", cooldown=6, attackScale=1.8, element="poison", range=5},
        {id="c_wa_6", name="생명력 전환", desc="HP 20%를 깎고 마나 50% 회복", type="active", cooldown=10, action="life_tap"}
    },
    tier3 = {
        {id="c_wa_7", name="금지된 지식", desc="INT +12, 방어력 -5", type="passive", statBonus={int=12, def=-5}},
        {id="c_wa_8", name="파멸의 징조", desc="치명타 확률 +25%", type="passive", statBonus={critChance=25}},
        {id="c_wa_9", name="영혼 붕괴", desc="자신의 HP 30%를 소모하여 단일 적 즉사급 피해", type="active", cooldown=35, attackScale=5.0, element="poison", action="self_damage_30", range=6}
    }
}

M.classes.spellblade = {
    tier1 = {
        {id="c_sp_1", name="무기와 마법", desc="물리 및 마법 대미지 +10%", type="passive", statBonus={meleeDmgMult=0.1, magicDmgMult=0.1}},
        {id="c_sp_2", name="전투 집중", desc="명중 +10", type="passive", statBonus={accuracy=10}},
        {id="c_sp_3", name="원소 베기", 무작위 원소 근접 타격="active", cooldown=4, attackScale=1.4, element="magic"}
    },
    tier2 = {
        {id="c_sp_4", name="마법 부여", desc="3턴간 무기에 화염, 얼음 속성 부여", type="active", cooldown=12, buff="enchant_weapon"},
        {id="c_sp_5", name="검기", desc="전방 일직선 관통 피해", type="active", cooldown=8, attackScale=1.5, element="slash", aoeRadius="line_3"},
        {id="c_sp_6", name="비전 방패", desc="마나의 일정량만큼 대미지 흡수막 생성", type="active", cooldown=15, buff="mana_barrier"}
    },
    tier3 = {
        {id="c_sp_7", name="마검 마스터", desc="STR +5, INT +5", type="passive", statBonus={str=5, int=5}},
        {id="c_sp_8", name="검과 마법의 조화", desc="스킬 사용 후 다음 기본 공격 대미지 2배", type="passive", statBonus={spellbladeCombo=true}},
        {id="c_sp_9", name="마법검 해방", desc="다음 3번의 공격에 모든 원소 속성 동시 적용 폭딜", type="active", cooldown=35, buff="omni_enchant"}
    }
}

M.classes.guardian = {
    tier1 = {
        {id="c_gu_1", name="방패 수련", desc="방어력 +5", type="passive", statBonus={def=5}},
        {id="c_gu_2", name="강인함", desc="최대 HP +30", type="passive", statBonus={maxHp=30}},
        {id="c_gu_3", name="방패 밀치기", desc="적에게 피해 + 기절", type="active", cooldown=6, attackScale=1.2, element="strike", debuff="stun"}
    },
    tier2 = {
        {id="c_gu_4", name="도발", desc="주변 적의 어그로 획득", type="active", cooldown=10, aoeRadius=3, debuff="taunt"},
        {id="c_gu_5", name="수호자의 오라", desc="주변 아군 방어력 증가", type="passive", statBonus={auraDefUp=3}},
        {id="c_gu_6", name="철벽 방어", desc="1턴간 피해 무효화", type="active", cooldown=15, buff="invincible_1"}
    },
    tier3 = {
        {id="c_gu_7", name="요새", desc="CON +10", type="passive", statBonus={con=10}},
        {id="c_gu_8", name="반사 신경", desc="피격 시 20% 대미지 반사", type="passive", statBonus={thorns=20}},
        {id="c_gu_9", name="절대 방벽", desc="3턴간 받는 데미지 80% 감소 및 상태이상 면역", type="active", cooldown=40, buff="absolute_guard"}
    }
}

M.classes.shaman = {
    tier1 = {
        {id="c_sh_1", name="정령의 축복", desc="모든 저항 +10%", type="passive", resist={fire=0.1, ice=0.1, poison=0.1, lightning=0.1}},
        {id="c_sh_2", name="영적 시야", desc="시야 반경 +2", type="passive", statBonus={fov=2}},
        {id="c_sh_3", name="치유의 토템", desc="매 턴 체력을 회복하는 토템 소환", type="active", cooldown=15, summon="heal_totem"}
    },
    tier2 = {
        {id="c_sh_4", name="정령술", desc="번개 및 얼음 공격력 +15%", type="passive", statBonus={lightningDmgMult=0.15, iceDmgMult=0.15}},
        {id="c_sh_5", name="번개 토템", desc="적을 자동 공격하는 번개 토템 소환", type="active", cooldown=15, summon="lightning_totem"},
        {id="c_sh_6", name="정령의 결속", desc="소환수의 체력/공격력 50% 증가", type="passive", statBonus={summonPower=50}}
    },
    tier3 = {
        {id="c_sh_7", name="대주술사", desc="INT +8, CON +2", type="passive", statBonus={int=8, con=2}},
        {id="c_sh_8", name="대지의 진동", desc="광역 타격 데미지 및 이동 속도 감소", type="active", cooldown=20, aoeRadius=3, attackScale=1.8, element="strike", debuff="slow"},
        {id="c_sh_9", name="정령의 대토템", desc="아군 대량 회복 + 적 광역 공격 융합 토템 소환", type="active", cooldown=45, summon="master_totem"}
    }
}

M.classes.engineer = {
    tier1 = {
        {id="c_en_1", name="공학 지식", desc="원거리 대미지 +15%", type="passive", statBonus={rangedDmgMult=0.15}},
        {id="c_en_2", name="빠른 설치", desc="덫/소환수 쿨타임 20% 감소", type="passive", statBonus={summonCdReduction=20}},
        {id="c_en_3", name="지뢰 설치", desc="밟으면 터지는 지뢰", type="active", cooldown=5, action="spawn_mine"}
    },
    tier2 = {
        {id="c_en_4", name="충격장", desc="마법 방어력 +20%", type="passive", statBonus={magicResist=0.2}},
        {id="c_en_5", name="터렛 설치", desc="자동 사격 터렛 소환", type="active", cooldown=15, summon="turret"},
        {id="c_en_6", name="강화 산탄", desc="부채꼴 넓은 범위 물리 데미지", type="active", cooldown=8, attackScale=1.5, element="pierce", aoeRadius=2}
    },
    tier3 = {
        {id="c_en_7", name="수석 공학자", desc="DEX +6, INT +4", type="passive", statBonus={dex=6, int=4}},
        {id="c_en_8", name="탄약 개조", desc="모든 원거리 공격이 적 방어력 30% 무시", type="passive", statBonus={armorPenetration=30}},
        {id="c_en_9", name="자동 포탑", desc="전투 종료 시까지 적을 강력하게 사격하는 중무장 포탑", type="active", cooldown=40, summon="heavy_turret"}
    }
}

return M
"""

with open("d:/2021391007/LUAproject/project/src/skills_db_expanded.lua", "w", encoding="utf-8") as f:
    f.write(get_lua_str())

print("Successfully wrote skills_db_expanded.lua")
