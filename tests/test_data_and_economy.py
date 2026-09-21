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
        self.assertIn('const SAVE_VERSION: int = 11', state)
        self.assertIn('return 50 + (player_level - 1) * 25', state)
        self.assertIn('if version == 5:', migration)
        self.assertIn('if version == 6:', migration)
        self.assertIn('if version == 7:', migration)
        self.assertIn('if version == 8:', migration)
        self.assertIn('if version == 9:', migration)
        self.assertIn('if version == 10:', migration)
        self.assertIn('data["version"] = 11', migration)
        self.assertIn('data["research_ids"] = data.get("research_ids", [])', migration)
        self.assertIn('prestige_tokens_collected', migration)
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
        salon = Path('core/gameplay/SalonTuning.gd').read_text(encoding='utf8')
        self.assertIn('prestige_level', salon)
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
        salon = Path('core/gameplay/SalonTuning.gd').read_text(encoding='utf8')
        self.assertIn('GameState.favorite_pet', main)
        self.assertIn('buddy_spawned', salon)
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
        salon = Path('core/gameplay/SalonTuning.gd').read_text(encoding='utf8')
        self.assertIn('LiveOps.featured_service()', salon)
        self.assertIn('event_client', salon)

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

    def test_daily_missions_come_from_the_catalog(self):
        """Diárias sorteadas do catálogo (3 regulares + épica), metas escaladas
        e moedas escaladas à renda — antes eram 3 fixas triviais no código."""
        catalog = json.loads(Path('data/daily_missions.json').read_text(encoding='utf8'))
        missions = catalog['missions']
        regular = [m for m in missions if not m.get('epic')]
        epic = [m for m in missions if m.get('epic')]
        self.assertGreaterEqual(len(regular), 4, 'precisa de variedade para sortear 3')
        self.assertEqual(len(epic), 1)
        gd = Path('core/progression/Missions.gd').read_text(encoding='utf8')
        for metric in {m['metric'] for m in missions}:
            self.assertIn('"%s"' % metric, gd, 'métrica sem mapeamento de progresso')
            for code in ('pt_BR', 'en_US', 'es_ES'):
                self.assertIn('MISSION_METRIC_' + metric, _loc_table(code))
        self.assertIn('rng.seed = hash(day_key)', gd)
        self.assertIn('const REGULAR_COUNT: int = 3', gd)
        state = Path('autoload/GameState.gd').read_text(encoding='utf8')
        self.assertIn('daily_mission_ids = Missions.roll_for_day(today, player_level)', state)
        self.assertIn('Missions.is_ready(mission)', state)
        self.assertIn('Missions.regular_claimed_count() >= Missions.REGULAR_COUNT', state)
        self.assertNotIn('id == "daily_bath_5"', state)
        for key in ('four_plus_reviews', 'combo_reached'):
            self.assertIn('mission_progress["%s"]' % key, state)
        panel = Path('scenes/main/MetaPanel.gd').read_text(encoding='utf8')
        self.assertIn('Missions.today()', panel)
        content = Path('autoload/ContentDB.gd').read_text(encoding='utf8')
        self.assertIn('res://data/daily_missions.json', content)

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
        # Melhorias saíram do HUD de ação: botão redondo único abre o painel.
        self.assertIn('upgrades_button', main)
        self.assertIn('SessionFeedback.open_meta.bind(self, &"upgrades"', main)
        self.assertNotIn('upgrade_button = _button', main)
        self.assertNotIn('tool_upgrade_button', main)
        panel = Path('scenes/main/MetaPanel.gd').read_text(encoding='utf8')
        self.assertIn('buy_bath_upgrade', panel)
        self.assertIn('buy_tool_upgrade', panel)
        self.assertIn('&"upgrades":', panel)
        # Mobiliário funcional desenhado por código (alinhamento garantido).
        self.assertIn('StationArt.draw_shelf_unit(self)', canvas)
        self.assertIn('StationArt.draw_station(self)', canvas)
        self.assertIn('StationArt.draw_station_foreground(self)', canvas)
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
            # cada cenário tem a SUA estante temática (mesma geometria de
            # pranchas, material harmônico com a parede) — o item apoia nelas.
            shelf = Path('art/stations') / f"shelf_{stage['service']}.png"
            raw = shelf.read_bytes()
            self.assertEqual(raw[:8], b'\x89PNG\r\n\x1a\n', shelf.name)
            self.assertEqual(raw[25], 6, f'{shelf.name} precisa de alfa (RGBA)')
        # o runtime escolhe a estante pelo serviço (com fallback neutro)
        station_art = Path('core/gameplay/StationArt.gd').read_text(encoding='utf8')
        self.assertIn('"shelf_" + String(shop.service_mode)', station_art)
        self.assertIn('_art_texture(&"shelf_unit")', station_art)
        for tool in ('soap', 'clipper', 'dryer', 'perfume', 'bow'):
            path = Path('art/props') / f'tool_{tool}.png'
            raw = path.read_bytes()
            self.assertGreater(len(raw), 100_000)
            self.assertEqual(raw[:8], b'\x89PNG\r\n\x1a\n')
            self.assertEqual(raw[24], 8)  # 8-bit channels
            self.assertEqual(raw[25], 6)  # RGBA, transparency is mandatory

    def test_pet_accessory_worn_art(self):
        # todo acessório de pet tem ilustração própria "vestida" (RGBA) e o
        # runtime a ancora por espécie com fallback vetorial.
        cosmetics = json.loads(Path('data/cosmetics.json').read_text(encoding='utf8'))
        accessories = [
            item['id'] for item in cosmetics['cosmetics']
            if item.get('slot') == 'pet_accessory'
        ]
        self.assertEqual(
            sorted(accessories),
            ['bandana_blue', 'bandana_red', 'crown_bubbles', 'crown_gold', 'scarf_caramel'],
        )
        for acc_id in accessories:
            path = Path('art/cosmetics') / f'{acc_id}.png'
            raw = path.read_bytes()
            self.assertEqual(raw[:8], b'\x89PNG\r\n\x1a\n', path.name)
            self.assertEqual(raw[25], 6, f'{path.name} precisa de alfa (RGBA)')
        art = Path('core/gameplay/PetCosmeticsArt.gd').read_text(encoding='utf8')
        self.assertIn('"res://art/cosmetics/%s.png"', art)
        for acc_id in accessories:
            self.assertIn(f'"{acc_id}": {{', art, f'spec de {acc_id}')
        # âncoras por espécie (gato sentado tem cabeça/pescoço deslocados)
        self.assertIn('shop.species == &"cat"', art)
        self.assertIn('_draw_accessory_polygons', art)

    def test_godot_47_compatibility_regressions(self):
        canvas = Path('core/gameplay/PetShopCanvas.gd').read_text(encoding='utf8')
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        presets = Path('export_presets.cfg').read_text(encoding='utf8')
        content_db = Path('autoload/ContentDB.gd').read_text(encoding='utf8')
        self.assertNotIn('func draw_ellipse(', canvas)
        self.assertIn('func _draw_pet_ellipse(', canvas)
        # 4.7.2: `func staff` colidia com `var staff` (erro de parse que impede
        # a inicialização; o Godot 4.3 do CI tolerava a colisão). O rename
        # precisa ser COMPLETO: atribuição/iteração pela `staff` órfã resolvem
        # para o método e viram "assign to constant"/"iterate Callable".
        self.assertIn('var staff_members:', content_db)
        self.assertNotIn('var staff:', content_db)
        self.assertIn('func staff(', content_db)
        self.assertIn('staff_members = _load_array(STAFF_PATH', content_db)
        self.assertIn('for member: Dictionary in staff_members:', content_db)
        self.assertNotIn('\n\tstaff = ', content_db)
        self.assertNotIn(' in staff:', content_db)
        # 4.7.2 runtime: os botões de navegação eram conectados a `meta.open`
        # antes do MetaPanel existir (Nil access no meio do _build_interface,
        # sem afetar o exit code do smoke). O acesso ao painel é mediado.
        self.assertIn('SessionFeedback.open_meta.bind(self', main)
        self.assertNotIn('meta.open.bind', main)
        # 4.7.2 runtime: o painel meta nascia "aberto" — is_open() lê
        # screen.panel.visible, mas o _ready escondia só a raiz (panel.visible
        # continua true) → cartões da fila desabilitados para sempre e painéis
        # que não renderizavam ao abrir (open() não re-exibia a raiz).
        screen = Path('scenes/ui/meta_screen.gd').read_text(encoding='utf8')
        self.assertIn('panel.hide()', screen)
        self.assertIn('backdrop.hide()', screen)
        self.assertNotIn('\n\thide()\n', screen)
        metapanel = Path('scenes/main/MetaPanel.gd').read_text(encoding='utf8')
        self.assertIn('screen.panel.hide()', metapanel)
        self.assertIn('screen.backdrop.hide()', metapanel)
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
            # Escaneia só código: strings e comentários não são chamadas
            # (mensagens de erro podem citar nomes de métodos).
            code_only = re.sub(r'"[^"\n]*"', '""', text)
            code_only = re.sub(r"'[^'\n]*'", "''", code_only)
            code_only = re.sub(r'#.*', '', code_only)
            defined = set(re.findall(r'^\t?(?:static\s+)?func\s+(_?[A-Za-z_][A-Za-z0-9_]*)', code_only, re.MULTILINE))
            for match in call_pattern.finditer(code_only):
                name = match.group(1)
                if name in defined or name in lifecycle:
                    continue
                line = code_only[:match.start()].count('\n') + 1
                self.fail(f'{path}:{line}: chamada órfã {name}() — método não declarado no arquivo')
            for match in connect_pattern.finditer(code_only):
                name = match.group(1)
                if name in defined:
                    continue
                line = code_only[:match.start()].count('\n') + 1
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
        salon = Path('core/gameplay/SalonTuning.gd').read_text(encoding='utf8')
        self.assertIn('Economy.vip_chance(GameState.reviews_sum)', salon)
        self.assertIn('Economy.tip_bonus(GameState.reviews_sum)', salon)
        self.assertIn('REP_UP', main)
        panel = Path('scenes/main/MetaPanel.gd').read_text(encoding='utf8')
        self.assertIn('NEIGHBORHOOD_%d', panel)


