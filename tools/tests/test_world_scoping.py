"""Actors must find their surroundings in their own world (roadmap GT-1).

Two worlds can be loaded side by side (docs/plans/gate-travel-split-worlds.md). A search of
the whole game returns whichever world loaded first: with the SGC and an offworld site
together, a sentry could not see an operative standing in front of it. The engine-side proof
is client/tests/test_world_coexistence.gd; this keeps such a lookup from being written again.
"""
from pathlib import Path
import re
import unittest

SCRIPTS = Path(__file__).resolve().parents[2] / 'client' / 'scripts'
HELPER = 'world/MissionWorld.gd'

# Whole-game searches: use MissionWorld.find, MissionWorld.of(self).find_children or
# MissionWorld.in_group instead.
FORBIDDEN = {
    'a search of the whole game by name': re.compile(r'\broot(_node)?\.(find_child|find_children)\('),
    'a group lookup across every world': re.compile(r'\.(get_nodes_in_group|get_first_node_in_group)\('),
}

# Lookups that are already limited to one level by an `is_ancestor_of` test on the same members.
ALREADY_SCOPED = {
    'level/LevelNavigation.gd': 'root.is_ancestor_of(door)',
    'level/LevelNavigator.gd': 'level.is_ancestor_of(door)',
}

# Group calls that carry a position and a radius, so they cannot reach a world 2 km away.
RANGED_GROUP_CALLS = {'noise_listeners'}


def sources():
    for path in sorted(SCRIPTS.rglob('*.gd')):
        yield path.relative_to(SCRIPTS).as_posix(), path.read_text()


def code_lines(text):
    for number, line in enumerate(text.splitlines(), 1):
        if not line.lstrip().startswith('#'):
            yield number, line


class WorldScoping(unittest.TestCase):
    def test_no_script_searches_the_whole_game(self):
        found = []
        for name, text in sources():
            if name == HELPER:
                continue
            for number, line in code_lines(text):
                for what, pattern in FORBIDDEN.items():
                    if pattern.search(line):
                        if name in ALREADY_SCOPED and 'in_group' in line:
                            continue
                        found.append('%s:%d is %s' % (name, number, what))
        self.assertEqual(found, [], 'Use MissionWorld (client/scripts/world/MissionWorld.gd)')

    def test_the_exceptions_still_scope_themselves(self):
        for name, guard in ALREADY_SCOPED.items():
            self.assertIn(guard, (SCRIPTS / name).read_text(), name)

    def test_group_calls_are_ranged(self):
        for name, text in sources():
            for match in re.finditer(r'call_group\(\s*&?"([a-z_]+)"', text):
                self.assertIn(match.group(1), RANGED_GROUP_CALLS, name)

    def test_spawned_nodes_are_not_given_a_game_position_as_their_own(self):
        # A world can stand 2 km from the origin: `position` under it is not a place in the
        # game. Convert with MissionWorld.local(parent, point), or set global_position
        # after add_child. The SGC is exempt in practice: its sectors, waves and shrouds are
        # written in fixed coordinates, so it is always the world at the origin.
        wrong = re.compile(r'\b\w+\.position = global_position\b')
        found = ['%s:%d' % (name, number) for name, text in sources()
                 for number, line in code_lines(text) if wrong.search(line)]
        self.assertEqual(found, [])

    def test_the_helper_does_not_name_itself(self):
        # A script that names its own class from a static function is never freed.
        body = (SCRIPTS / HELPER).read_text().split('const GROUP', 1)[1]
        self.assertNotIn('MissionWorld', body)

    def test_a_world_joins_the_group_actors_look_for(self):
        self.assertIn('add_to_group(MissionWorld.GROUP)', (SCRIPTS / 'world/GateRoom.gd').read_text())


if __name__ == '__main__':
    unittest.main()
