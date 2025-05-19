reverse = $(if $(wordlist 2,2,$(1)),$(call reverse,$(wordlist 2,$(words $(1)),$(1))) $(firstword $(1)),$(1))

SHELL=/bin/bash

EXTENSION = pg_role_fkey_trigger_functions

EXTENSION_DEFAULT_VERSION = $(shell sed -n -E "/default_version/ s/^.*'(.*)'.*$$/\1/p" $(EXTENSION).control)

ifneq (,$(filter tag_default_version,$(MAKECMDGOALS)))
EXTENSION_DEFAULT_VERSION_RELEASE_DATE ?= $(shell date +%Y-%m-%d)
endif
ifneq (,$(EXTENSION_DEFAULT_VERSION_RELEASE_DATE))
EXTENSION_VERSION_V_SUFFIX = ":$(EXTENSION_DEFAULT_VERSION)@$(EXTENSION_DEFAULT_VERSION_RELEASE_DATE)"
endif

# Anchoring the changelog:
OLDEST_VERSION = 0.9.0

DATA = $(wildcard sql/$(EXTENSION)*.sql)

UPDATE_SCRIPTS = $(wildcard sql/$(EXTENSION)--[0-99].[0-99].[0-99]--[0-99].[0-99].[0-99].sql)

REGRESS = test_extension_update_paths

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# Set some environment variables for the regression tests that will be fed to `pg_regress`:
installcheck: export EXTENSION_NAME=$(EXTENSION)
installcheck: export EXTENSION_ENTRY_VERSIONS?=$(patsubst $(EXTENSION)--%.sql,%,$(shell ls sql/ | grep -E "$(EXTENSION)--[0-9]+\.[0-9]+\.[0-9]+\.sql"))

README.md: sql/README.sql install
	psql --quiet postgres < $< > $@

META.json: sql/META.sql install
	psql --quiet postgres < $< > $@

CHANGELOG.md: bin/sql-to-changelog.md.sh sql/pg_extension_update_scripts_sequence.sql CHANGELOG.preamble.md install $(UPDATE_SCRIPTS)
	echo $(EXTENSION_VERSION_V_SUFFIX)
	cat CHANGELOG.preamble.md > $@
	bin/sql-to-changelog.md.sh -r '## [%v] – %d' -u '## [%v] – unreleased' -c 'https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/%f…%t' -p $(call reverse,$(shell env EXTENSION_NAME=$(EXTENSION) EXTENSION_OLDEST_VERSION=$(OLDEST_VERSION) EXTENSION_VERSION_V_SUFFIX=$(EXTENSION_VERSION_V_SUFFIX) psql -X postgres < sql/pg_extension_update_scripts_sequence.sql)) >> $@

.PHONY: tag_default_version
tag_default_version: META.json README.md CHANGELOG.md
	git add $^
	git commit -m "Version $(EXTENSION_DEFAULT_VERSION); see "'`CHANGELOG.md`'
	git tag -m "Release $(EXTENSION_DEFAULT_VERSION)" v$(EXTENSION_DEFAULT_VERSION)

.PHONY: zip_default_version
zip_default_version: tag_default_version
	git archive --format zip --prefix=$(EXTENSION)-$(EXTENSION_DEFAULT_VERSION)/ -o $(EXTENSION)-$(EXTENSION_DEFAULT_VERSION).zip v$(EXTENSION_DEFAULT_VERSION)

test_dump_restore: $(CURDIR)/bin/test_dump_restore.sh sql/test_dump_restore.sql
	PGDATABASE=test_dump_restore \
		$< --extension $(EXTENSION) \
		--psql-script-file sql/test_dump_restore.sql \
		--out-file results/test_dump_restore.out \
		--expected-out-file expected/test_dump_restore.out