class EngagementWaveTests(unittest.TestCase):
    """Ondas 1-3 do DESIGN_ENGAJAMENTO.md: gestos por serviço, temperamento,
    estados-consequência, fila com trade-offs, upsell, pico, marcos,
    maestria e carinho — contratos de fonte que o CI valida."""

    def _read(self, path):
        return Path(path).read_text(encoding='utf8')

    def test_wave1_gesture_modes_per_service(self):
        tuning = self._read('core/gameplay/SalonTuning.gd')
        for service, mode in (('bath', 'rub'), ('groom', 'stroke'), ('dry', 'zone'),
                              ('perfume', 'pulse'), ('style', 'drop')):
            self.assertIn(f'&"{service}": {{"axis":', tuning)
            self.assertIn(f'"mode": &"{mode}"', tuning)
        bath = self._read('core/gameplay/BathService.gd')
        for token in ('func configure_strokes', 'func configure_zone', 'func configure_pulses',
                      'func configure_drop', 'func configure_temperament', 'func pulse_contact',
                      'func pulse_bright', 'const GOOD_FLOOR'):
            self.assertIn(token, bath)

    def test_wave1_gesture_ui_and_forced_states_in_canvas(self):
        canvas = self._read('core/gameplay/PetShopCanvas.gd')
        gesture = self._read('core/gameplay/GestureArt.gd')
        for token in ('var gesture_ui', 'var forced_state', 'var playful_hop',
                      'var rush_active', 'var buddy_active', 'var buddy_pet_id',
                      'var tool_levels', 'GestureArt.draw_gesture_ui',
                      'GestureArt.draw_buddy'):
            self.assertIn(token, canvas)
        for token in ('static func draw_gesture_ui', 'static func draw_buddy',
                      'static func gesture_snapshot', '&"stroke"', '&"zone"',
                      '&"pulse"', '&"drop"'):
            self.assertIn(token, gesture)

    def test_wave1_localized_hints_match_new_gestures(self):
        expectations = {
            'data/localization/pt_BR.csv': ('setas', 'círculo', 'anel dourado', 'marca rosa'),
            'data/localization/en_US.csv': ('arrows', 'circle', 'golden ring', 'pink mark'),
            'data/localization/es_ES.csv': ('flechas', 'círculo', 'anillo dorado', 'marca rosa'),
        }
        for path, needles in expectations.items():
            text = self._read(path)
            for needle in needles:
                self.assertIn(needle, text, f'{path} sem hint do gesto novo: {needle}')

    def test_wave2_rush_and_upsell_remote_config(self):
        config = self._read('autoload/RemoteConfig.gd')
        for key in ('rush_interval_seconds', 'rush_duration', 'rush_tip_mult',
                    'upsell_chance', 'upsell_tip_mult', 'petting_max_per_client'):
            self.assertIn(f'"{key}"', config)
        # cada chave nova existe em DEFAULTS e em RANGES (2 ocorrências)
        for key in ('rush_interval_seconds', 'rush_duration', 'rush_tip_mult',
                    'upsell_chance', 'upsell_tip_mult', 'petting_max_per_client'):
            self.assertEqual(config.count(f'"{key}"'), 2, key)

    def test_wave2_rush_upsell_and_queue_tradeoffs_wired(self):
        main = self._read('scenes/main/Main.gd')
        for token in ('func _update_rush', 'func _start_rush', 'func _end_rush',
                      'func _offer_special', 'func _on_upsell_accept', 'func _on_upsell_decline',
                      'func _refill_delay', 'rush_combo_protection',
                      'SalonTuning.queue_info_text', 'SalonTuning.queue_border',
                      'special_multiplier'):
            self.assertIn(token, main, token)
        salon = self._read('core/gameplay/SalonTuning.gd')
        self.assertIn('upsell_chance', salon)
        salon = self._read('core/gameplay/SalonPanels.gd')
        for token in ('build_result_panel', 'build_upsell_panel', 'build_queue_card'):
            self.assertIn(token, salon)
            self.assertIn(token, main)

    def test_wave3_mastery_petting_and_buddy(self):
        state = self._read('autoload/GameState.gd')
        for token in ('func register_tool_use', 'var tool_uses', 'var rush_combo_protection',
                      '"tool_uses": tool_uses', 'TOOL_MASTERY_STEPS'):
            self.assertIn(token, state, token)
        tuning = self._read('core/gameplay/SalonTuning.gd')
        for token in ('TOOL_MASTERY_STEPS', 'static func mastery_bonus',
                      'static func compute_reward', 'static func make_client',
                      'static func hint'):
            self.assertIn(token, tuning, token)
        main = self._read('scenes/main/Main.gd')
        for token in ('register_tool_use', 'petting_max_per_client', 'buddy_active',
                      'bath_upgrade_level >= 30', 'mood_buff_clients', 'recovery_penalty'):
            self.assertIn(token, main, token)

    def test_tutorial_flow_extracted_and_wired(self):
        flow = self._read('scenes/main/TutorialFlow.gd')
        for token in ('func setup', 'func advance', 'func skip', 'func apply'):
            self.assertIn(token, flow)
        main = self._read('scenes/main/Main.gd')
        self.assertIn('var tutorial := TutorialFlow.new()', main)
        self.assertIn('tutorial.attach(self)', main)
        self.assertIn('tutorial_skip_button.pressed.connect(tutorial.skip)', main)
        self.assertNotIn('var tutorial_step', main)


