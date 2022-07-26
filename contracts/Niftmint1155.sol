//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract Niftmnt1155 is ERC1155, Ownable, Pausable, AccessControl{
    using Address for address;
    using SafeMath for uint256;
    using Math for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    //NFTs totally minted
    uint256 private minted;
    //NFTs minted by Mint Function
    uint256 public mintedGeneral;
    //max allowed NFT Minting Number 
    mapping(uint256 => uint256) private maxTokenMintingNumber;
    //An address can be assigned to the "Minter role" to handle giveaway or other promotions
    //Tracks the number of NFTs Minted by promotions
    mapping (address => uint256) private promotions;
    //Metadata URI
    string metadataRoot;
    //Promotion minters limits
    mapping (address => uint256) private mintAllowance;
    //Sell phases -> prices
    mapping (uint32 => uint256) private prices;
    //sell phases => enabled
    mapping (uint32 => bool) private sellPhases;
 
    event maxnftsNumberChanged(address changer, uint256 tokenID, uint256 maxMinting);
    event MintersUpdated(address changer, address newMinter);
    event MetadataUpdated(string metadata);
    event PausedStateChanged(address changer, bool state);
    event SetMintAllowance(address minter, uint256 NFTs);
    event SellPhasePriceUpdated(uint32 phase, uint256 price );

    constructor(
            string memory initMetadataRoot) ERC1155(initMetadataRoot) {

        metadataRoot = initMetadataRoot;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function updateMaxMint(uint256 tokenID, uint256 _maxTokenMintingNumber) public onlyOwner {
        maxTokenMintingNumber[tokenID] = _maxTokenMintingNumber;
        emit maxnftsNumberChanged(msg.sender, tokenID, _maxTokenMintingNumber);
    }

    function setMinter(address newMinter) public onlyOwner {
        _setupRole(MINTER_ROLE, newMinter);
        emit MintersUpdated(msg.sender, newMinter);
    }

    function updateMetadata(string calldata _newUri) public onlyOwner {
        metadataRoot = _newUri;
        emit MetadataUpdated(_newUri);
    }

    function setPaused(bool pausedState) public onlyOwner {
        if(pausedState == true)
            _pause();
        else if(pausedState == false)
            _unpause();
        
        emit PausedStateChanged(msg.sender, pausedState);
    }

    function getMintingNumber(uint256 tokenID) public view returns(uint256){
        return maxTokenMintingNumber[tokenID];
    }

    function  setMintAllowance(address minter, uint256 _nftsNumber) public onlyOwner {
        //Validates address
        require(minter != address(0), "Setting for the zero address not allowed");
        require(hasRole(MINTER_ROLE, minter), "Address has not the Minter Role");

        mintAllowance[minter] = _nftsNumber;

        emit SetMintAllowance(minter, _nftsNumber);

    }

    function getAllowance(address minter) public view returns(uint256){
        require(minter != address(0), "Querying for the zero address not allowed");
        return mintAllowance[minter];
    }

    function setPrice(uint32 sellPhase, uint256 price) public onlyOwner {
        sellPhases[sellPhase] = true;
        prices[sellPhase] = price;
    }

    function getPrice(uint32 sellPhase) public view returns(uint256){

        return prices[sellPhase];

    }

    function mint(uint256 tokenID, uint256 nftsNum, uint32 sellPhase) public onlyOwner whenNotPaused returns(bool){

        //validate nftsNum by transaction, max nftsNum
        require(nftsNum <= maxTokenMintingNumber[tokenID], "Can't buy more NFTs per transaction than maxTokenMintingNumber");

        //Si se pasa del rango limitar nftsNum
        nftsNum = nftsNum.min(prices[sellPhase].sub(mintedGeneral));
        
         //validates the number of NFTs is more than 0 and not exceed the max per transaction
        require(nftsNum > 0, "Needs to provide a valid number of NFTs");

        //ERC1155Mint
        _mint(msg.sender, tokenID, nftsNum, "");
        mintedGeneral += nftsNum;

        minted += nftsNum;

        return true;        
    }

    function mintPromotions(uint256 tokenID, uint256 nftsNum, address to) public whenNotPaused onlyRole(MINTER_ROLE)  returns(bool){

        //validates the number of NFTs is more than 0 and not exceed the max per transaction
        require(nftsNum > 0, "Needs to provide a valid number of NFTs");
        require(nftsNum <= maxTokenMintingNumber[tokenID], "Can't buy more NFTs per transaction than maxTokenMintingNumber");

        //Validates address
        require(to != address(0), "Minting for the zero address not allowed");

        //validates the allowed amount to mint
        uint256 allowance = mintAllowance[msg.sender];

        require(nftsNum <= allowance, "NFTs number exceed the minting allowance");

         //ERC1155Mint
        _mint(to, tokenID, nftsNum, "");

        promotions[to] += nftsNum;
        minted += nftsNum;
        mintAllowance[msg.sender] -= nftsNum;

        return true;
    }

    function name() external pure returns (string memory) {
        return "Fragmented Spells";
    }

    function symbol() external pure returns (string memory) {
        return "FRAG";
    }

    function decimals() external pure returns (uint8) {
        return 0;
    }

    function totalSupply() public view returns (uint256) {
        return minted;
    }

    function tokenURI(uint256 id) external view returns (string memory) {
        return uri(id);
    }

    function uri(uint256 id) override public view returns (string memory) {
        return string(abi.encodePacked(metadataRoot, Strings.toString(id), ".json"));
    }

    function balanceOf(address account, uint256 tokenID) public view override returns (uint256) {
        return balanceOf(account, tokenID);
    }


    function supportsInterface(bytes4 interfaceId) 
        public view virtual override(ERC1155, AccessControl) returns (bool) 
    {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

}