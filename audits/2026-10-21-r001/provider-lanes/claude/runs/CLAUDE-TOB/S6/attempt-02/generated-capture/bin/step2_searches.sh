#!/bin/bash
# Generated scratch helper: Step 2 applicability source searches (bash + /usr/bin/grep for reproducibility).
cd "$1/packages/contracts" || exit 1
G=/usr/bin/grep
echo "# Step 2 applicability searches over ORIGINAL packages/contracts (src + reachable node_modules deps)"
echo "# generated $(date -u +%FT%TZ) using $G ($($G --version | head -1))"
s() { local pat="$1"; shift; echo; echo "## $G -rnE '$pat' $*"; $G -rnE "$pat" "$@" || echo "(no matches)"; }
echo; echo "### A. Upgradeability / proxy indicators"
s 'delegatecall|DELEGATECALL' src node_modules
s 'Initializable|initializer|reinitializer|_disableInitializers' src node_modules
s 'function initialize|initialized' src
s 'upgradeTo|upgradeToAndCall|UUPS|ERC1967|TransparentUpgradeable|Beacon|_implementation|proxiableUUID' src node_modules
s 'Clones\.|cloneDeterministic|predictDeterministicAddress|create\(|create2\(' src node_modules/@openzeppelin/contracts/proxy
s 'selfdestruct|SELFDESTRUCT' src node_modules
echo; echo "### B. Token standards implemented or integrated"
s '^(abstract )?contract |^interface |^library ' src
s 'is .*ERC721|ERC721\(|IERC721Receiver|onERC721Received' src
s 'ERC20|IERC20|SafeERC20|safeTransfer|safeTransferFrom|balanceOf|approve\(|transferFrom\(' src
s 'ERC1155|ERC777|ERC4626|ERC2612|permit\(|ERC2981|royalt' src
s 'supportsInterface|IERC165|interfaceId' src
echo; echo "### C. Truffle / slither-prop prerequisites"
echo "## find . -iname 'truffle*' (excluding node_modules)"; find . -iname 'truffle*' -not -path './node_modules/*'; echo "(end of find)"
s 'truffle' package.json hardhat.config.ts foundry.toml remappings.txt
s 'contract [A-Za-z0-9_]+ is [^{]*\bERC20\b' src
echo; echo "### D. VRF LINK-payment path reachability (dependency unused-return triage)"
s 'requestRandomness\(|requestRandomnessPayInNative\(' src
s 'i_linkToken|LinkTokenInterface|transferAndCall' src
echo; echo "### E. Tests present in the provided clean context?"
echo "## find . -path ./node_modules -prune -o \\( -iname '*.t.sol' -o -iname '*test*' \\) -print"; find . -path ./node_modules -prune -o \( -iname '*.t.sol' -o -iname '*test*' \) -print; echo "(end of find)"