class SoundDesignTests(unittest.TestCase):
    """Som com identidade por ação: cada gesto tem o SEU instrumento, modelado
    fisicamente (água, tesoura, ar, corda, aerossol) e versionado como WAV de
    44,1 kHz gerado por tools/gen_sfx.py — os osciladores de 8 bits em runtime
    foram aposentados. Junto: a trilha progressiva (a nota sobe com o
    progresso, aviso grave ao drenar, chime na janela perfeita, borrifadas
    subindo uma a uma) e a música ambiente intocada."""

    def _read(self, path):
        return Path(path).read_text(encoding='utf8')

    def _cached_names(self):
        """Nomes que o AudioManager coloca no cache -> (sons, aliases)."""
        cached, aliases = set(), set()
        for line in self._read('autoload/AudioManager.gd').splitlines():
            if line.startswith('\tcache[&"'):
                name = line.split('"')[1]
                cached.add(name)
                if '= cache[&"' in line:  # alias: aponta para outro som
                    aliases.add(name)
            elif line.startswith('\t_cache_ladder(&"'):
                base = line.split('(&"')[1].split('"')[0]
                steps = int(line.rstrip().rstrip(')').split(', ')[1])
                cached.update(f'{base}_{i}' for i in range(steps))
                # _cache_ladder também guarda o degrau 0 no nome base
                cached.add(base)
                aliases.add(base)
        return cached, aliases

    def test_audio_contracts(self):
        audio = self._read('autoload/AudioManager.gd')
        # mixer: pool de vozes, trilha progressiva, jitter e loader de assets
        for token in ('const PENTATONIC', 'const VOICE_COUNT', 'const SFX_DIR',
                      'res://audio/sfx/', 'func play_progress', 'func play_gesture',
                      'func _next_voice', 'func _load_sfx', 'func _cache_ladder',
                      'randf_range(0.992, 1.008)'):
            self.assertIn(token, audio, token)
        # escadas = um WAV por degrau; perfume sobe C6→D6→E6 (a 3ª é o
        # perfect); chime da janela e aviso de drenagem (oitava abaixo) ficam.
        for token in ('_cache_ladder(&"bubble", 10)', '_cache_ladder(&"clipper", 10)',
                      '_cache_ladder(&"dryer", 10)', '_cache_ladder(&"bow", 10)',
                      'cache[&"spray_0"] = _load_sfx(&"spray_0")',
                      'cache[&"spray_1"] = _load_sfx(&"spray_1")',
                      'cache[&"spray_2"] = _load_sfx(&"spray_2")',
                      'cache[&"window"]', 'window_chime_armed',
                      'volume_scale = 0.5', '0.8 + 0.4'):
            self.assertIn(token, audio, token)
        # a síntese 8-bit em runtime (seno + ruído de hash) foi aposentada:
        # o som agora vem do gerador versionado, não de osciladores no jogo.
        for token in ('func _pluck', 'func _bloop', 'func _air(', 'func _spray',
                      'func _wav_norm', 'func _cache_ticks', 'func _cache_air_ticks',
                      'func _chime', 'const ATTACK', '3100.0'):
            self.assertNotIn(token, audio, token)
        # música ambiente e sincronia de compasso intocadas (contrato fase 4).
        for token in ('func _ambient_loop', 'func beat_phase', 'func _energy_loop',
                      'get_playback_position', 'MUSIC_BPM'):
            self.assertIn(token, audio, token)
        canvas = self._read('core/gameplay/PetShopCanvas.gd')
        self.assertIn('AudioManager.beat_phase', canvas)

    def test_main_gesture_loop_is_progressive(self):
        main = self._read('scenes/main/Main.gd')
        # trilha do gesto delegada: nota sobe com o progresso + chime da
        # janela perfeita (play_gesture), throttle de 0,16 s
        self.assertIn('AudioManager.play_gesture(current_service, bath)', main)
        self.assertIn('bubble_sound_gate = 0.16', main)
        # perfume: som por evento de borrifada, subindo uma nota a cada acerto
        self.assertIn('spray_%d', main)
        self.assertIn('bath.pulses_hit - 1', main)
        self.assertNotIn('play_tick', main)
        self.assertNotIn('bubble_sound_gate = 0.11', main)

    def test_every_sfx_played_is_cached(self):
        cached, _ = self._cached_names()
        played = set()
        for path in Path('.').rglob('*.gd'):
            if '.git' in path.parts or 'tools' in path.parts:
                continue
            for line in path.read_text(encoding='utf8').splitlines():
                for call in ('AudioManager.play(&"',):
                    if call in line:
                        played.add(line.split(call)[1].split('"')[0])
        # nomes vindos de service_sound() são dinâmicos: cobrir pelo mapa
        tuning = self._read('core/gameplay/SalonTuning.gd')
        dynamic = set()
        for line in tuning.splitlines():
            # formato do mapa service_sound: &"bath": &"bubble",
            if ': &"' in line and '{' not in line and 'func' not in line:
                dynamic.add(line.split(': &"')[1].split('"')[0])
        missing = (played | dynamic) - cached
        self.assertEqual(missing, set(), f'SFX tocados sem cache: {missing}')
        self.assertTrue({'bubble', 'clipper', 'dryer', 'spray', 'bow'} <= cached)
        # escada do perfume (spray_%d dinâmico no Main) e chime da janela
        self.assertTrue({'spray_0', 'spray_1', 'spray_2', 'window'} <= cached)

    def test_every_cached_sfx_ships_an_asset(self):
        """Cada som do cache tem o WAV versionado — e não existe WAV órfão nem
        arquivo fora do manifesto do gerador (fonte única)."""
        from gen_sfx import all_names
        cached, aliases = self._cached_names()
        files = cached - aliases
        shipped = {path.stem for path in Path('audio/sfx').glob('*.wav')}
        self.assertEqual(files - shipped, set(), 'som no cache sem WAV em audio/sfx')
        self.assertEqual(shipped - files, set(), 'WAV órfão (nada toca)')
        self.assertEqual(shipped, set(all_names()), 'WAVs != manifesto do gerador')
        # degrau 0 de cada escada + a primeira borrifada servem de fallback
        self.assertTrue({'bubble', 'clipper', 'dryer', 'bow', 'spray'} <= aliases)

    def test_sfx_assets_are_studio_quality(self):
        """Valida os ARQUIVOS que embarcam (não a intenção do gerador):
        44,1 kHz, estéreo nos eventos e mono nos ticks, sem clipping nem
        offset DC nem degrau de silêncio nas bordas, ticks de loop bem abaixo
        dos eventos e as escadas subindo de verdade degrau a degrau."""
        from gen_sfx import (all_names, load_rendered, validate_assets,
                             validate_manifest)
        self.assertEqual(validate_manifest(), [], 'manifesto fora da pentatônica')
        rendered = load_rendered()
        self.assertEqual(set(rendered), set(all_names()))
        self.assertEqual(validate_assets(rendered), [], 'SFX fora do padrão')


