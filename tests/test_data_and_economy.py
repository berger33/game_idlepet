import glob, json, unittest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).parents[1] / 'tools'))
from economy_sim import Config, simulate
from career_sim import simulate as simulate_career

class FoundationTests(unittest.TestCase):
    def test_all_json_parses_and_has_schema(self):
        for path in glob.glob('data/*.json'):
            with self.subTest(path=path):
                data=json.loads(Path(path).read_text(encoding='utf8'))
                self.assertGreaterEqual(data['schema_version'],1)
    def test_ids_are_unique(self):
        for path in glob.glob('data/*.json'):
            data=json.loads(Path(path).read_text(encoding='utf8'))
            arrays=[v for v in data.values() if isinstance(v,list)]
            for arr in arrays:
                ids=[v.get('id') for v in arr if isinstance(v,dict) and 'id' in v]
                self.assertEqual(len(ids),len(set(ids)),path)
    def test_early_upgrade_pacing(self):
        rows=simulate(Config(),5)
        self.assertLessEqual(rows[0][3],3)
        self.assertLess(rows[4][4],8)
    def test_cost_and_income_monotonic(self):
        rows=simulate(Config(),20)
        self.assertEqual([r[1] for r in rows],sorted(r[1] for r in rows))
        self.assertEqual([r[2] for r in rows],sorted(r[2] for r in rows))

    def test_save_schema_and_migration_are_current(self):
        state = Path('autoload/GameState.gd').read_text(encoding='utf8')
        migration = Path('autoload/SaveManager.gd').read_text(encoding='utf8')
        self.assertIn('const SAVE_VERSION: int = 8', state)
        self.assertIn('return 50 + (player_level - 1) * 25', state)
        self.assertIn('if version == 5:', migration)
        self.assertIn('if version == 6:', migration)
        self.assertIn('if version == 7:', migration)
        self.assertIn('data["version"] = 8', migration)
        self.assertIn('tool_upgrade_levels', state)
        self.assertIn('active_cosmetics', state)

    def test_retention_systems_are_wired(self):
        state = Path('autoload/GameState.gd').read_text(encoding='utf8')
        self.assertIn('streak_freezes', state)
        self.assertIn('claim_pass_day', state)
        self.assertIn('check_return_bonus', state)
        pass_data = json.loads(Path('data/pass.json').read_text(encoding='utf8'))
        days = pass_data['pass']
        self.assertEqual(len(days), 28)
        self.assertEqual([d['day'] for d in days], list(range(1, 29)))
        self.assertTrue(all(d['coins'] > 0 for d in days))
        self.assertTrue(any('embers' in d for d in days))
        self.assertTrue(any('freeze' in d for d in days))
        liveops = Path('autoload/LiveOps.gd').read_text(encoding='utf8')
        self.assertIn('events_enabled', liveops)
        self.assertIn('event_boost_scale', liveops)
        notif = Path('autoload/NotificationManager.gd').read_text(encoding='utf8')
        self.assertIn('deep_link_section', notif)
        self.assertIn('--section=', notif)
        share = Path('autoload/ShareManager.gd').read_text(encoding='utf8')
        self.assertIn('finish_snapshot', share)
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        self.assertEqual(main.count('Button.new()'), 1)
        self.assertIn('ShareManager.begin_snapshot', main)
        self.assertIn('SessionFeedback.show_comeback(self)', main)
        self.assertIn('SessionFeedback.on_share_pressed.bind(self)', main)
        feedback = Path('core/ui/SessionFeedback.gd').read_text(encoding='utf8')
        self.assertIn('static func show_comeback(', feedback)
        self.assertIn('static func on_share_pressed(', feedback)
        self.assertIn('GameState.check_return_bonus()', feedback)
        self.assertIn('ShareManager.last_saved_path', feedback)

    def test_localization_parity_across_languages(self):
        import csv
        sets = {}
        for lang in ('pt_BR', 'en_US', 'es_ES'):
            with open(f'data/localization/{lang}.csv', encoding='utf-8') as f:
                sets[lang] = {r[0] for r in csv.reader(f) if r and r[0] != 'key'}
        self.assertEqual(sets['pt_BR'], sets['en_US'])
        self.assertEqual(sets['pt_BR'], sets['es_ES'])

    def test_fase4_prestige_cosmetics_and_audio_anchor(self):
        economy = Path('autoload/Economy.gd').read_text(encoding='utf8')
        self.assertIn('prestige_coin_multiplier', economy)
        self.assertIn('PRESTIGE_COIN_BONUS', economy)
        state = Path('autoload/GameState.gd').read_text(encoding='utf8')
        for token in ('func equip_cosmetic', 'func perform_prestige',
                      'prestige_tokens_available', 'active_cosmetics'):
            self.assertIn(token, state)
        reset_block = state.split('func perform_prestige', 1)[1].split('func ', 2)[1]
        self.assertNotIn('total_coins =', reset_block)
        self.assertNotIn('unlocked_pets =', reset_block)
        canvas = Path('core/gameplay/PetShopCanvas.gd').read_text(encoding='utf8')
        for token in ('func set_cosmetics', '_bath_foam_color', 'AudioManager.beat_phase'):
            self.assertIn(token, canvas)
        cosmetics_art = Path('core/gameplay/PetCosmeticsArt.gd').read_text(encoding='utf8')
        for token in ('bandana_blue', 'crown_bubbles', 'wall_junina', 'scarf_caramel'):
            self.assertIn(token, cosmetics_art)
        audio = Path('autoload/AudioManager.gd').read_text(encoding='utf8')
        self.assertIn('func beat_phase', audio)
        self.assertIn('get_playback_position', audio)
        self.assertIn('MUSIC_BPM', audio)
        self.assertIn('func _energy_loop', audio)
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        self.assertIn('prestige_level', main)
        self.assertIn('world.set_cosmetics', main)
        panel = Path('scenes/main/MetaPanel.gd').read_text(encoding='utf8')
        self.assertIn('EQUIPPED', panel)
        self.assertIn('PRESTIGE_GO', panel)
        migration = Path('autoload/SaveManager.gd').read_text(encoding='utf8')
        self.assertIn('if version == 7:', migration)

    def test_fase6_buddy_priority_and_staff_vocations(self):
        state = Path('autoload/GameState.gd').read_text(encoding='utf8')
        for token in ('func set_favorite_pet', 'func staff_vocation', 'STAFF_VOCATION',
                      'var favorite_pet'):
            self.assertIn(token, state)
        for voc in ('VOCATION_BATHER', 'VOCATION_STYLIST', 'VOCATION_VETERINARY',
                    'VOCATION_PERFECTIONIST', 'VOCATION_GROOMER', 'VOCATION_MASSEUSE'):
            self.assertIn(f'"{voc}"', state)
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        self.assertIn('GameState.favorite_pet', main)
        self.assertIn('buddy_spawned', main)
        panel = Path('scenes/main/MetaPanel.gd').read_text(encoding='utf8')
        self.assertIn('FAVORITE_SET', panel)
        self.assertIn('MISSION_NOTE', panel)
        content = Path('autoload/ContentDB.gd').read_text(encoding='utf8')
        self.assertIn('func staff(', content)

    def test_fase7_queue_follows_daily_event(self):
        liveops = Path('autoload/LiveOps.gd').read_text(encoding='utf8')
        self.assertIn('func featured_service', liveops)
        self.assertIn('events_on()', liveops)
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        self.assertIn('LiveOps.featured_service()', main)
        self.assertIn('event_client', main)

    def test_fase5_weekly_missions_and_cosmetic_catalog(self):
        weekly = json.loads(Path('data/weekly_missions.json').read_text(encoding='utf8'))
        missions = weekly['missions']
        self.assertEqual(len(missions), 7)
        ids = [m['id'] for m in missions]
        self.assertEqual(len(set(ids)), 7)
        self.assertTrue(
            {m['metric'] for m in missions}
            <= {'services', 'perfect', 'combo_max', 'tips', 'style', 'vip', 'spend'}
        )
        self.assertTrue(
            all(m['reward'].get('coins', 0) >= 400 or m['reward'].get('embers', 0) >= 2
                for m in missions)
        )
        state = Path('autoload/GameState.gd').read_text(encoding='utf8')
        for token in ('func claim_weekly', 'func register_weekly_event',
                      'func register_weekly_spend', 'func _week_key', 'claimed_weeklies'):
            self.assertIn(token, state)
        self.assertIn('weekly_mission', Path('autoload/ContentDB.gd').read_text(encoding='utf8'))
        cosmetics = json.loads(Path('data/cosmetics.json').read_text(encoding='utf8'))['cosmetics']
        self.assertEqual(len(cosmetics), 11)
        cosmetic_ids = {c['id'] for c in cosmetics}
        self.assertTrue(
            {'tub_mint', 'tub_lavender', 'bandana_red', 'scarf_caramel', 'crown_gold',
             'wall_beach'} <= cosmetic_ids
        )
        cosmetics_art = Path('core/gameplay/PetCosmeticsArt.gd').read_text(encoding='utf8')
        for token in ('tub_mint', 'tub_lavender', 'bandana_red', 'scarf_caramel',
                      'crown_gold', 'wall_beach'):
            self.assertIn(token, cosmetics_art)
        liveops = Path('autoload/LiveOps.gd').read_text(encoding='utf8')
        self.assertIn('EVENT_%d', liveops)
        self.assertIn('claim_weekly', Path('scenes/main/MetaPanel.gd').read_text(encoding='utf8'))

    def test_career_has_at_least_fifty_active_hours(self):
        rows = simulate_career()
        self.assertEqual(rows[-1]['reached_level'], 120)
        self.assertGreaterEqual(rows[-1]['estimated_active_hours'], 60.0)
        expert_hours = rows[-1]['cumulative_xp'] / 15.0 * 14.5 / 3600.0 * 1.10
        self.assertGreaterEqual(expert_hours, 50.0)

    def test_pet_catalog_has_dogs_cats_and_long_term_unlocks(self):
        pets = json.loads(Path('data/pets.json').read_text(encoding='utf8'))['pets']
        self.assertEqual(len(pets), 50)
        self.assertEqual(sum(pet['species'] == 'dog' for pet in pets), 25)
        self.assertEqual(sum(pet['species'] == 'cat' for pet in pets), 25)
        levels = sorted(pet['unlock_level'] for pet in pets)
        self.assertEqual(max(levels), 120)
        self.assertLessEqual(max(b - a for a, b in zip(levels, levels[1:])), 8)

    def test_all_buttons_use_universal_interaction_feedback(self):
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        self.assertEqual(main.count('Button.new()'), 1)
        self.assertIn('InteractionFX.bind_button(button)', main)
        self.assertIn('react_to_touch()', main)

    def test_every_catalogued_achievement_is_evaluated(self):
        catalog = json.loads(Path('data/achievements.json').read_text(encoding='utf8'))
        source = Path('autoload/GameState.gd').read_text(encoding='utf8')
        for achievement in catalog['achievements']:
            self.assertIn(f'_unlock_achievement("{achievement["id"]}"', source)
        self.assertIn('unlocked_cosmetics.append("crown_bubbles")', source)

    def test_daily_mission_rewards_match_the_hud_contract(self):
        catalog = json.loads(Path('data/daily_missions.json').read_text(encoding='utf8'))
        active = {mission['id']: mission for mission in catalog['missions'][:3]}
        self.assertEqual(set(active), {'daily_bath_5', 'daily_perfect_3', 'daily_upgrade_1'})
        self.assertTrue(all(mission['reward'] == {'coins': 75} for mission in active.values()))

    def test_drag_tools_and_individual_upgrades_are_complete(self):
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        canvas = Path('core/gameplay/PetShopCanvas.gd').read_text(encoding='utf8')
        upgrades = json.loads(Path('data/upgrades.json').read_text(encoding='utf8'))['upgrades']
        systems = {entry['system'] for entry in upgrades}
        self.assertTrue({'soap', 'clipper', 'dryer', 'perfume', 'bow'} <= systems)
        for tool in ('soap', 'clipper', 'dryer', 'perfume', 'bow'):
            self.assertIn(f'&"{tool}"', main)
            self.assertIn(f'&"{tool}"', canvas)
        self.assertNotIn('ProgressBar.new()', main)
        tool_drawer = canvas.split('func _draw_tool(', 1)[1].split('func _draw_heart', 1)[0]
        self.assertIn('draw_texture_rect(', tool_drawer)
        self.assertIn('var texture: Texture2D = TOOL_TEXTURES[tool]', tool_drawer)
        self.assertNotIn('draw_colored_polygon', tool_drawer)
        self.assertIn('buy_tool_upgrade', main)
        self.assertIn('upgrade_income_growth": 1.075', Path('autoload/RemoteConfig.gd').read_text())

    def test_all_catalogued_pets_have_commercial_art_and_safe_fallback(self):
        catalog = json.loads(Path('data/pets.json').read_text(encoding='utf8'))['pets']
        expected = {pet['id'] for pet in catalog}
        files = {path.stem for path in Path('art/pets').glob('*.png')}
        self.assertEqual(len(files), 50)
        self.assertEqual(files, expected)
        for pet_id in expected:
            raw = (Path('art/pets') / f'{pet_id}.png').read_bytes()
            self.assertGreater(len(raw), 150_000)
            self.assertEqual(raw[24], 8)
            self.assertEqual(raw[25], 6)
        canvas = Path('core/gameplay/PetShopCanvas.gd').read_text(encoding='utf8')
        self.assertIn('ResourceLoader.exists(texture_path)', canvas)
        self.assertIn('if is_instance_valid(pet_texture):', canvas)
        self.assertIn('_draw_illustrated_pet(center)', canvas)

    def test_pet_animation_production_tracker_and_first_batch(self):
        tracker = json.loads(Path('data/pet_animation_production.json').read_text(encoding='utf8'))
        catalog = json.loads(Path('data/pets.json').read_text(encoding='utf8'))['pets']
        states = {
            'dirty', 'wet', 'messy', 'tilt_left', 'tilt_right',
            'happy_squash', 'happy_air', 'dizzy', 'sad', 'blink'
        }
        self.assertEqual(tracker['generated_image_limit_per_batch'], 10)
        self.assertEqual(set(tracker['authored_states']), states)
        self.assertEqual([entry['pet_id'] for entry in tracker['pets']], [pet['id'] for pet in catalog])
        self.assertEqual(len({entry['batch_id'] for entry in tracker['pets']}), 50)
        self.assertTrue(all(set(entry['states']) == states for entry in tracker['pets']))
        self.assertEqual(tracker['summary']['images_expected'], 500)
        accepted = sum(
            record['status'] == 'qa_passed'
            for entry in tracker['pets'] for record in entry['states'].values()
        )
        self.assertEqual(tracker['summary']['images_generated'], accepted)
        self.assertEqual(tracker['summary']['images_qa_passed'], accepted)
        self.assertEqual(
            tracker['summary']['generation_attempts'],
            sum(entry['generation_attempts'] for entry in tracker['pets'])
        )
        for entry in tracker['pets']:
            for record in entry['states'].values():
                path = Path(record['path'])
                if record['status'] == 'qa_passed':
                    raw = path.read_bytes()
                    self.assertEqual(int.from_bytes(raw[16:20], 'big'), 512)
                    self.assertEqual(int.from_bytes(raw[20:24], 'big'), 512)
                    self.assertEqual(raw[25], 6)
                elif record['status'].startswith('rejected'):
                    self.assertFalse(path.exists())
        first = tracker['pets'][0]
        self.assertEqual(first['pet_id'], 'caramelo')
        self.assertEqual(first['visual_qa_status'], 'passed')
        self.assertEqual(first['integration_status'], 'integrated')
        for state, record in first['states'].items():
            path = Path(record['path'])
            raw = path.read_bytes()
            self.assertEqual(record['status'], 'qa_passed', state)
            self.assertEqual(raw[:8], b'\x89PNG\r\n\x1a\n')
            self.assertEqual(int.from_bytes(raw[16:20], 'big'), 512)
            self.assertEqual(int.from_bytes(raw[20:24], 'big'), 512)
            self.assertEqual(raw[24], 8)
            self.assertEqual(raw[25], 6)
        luna = tracker['pets'][1]
        self.assertEqual(luna['generation_status'], 'complete')
        self.assertEqual(luna['visual_qa_status'], 'passed')
        self.assertEqual(luna['integration_status'], 'integrated')
        for state, record in luna['states'].items():
            self.assertEqual(record['status'], 'qa_passed')
            self.assertTrue(Path(record['path']).exists(), state)
        mingau = tracker['pets'][2]
        self.assertEqual(mingau['generation_status'], 'complete')
        self.assertEqual(mingau['visual_qa_status'], 'passed')
        self.assertEqual(mingau['integration_status'], 'integrated')
        self.assertTrue(all(record['status'] == 'qa_passed' for record in mingau['states'].values()))
        for entry in tracker['pets'][3:17]:
            self.assertEqual(entry['generation_status'], 'complete', entry['pet_id'])
            self.assertEqual(entry['visual_qa_status'], 'passed', entry['pet_id'])
            self.assertEqual(entry['integration_status'], 'integrated', entry['pet_id'])
            self.assertTrue(
                all(record['status'] == 'qa_passed' for record in entry['states'].values()),
                entry['pet_id']
            )
        self.assertEqual(tracker['summary']['pets_integrated'], 50)

    def test_pet_animation_runtime_uses_strict_context_triggers(self):
        canvas = Path('core/gameplay/PetShopCanvas.gd').read_text(encoding='utf8')
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        self.assertIn('PET_TEXTURE_BASELINE', canvas)
        self.assertIn('art/pet_animations/%s/%s.png', canvas)
        self.assertIn('func begin_service()', canvas)
        self.assertIn('func complete_service()', canvas)
        self.assertIn('func depart()', canvas)
        self.assertIn('func _service_effect_active()', canvas)
        self.assertIn('celebration > 0.0 and special_reward_active', canvas)
        self.assertNotIn('if service_progress > 0.96:', canvas)
        self.assertIn('world.begin_service()', main)
        self.assertIn('world.complete_service()', main)
        self.assertIn('world.depart()', main)
        self.assertIn('world.celebrate(quality == &"perfect" or GameState.combo >= 5)', main)
        touch = canvas.split('func react_to_touch()', 1)[1].split('func react_to_service', 1)[0]
        self.assertIn('reaction_kind = &"love"', touch)
        self.assertIn('hearts', touch)

    def test_service_layouts_and_commercial_tool_art(self):
        layouts = json.loads(Path('data/service_layouts.json').read_text(encoding='utf8'))
        self.assertEqual([stage['unlock_level'] for stage in layouts['stages']], [1, 3, 5, 7, 10])
        self.assertEqual({stage['workstation'] for stage in layouts['stages']}, {
            'deep_bathtub', 'grooming_table', 'padded_drying_table',
            'spa_pedestal', 'styling_ottoman'
        })
        for stage in layouts['stages']:
            self.assertEqual(len(stage['shelf_y']), 5)
            self.assertEqual(stage['shelf_y'], sorted(stage['shelf_y']))
            self.assertTrue((Path('art/backgrounds') / stage['background']).exists())
        for tool in ('soap', 'clipper', 'dryer', 'perfume', 'bow'):
            path = Path('art/props') / f'tool_{tool}.png'
            raw = path.read_bytes()
            self.assertGreater(len(raw), 100_000)
            self.assertEqual(raw[:8], b'\x89PNG\r\n\x1a\n')
            self.assertEqual(raw[24], 8)  # 8-bit channels
            self.assertEqual(raw[25], 6)  # RGBA, transparency is mandatory

    def test_godot_47_compatibility_regressions(self):
        canvas = Path('core/gameplay/PetShopCanvas.gd').read_text(encoding='utf8')
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        presets = Path('export_presets.cfg').read_text(encoding='utf8')
        content_db = Path('autoload/ContentDB.gd').read_text(encoding='utf8')
        self.assertNotIn('func draw_ellipse(', canvas)
        self.assertIn('func _draw_pet_ellipse(', canvas)
        # 4.7.2: `func staff` colidia com `var staff` (erro de parse que impede
        # a inicialização; o Godot 4.3 do CI tolerava a colisão).
        self.assertIn('var staff_members:', content_db)
        self.assertNotIn('var staff:', content_db)
        self.assertIn('func staff(', content_db)
        self.assertNotIn('FILA  2', canvas)
        self.assertNotIn('bottom.offset_top', main)
        self.assertIn('action_hud.position = Vector2(45, 1350)', main)
        self.assertIn('nav.position = Vector2(45, 155)', main)
        self.assertNotIn('ProgressBar.new()', main)
        self.assertIn('world.tool_at(point)', main)
        self.assertIn('draw_arc(tool_position, 66.0', canvas)
        self.assertNotIn('for shelf_y:', canvas)
        self.assertIn('✓  CONTINUAR', main)
        # O CTA morto "DOBRAR PONTUAÇÃO • EM BREVE" foi removido (auditoria C10);
        # ele não pode voltar sem um provedor de anúncios real.
        self.assertNotIn('EM BREVE', main)
        self.assertNotIn('double_reward_button', main)
        self.assertIn('include_filter=""', presets)
        self.assertIn('exclude_filter=', presets)
        self.assertNotIn('platform="Android"', presets)

    def test_no_gdscript_name_collisions(self):
        # No Godot 4.4+ declarar função com o mesmo nome de uma variável já
        # declarada é erro de parse (o 4.3 usado pelo CI tolerava). Esta varredura
        # cobre a classe inteira de erro em todas as versões.
        import re
        pattern = re.compile(
            r'^(?:var|const|signal|enum)\s+([A-Za-z_][A-Za-z0-9_]*)'
            r'|^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)',
            re.MULTILINE,
        )
        for path in Path('.').rglob('*.gd'):
            if '.git' in path.parts:
                continue
            names: dict = {}
            for match in pattern.finditer(path.read_text(encoding='utf8')):
                name = match.group(1) or match.group(2)
                names.setdefault(name, []).append(match.start())
            collisions = {name for name, spots in names.items() if len(spots) > 1}
            self.assertEqual(collisions, set(), f'{path}: nomes declarados 2x (var/func/const/signal): {collisions}')

    def test_no_orphan_private_method_references(self):
        # Referências a métodos privados (_nome) sem definição no próprio
        # arquivo são erros de análise no Godot 4.7+ (ex.: _show_comeback e
        # _on_share_pressed órfãos quebravam o Main). Métodos nativos não usam
        # o prefixo _ exceto os overrides de ciclo de vida abaixo.
        import re
        lifecycle = {
            '_ready', '_process', '_physics_process', '_input', '_unhandled_input',
            '_unhandled_key_input', '_draw', '_notification', '_init', '_enter_tree',
            '_exit_tree', '_gui_input', '_get_configuration_warnings', '_make_custom_tooltip',
        }
        call_pattern = re.compile(r'(?<![\w.])(_[A-Za-z_][A-Za-z0-9_]*)\s*\(')
        connect_pattern = re.compile(r'\.connect\(\s*(_[A-Za-z_][A-Za-z0-9_]*)\s*[,)]')
        for path in Path('.').rglob('*.gd'):
            if '.git' in path.parts:
                continue
            text = path.read_text(encoding='utf8')
            defined = set(re.findall(r'^\t?(?:static\s+)?func\s+(_?[A-Za-z_][A-Za-z0-9_]*)', text, re.MULTILINE))
            for match in call_pattern.finditer(text):
                name = match.group(1)
                if name in defined or name in lifecycle:
                    continue
                line = text[:match.start()].count('\n') + 1
                self.fail(f'{path}:{line}: chamada órfã {name}() — método não declarado no arquivo')
            for match in connect_pattern.finditer(text):
                name = match.group(1)
                if name in defined:
                    continue
                line = text[:match.start()].count('\n') + 1
                self.fail(f'{path}:{line}: connect({name}) referencia handler não declarado')

    def test_professional_backgrounds_exist_and_are_reasonable(self):
        for name in (
            'petshop_quintal.png', 'petshop_tosa.png', 'petshop_secagem.png',
            'petshop_perfume.png', 'petshop_estilo.png'
        ):
            path = Path('art/backgrounds') / name
            self.assertTrue(path.exists(), name)
            self.assertGreater(path.stat().st_size, 100_000)
            self.assertLess(path.stat().st_size, 5_000_000)

    def test_fase8_neighborhood_reputation(self):
        economy = Path('autoload/Economy.gd').read_text(encoding='utf8')
        for token in ('NEIGHBORHOOD_TIERS', 'func neighborhood_tier', 'func vip_chance',
                      'func tip_bonus', 'NEIGHBORHOOD_VIP_BONUS', 'NEIGHBORHOOD_TIP_BONUS'):
            self.assertIn(token, economy)
        self.assertIn('[0, 60, 150, 300, 600]', economy)
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        self.assertIn('Economy.vip_chance(GameState.reviews_sum)', main)
        self.assertIn('Economy.tip_bonus(GameState.reviews_sum)', main)
        self.assertIn('REP_UP', main)
        panel = Path('scenes/main/MetaPanel.gd').read_text(encoding='utf8')
        self.assertIn('NEIGHBORHOOD_%d', panel)


if __name__=='__main__': unittest.main()
