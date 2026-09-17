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
        self.assertIn('const SAVE_VERSION: int = 4', state)
        self.assertIn('if version == 3:', migration)
        self.assertIn('data["version"] = 4', migration)

    def test_career_has_at_least_fifty_active_hours(self):
        rows = simulate_career()
        self.assertEqual(rows[-1]['reached_level'], 120)
        self.assertGreaterEqual(rows[-1]['estimated_active_hours'], 60.0)
        expert_hours = rows[-1]['cumulative_xp'] / 15.0 * 14.5 / 3600.0 * 1.10
        self.assertGreaterEqual(expert_hours, 50.0)

    def test_pet_catalog_has_dogs_cats_and_long_term_unlocks(self):
        pets = json.loads(Path('data/pets.json').read_text(encoding='utf8'))['pets']
        self.assertEqual(len(pets), 30)
        self.assertEqual(sum(pet['species'] == 'dog' for pet in pets), 15)
        self.assertEqual(sum(pet['species'] == 'cat' for pet in pets), 15)
        levels = sorted(pet['unlock_level'] for pet in pets)
        self.assertEqual(max(levels), 120)
        self.assertLessEqual(max(b - a for a, b in zip(levels, levels[1:])), 8)

    def test_all_buttons_use_universal_interaction_feedback(self):
        main = Path('scenes/main/Main.gd').read_text(encoding='utf8')
        self.assertEqual(main.count('Button.new()'), 1)
        self.assertIn('InteractionFX.bind_button(button)', main)
        self.assertIn('react_to_touch()', main)

    def test_professional_backgrounds_exist_and_are_reasonable(self):
        for name in ('petshop_quintal.png', 'petshop_tosa.png'):
            path = Path('art/backgrounds') / name
            self.assertTrue(path.exists(), name)
            self.assertGreater(path.stat().st_size, 100_000)
            self.assertLess(path.stat().st_size, 5_000_000)

if __name__=='__main__': unittest.main()