def _loc_table(code):
    table = {}
    for line in Path(f'data/localization/{code}.csv').read_text(encoding='utf8').splitlines():
        if not line.strip() or line.startswith('key,'):
            continue
        key, value = line.split(',', 1)
        table[key] = value.strip().strip('"')
    return table


class LiveOpsAndResearchTests(unittest.TestCase):
    """Mecânicas antes órfãs em data/ (auditoria): agenda semanal dirigida por
    events.json, temporadas que presenteiam cosmético e a pesquisa da franquia
    como sink dos tokens de prestígio. Testes de contrato (texto + dados) no
    mesmo padrão do restante do arquivo."""

    def test_events_json_is_the_weekly_source_of_truth(self):
        events = json.loads(Path('data/events.json').read_text(encoding='utf8'))
        weekly = events['weekly']
        self.assertEqual(sorted(e['weekday'] for e in weekly), list(range(7)))
        services = {'', 'bath', 'groom', 'dry', 'perfume', 'style'}
        modifiers = {'', 'all_income', 'rare_chance', 'vip_frequency', 'perfect_bonus'}
        for entry in weekly:
            self.assertIn(entry['service'], services, entry['id'])
            self.assertIn(entry['modifier'], modifiers, entry['id'])
            self.assertGreaterEqual(entry['multiplier'], 1.0)
            self.assertGreaterEqual(entry['service_multiplier'], 1.0)
        # Cada serviço tem o seu dia temático (a fila segue o evento).
        self.assertEqual({e['service'] for e in weekly} - {''}, services - {''})
        # O rótulo do dia é honesto: "Sexta do VIP" tem VIPs de verdade e
        # "Quinta do Laço" traz os pets raros prometidos pelo design.
        by_day = {e['weekday']: e for e in weekly}
        self.assertEqual(by_day[5]['modifier'], 'vip_frequency')
        self.assertEqual(by_day[4]['modifier'], 'rare_chance')
        self.assertEqual(by_day[6]['modifier'], 'perfect_bonus')
        self.assertEqual(by_day[0]['modifier'], 'all_income')
        # Nomes em pt_BR sincronizados com a localização (EVENT_n).
        pt = _loc_table('pt_BR')
        for entry in weekly:
            self.assertEqual(pt['EVENT_%d' % entry['weekday']], entry['name'])
        content = Path('autoload/ContentDB.gd').read_text(encoding='utf8')
        self.assertIn('res://data/events.json', content)
        self.assertIn('func weekly_event_for', content)
        liveops = Path('autoload/LiveOps.gd').read_text(encoding='utf8')
        self.assertNotIn('DAY_SERVICE', liveops)
        self.assertIn('ContentDB.weekly_event_for(weekday())', liveops)
        for token in ('func modifier_multiplier', 'func event_description_for',
                      'boost_scale()'):
            self.assertIn(token, liveops)

    def test_queue_applies_vip_and_rare_modifiers(self):
        salon = Path('core/gameplay/SalonTuning.gd').read_text(encoding='utf8')
        self.assertIn('LiveOps.modifier_multiplier(&"vip_frequency")', salon)
        self.assertIn('LiveOps.modifier_multiplier(&"rare_chance")', salon)
        self.assertIn('static func draw_pet', salon)
        self.assertIn('VIP_CHANCE_CAP', salon)
        # Viés por raridade cobre as cinco raridades do catálogo.
        for rarity in ('common', 'uncommon', 'rare', 'epic', 'legendary'):
            self.assertIn('&"%s"' % rarity, salon)
        for code in ('pt_BR', 'en_US', 'es_ES'):
            table = _loc_table(code)
            for day in range(7):
                self.assertIn('EVENT_DESC_%d' % day, table)
        panel = Path('scenes/main/MetaPanel.gd').read_text(encoding='utf8')
        self.assertIn('LiveOps.event_description_for', panel)

    def test_seasonal_cosmetics_are_obtainable(self):
        events = json.loads(Path('data/events.json').read_text(encoding='utf8'))
        cosmetics = json.loads(Path('data/cosmetics.json').read_text(encoding='utf8'))
        by_id = {c['id']: c for c in cosmetics['cosmetics']}
        seasons = {s['id']: s for s in events['seasonal']}
        months = [m for s in events['seasonal'] for m in s['months']]
        self.assertEqual(len(months), len(set(months)), 'temporadas não podem se sobrepor')
        for season in events['seasonal']:
            gift = season['cosmetic']
            if gift:
                self.assertIn(gift, by_id)
                self.assertEqual(by_id[gift]['source'], season['id'])
        # Todo cosmético sem preço tem uma rota real: conquista ou temporada.
        state = Path('autoload/GameState.gd').read_text(encoding='utf8')
        for look in cosmetics['cosmetics']:
            if 'price' in look:
                continue
            source = look['source']
            if source == 'achievement':
                self.assertIn('unlocked_cosmetics.append("%s")' % look['id'], state)
            else:
                self.assertEqual(seasons[source]['cosmetic'], look['id'])
        liveops = Path('autoload/LiveOps.gd').read_text(encoding='utf8')
        for token in ('func active_seasonal', 'func claim_seasonal_gift',
                      'ContentDB.seasonal_for_month', 'GameState.unlocked_cosmetics.append',
                      'SaveManager.request_save()', 'func source_label'):
            self.assertIn(token, liveops)
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        self.assertIn('LiveOps.claim_seasonal_gift()', main)
        panel = Path('scenes/main/MetaPanel.gd').read_text(encoding='utf8')
        self.assertIn('LiveOps.source_label(source)', panel)
        self.assertNotIn('"EVENTO"', panel)
        for code in ('pt_BR', 'en_US', 'es_ES'):
            table = _loc_table(code)
            for season in events['seasonal']:
                self.assertIn('SEASON_' + season['id'], table)
                self.assertIn('SEASON_WHEN_' + season['id'], table)
            for key in ('SEASON_GIFT', 'SEASON_ACTIVE', 'SOURCE_achievement',
                        'SOURCE_BTN_SEASON', 'SOURCE_BTN_ACHIEVEMENT'):
                self.assertIn(key, table)
            self.assertEqual(table['SEASON_GIFT'].count('%s'), 2)

    def test_research_tree_is_a_real_prestige_sink(self):
        research = json.loads(Path('data/research.json').read_text(encoding='utf8'))
        nodes = research['nodes']
        ids = {n['id'] for n in nodes}
        effects = set()
        for node in nodes:
            self.assertEqual(node['currency'], 'franchise_token')
            self.assertGreaterEqual(node['cost'], 1)
            self.assertTrue(set(node['requires']) <= ids, node['id'])
            self.assertTrue(node['effect'])
            effects |= set(node['effect'])
            for value in node['effect'].values():
                self.assertTrue(0.0 < value <= 0.5)
        # A árvore é alcançável: tier 1 sem pré-requisitos e o topo custa o
        # que um ciclo de prestígio realista rende (soma <= 10 tokens).
        self.assertTrue(any(not n['requires'] for n in nodes))
        self.assertLessEqual(sum(n['cost'] for n in nodes), 10)
        # Todo efeito declarado tem hook em código e texto localizado.
        hooks = {
            'bath_income': ('core/gameplay/SalonTuning.gd', 'Research.bonus(&"bath_income")'),
            'satisfaction': ('core/gameplay/SalonTuning.gd', 'Research.bonus(&"satisfaction")'),
            'service_speed': ('core/gameplay/SalonTuning.gd', 'Research.bonus(&"service_speed")'),
            'patience': ('scenes/main/Main.gd', 'Research.bonus(&"patience")'),
            'offline_rate': ('autoload/SaveManager.gd', 'Research.bonus(&"offline_rate")'),
        }
        self.assertEqual(effects, set(hooks))
        for effect, (path, token) in hooks.items():
            self.assertIn(token, Path(path).read_text(encoding='utf8'), effect)
            for code in ('pt_BR', 'en_US', 'es_ES'):
                self.assertIn('RESEARCH_EFFECT_' + effect, _loc_table(code))
        research_gd = Path('core/progression/Research.gd').read_text(encoding='utf8')
        for token in ('class_name Research', 'static func bonus', 'static func buy',
                      'GameState.franchise_tokens -= price', 'GameState.research_ids.append',
                      'SaveManager.request_save()', 'research_complete'):
            self.assertIn(token, research_gd)
        state = Path('autoload/GameState.gd').read_text(encoding='utf8')
        self.assertIn('var research_ids: Array[String] = []', state)
        self.assertIn('"research_ids": research_ids', state)
        self.assertIn('_valid_research_array(data.get("research_ids", []))', state)
        # Prestígio NÃO apaga a pesquisa (é o motivo de prestigiar de novo).
        prestige = state[state.index('func perform_prestige'):state.index('func register_review')]
        self.assertNotIn('research_ids', prestige)
        economy = Path('autoload/Economy.gd').read_text(encoding='utf8')
        self.assertIn('research_bonus: float = 0.0', economy)
        content = Path('autoload/ContentDB.gd').read_text(encoding='utf8')
        self.assertIn('res://data/research.json', content)
        self.assertIn('func research(', content)
        panel = Path('scenes/main/MetaPanel.gd').read_text(encoding='utf8')
        self.assertIn('func _build_research', panel)
        self.assertIn('Research.buy(nid)', panel)


