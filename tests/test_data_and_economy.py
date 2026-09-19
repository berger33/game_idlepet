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
        self.assertIn('const SAVE_VERSION: int = 7', state)
        self.assertIn('return 50 + (player_level - 1) * 25', state)
        self.assertIn('if version == 5:', migration)
        self.assertIn('if version == 6:', migration)
        self.assertIn('data["version"] = 7', migration)
        self.assertIn('tool_upgrade_levels', state)

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
        self.assertIn('_show_comeback()', main)

    def test_localization_parity_across_languages(self):
        import csv
        sets = {}
        for lang in ('pt_BR', 'en_US', 'es_ES'):
            with open(f'data/localization/{lang}.csv', encoding='utf-8') as f:
                sets[lang] = {r[0] for r in csv.reader(f) if r and r[0] != 'key'}
        self.assertEqual(sets['pt_BR'], sets['en_US'])
        self.assertEqual(sets['pt_BR'], sets['es_ES'])

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
        self.assertEqual(tracker['summary']['pets_integrated'], 17)

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
        self.assertNotIn('func draw_ellipse(', canvas)
        self.assertIn('func _draw_pet_ellipse(', canvas)
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

    def test_professional_backgrounds_exist_and_are_reasonable(self):
        for name in (
            'petshop_quintal.png', 'petshop_tosa.png', 'petshop_secagem.png',
            'petshop_perfume.png', 'petshop_estilo.png'
        ):
            path = Path('art/backgrounds') / name
            self.assertTrue(path.exists(), name)
            self.assertGreater(path.stat().st_size, 100_000)
            self.assertLess(path.stat().st_size, 5_000_000)

if __name__=='__main__': unittest.main()
