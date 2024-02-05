# Echidna
echidna:
	echidna test/invariants/Tester.t.sol --contract Tester --config ./test/invariants/_config/echidna_config.yaml --corpus-dir ./test/invariants/_corpus/echidna/default/_data/corpus

echidna-assert:
	echidna test/invariants/Tester.t.sol --contract --test-mode assertion Tester --config ./test/invariants/_config/echidna_config.yaml --corpus-dir ./test/invariants/_corpus/echidna/default/_data/corpus

# Medusa
medusa:
	medusa fuzz --config ./test/invariants/_config/medusa.json