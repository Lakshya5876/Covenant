import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ENGINE = Path(__file__).parents[1] / 'src' / 'covenantwin.py'
COVENANTMAC_TEMPLATES = ENGINE.parents[2] / 'CovenantMac' / 'templates'
V1_RELEASE = ENGINE.parents[2] / 'v1_release'
# pwsh (PowerShell Core) ships on GitHub Actions' ubuntu-latest/macos-latest/
# windows-latest runners alike; powershell.exe (Windows PowerShell 5.1) is
# the native fallback on a plain Windows dev machine that hasn't installed
# PowerShell 7. Prefer pwsh so the same test exercises the same interpreter
# family CovenantWin's own CI will use cross-platform; fall back for local dev.
POWERSHELL = shutil.which('pwsh') or shutil.which('powershell.exe') or shutil.which('powershell')

def call(args, cwd, **kwargs):
    # Default to a human-shaped environment: strip CLAUDECODE unless the
    # caller explicitly passes its own `env` (as the agent-gate tests below
    # do). Without this, running this suite from inside an actual Claude Code
    # session (this engine's own $CLAUDECODE marker leaking through to every
    # subprocess call) would spuriously trip the agent-only tier-3/checkpoint
    # gates on every pre-existing test that stages 5+ files or pushes source —
    # a real environment-leakage risk, not just a testing convenience.
    if 'env' not in kwargs:
        kwargs['env'] = {k: v for k, v in os.environ.items() if k != 'CLAUDECODE'}
    return subprocess.run(args, cwd=cwd, text=True, encoding='utf-8', errors='replace', capture_output=True, **kwargs)

def init_repo(path: Path, branch='feature/test'):
    path.mkdir(parents=True, exist_ok=True)
    for args in (['git', 'init', '-b', branch],
                 ['git', 'config', 'user.email', 'covenantwin@example.test'],
                 ['git', 'config', 'user.name', 'CovenantWin Test']):
        assert call(args, path).returncode == 0
    (path / 'README.md').write_text('fixture\n')
    call(['git', 'add', '.'], path)
    assert call(['git', 'commit', '-m', 'initial'], path).returncode == 0

def install_covenant(path: Path, basket: str):
    p = call([sys.executable, str(ENGINE), 'install', str(path), '--basket', basket], path)
    assert p.returncode == 0, p.stderr
    call(['git', 'add', '-A'], path)
    committed = call(['git', 'commit', '-m', 'install covenant'], path)
    assert committed.returncode == 0, committed.stderr
    return p

class CovenantWinIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='Covenant Win space ')
        self.repo = Path(self.tmp.name) / 'repository with spaces'
        init_repo(self.repo)
        install_covenant(self.repo, 'brownfield')

    def tearDown(self): self.tmp.cleanup()

    def test_real_precommit_hook_blocks_secret(self):
        (self.repo/'bad.txt').write_text('api' + '_key = super-secret-value')
        call(['git','add','bad.txt'],self.repo)
        p=call(['git','commit','-m','bad secret'],self.repo)
        self.assertNotEqual(p.returncode,0)
        self.assertIn('secret-like material',p.stderr)

    def test_real_precommit_hook_allows_clean_change(self):
        (self.repo/'good.txt').write_text('safe content')
        call(['git','add','good.txt'],self.repo)
        p=call(['git','commit','-m','clean change'],self.repo)
        self.assertEqual(p.returncode,0,p.stderr)
        state=json.loads((self.repo/'.claude/covenant_state.json').read_text())
        self.assertTrue(state['receipts'])
        self.assertTrue((self.repo/'.githooks/covenantwin.py').is_file())

    def test_install_refuses_the_covenantwin_repo_itself(self):
        # CovenantWin/ itself has no .git of its own inside the Covenant monorepo (only
        # Covenant/.git does) — so the more realistic self-install mistake to guard
        # against is running the installer against the *monorepo root*, which
        # does have .git and does contain the CovenantWin engine under CovenantWin/src/.
        covenant_monorepo_root = ENGINE.parents[2]
        if not (covenant_monorepo_root / '.git').exists():
            self.skipTest('not running inside the Covenant monorepo (no root .git found)')
        p = call([sys.executable, str(ENGINE), 'install', str(covenant_monorepo_root), '--basket', 'greenfield'], covenant_monorepo_root)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('installer itself', p.stderr)

    def test_real_prepush_hook_runs_integrity_and_covenant(self):
        remote = Path(self.tmp.name) / 'remote.git'
        self.assertEqual(call(['git','init','--bare',str(remote)],self.repo).returncode, 0)
        # `git remote add` refuses once any remote.origin.* config exists —
        # install() already added the bypass-notes refspecs under that name
        # (matching CovenantMac's install.sh, which does the same best-effort
        # `git config --add remote.origin.push/fetch`, real-world-ordered
        # after a repo's real origin already exists). Setting the url key
        # directly avoids the "remote origin already exists" conflict this
        # fixture's ordering (install before any origin is configured) hits.
        self.assertEqual(call(['git','config','remote.origin.url',str(remote)],self.repo).returncode, 0)
        p=call(['git','push','-u','origin','feature/test'],self.repo)
        self.assertEqual(p.returncode,0,p.stderr)
        self.assertIn('COVENANT PASS',p.stderr)

    def test_integrity_manifest_covers_exact_governance_set_and_verifies(self):
        manifest = (self.repo/'.claude/covenant_integrity.sha256').read_text().splitlines()
        self.assertEqual(len(manifest), 4)
        for line in manifest:
            expected, rel = line.split('  ', 1)
            actual = hashlib.sha256((self.repo/rel).read_bytes()).hexdigest()
            self.assertEqual(actual, expected, f'{rel} does not match its pinned hash')
        p = call([sys.executable, str(ENGINE), 'check-integrity', str(self.repo)], self.repo)
        self.assertEqual(p.returncode, 0, p.stderr)

    def test_integrity_check_fails_when_a_governance_file_is_tampered(self):
        guard = self.repo/'.claude/hooks/pre_bash_trust_root_guard.sh'
        guard.write_text(guard.read_text() + '\n# tampered\n')
        p = call([sys.executable, str(ENGINE), 'check-integrity', str(self.repo)], self.repo)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('integrity mismatch', p.stderr)

    def test_trust_root_settings_has_deny_list_and_bash_guard_hook(self):
        settings = json.loads((self.repo/'.claude/settings.json').read_text())
        deny = settings['permissions']['deny']
        self.assertIn('Bash(rm -rf*)', deny)
        self.assertIn('Bash(SKIP_COVENANT=*)', deny)
        self.assertIn('Write(.claude/covenant_state.json)', deny)
        # brownfield dev-guide/init-package filenames must be individually protected
        self.assertIn('Write(v1_claude_code_development_guide_existing.md)', deny)
        hooks = [h for h in settings['hooks']['PreToolUse'] if h.get('matcher') == 'Bash']
        self.assertTrue(hooks, 'no Bash PreToolUse guard registered')
        self.assertTrue(any('pre_bash_trust_root_guard.sh' in hh['command'] for hh in hooks[0]['hooks']))

    def test_codeowners_scaffolded_with_placeholder_and_never_overwritten(self):
        codeowners = self.repo/'.github/CODEOWNERS'
        self.assertTrue(codeowners.exists())
        self.assertIn('@your-org/platform-team', codeowners.read_text())
        codeowners.write_text('# human-owned content\n')
        # re-running install's codeowners step must not clobber real content —
        # exercised indirectly: the write function itself no-ops if the file exists.
        sys.path.insert(0, str(ENGINE.parent))
        import importlib
        covenantwin = importlib.import_module('covenantwin')
        covenantwin._write_codeowners(self.repo)
        self.assertEqual(codeowners.read_text(), '# human-owned content\n')

    def test_init_governance_command_extracts_prompt_content_byte_for_byte(self):
        cmd_file = self.repo/'.claude/commands/init-governance.md'
        self.assertTrue(cmd_file.is_file())
        source = V1_RELEASE/'basket-1-brownfield'/'v1_implementation_package_existing.md'
        lines = source.read_text(encoding='utf-8').splitlines(keepends=True)
        start = next(i for i, l in enumerate(lines) if 'PROMPT START' in l) + 1
        end = next(i for i, l in enumerate(lines) if 'PROMPT END' in l)
        expected_prompt = ''.join(lines[start:end]).strip()
        content = cmd_file.read_text(encoding='utf-8')
        self.assertIn(expected_prompt, content)

    def test_brownfield_seeds_unpopulated_baseline(self):
        baseline = json.loads((self.repo/'.claude/baseline.json').read_text())
        self.assertFalse(baseline['populated'])
        self.assertEqual(baseline['lint_findings'], [])
        self.assertEqual(baseline['ratchet_mode'], 'identity')

    def test_debt_ratchet_grandfathers_baseline_blocks_new_finding(self):
        fake_lint = self.repo/'fake_lint.py'
        fake_lint.write_text(
            "import sys\n"
            "print('bad.py:10:1: E501 line too long')\n"
            "print('new_bad.py:3:1: E999 new violation')\n"
            "sys.exit(1)\n"
        )
        state_path = self.repo/'.claude/covenant_state.json'
        state = json.loads(state_path.read_text())
        state['commands']['lint'] = f'{sys.executable} fake_lint.py'
        # fake_lint.py is itself a staged .py (source) file, which now trips the
        # fail-closed missing-test-runner check before the lint step even runs
        # (see covenant() step 3.5) unless a test command is configured — same
        # neutralization CovenantMac's own bats suite needed when its
        # equivalent fail-closed check shipped.
        state['commands']['test'] = 'true' if sys.platform != 'win32' else 'cmd /c exit 0'
        state_path.write_text(json.dumps(state, indent=2))

        baseline_path = self.repo/'.claude/baseline.json'
        baseline = json.loads(baseline_path.read_text())
        baseline['populated'] = True
        baseline['lint_findings'] = ['bad.py|E501']
        baseline_path.write_text(json.dumps(baseline, indent=2))

        call(['git', 'add', '-A'], self.repo)
        p = call(['git', 'commit', '-m', 'trigger ratchet'], self.repo)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('debt ratchet', p.stderr)
        self.assertIn('new_bad.py|E999', p.stderr)
        self.assertNotIn('bad.py|E501', p.stderr.split('debt ratchet')[-1])

    def test_greenfield_has_no_debt_baseline(self):
        greenfield_repo = Path(self.tmp.name) / 'greenfield-repo'
        init_repo(greenfield_repo)
        install_covenant(greenfield_repo, 'greenfield')
        self.assertFalse((greenfield_repo/'.claude/baseline.json').exists())
        self.assertTrue((greenfield_repo/'v1_claude_code_development_guide_new.md').exists())
        self.assertTrue((greenfield_repo/'v1_implementation_package_new.md').exists())

    def test_bypass_note_refspecs_configured_at_install(self):
        push = call(['git', 'config', '--get-all', 'remote.origin.push'], self.repo).stdout
        fetch = call(['git', 'config', '--get-all', 'remote.origin.fetch'], self.repo).stdout
        self.assertIn('refs/notes/bypasses:refs/notes/bypasses', push)
        self.assertIn('refs/notes/bypasses:refs/notes/bypasses', fetch)

    def test_hook_shims_reuse_covenantmac_scripts_and_call_this_engine(self):
        precommit = (self.repo/'.githooks/pre-commit').read_text()
        prepush = (self.repo/'.githooks/pre-push').read_text()
        # bypass/audit-trail logic reused verbatim from CovenantMac
        self.assertIn('SKIP_COVENANT', precommit)
        self.assertIn('refs/notes/bypasses', precommit)
        self.assertIn('refs/notes/bypasses', prepush)
        # delegates to the Python engine directly, not a PowerShell hop
        self.assertIn('covenantwin.py covenant --trigger pre-commit', precommit)
        self.assertIn('covenantwin.py covenant --trigger pre-push', prepush)
        self.assertNotIn('.ps1', precommit)
        self.assertNotIn('powershell', precommit.lower())

    def test_ci_workflow_installed_and_not_clobbered_on_fresh_install(self):
        workflow = self.repo/'.github/workflows/covenant.yml'
        self.assertTrue(workflow.is_file())
        self.assertIn('governance-covenant', workflow.read_text())
        workflow.write_text('# human customized\n')
        p = call([sys.executable, str(ENGINE), 'install', str(self.repo), '--basket', 'brownfield'], self.repo)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(workflow.read_text(), '# human customized\n')

    def test_upgrade_requires_existing_governed_repo(self):
        fresh = Path(self.tmp.name) / 'never-installed'
        init_repo(fresh)
        p = call([sys.executable, str(ENGINE), 'upgrade', str(fresh)], fresh)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('existing governed repo', p.stderr)

    def test_upgrade_refreshes_hooks_bumps_version_preserves_baseline(self):
        baseline_path = self.repo/'.claude/baseline.json'
        baseline = json.loads(baseline_path.read_text())
        baseline['populated'] = True
        baseline['lint_findings'] = ['keep_me.py|E501']
        baseline_path.write_text(json.dumps(baseline, indent=2))

        state_path = self.repo/'.claude/covenant_state.json'
        state = json.loads(state_path.read_text())
        state['framework_version'] = '0.0.1-win'
        state_path.write_text(json.dumps(state, indent=2))

        p = call([sys.executable, str(ENGINE), 'upgrade', str(self.repo)], self.repo)
        self.assertEqual(p.returncode, 0, p.stderr)

        new_state = json.loads(state_path.read_text())
        self.assertEqual(new_state['framework_version'], '1.0.0-win')
        self.assertIn('framework_last_upgrade', new_state)
        new_baseline = json.loads(baseline_path.read_text())
        self.assertEqual(new_baseline['lint_findings'], ['keep_me.py|E501'])
        # integrity manifest must be re-pinned and internally consistent after upgrade
        check = call([sys.executable, str(ENGINE), 'check-integrity', str(self.repo)], self.repo)
        self.assertEqual(check.returncode, 0, check.stderr)

    def test_upgrade_force_overwrites_ci_workflow_but_never_clobbers_codeowners(self):
        workflow = self.repo/'.github/workflows/covenant.yml'
        workflow.write_text('# stale, pre-upgrade content\n')
        codeowners = self.repo/'.github/CODEOWNERS'
        codeowners.write_text('# human-owned content\n')

        p = call([sys.executable, str(ENGINE), 'upgrade', str(self.repo)], self.repo)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn('governance-covenant', workflow.read_text())
        self.assertEqual(codeowners.read_text(), '# human-owned content\n')

    def test_upgrade_generates_reconcile_command_when_dev_guide_content_changed(self):
        dev_guide = self.repo/'v1_claude_code_development_guide_existing.md'
        dev_guide.write_text(dev_guide.read_text(encoding='utf-8') + '\n\nSTALE LOCAL LINE\n', encoding='utf-8')

        p = call([sys.executable, str(ENGINE), 'upgrade', str(self.repo)], self.repo)
        self.assertEqual(p.returncode, 0, p.stderr)
        reconcile = self.repo/'.claude/commands/reconcile-governance.md'
        self.assertTrue(reconcile.is_file())
        content = reconcile.read_text(encoding='utf-8')
        self.assertIn('STALE LOCAL LINE', content)
        self.assertIn('propose', content.lower())
        # the dev guide itself must be refreshed back to the shared source (upgrade always re-copies)
        self.assertNotIn('STALE LOCAL LINE', dev_guide.read_text(encoding='utf-8'))

    def test_ci_trigger_scans_whole_tree_on_cold_start_not_nothing(self):
        # Simulates a CI checkout: nothing staged (git diff --cached is always
        # empty there), no CI_BASE_SHA resolvable. Must fail-safe by scanning
        # every tracked file, not fail-open by silently scanning zero files —
        # the same class of bug covenant.sh itself was found and fixed for.
        (self.repo/'ci_secret.txt').write_text('api_key: super-secret-value')
        call(['git', 'add', '-A'], self.repo)
        call(['git', 'commit', '-m', 'add a file only a full-tree CI scan would catch'], self.repo)
        env = {'COVENANT_TRIGGER': 'ci', 'RUN_TESTS': 'false'}
        import os as _os
        p = call([sys.executable, str(ENGINE), 'covenant', '--trigger', 'ci'], self.repo, env={**_os.environ, **env})
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('secret-like material', p.stderr)

    def test_ci_trigger_does_not_block_on_protected_branch_guard(self):
        # Regression for a real, confirmed bug found by directly running the
        # real covenant.yml-equivalent workflow trigger against a checkout on
        # "main": actions/checkout@v4 checks out a real local branch (not
        # detached HEAD) for a push event, so covenant()'s branch guard
        # previously fired on every single push-triggered CI run against a
        # protected branch — before any real check (secrets, layer boundary,
        # lint, tests) ever ran, including for a completely legitimate,
        # already-reviewed PR merge landing on main.
        call(['git', 'checkout', '-q', '-b', 'main-standin'], self.repo)
        call(['git', 'branch', '-m', 'main'], self.repo)
        p = call([sys.executable, str(ENGINE), 'covenant', '--trigger', 'ci'], self.repo,
                  env={**os.environ, 'COVENANT_TRIGGER': 'ci', 'RUN_TESTS': 'false'})
        self.assertNotIn("forbidden", p.stderr)

    def test_precommit_on_protected_branch_is_still_blocked(self):
        # The CI exemption above must not weaken the local guard.
        call(['git', 'checkout', '-q', '-b', 'main-standin'], self.repo)
        call(['git', 'branch', '-m', 'main'], self.repo)
        (self.repo/'x.txt').write_text('x')
        call(['git', 'add', 'x.txt'], self.repo)
        p = call(['git', 'commit', '-m', 'direct commit to main'], self.repo)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('forbidden', p.stderr)

    def test_fail_closed_when_source_changes_without_a_configured_test_command(self):
        # Regression for a real, confirmed platform-parity gap: covenant.sh
        # fails closed (BLOCK) when source changed but no test runner is
        # configured or inferable; covenantwin.py previously silently no-op'd
        # (safe_command returns 0 for an empty command), meaning a
        # Windows-governed repo could pass every commit with zero tests ever
        # run and no warning.
        (self.repo/'app.py').write_text("def f():\n    return 1\n")
        call(['git', 'add', 'app.py'], self.repo)
        p = call(['git', 'commit', '-m', 'add source with no test command configured'], self.repo)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('no test runner is configured', p.stderr)

    def test_no_fail_closed_for_docs_only_change_without_a_test_command(self):
        (self.repo/'NOTES.md').write_text("just docs\n")
        call(['git', 'add', 'NOTES.md'], self.repo)
        p = call(['git', 'commit', '-m', 'docs only'], self.repo)
        self.assertEqual(p.returncode, 0, p.stderr)

    def test_tier3_brainstorm_block_applies_to_agent_with_five_plus_files_and_no_checkpoint(self):
        for i in range(5):
            (self.repo/f'file{i}.py').write_text(f"x = {i}\n")
        call(['git', 'add', '-A'], self.repo)
        p = call(['git', 'commit', '-m', 'large agent change'], self.repo, env={**os.environ, 'CLAUDECODE': '1'})
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('brainstorming checkpoint', p.stderr)

    def test_tier3_brainstorm_block_does_not_apply_to_a_human_commit(self):
        for i in range(5):
            (self.repo/f'file{i}.py').write_text(f"x = {i}\n")
        state_path = self.repo/'.claude/covenant_state.json'
        state = json.loads(state_path.read_text())
        state['commands']['test'] = 'true' if sys.platform != 'win32' else 'cmd /c exit 0'
        state_path.write_text(json.dumps(state, indent=2))
        call(['git', 'add', '-A'], self.repo)
        env = {k: v for k, v in os.environ.items() if k != 'CLAUDECODE'}
        p = call(['git', 'commit', '-m', 'large human change'], self.repo, env=env)
        self.assertEqual(p.returncode, 0, p.stderr)

    def test_tier3_brainstorm_block_passes_once_checkpoint_file_exists(self):
        (self.repo/'.claude/checkpoints').mkdir(parents=True, exist_ok=True)
        (self.repo/'.claude/checkpoints/LATEST.md').write_text('# design brief\n')
        state_path = self.repo/'.claude/covenant_state.json'
        state = json.loads(state_path.read_text())
        state['commands']['test'] = 'true' if sys.platform != 'win32' else 'cmd /c exit 0'
        state_path.write_text(json.dumps(state, indent=2))
        for i in range(5):
            (self.repo/f'file{i}.py').write_text(f"x = {i}\n")
        call(['git', 'add', '-A'], self.repo)
        p = call(['git', 'commit', '-m', 'large agent change with checkpoint'], self.repo, env={**os.environ, 'CLAUDECODE': '1'})
        self.assertEqual(p.returncode, 0, p.stderr)

    def test_prepush_checkpoint_gate_blocks_agent_pushing_source_without_checkpoint(self):
        state_path = self.repo/'.claude/covenant_state.json'
        state = json.loads(state_path.read_text())
        state['commands']['test'] = 'true' if sys.platform != 'win32' else 'cmd /c exit 0'
        state_path.write_text(json.dumps(state, indent=2))
        (self.repo/'app.py').write_text("def f():\n    return 1\n")
        call(['git', 'add', '-A'], self.repo)
        # Commit as a human (checkpoint gate is push-time and agent-only; a
        # human commit must be able to create the commit this test then tries
        # to push as an agent).
        env_human = {k: v for k, v in os.environ.items() if k != 'CLAUDECODE'}
        committed = call(['git', 'commit', '-m', 'source change'], self.repo, env=env_human)
        self.assertEqual(committed.returncode, 0, committed.stderr)

        remote = Path(self.tmp.name) / 'remote2.git'
        self.assertEqual(call(['git', 'init', '--bare', str(remote)], self.repo).returncode, 0)
        self.assertEqual(call(['git', 'config', 'remote.origin.url', str(remote)], self.repo).returncode, 0)
        p = call(['git', 'push', '-u', 'origin', 'feature/test'], self.repo, env={**os.environ, 'CLAUDECODE': '1'})
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('checkpoint', p.stderr)

    def test_uninstall_removes_everything_and_leaves_clean_repo(self):
        # No -Confirm needed: ShouldProcess only prompts interactively above
        # the default ConfirmPreference ('High'), and this script declares no
        # elevated ConfirmImpact — it already runs non-interactively by
        # default. (Passing -Confirm:$false through -File's string-argument
        # binding doesn't work anyway — PowerShell binds it as the literal
        # string "$false", not a boolean, and errors.)
        if not POWERSHELL:
            self.skipTest('no PowerShell interpreter (pwsh/powershell.exe) found on PATH')
        uninstall_ps1 = ENGINE.parents[1] / 'uninstall.ps1'
        p = call([POWERSHELL, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(uninstall_ps1),
                   '-Path', str(self.repo)], self.repo)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertFalse((self.repo/'.githooks').exists())
        self.assertFalse((self.repo/'.claude').exists())
        self.assertFalse((self.repo/'.github/workflows/covenant.yml').exists())
        self.assertFalse((self.repo/'v1_claude_code_development_guide_existing.md').exists())
        self.assertFalse((self.repo/'v1_implementation_package_existing.md').exists())
        # CODEOWNERS must survive — never auto-removed
        self.assertTrue((self.repo/'.github/CODEOWNERS').exists())
        hook_path = call(['git', 'config', '--get', 'core.hooksPath'], self.repo).stdout.strip()
        self.assertEqual(hook_path, '')

if __name__ == '__main__': unittest.main(verbosity=2)
