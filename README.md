here below is a single-file, no-imports, no-constructor Solidity contract that implements a compact, self-contained ERC-721-like NFT with dynamic metadata for AI-generated art.

Key design choices (so you know what you're getting):

No import statements and no constructor (per your request).

Owner of the contract must call initialize() once (no parameters) after deployment; initialize() sets the caller as contract owner. This avoids using a constructor while still letting a deployer become owner.

Minimal ERC-721 functionality: balanceOf, ownerOf, transferFrom, approve, setApprovalForAll, events.

Dynamic metadata: each token has a mutable tokenURI stored on-chain (_tokenURIs[tokenId]). If unset, tokenURI falls back to baseURI + tokenId.

Admin/owner can mint new tokens (owner-only mint(address to, uint256 tokenId)).

Token owner or contract owner can update a token's metadata (setTokenURI) — useful for AI-generated art that evolves.

No external library dependencies — fully self-contained.

Light, readable comments included.

contact address: 0xd2e19e6cd3653425b49Ac7dEc7d6a98d459d4117 