class EconomyScalingTests(unittest.TestCase):
    """Auditoria de retenção (§1/§2 do RETENTION_VIRALITY_PLAN): recompensas e
    sinks em segundos de renda, cofre offline relevante, equipe como automação,
    prestígio com herança e o bug dos tokens em dobro."""

    def test_rewards_are_expressed_in_seconds_of_income(self):
        rewards = Path('core/progression/Rewards.gd').read_text(encoding='utf8')
        self.assertIn('static func income_per_second', rewards)
        self.assertIn('Economy.service_reward(', rewards)
        self.assertIn('static func scaled(seconds: float, minimum: int = 0)', rewards)
        for kind in ('daily_mission', 'weekly_mission', 'weekly_chest', 'pass_day',
                     'streak_day', 'level_up', 'achievement', 'return_bonus', 'prestige_start'):
            self.assertIn('&"%s"' % kind, rewards)
        state = Path('autoload/GameState.gd').read_text(encoding='utf8')
        # Cada faucet fixo passou pelo escalonamento (piso = valor antigo).
        for token in ('Rewards.for_kind(&"weekly_mission"', 'Rewards.for_kind(&"weekly_chest", 200)',
                      'Rewards.pass_day_coins(pass_day_claimed)', 'Rewards.SECONDS[&"streak_day"]',
                      'Rewards.for_kind(&"level_up", 20 + player_level * 5)',
                      'Rewards.for_kind(&"achievement", coins_reward)',
                      'Rewards.for_kind(&"return_bonus"', 'Rewards.for_kind(&"prestige_start", 150)'):
            self.assertIn(token, state)
        for stale in ('add_coins(75, &"daily_mission")', 'add_coins(200.0, &"weekly_chest")',
                      'var reward: int = 25 * daily_streak', 'var level_reward: int = 20 + player_level * 5'):
            self.assertNotIn(stale, state)
        # Sinks acompanham a curva: preços dinâmicos na compra E na vitrine.
        self.assertIn('Rewards.hire_price(staff_id', state)
        self.assertIn('Rewards.cosmetic_price(cosmetic_id)', state)
        panel = Path('scenes/main/MetaPanel.gd').read_text(encoding='utf8')
        self.assertIn('Rewards.cosmetic_price(look_id)', panel)
        self.assertIn('GameState.hire_cost(staff_id)', panel)
        # Fonte única do pagamento base (compute_reward e estimativa de renda).
        salon = Path('core/gameplay/SalonTuning.gd').read_text(encoding='utf8')
        self.assertIn('static func base_reward(service: StringName)', salon)
        self.assertIn('var base_reward: float = base_reward(service)', salon)

    def test_offline_vault_and_staff_automation_are_meaningful(self):
        remote = Path('autoload/RemoteConfig.gd').read_text(encoding='utf8')
        self.assertIn('"offline_rate": 0.15', remote)
        economy = Path('autoload/Economy.gd').read_text(encoding='utf8')
        self.assertIn('automation_share: float = 0.0', economy)
        save = Path('autoload/SaveManager.gd').read_text(encoding='utf8')
        self.assertIn('Rewards.income_per_second()', save)
        self.assertIn('Rewards.automation_share()', save)
        self.assertNotIn('0.015 * Economy.income_multiplier', save)
        staff = json.loads(Path('data/staff.json').read_text(encoding='utf8'))['staff']
        hired = [m for m in staff if m['id'] != 'player']
        self.assertTrue(all(0.0 < m['automation'] <= 0.12 for m in hired))
        self.assertEqual(next(m for m in staff if m['id'] == 'player')['automation'], 0.0)
        # Raridade maior rende mais sozinha (ordem legendary > epic > rare > common).
        by_rarity = {m['rarity']: m['automation'] for m in hired}
        self.assertGreater(by_rarity['legendary'], by_rarity['epic'])
        self.assertGreater(by_rarity['epic'], by_rarity['rare'])
        self.assertGreater(by_rarity['rare'], by_rarity['common'])
        state = Path('autoload/GameState.gd').read_text(encoding='utf8')
        self.assertIn('Rewards.passive_income_per_second()', state)
        self.assertNotIn('hired_staff.has("bia"):\n\t\treturn', state)
        # Cartão de retorno com dobro por brasa/vídeo no lugar do toast.
        feedback = Path('core/ui/SessionFeedback.gd').read_text(encoding='utf8')
        for token in ('static func show_offline_card', 'OFFLINE_DOUBLE_EMBER', 'OFFLINE_DOUBLE_AD',
                      'RevealCard.enqueue', 'consume_pending_offline_reward'):
            self.assertIn(token, feedback)
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        self.assertIn('SessionFeedback.show_offline_card(self)', main)
        self.assertNotIn('func _show_pending_offline_reward', main)
        self.assertNotIn('GameState.register_review(3)', main)
        card = Path('core/ui/RevealCard.gd').read_text(encoding='utf8')
        self.assertIn('static func enqueue', card)
        self.assertIn('main._button(', card)
        self.assertNotIn('Button.new()', card)

    def test_prestige_tokens_are_cumulative_and_prestige_has_inheritance(self):
        state = Path('autoload/GameState.gd').read_text(encoding='utf8')
        self.assertIn('Economy.prestige_tokens(total_coins) - prestige_tokens_collected', state)
        self.assertIn('prestige_tokens_collected += gain', state)
        self.assertIn('const PRESTIGE_KEEP_RATIO: float = 0.25', state)
        self.assertIn('const PRESTIGE_START_LEVEL: int = 10', state)
        self.assertIn('bath_upgrade_level = int(bath_upgrade_level * PRESTIGE_KEEP_RATIO)', state)
        self.assertIn('player_level = PRESTIGE_START_LEVEL', state)
        self.assertNotIn('coins = 150.0', state)
        panel = Path('scenes/main/MetaPanel.gd').read_text(encoding='utf8')
        self.assertIn('PRESTIGE_PREVIEW', panel)
        # Bug de exibição: o painel mostrava o multiplicador (1.1) como "+1%".
        self.assertIn('- 1.0) * 100.0', panel)
        # Reprodução do bug do dobro com a fórmula antiga vs. a nova.
        import math
        tokens = lambda total: int(math.floor(math.sqrt(total / 1e6)))
        old_level, old_granted, new_collected, new_granted = 0, 0, 0, 0
        for total in (9e6, 16e6, 25e6):
            old_granted += tokens(total) - old_level; old_level += 1
            gain = tokens(total) - new_collected; new_granted += gain; new_collected += gain
        self.assertEqual(old_granted, 9)
        self.assertEqual(new_granted, tokens(25e6))


