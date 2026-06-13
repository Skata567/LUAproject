local SKILLS_DB = {
    races = {
        human = {
            tier1 = {
                {id="h_t1_1", name="적응력", desc="최대 HP +10", type="passive", statBonus={maxHp=10}},
                {id="h_t1_2", name="끈기", desc="방어력 +1", type="passive", statBonus={def=1}},
                {id="h_t1_3", name="응급처치", desc="HP 10 회복", type="active", cooldown=10, heal=10}
            },
            tier2 = {
                {id="h_t2_1", name="잠재력", desc="모든 스탯 +1", type="passive", statBonus={str=1, dex=1, int=1, con=1, lck=1}},
                {id="h_t2_2", name="유연성", desc="회피율 +5", type="passive", statBonus={ev=5}},
                {id="h_t2_3", name="전력 질주", desc="다음 이동/공격 딜레이 감소", type="active", cooldown=15, buff="haste"}
            },
            tier3 = {
                {id="h_t3_1", name="인간의 의지", desc="최대 HP +20", type="passive", statBonus={maxHp=20}},
                {id="h_t3_2", name="만능 숙련", desc="모든 공격 대미지 +10%", type="passive", statBonus={dmgMult=0.1}},
                {id="h_t3_3", name="불굴", desc="다음 피격 대미지 50% 감소", type="active", cooldown=20, buff="shield_50"}
            }
        },
        elf = {
            tier1 = {
                {id="e_t1_1", name="마나 친화", desc="INT +2", type="passive", statBonus={int=2}},
                {id="e_t1_2", name="가벼운 발걸음", desc="회피율 +5", type="passive", statBonus={ev=5}},
                {id="e_t1_3", name="요정의 빛", desc="시야 반경 +2", type="passive", statBonus={fov=2}}
            },
            tier2 = {
                {id="e_t2_1", name="정밀 마법", desc="마법 대미지 +15%", type="passive", statBonus={magicDmgMult=0.15}},
                {id="e_t2_2", name="자연 저항", desc="독, 얼음 저항 +20%", type="passive", resist={poison=0.2, ice=0.2}},
                {id="e_t2_3", name="마나 실드", desc="3턴간 받는 대미지 30% 감소", type="active", cooldown=15, buff="mana_shield"}
            },
            tier3 = {
                {id="e_t3_1", name="엘프의 지혜", desc="INT +5", type="passive", statBonus={int=5}},
                {id="e_t3_2", name="바람의 인도", desc="DEX +3, 회피율 +10", type="passive", statBonus={dex=3, ev=10}},
                {id="e_t3_3", name="요정의 화살", desc="원거리 마법 대미지 발사", type="active", cooldown=8, attackScale=2.0, element="magic", range=5}
            }
        },
        dwarf = {
            tier1 = {
                {id="d_t1_1", name="튼튼한 체력", desc="CON +2, 최대 HP +15", type="passive", statBonus={con=2, maxHp=15}},
                {id="d_t1_2", name="대장장이의 손", desc="STR +2", type="passive", statBonus={str=2}},
                {id="d_t1_3", name="바위 던지기", desc="원거리 물리 대미지", type="active", cooldown=5, attackScale=1.2, range=4}
            },
            tier2 = {
                {id="d_t2_1", name="두꺼운 피부", desc="방어력 +3", type="passive", statBonus={def=3}},
                {id="d_t2_2", name="대지의 가호", desc="화염, 번개 저항 +20%", type="passive", resist={fire=0.2, lightning=0.2}},
                {id="d_t2_3", name="함성", desc="주변 적 방어력 감소", type="active", cooldown=15, aoeRadius=3, debuff="def_down"}
            },
            tier3 = {
                {id="d_t3_1", name="산의 심장", desc="CON +5, 독 면역", type="passive", statBonus={con=5}, resist={poison=1.0}},
                {id="d_t3_2", name="무기 연마", desc="참격, 타격 대미지 +20%", type="passive", statBonus={meleeDmgMult=0.2}},
                {id="d_t3_3", name="지진 타격", desc="주변 모든 적에게 강력한 타격 대미지", type="active", cooldown=20, attackScale=2.5, element="strike", aoeRadius=2}
            }
        },
        orc_p = {
            tier1 = {
                {id="o_t1_1", name="야성의 힘", desc="STR +3", type="passive", statBonus={str=3}},
                {id="o_t1_2", name="두꺼운 가죽", desc="방어력 +2", type="passive", statBonus={def=2}},
                {id="o_t1_3", name="피의 일격", desc="적에게 추가 대미지(타격)", type="active", cooldown=6, attackScale=1.5, element="strike"}
            },
            tier2 = {
                {id="o_t2_1", name="전투 본능", desc="공격력 +10%", type="passive", statBonus={atkMult=0.1}},
                {id="o_t2_2", name="강인한 생명력", desc="최대 HP +25", type="passive", statBonus={maxHp=25}},
                {id="o_t2_3", name="광폭화", desc="3턴간 공격력 50% 증가, 방어력 50% 감소", type="active", cooldown=20, buff="berserk"}
            },
            tier3 = {
                {id="o_t3_1", name="오크 대족장", desc="STR +5, 최대 HP +30", type="passive", statBonus={str=5, maxHp=30}},
                {id="o_t3_2", name="치명타 강화", desc="치명타 데미지 배율 +0.5x", type="passive", statBonus={critMult=0.5}},
                {id="o_t3_3", name="처형", desc="적의 체력이 30% 이하일 때 즉사급 대미지", type="active", cooldown=25, attackScale=4.0, element="slash"}
            }
        },
        halfling = {
            tier1 = {
                {id="ha_t1_1", name="작은 체구", desc="회피율 +10", type="passive", statBonus={ev=10}},
                {id="ha_t1_2", name="행운아", desc="LCK +3", type="passive", statBonus={lck=3}},
                {id="ha_t1_3", name="재빠른 도망", desc="다음 턴 이동속도 2배", type="active", cooldown=10, buff="fast_move"}
            },
            tier2 = {
                {id="ha_t2_1", name="기습", desc="찌르기 대미지 +15%", type="passive", statBonus={pierceDmgMult=0.15}},
                {id="ha_t2_2", name="독 내성", desc="독 저항 +50%", type="passive", resist={poison=0.5}},
                {id="ha_t2_3", name="돌팔매", desc="원거리 타격 대미지 + 기절 확률", type="active", cooldown=8, attackScale=1.0, element="strike", range=4, debuff="stun"}
            },
            tier3 = {
                {id="ha_t3_1", name="네잎 클로버", desc="LCK +7, 회피율 +15", type="passive", statBonus={lck=7, ev=15}},
                {id="ha_t3_2", name="약점 파악", desc="치명타 확률 +15%", type="passive", statBonus={critChance=15}},
                {id="ha_t3_3", name="행운의 회피", desc="3턴간 회피율 99% 증가", type="active", cooldown=30, buff="lucky_dodge_3"}
            }
        },
        troll_p = {
            tier1 = {
                {id="t_t1_1", name="거인의 체력", desc="최대 HP +30", type="passive", statBonus={maxHp=30}},
                {id="t_t1_2", name="자연 치유", desc="초당 체력 자연회복 증가 (매 10턴마다 1회복)", type="passive", statBonus={hpRegen=1}},
                {id="t_t1_3", name="거친 몽둥이질", desc="강력한 타격 공격", type="active", cooldown=5, attackScale=1.6, element="strike"}
            },
            tier2 = {
                {id="t_t2_1", name="압도적인 완력", desc="STR +4", type="passive", statBonus={str=4}},
                {id="t_t2_2", name="초재생", desc="체력 자연회복 2배 (매 5턴마다 1회복)", type="passive", statBonus={hpRegen=2}},
                {id="t_t2_3", name="괴성", desc="주변 적 공격력 감소", type="active", cooldown=15, aoeRadius=3, debuff="atk_down"}
            },
            tier3 = {
                {id="t_t3_1", name="불사의 피", desc="CON +6, 체력 회복량 +50%", type="passive", statBonus={con=6, healMult=0.5}},
                {id="t_t3_2", name="바위 맷집", desc="받는 물리 대미지 20% 감소", type="passive", statBonus={physResist=0.2}},
                {id="t_t3_3", name="대지 부수기", desc="주변 반경 3칸 내 적에게 큰 데미지 + 기절", type="active", cooldown=25, attackScale=2.0, element="strike", aoeRadius=3, debuff="stun"}
            }
        },
        undead_p = {
            tier1 = {
                {id="u_t1_1", name="시체의 육체", desc="최대 HP +10, 방어력 +2", type="passive", statBonus={maxHp=10, def=2}},
                {id="u_t1_2", name="어둠의 시야", desc="시야 반경 +1", type="passive", statBonus={fov=1}},
                {id="u_t1_3", name="부패의 손길", desc="독 속성 공격", type="active", cooldown=6, attackScale=1.2, element="poison"}
            },
            tier2 = {
                {id="u_t2_1", name="망자의 한기", desc="얼음 저항 +50%, 얼음 공격력 +15%", type="passive", resist={ice=0.5}, statBonus={iceDmgMult=0.15}},
                {id="u_t2_2", name="뼈의 갑옷", desc="참격 저항 +20%", type="passive", resist={slash=0.2}},
                {id="u_t2_3", name="영혼 흡수", desc="적의 마나 흡수", type="active", cooldown=12, action="mp_drain", value=10}
            },
            tier3 = {
                {id="u_t3_1", name="불멸자", desc="체력이 0이 될 때 1회 부활 (HP 30%)", type="passive", statBonus={resurrect=1}},
                {id="u_t3_2", name="맹독의 체액", desc="공격 시 20% 확률로 독 상태이상 부여", type="passive", statBonus={poisonHit=20}},
                {id="u_t3_3", name="망자의 군단", desc="주변에 해골 2마리 소환", type="active", cooldown=40, summon="skeleton"}
            }
        },
        vampire = {
            tier1 = {
                {id="v_t1_1", name="어둠의 권속", desc="시야 반경 +2", type="passive", statBonus={fov=2}},
                {id="v_t1_2", name="날카로운 송곳니", desc="찌르기 대미지 +10%", type="passive", statBonus={pierceDmgMult=0.1}},
                {id="v_t1_3", name="흡혈 박쥐", desc="단일 대상 HP 흡수", type="active", cooldown=8, attackScale=1.0, healScale=1.0}
            },
            tier2 = {
                {id="v_t2_1", name="매혹", desc="적 1마리를 3턴간 기절(혼란)", type="active", cooldown=15, range=4, debuff="stun"},
                {id="v_t2_2", name="귀족의 혈통", desc="모든 스탯 +1, 최대 HP +15", type="passive", statBonus={str=1, dex=1, int=1, con=1, lck=1, maxHp=15}},
                {id="v_t2_3", name="안개화", desc="3턴간 모든 물리 공격 무시", type="active", cooldown=30, buff="ethereal"}
            },
            tier3 = {
                {id="v_t3_1", name="진조", desc="STR +3, INT +3, 흡혈량 +50%", type="passive", statBonus={str=3, int=3, lifestealMult=0.5}},
                {id="v_t3_2", name="핏빛 장막", desc="적을 처치할 때마다 최대 HP의 5% 회복", type="passive", statBonus={healOnKill=5}},
                {id="v_t3_3", name="피의 폭풍", desc="주변 반경 4칸 적 모두에게 큰 데미지 및 대량 흡혈", type="active", cooldown=40, attackScale=2.5, healScale=0.5, aoeRadius=4}
            }
        },
        automaton = {
            tier1 = {
                {id="a_t1_1", name="장갑판", desc="방어력 +4", type="passive", statBonus={def=4}},
                {id="a_t1_2", name="강철 주먹", desc="타격 대미지 +15%", type="passive", statBonus={strikeDmgMult=0.15}},
                {id="a_t1_3", name="과열", desc="다음 공격이 화염 대미지 추가", type="active", cooldown=10, buff="fire_weapon"}
            },
            tier2 = {
                {id="a_t2_1", name="야간 투시", desc="시야 반경 +3", type="passive", statBonus={fov=3}},
                {id="a_t2_2", name="완전 면역", desc="독, 출혈 면역", type="passive", resist={poison=1.0, bleed=1.0}},
                {id="a_t2_3", name="로켓 펀치", desc="원거리 물리(타격) 대미지", type="active", cooldown=12, attackScale=2.0, element="strike", range=5}
            },
            tier3 = {
                {id="a_t3_1", name="초합금 프레임", desc="방어력 +10, 최대 HP +40", type="passive", statBonus={def=10, maxHp=40}},
                {id="a_t3_2", name="자가 수리", desc="피격 시 20% 확률로 HP 5 회복", type="passive", statBonus={autoRepair=20}},
                {id="a_t3_3", name="오버클럭", desc="5턴간 모든 행동 딜레이 절반, 공격력 2배. 이후 1턴 기절", type="active", cooldown=40, buff="overclock"}
            }
        }
    },
    classes = {
        fighter = {
            tier1 = {
                {id="c_f_t1_1", name="검술 연마", desc="참격 대미지 +15%", type="passive", statBonus={slashDmgMult=0.15}},
                {id="c_f_t1_2", name="단련된 신체", desc="최대 HP +20", type="passive", statBonus={maxHp=20}},
                {id="c_f_t1_3", name="강타", desc="적에게 강력한 일격", type="active", cooldown=5, attackScale=1.5}
            },
            tier2 = {
                {id="c_f_t2_1", name="방어 태세", desc="방어력 +5", type="passive", statBonus={def=5}},
                {id="c_f_t2_2", name="분노", desc="HP가 50% 이하일 때 공격력 20% 증가", type="passive", statBonus={rage=20}},
                {id="c_f_t2_3", name="돌진", desc="적에게 다가가며 공격 (사거리 3)", type="active", cooldown=10, attackScale=1.2, range=3, dash=true}
            },
            tier3 = {
                {id="c_f_t3_1", name="전장의 지배자", desc="STR +5, 최대 HP +50", type="passive", statBonus={str=5, maxHp=50}},
                {id="c_f_t3_2", name="반격", desc="회피 성공 시 적에게 100% 확률로 반격", type="passive", statBonus={counterAttack=100}},
                {id="c_f_t3_3", name="휠윈드", desc="주변 모든 적에게 무기 대미지 2배", type="active", cooldown=15, attackScale=2.0, aoeRadius=1}
            }
        },
        rogue = {
            tier1 = {
                {id="c_r_t1_1", name="단검 숙련", desc="찌르기 대미지 +15%", type="passive", statBonus={pierceDmgMult=0.15}},
                {id="c_r_t1_2", name="민첩함", desc="회피율 +10", type="passive", statBonus={ev=10}},
                {id="c_r_t1_3", name="독 바르기", desc="다음 3번의 공격에 독 부여", type="active", cooldown=15, buff="poison_weapon"}
            },
            tier2 = {
                {id="c_r_t2_1", name="급소 노리기", desc="치명타 확률 +15%", type="passive", statBonus={critChance=15}},
                {id="c_r_t2_2", name="그림자 걷기", desc="은신 상태 돌입 (적의 시야에서 벗어남)", type="active", cooldown=20, buff="stealth"},
                {id="c_r_t2_3", name="투척", desc="단검을 던져 원거리 공격", type="active", cooldown=4, attackScale=1.0, range=5, element="pierce"}
            },
            tier3 = {
                {id="c_r_t3_1", name="암살자", desc="DEX +5, 치명타 데미지 배율 +1.0x", type="passive", statBonus={dex=5, critMult=1.0}},
                {id="c_r_t3_2", name="치명적인 독", desc="독 속성 공격력 +50%", type="passive", statBonus={poisonDmgMult=0.5}},
                {id="c_r_t3_3", name="암살", desc="은신 상태에서 공격 시 4배 대미지", type="active", cooldown=30, buff="assassinate"}
            }
        },
        mage = {
            tier1 = {
                {id="c_m_t1_1", name="마나 증폭", desc="마법 공격력 +15%", type="passive", statBonus={magicDmgMult=0.15}},
                {id="c_m_t1_2", name="명상", desc="매 턴 마나 혹은 체력 약간 회복", type="passive", statBonus={hpRegen=1}},
                {id="c_m_t1_3", name="매직 미사일", desc="원거리 마법 공격", type="active", cooldown=3, attackScale=1.2, range=6, element="magic"}
            },
            tier2 = {
                {id="c_m_t2_1", name="원소 지식", desc="화염, 얼음, 번개 공격력 +20%", type="passive", statBonus={elementDmgMult=0.2}},
                {id="c_m_t2_2", name="화염구", desc="지정된 위치 반경 1칸 화염 폭발", type="active", cooldown=8, attackScale=1.8, range=5, aoeRadius=1, element="fire"},
                {id="c_m_t2_3", name="얼음 창", desc="단일 적에게 얼음 대미지 + 빙결(기절)", type="active", cooldown=12, attackScale=1.5, range=6, element="ice", debuff="stun"}
            },
            tier3 = {
                {id="c_m_t3_1", name="대마법사", desc="INT +7, 마법 쿨타임 20% 감소", type="passive", statBonus={int=7, cooldownReduction=20}},
                {id="c_m_t3_2", name="마나 장벽", desc="데미지 20% 무조건 감소", type="passive", statBonus={magicShield=20}},
                {id="c_m_t3_3", name="메테오", desc="화면 전체의 적에게 파괴적인 화염 대미지", type="active", cooldown=50, attackScale=4.0, element="fire", aoeRadius=10}
            }
        },
        paladin = {
            tier1 = {
                {id="c_p_t1_1", name="신앙심", desc="신성 공격력 +20%", type="passive", statBonus={holyDmgMult=0.2}},
                {id="c_p_t1_2", name="견고한 갑옷", desc="방어력 +4", type="passive", statBonus={def=4}},
                {id="c_p_t1_3", name="치유의 빛", desc="자신의 체력 30 회복", type="active", cooldown=15, heal=30}
            },
            tier2 = {
                {id="c_p_t2_1", name="성전사", desc="악마, 언데드 대상 대미지 +30%", type="passive", statBonus={smiteEvil=30}},
                {id="c_p_t2_2", name="신의 방패", desc="3턴간 모든 상태이상 면역 및 방어력 2배", type="active", cooldown=25, buff="holy_shield"},
                {id="c_p_t2_3", name="심판의 일격", desc="적에게 신성 대미지", type="active", cooldown=6, attackScale=1.5, element="holy"}
            },
            tier3 = {
                {id="c_p_t3_1", name="빛의 화신", desc="CON +4, INT +4, 신성 대미지 50% 추가", type="passive", statBonus={con=4, int=4, holyDmgMult=0.5}},
                {id="c_p_t3_2", name="신의 가호", desc="피격 시 10% 확률로 대미지 완전 무효화", type="passive", statBonus={divineBlock=10}},
                {id="c_p_t3_3", name="성역", desc="주변 3칸 내 적에게 턴당 신성 대미지 5턴 지속", type="active", cooldown=35, buff="sanctuary"}
            }
        },
        ranger = {
            tier1 = {
                {id="c_ra_t1_1", name="궁술 연마", desc="원거리 무기 사거리 +1 (회피+5)", type="passive", statBonus={ev=5, rangeBonus=1}},
                {id="c_ra_t1_2", name="야생의 감각", desc="시야 반경 +2", type="passive", statBonus={fov=2}},
                {id="c_ra_t1_3", name="조준 사격", desc="다음 공격이 무조건 명중 및 치명타", type="active", cooldown=12, buff="aimed_shot"}
            },
            tier2 = {
                {id="c_ra_t2_1", name="동체 시력", desc="치명타 확률 +20%", type="passive", statBonus={critChance=20}},
                {id="c_ra_t2_2", name="발목 베기", desc="적에게 대미지 + 3턴간 속도 감소", type="active", cooldown=10, attackScale=1.0, range=4, debuff="slow"},
                {id="c_ra_t2_3", name="덫 놓기", desc="현재 위치에 밟으면 기절하는 덫 설치", type="active", cooldown=15, action="spawn_trap"}
            },
            tier3 = {
                {id="c_ra_t3_1", name="사냥의 명수", desc="DEX +6, 공격력 +15%", type="passive", statBonus={dex=6, atkMult=0.15}},
                {id="c_ra_t3_2", name="다중 사격", desc="주변 3칸 내 모든 적에게 공격", type="active", cooldown=15, attackScale=1.0, aoeRadius=3},
                {id="c_ra_t3_3", name="자연의 동화", desc="5턴간 회피율 50 증가 및 이동 딜레이 무시", type="active", cooldown=40, buff="nature_meld"}
            }
        }
    }
}

local expanded = require("skills_db_expanded")
if expanded then
    for k, v in pairs(expanded.races) do
        SKILLS_DB.races[k] = v
    end
    for k, v in pairs(expanded.classes) do
        SKILLS_DB.classes[k] = v
    end
end

return SKILLS_DB
