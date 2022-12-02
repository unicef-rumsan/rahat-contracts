//SPDX-License-Identifier: LGPL-3.0
//TODO add balance of beneficiary per project
//TODO suspend mobilizer and vendor
//TODO test tokenissue by mobilizer
//TODO test otp set by server account and otp submission by vendor account
//TODO revole roles

pragma solidity ^0.8.16;
import "./RahatERC20.sol";
import "./RahatRegistry.sol";
import "./RahatWallet.sol";
import "./RahatTriggerResponse.sol";
import "../libraries/AbstractERC20Func.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Rahat is AccessControl, AbstractERC20Func {
  using Strings for uint256;
  using EnumerableSet for EnumerableSet.Bytes32Set;
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.UintSet;
  using ECDSA for bytes32;

  //***** Events *********//
  event ClaimedERC20(
    address indexed vendor,
    uint256 indexed beneficiary,
    uint256 amount
  );
  event ClaimApproved(
    address indexed vendor,
    uint256 indexed phone,
    uint256 amount
  );
  event IssuedERC20(
    bytes32 indexed projectId,
    uint256 indexed phone,
    uint256 amount
  );
  event ClaimAcquiredERC20(
    address indexed vendor,
    uint256 indexed beneficiary,
    uint256 amount
  );
  event InvalidSignature(
    bytes signature,
    bytes32 digest,
    address expectedSigner,
    address recoveredSigner
  );
  event Received(address, uint);

  //event BalanceAdjusted(uint256 indexed phone, uint256 amount, string reason);

  //***** Constant Variables (Roles) *********//
  bytes32 public constant SERVER_ROLE = keccak256("SERVER");
  bytes32 public constant VENDOR_ROLE = keccak256("VENDOR");
  bytes32 public constant MANAGER_ROLE = keccak256("MANAGER");
  bytes32 public constant MOBILIZER_ROLE = keccak256("MOBILIZER");
  bytes32 public constant ISSUE_TOKEN = keccak256("issueToken");
  bytes32 public constant CREATE_CLAIM = keccak256("createClaim");
  bytes32 public constant GET_TOKENS_FROM_CLAIM = keccak256(
    "getTokensFromClaim"
  );

  mapping(address => uint256) public nonces; //delegated users nonces

  //***** Variables (State) *********//
  //AidToken public tokenContract;
  RahatERC20 public erc20;
  RahatERC20 public cashToken;
  RahatRegistry public registry;
  RahatTriggerResponse public triggerResponse;

  ///@notice track total issued tokens of each benefiicary phone
  mapping(uint256 => uint256) public erc20Issued; //phone=>balance

  /// @notice track balances of each beneficiary phone
  mapping(uint256 => uint256) public erc20Balance; //phone=>balance

  mapping(uint256 => bool) public isBanked;

  /// @notice track projectBalances
  //bytes32[] public projectId;
  EnumerableSet.Bytes32Set private projectId;
  mapping(bytes32 => uint256) public totalProjectErc20Issued;
  mapping(bytes32 => uint256) public remainingProjectErc20Balances;
  mapping(bytes32 => EnumerableSet.AddressSet) projectMobilizers;
  EnumerableSet.AddressSet private projectVendors;

  mapping(address => uint256) public erc20IssuedBy;

  struct claim {
    uint256 amount;
    bytes32 otpHash;
    bool isReleased;
    uint256 date;
  }
  /// @dev vendorAddress => phone => claim
  mapping(address => mapping(bytes32 => claim)) public recentERC20Claims;

  //***** Constructor *********//
  constructor(
    RahatERC20 _erc20,
    RahatRegistry _registry,
    RahatTriggerResponse _triggerResponse,
    address _admin
  ) {
    _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    owner[_admin] = true;
    _setRoleAdmin(SERVER_ROLE, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(VENDOR_ROLE, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
    _setRoleAdmin(MOBILIZER_ROLE, DEFAULT_ADMIN_ROLE);
    erc20 = _erc20;
    registry = _registry;
    triggerResponse = _triggerResponse;
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControl)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  //***** Modifiers *********//
  modifier OnlyServer() {
    require(
      hasRole(SERVER_ROLE, msg.sender),
      "RAHAT: Sender must be an authorized server"
    );
    _;
  }
  modifier OnlyAdmin {
    require(
      hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
      "RAHAT: Sender must be an admin."
    );
    _;
  }
  modifier IsBeneficiary(uint256 _phone) {
    bytes32 _benId = findHash(_phone);
    require(
      erc20Balance[_phone] != 0,
      "RAHAT: No any token was issued to this number"
    );
    _;
  }
  modifier OnlyVendor {
    require(
      hasRole(VENDOR_ROLE, msg.sender),
      "RAHAT: Sender Must be a registered vendor."
    );
    _;
  }
  modifier OnlyAdminOrMobilizer {
    require(
      (hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
        hasRole(MOBILIZER_ROLE, msg.sender)),
      "RAHAT: Sender Must be a registered Admin Or Mobilizer."
    );
    _;
  }

  //***** Methods *********//
  //Access Control Management
  /// @notice add admin of the this contract
  /// @param _account address of the new admin
  function addAdmin(address _account) external OnlyAdmin {
    grantRole(DEFAULT_ADMIN_ROLE, _account);
    owner[_account] = true;
  }

  function isAdmin(address _account) external view returns(bool){
    return hasRole(DEFAULT_ADMIN_ROLE, _account);
  }

  /// @notice add server account for this contract
  /// @param _account address of the new server account
  function addServer(address _account) external OnlyAdmin {
    grantRole(SERVER_ROLE, _account);
  }

  /// @notice add vendors
  /// @param _account address of the new vendor
  function addVendor(address payable _account) external OnlyAdmin returns (address) {
    RahatWallet vWallet;
    bytes32 idHash = findHash(_account);
    address vWalletAddress = registry.id2Address(idHash);
    if(vWalletAddress!=address(0)){
      vWallet = RahatWallet(vWalletAddress);
    }
    else {
      vWallet = new RahatWallet(address(this));
      registry.addId2AddressMap(findHash(_account), address(vWallet));
    } 
    vWallet.addOwner(_account);
    grantRole(VENDOR_ROLE, _account);
    projectVendors.add(_account);
    if(_account.balance < 0.1 ether){
      (bool success,) = _account.call{value: 0.2 ether}("");
      require(success, "Rahat needs more ether.");
    }
    return address(vWallet);
  }

  function isVendor(address _account) public view returns(bool){
    return hasRole(VENDOR_ROLE, _account);
  }

  function listVendors() public view returns(address[] memory){
    return projectVendors.values();
  }

  /// @notice add vendors
  /// @param _account address of the new vendor
  /// @param _projectId projectId
  function addMobilizer(address _account, string memory _projectId)
    external
    OnlyAdmin
  {
    bytes32 _id = findHash(_projectId);
    grantRole(MOBILIZER_ROLE, _account);
    projectMobilizers[_id].add(_account);
  }

  /// @notice set IsBanked Beneficiary
  /// @param _phone beneficiary phone number
  /// @param _isBanked true/false
  function setAsBankedBeneficiary(uint256 _phone, bool _isBanked)
    external
    OnlyAdmin
  {
    isBanked[_phone] = _isBanked;
  }

  // function suspendMobilizer() public {}

  // function suspendVendor() public {}

  //Beneficiary Management
  /// @notice suspend the benficiary by deducting all the balance beneficiary owns
  /// @param _phone phone number of the Beneficiary
  /// @param _projectId projectId beneficiary is involved in
  function suspendBeneficiary(uint256 _phone, bytes32 _projectId)
    public
    OnlyAdmin
    IsBeneficiary(_phone)
  {
    //  bytes32 _benId = findHash(_phone);

    uint256 _balance = erc20Balance[_phone];
    remainingProjectErc20Balances[_projectId] += _balance;
    erc20Balance[_phone] = 0;
    erc20Issued[_phone] = erc20Issued[_phone] - _balance;
  }

  /// @notice adds the token from beneficiary
  function adjustTokenAdd(uint256 _phone, uint256 _amount) private {
    // bytes32 _benId = findHash(_phone);
    erc20Balance[_phone] = erc20Balance[_phone] + _amount;
    erc20Issued[_phone] = erc20Issued[_phone] + _amount;
    //emit BalanceAdjusted(_phone, _amount, _reason);
  }

  /// @notice deducts the token from beneficiary
  function adjustTokenDeduct(uint256 _phone, uint256 _amount)
    private
    IsBeneficiary(_phone)
  {
    //bytes32 _benId = findHash(_phone);
    erc20Balance[_phone] = erc20Balance[_phone] - _amount;
    //emit BalanceAdjusted(_phone, _amount, _reason);
  }

  /// @notice update a project balance.
  /// @notice called by rahatdmin contract
  /// @param _projectId Id of the project to assign budget
  /// @param _projectCapital amount of budget to be added to project
  function updateProjectBudget(bytes32 _projectId, uint256 _projectCapital)
    external
  {
    remainingProjectErc20Balances[_projectId] += _projectCapital;
    totalProjectErc20Issued[_projectId] += _projectCapital;
  }

  /// @notice get the current balance of project
  function getProjectBalance(bytes32 _projectId)
    external
    view
    returns (uint256 _balance)
  {
    return remainingProjectErc20Balances[_projectId];
  }

  function verifyVendor(bytes32 _hash, bytes memory _signature)
    internal
    view
    returns (address)
  {
    address _signer = _hash.recover(_signature);
    require(hasRole(VENDOR_ROLE, _signer), "Signer should be Mobilizer");
    return _signer;
  }

  function verifyMobilizer(bytes32 _hash, bytes memory _signature)
    internal
    view
    returns (address)
  {
    address _signer = _hash.recover(_signature);
    require(hasRole(MOBILIZER_ROLE, _signer), "Signer should be Mobilizer");
    return _signer;
  }

  /// @notice Issue tokens to beneficiary
  /// @param _projectId Id of the project beneficiary is involved in
  /// @param _phone phone number of the beneficiary
  /// @param _amount Amount of token to be assigned to beneficiary
  function issueERC20ToBeneficiary(
    string memory _projectId,
    uint256 _phone,
    uint256 _amount
  ) public OnlyAdmin {
    bytes32 _id = findHash(_projectId);

    //check beneficiary in registry;
    require(registry.exists(findHash(_phone)), "Beneficiary not registered.");
    erc20IssuedBy[msg.sender] += _amount;
    require(
      remainingProjectErc20Balances[_id] >= _amount,
      "RAHAT: Amount is greater than remaining Project Budget"
    );
    remainingProjectErc20Balances[_id] -= _amount;
    adjustTokenAdd(_phone, _amount);

    emit IssuedERC20(_id, _phone, _amount);
  }

  /// @notice request a token to beneficiary by vendor
  /// @param _phone Phone number of beneficiary to whom token is requested
  /// @param _tokens Number of tokens to request
  function createERC20Claim(uint256 _phone, uint256 _tokens)
    public
    IsBeneficiary(_phone)
    OnlyVendor
  {
    require(
      triggerResponse.isLive(),
      "This response has not been activated yet, please contact admin."
    );
    require(!isBanked[_phone], "Cannot claim from banked beneficiary");
    
    _verifyVendorCashBalance(msg.sender, _tokens);

    bytes32 _benId = findHash(_phone);
    require(
      erc20Balance[_phone] >= _tokens,
      "RAHAT: Amount requested is greater than beneficiary balance."
    );

    claim storage ac = recentERC20Claims[msg.sender][_benId];
    ac.isReleased = false;
    ac.amount = _tokens;
    ac.date = block.timestamp;
    emit ClaimedERC20(tx.origin, _phone, _tokens);
  }

  /// @notice Approve the requested claim from serverside and set the otp hash
  /// @param _vendor Address of the vendor who requested the token from beneficiary
  /// @param _phone Phone number of the beneficiary, to whom token request was sent
  /// @param _otpHash Hash of OTP sent to beneficiary by server
  /// @param _timeToLive Validity of OTP in seconds
  function approveERC20Claim(
    address _vendor,
    uint256 _phone,
    bytes32 _otpHash,
    uint256 _timeToLive
  ) public IsBeneficiary(_phone) OnlyServer {
    bytes32 _benId = findHash(_phone);
    claim storage ac = recentERC20Claims[_vendor][_benId];
    require(ac.date != 0, "RAHAT: Claim has not been created yet");
    require(
      _timeToLive <= 86400,
      "RAHAT:Time To Live should be less than 24 hours"
    );
    require(
      block.timestamp <= ac.date + 86400,
      "RAHAT: Claim is older than 24 hours"
    );
    require(!ac.isReleased, "RAHAT: Claim has already been released.");
    ac.otpHash = _otpHash;
    ac.isReleased = true;
    ac.date = block.timestamp + _timeToLive;
    emit ClaimApproved(_vendor, _phone, ac.amount);
  }

  /// @notice Retrieve tokens that was requested to beneficiary by entering OTP
  /// @param _phone Phone Number of the beneficiary, to whom token request was sent
  /// @param _otp OTP sent by the server
  function getERC20FromClaim(uint256 _phone, string memory _otp)
    public
    IsBeneficiary(_phone)
    OnlyVendor
  {
    bytes32 _benId = findHash(_phone);
    claim storage ac = recentERC20Claims[msg.sender][_benId];
    require(ac.isReleased, "RAHAT: Claim has not been released.");
    require(ac.date >= block.timestamp, "RAHAT: Claim has already expired.");
    bytes32 otpHash = findHash(_otp);
    require(
      recentERC20Claims[msg.sender][_benId].otpHash == otpHash,
      "RAHAT: OTP did not match."
    );
    adjustTokenDeduct(_phone, ac.amount);
    uint256 amt = ac.amount;
    ac.isReleased = false;
    ac.amount = 0;
    ac.date = 0;
    erc20.transfer(msg.sender, amt);
    _transferCashFromVendor(msg.sender, _phone, amt);
    emit ClaimAcquiredERC20(msg.sender, _phone, amt);
  }

  /// @notice Admin function to transfer beneficiary token to vendor
  /// @param _phone Phone number of beneficiary to whom token is requested
  /// @param _vendorAddress vendor's address
  /// @param _amount Number of tokens to request
  function transferTokenToVendorByAdmin(uint256 _phone, address _vendorAddress, uint256 _amount) 
    public IsBeneficiary(_phone) OnlyAdmin {
      require(isVendor(_vendorAddress), "Transfer to must be vendor address");
      adjustTokenDeduct(_phone, _amount);
      _transferCashFromVendor(_vendorAddress, _phone, _amount);
      erc20.transfer(_vendorAddress, _amount);
      emit ClaimAcquiredERC20(_vendorAddress, _phone, _amount);
  }
  
  function transferCashToVendor(address _vendorAddress, uint _amount) public OnlyAdmin {
    require(registry.exists(findHash(_vendorAddress)), "vendor wallet not registered.");
    cashToken.approve(registry.id2Address(findHash(_vendorAddress)), _amount);
  }

  function _transferCashFromVendor(address _vendorAddress, uint256 _phone, uint _amount) private {
    RahatWallet vendorWallet = RahatWallet(registry.id2Address(findHash(_vendorAddress)));
    vendorWallet.transferToken(address(cashToken), registry.id2Address(findHash(_phone)), _amount);
  }

  function _verifyVendorCashBalance(address _vendorAddress, uint256 _amount) private view {
    uint balance = cashToken.balanceOf(registry.id2Address(findHash(_vendorAddress)));
    require(balance >= _amount, "Vendor does not have enough cash balance.");
  } 

  function claimTokenForProject(address _token, address _from, bytes32 _projectId, uint256 _amount) public OnlyOwner {
    if(address(cashToken) == address(0)) cashToken = RahatERC20(_token);
    claimToken(_token, _from, _amount);
    remainingProjectErc20Balances[_projectId] += _amount;
    totalProjectErc20Issued[_projectId] += _amount;
  }

   function projectBalance(bytes32 _projectId, address _allowanceFrom) public view returns (uint totalBudget, uint cashAllowance, uint cashBalance, uint tokenBalance) {
    cashAllowance = cashToken.allowance(address(_allowanceFrom), address(this));
    cashBalance = cashToken.balanceOf(address(this));
    tokenBalance = remainingProjectErc20Balances[_projectId];
    totalBudget = totalProjectErc20Issued[_projectId];
  }

  function vendorBalance(address _vendorAddress) public view returns (address walletAddress, uint cashAllowance, uint cashBalance, uint tokenBalance) {
    walletAddress = registry.id2Address(findHash(_vendorAddress));
    cashAllowance = cashToken.allowance(address(this), walletAddress);
    cashBalance = cashToken.balanceOf(walletAddress);
    tokenBalance = erc20.balanceOf(_vendorAddress);
  } 

  function beneficiaryBalance(uint _phone) public view returns (address walletAddress, uint cashBalance, uint tokenBalance) {
    walletAddress = registry.id2Address(findHash(_phone));
    cashBalance = cashToken.balanceOf(walletAddress);
    tokenBalance = erc20Balance[_phone];
  } 

  /// @notice generates the hash of the given string
  /// @param _data String of which hash is to be generated
  function findHash(string memory _data) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(_data));
  }

  /// @notice generates the hash of the given string
  function findHash(uint256 _data) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(_data.toString()));
  }

  function findHash(address _data) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(_data));
  }

  /// @notice Generates the sum of all the integers in array
  /// @param _array Array of uint
  function getArraySum(uint256[] memory _array)
    public
    pure
    returns (uint256 sum)
  {
    sum = 0;
    for (uint256 i = 0; i < _array.length; i++) {
      sum += _array[i];
    }
    return sum;
  }

  receive() external payable {
      emit Received(msg.sender, msg.value);
  }

  function withdraw(address payable _to) public payable OnlyAdmin {
        (bool sent,) = _to.call{value:address(this).balance}("");
        require(sent, "Failed to send Ether");
    }
}
