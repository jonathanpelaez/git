#!/bin/sh

test_description='checkout can handle submodules'

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-submodule-update.sh

test_expect_success 'setup' '
	mkdir submodule &&
	(cd submodule &&
	 git init &&
	 test_commit first) &&
	git add submodule &&
	test_tick &&
	git commit -m superproject &&
	(cd submodule &&
	 test_commit second) &&
	git add submodule &&
	test_tick &&
	git commit -m updated.superproject
'

test_expect_success '"reset <submodule>" updates the index' '
	git update-index --refresh &&
	git diff-files --quiet &&
	git diff-index --quiet --cached HEAD &&
	git reset HEAD^ submodule &&
	test_must_fail git diff-files --quiet &&
	git reset submodule &&
	git diff-files --quiet
'

test_expect_success '"checkout <submodule>" updates the index only' '
	git update-index --refresh &&
	git diff-files --quiet &&
	git diff-index --quiet --cached HEAD &&
	git checkout HEAD^ submodule &&
	test_must_fail git diff-files --quiet &&
	git checkout HEAD submodule &&
	git diff-files --quiet
'

test_expect_success '"checkout <submodule>" honors diff.ignoreSubmodules' '
	git config diff.ignoreSubmodules dirty &&
	echo x> submodule/untracked &&
	git checkout HEAD >actual 2>&1 &&
	test_must_be_empty actual
'

test_expect_success '"checkout <submodule>" honors submodule.*.ignore from .gitmodules' '
	git config diff.ignoreSubmodules none &&
	git config -f .gitmodules submodule.submodule.path submodule &&
	git config -f .gitmodules submodule.submodule.ignore untracked &&
	git checkout HEAD >actual 2>&1 &&
	test_must_be_empty actual
'

test_expect_success '"checkout <submodule>" honors submodule.*.ignore from .git/config' '
	git config -f .gitmodules submodule.submodule.ignore none &&
	git config submodule.submodule.path submodule &&
	git config submodule.submodule.ignore all &&
	git checkout HEAD >actual 2>&1 &&
	test_must_be_empty actual
'

test_expect_success 'setup superproject with historic submodule' '
	test_create_repo super1 &&
	test_create_repo sub1 &&
	test_commit -C sub1 sub_content &&
	git -C super1 submodule add ../sub1 &&
	git -C super1 commit -a -m "sub1 added" &&
	test_commit -C super1 historic_state &&
	git -C super1 rm sub1 &&
	git -C super1 commit -a -m "deleted sub" &&
	test_commit -C super1 new_state &&
	test_path_is_missing super1/sub &&

	# The important part is to ensure sub1 is not in there any more.
	# There is another series in flight, that may remove an
	# empty .gitmodules file entirely.
	test_must_be_empty super1/.gitmodules
'

test_expect_success 'checkout old state with deleted submodule' '
	test_when_finished "rm -rf super1 sub1 super1_clone" &&
	git clone --recurse-submodules super1 super1_clone &&
	git -C super1_clone checkout --recurse-submodules historic_state
'

KNOWN_FAILURE_DIRECTORY_SUBMODULE_CONFLICTS=1
test_submodule_switch_recursing_with_args "checkout"

test_submodule_forced_switch_recursing_with_args "checkout -f"

test_submodule_switch "git checkout"

test_submodule_forced_switch "git checkout -f"

test_done
