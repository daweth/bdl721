// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IBDL721.sol";
import "./IERC721Receiver.sol";
import "./IERC721Metadata.sol";
import "./Address.sol";
import "./Context.sol";
import "./Strings.sol";
import "./ERC165.sol";
import "./Counters.sol";
import "./test/utils/Console.sol";

/// @title A bundling contrract for ERC721s
///  @author daweth
contract BDL721 is Context, ERC165, IBDL721, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;
    using Counters for Counters.Counter;
    
    Counters.Counter private _ids;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /// ******
    /// STORAGE 
    /// ******
     
    // Mapping from hash to Asset
    mapping(bytes32 => Asset) public _assets;

    // Mapping from token ID to Bundle
    mapping(uint256 => bytes32[]) private _bundles;

    // Mapping from Asset hash to Token ID
    mapping(bytes32 => uint256) private _bundleOf; 

    // Mapping from Asset hash to Index within Bundle
    mapping(bytes32 => uint256) private _indices;

    // Asset structure
    struct Asset {
        address nftRegistry;
        uint256 tokenId;
    }

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        Counters.increment(_ids); // reserved ID 0
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    } 

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = BDL721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approveAssets(to, tokenId); // approve all underlying assets
        _tokenApprovals[tokenId] = to; // aprove this bundle
        emit Approval(BDL721.ownerOf(tokenId), to, tokenId); // emission

        // use external approve function instead of internal function for public-facing stuff
       // _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "BDL721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }
        
    /// ******
    /// Core Functions
    /// ******

    function create(
        address[] memory _nftAddresses,
        uint256[] memory _tokenIds,
        uint256[] memory _sizes
    ) external returns (uint256) {
        require(_nftAddresses.length == _sizes.length, "BDL721: size array does not match address array length");

        bytes32[] memory bdl = new bytes32[](_tokenIds.length);
        uint256 tokenId = Counters.current(_ids);

		    uint offset = 0;
		    for(uint i=0; i<_nftAddresses.length; i++){
			      IERC721 nftRegistry = IERC721(_nftAddresses[i]);
            require(nftRegistry.isApprovedForAll(_msgSender(), address(this)), "BDL721: Bundle Contract is not approved to manage these assets");

			      for(uint j=0; j<_sizes[i]; j++){
                    
                require(nftRegistry.ownerOf(_tokenIds[offset+j])==_msgSender(), "BDL721: Only the owner can create a new bundle"); 

                bytes32 hash = generateHash(_nftAddresses[i], _tokenIds[offset+j]);
                require(_bundleOf[hash]==0, "BDL721: Asset is part of another bundle, check the bundle and try again");

                Asset memory nft = _assets[hash];
                if(nft.nftRegistry==address(0)){
                    _assets[hash] = Asset(_nftAddresses[i], _tokenIds[offset+j]);
                }
                _bundleOf[hash]=tokenId; // consider moving to the very end? /// sets the ownerOf to the new bundleID
                _indices[hash] = offset+j; // store the index of the hash within the bundle
                bdl[offset+j] = hash; // add the hash to the bundle in progress
		        }
			    offset += _sizes[i];
        }
        
        _bundles[tokenId] = bdl;
        _mint(_msgSender(), tokenId);
        Counters.increment(_ids);
        emit Creation(_msgSender(), tokenId);
        return tokenId;
    }

    function burn(
        uint256 bundleId
    ) external{
        require(BDL721.ownerOf(bundleId) == _msgSender(), "Caller does not own the bundle");        
        _burn(bundleId);
    }

    function insert(
        address nftAddress,
        uint256 tokenId,
        uint256 bundleId
    ) external{
        require(BDL721.ownerOf(bundleId)==_msgSender(), "BDL721: Caller does not own the bundle");

        bytes32 hash = generateHash(nftAddress, tokenId);
        require(_bundleOf[hash]==0, "BDL721: Asset is part of another bundle, check the bundle and try again.");
        
        Asset memory nft = _assets[hash];
        if(nft.nftRegistry==address(0)){
            _assets[hash] = Asset(nftAddress,tokenId);
        }
        _bundles[bundleId].push(hash);
        _bundleOf[hash] = bundleId;

        _indices[hash] = _bundles[bundleId].length-1;
    }

    function remove(
        address nftAddress,
        uint256 tokenId,
        uint256 bundleId
    ) external{
        require(BDL721.ownerOf(bundleId) == _msgSender(), "Caller does not own the bundle");

        bytes32 hash = generateHash(nftAddress, tokenId);
        require(_bundleOf[hash]==bundleId, "BDL721: Asset is not part of the bundle specified. Please try again.");

        Asset memory nft = _assets[hash];
        require(nft.nftRegistry!=address(0), "BDL721: Asset has not been initiated yet.");
        _removeFromBundleArray(hash, bundleId); // delete the hash from the bundle storage
        delete _bundleOf[hash];
        delete _indices[hash]; 
    }


    function check(
        uint256 bundleId
    ) external returns(bool) {
        bytes32[] memory bdl = _bundles[bundleId];
        for(uint i=0; i<bdl.length; i++){
            Asset memory nft = _assets[bdl[i]];
            IERC721 nftRegistry = IERC721(nft.nftRegistry);
            if(nftRegistry.ownerOf(nft.tokenId)!=BDL721.ownerOf(bundleId)){
                _burn(bundleId);         
                return false;
            }
        }
        return true;
    }

    function bundleOf(
        address nftAddress,
        uint256 tokenId
    ) external view returns(uint256) {
        bytes32 hash = generateHash(nftAddress, tokenId);
        return _bundleOf[hash];
    }

    function bundleIndexOf(
        address nftAddress,
        uint256 tokenId
    ) external view returns (uint256) {
        bytes32 hash = generateHash(nftAddress, tokenId);
        return _indices[hash];
    }



    /// ******
    /// Internal
    /// ******
    
    function generateHash(address _nftRegistry, uint256 _tokenId) public pure returns(bytes32){
        return keccak256(abi.encodePacked(_nftRegistry, _tokenId));
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = BDL721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = BDL721.ownerOf(tokenId);


        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(BDL721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");


        // Transfer all assets within the bundle
        _transferAssets(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }


    /**
     * @dev Approve `to` to operate on `tokenId`
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
   //     _approveAssets(to, tokenId);
        _tokenApprovals[tokenId] = to;
        emit Approval(BDL721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /// ******
    /// CORE
    /// ******

    function _transferAssets(
        address from,
        address to,
        uint256 bundleId
    ) internal virtual {
        bytes32[] memory bdl = _bundles[bundleId];
        for(uint i=0; i<bdl.length; i++){
            Asset memory nft = _assets[bdl[i]];
            IERC721 nftRegistry = IERC721(nft.nftRegistry);
            nftRegistry.transferFrom(from, to, nft.tokenId);
            /** 
            (bool success, bytes memory data) = nft.nftRegistry.delegatecall(
            abi.encodeWithSignature("transferFrom(address,address,uint256)",from,to,nft.tokenId)
            );
            require(success, "BDL721: Failed to transfer assets");
            */
        }
    }
  
    function _approveAssets(
        address to, 
        uint256 bundleId
    ) internal virtual {
        bytes32[] memory bdl = _bundles[bundleId];
        for(uint i=0; i<bdl.length; i++){
            Asset memory nft = _assets[bdl[i]];
            IERC721 nftRegistry = IERC721(nft.nftRegistry);
            nftRegistry.approve(to, nft.tokenId);            

/** 
 (bool success, bytes memory data) = address(nftRegistry).delegatecall(
            abi.encodeWithSignature("approve(address,uint256)",to,nft.tokenId)
            );
            require(success, "BDL721: Failed to approve assets");
*/
           
        }
    }
/**
    function _setApprovalForAssets(
        address owner,
        address operator,
        uint256 bundleId,
        bool approved
    ) internal virtual {
        bytes32[] memory bdl = _bundles[bundleId];
        for(uint i=0; i<bdl.length; i++){
            Asset memory nft = _assets[bdl[i]];
            IERC721 nftRegistry = IERC721(nft.nftRegistry);
            if(nftRegistry.isApprovedForAll(owner, operator)){ break; }

            nftRegistry.setApprovalForAll(operator, approved);
        }
    }

**/

    function _removeFromBundleArray(
        bytes32 hash,
        uint256 bundleId
    ) internal virtual {  
        uint index = _indices[hash]; 
        _bundles[bundleId][index]=0;
        delete _bundles[bundleId][index];
    }


    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
    }

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}