class MomentsAndGoalsTests(unittest.TestCase):
    """§3 do plano: momentos de revelação em vez de toast e meta visível no HUD."""

    def test_reveal_cards_replace_toasts_for_big_moments(self):
        bus = Path('autoload/EventBus.gd').read_text(encoding='utf8')
        self.assertIn('signal reveal_requested(kind: StringName, payload: Dictionary)', bus)
        state = Path('autoload/GameState.gd').read_text(encoding='utf8')
        for kind in ('&"pet"', '&"chapter"', '&"achievement"', '&"service"'):
            self.assertIn('EventBus.reveal_requested.emit(%s' % kind, state,
                          'momento %s ainda não é um cartão' % kind)
        for stale in ('"Novo pet: %s, %s!"', '"Novo capítulo: %s!"', '"NOVO! "',
                      'ACHIEVEMENT_TOAST'):
            self.assertNotIn(stale, state)
        liveops = Path('autoload/LiveOps.gd').read_text(encoding='utf8')
        self.assertIn('EventBus.reveal_requested.emit(', liveops)
        card = Path('core/ui/RevealCard.gd').read_text(encoding='utf8')
        self.assertIn('static func enqueue_kind', card)
        for kind in ('&"pet":', '&"chapter":', '&"achievement":', '&"service":', '&"cosmetic":'):
            self.assertIn(kind, card)
        self.assertIn('res://art/pets/%s.png', card)
        self.assertIn('SalonTuning.hint(service)', card, 'serviço novo ensina o gesto')
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        self.assertIn('RevealCard.enqueue_kind(self, kind, payload)', main)
        for code in ('pt_BR', 'en_US', 'es_ES'):
            table = _loc_table(code)
            for key in ('REVEAL_OK', 'REVEAL_PET_TITLE', 'REVEAL_CHAPTER_TITLE',
                        'REVEAL_ACHIEVEMENT_TITLE', 'REVEAL_SERVICE_TITLE', 'REVEAL_COSMETIC_TITLE',
                        'RARITY_common', 'RARITY_legendary', 'SERVICE_BATH', 'SERVICE_STYLE'):
                self.assertIn(key, table)

    def test_hud_shows_the_next_goal(self):
        goals = Path('core/progression/Goals.gd').read_text(encoding='utf8')
        self.assertIn('static func next_unlock', goals)
        self.assertIn('static func hud_line', goals)
        for source in ('ContentDB.pets', 'ContentDB.service_layouts', 'ContentDB.career'):
            self.assertIn(source, goals, 'meta deve considerar pets, serviços e capítulos')
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        self.assertIn('goal_label.text = Goals.hud_line()', main)
        self.assertIn('var goal_label: Label', main)
        for code in ('pt_BR', 'en_US', 'es_ES'):
            table = _loc_table(code)
            for key in ('GOAL_LINE', 'GOAL_NEXT_LEVEL', 'GOAL_PRESTIGE', 'GOAL_PET',
                        'GOAL_SERVICE', 'GOAL_CHAPTER'):
                self.assertIn(key, table)
            self.assertEqual(table['GOAL_LINE'].count('%'), 4)
        salon = Path('core/gameplay/SalonTuning.gd').read_text(encoding='utf8')
        self.assertIn('var buddy_chance: float = 0.25 + 0.15', salon)
        self.assertNotIn('randf() < 0.4:', salon)


if __name__=='__main__': unittest.main()
