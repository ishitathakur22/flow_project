// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
  Minimal ERC-721-like NFT contract
  - No imports
  - No constructor
  - Owner must call initialize() once after deployment to become admin
  - Dynamic metadata: per-token mutable tokenURI with a fallback baseURI + tokenId
  - Only contract owner (admin) can mint; token owner or admin can update tokenURI
  - Simple approvals and transfers implemented (not a full OpenZeppelin clone)
*/

contract AIGenDynamicNFT {
    // --- Events (ERC-721 style) ---
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // --- Basic storage ---
    string private _name;
    string private _symbol;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Dynamic metadata storage
    mapping(uint256 => string) private _tokenURIs; // per-token mutable URI
    string private _baseURI; // fallback base URI (e.g., "ipfs://.../metadata/")

    // Admin (owner) - no constructor so must call initialize()
    address public owner;
    bool private _initialized;

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier exists(uint256 tokenId) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        _;
    }

    // --- Initialize (no constructor) ---
    // Must be called once by the deployer (or intended admin) after deployment.
    function initialize(string calldata name_, string calldata symbol_, string calldata initialBaseURI) external {
        require(!_initialized, "Already initialized");
        _initialized = true;
        owner = msg.sender;
        name = name;
        symbol = symbol;
        _baseURI = initialBaseURI;
    }

    // --- ERC-721 basics ---
    function name() external view returns (string memory) { return _name; }
    function symbol() external view returns (string memory) { return _symbol; }

    function balanceOf(address ownerAddr) external view returns (uint256) {
        require(ownerAddr != address(0), "Zero address");
        return _balances[ownerAddr];
    }

    function ownerOf(uint256 tokenId) public view exists(tokenId) returns (address) {
        return _owners[tokenId];
    }

    // --- Approvals / Transfers (simplified) ---
    function approve(address to, uint256 tokenId) external exists(tokenId) {
        address tokenOwner = _owners[tokenId];
        require(msg.sender == tokenOwner || _operatorApprovals[tokenOwner][msg.sender], "Not authorized");
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function getApproved(uint256 tokenId) external view exists(tokenId) returns (address) {
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address ownerAddr, address operator) external view returns (bool) {
        return _operatorApprovals[ownerAddr][operator];
    }

    function _isAuthorized(address spender, uint256 tokenId) internal view returns (bool) {
        address tokenOwner = _owners[tokenId];
        return (spender == tokenOwner
                || _tokenApprovals[tokenId] == spender
                || _operatorApprovals[tokenOwner][spender]
                || spender == owner); // contract owner allowed to operate as admin
    }

    function transferFrom(address from, address to, uint256 tokenId) public exists(tokenId) {
        require(_isAuthorized(msg.sender, tokenId), "Not authorized to transfer");
        require(_owners[tokenId] == from, "From is not owner");
        require(to != address(0), "Transfer to zero");

        // Clear approvals
        if (_tokenApprovals[tokenId] != address(0)) {
            delete _tokenApprovals[tokenId];
        }

        // Update balances and ownership
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    // Convenience safe-like transfer (no ERC721Receiver checks for brevity)
    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
    }

    // --- Minting (owner only) ---
    // No constructor, so owner must call initialize() first.
    function mint(address to, uint256 tokenId) external onlyOwner {
        require(_initialized, "Not initialized");
        require(to != address(0), "Mint to zero");
        require(_owners[tokenId] == address(0), "Token already minted");

        _owners[tokenId] = to;
        _balances[to] += 1;

        emit Transfer(address(0), to, tokenId);
    }

    // Burn (owner or token owner)
    function burn(uint256 tokenId) external exists(tokenId) {
        address tokenOwner = _owners[tokenId];
        require(msg.sender == tokenOwner || msg.sender == owner, "Not authorized to burn");

        // Clear approvals
        if (_tokenApprovals[tokenId] != address(0)) {
            delete _tokenApprovals[tokenId];
        }

        // Update state
        _balances[tokenOwner] -= 1;
        delete _owners[tokenId];
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }

        emit Transfer(tokenOwner, address(0), tokenId);
    }

    // --- Metadata (dynamic) ---
    // Set or update base URI (admin only)
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseURI = newBaseURI;
    }

    // Set or update a specific token's URI (token owner OR admin)
    function setTokenURI(uint256 tokenId, string calldata newTokenURI) external exists(tokenId) {
        address tokenOwner = _owners[tokenId];
        require(msg.sender == tokenOwner || msg.sender == owner, "Not authorized to set tokenURI");
        _tokenURIs[tokenId] = newTokenURI;
    }

    // Retrieve tokenURI. If per-token URI is set, return it; otherwise fallback to baseURI + tokenId.
    function tokenURI(uint256 tokenId) external view exists(tokenId) returns (string memory) {
        string memory specific = _tokenURIs[tokenId];
        if (bytes(specific).length != 0) {
            return specific;
        }
        // Fallback: concatenate baseURI and tokenId
        return _concatBaseURI(tokenId);
    }

    // Helper: basic uint -> string conversion and concatenation (no libraries)
    function _concatBaseURI(uint256 tokenId) internal view returns (string memory) {
        if (bytes(_baseURI).length == 0) {
            return "";
        }
        return string(abi.encodePacked(_baseURI, _uintToString(tokenId)));
    }

    // Minimal uint -> string helper
    function _uintToString(uint256 v) internal pure returns (string memory str) {
        if (v == 0) { return "0"; }
        uint256 digits;
        uint256 tmp = v;
        while (tmp != 0) { digits++; tmp /= 10; }
        bytes memory buffer = new bytes(digits);
        uint256 index = digits - 1;
        tmp = v;
        while (tmp != 0) {
            buffer[index--] = bytes1(uint8(48 + tmp % 10));
            tmp /= 10;
        }
        return string(buffer);
    }

    // --- Admin utilities ---
    // Transfer contract ownership (admin only)
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }

    // Emergency setter: owner can force set tokenURI (admin action)
    function adminSetTokenURI(uint256 tokenId, string calldata newTokenURI) external onlyOwner exists(tokenId) {
        _tokenURIs[tokenId] = newTokenURI;
    }

    // Read-only helper to get on-chain stored tokenURI (may be empty)
    function storedTokenURI(uint256 tokenId) external view exists(tokenId) returns (string memory) {
        return _tokenURIs[tokenId];
    }

    // --- Misc: receive / fallback ---
    // Reject direct ETH transfers by default (keeps contract simple)
    receive() external payable {
        revert("Contract does not accept ETH");
    }
    fallback() external payable {
        revert("Invalid call");
    }
}
//Contract Address : '0xd2e19e6cd3653425b49Ac7dEc7d6a98d459d4117 '
