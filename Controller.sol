pragma solidity <0.7.0;

import "./Shared.sol";

contract Controller {
    // State variables
    address owner;
    mapping (address => Shared.DataOwner) public dataOwners;
    mapping (address => Shared.DataRequester) public dataRequesters;
    mapping (address => Shared.Oracle) public oracles;
    mapping (address => Shared.MPA) public MPAs; 
    uint MPACount;
    
    // Modifier
    modifier notOwner {
        require(msg.sender != owner);
        _;
    }
    
    modifier onlyNotRegistered {
        require(!dataOwners[msg.sender].registered);
        require(!dataRequesters[msg.sender].registered);
        require(!oracles[msg.sender].registered);
        require(!MPAs[msg.sender].registered);
        _;
    }
    
    modifier onlyMPA {
        require(MPAs[msg.sender].registered);
        _;
    }
    
    modifier notOracle {
        require(!oracles[msg.sender].registered);
        _;
    }
    
    // Constructor
    constructor() public {
        owner = msg.sender;
        MPACount = 0;
    }
    
    
    // Add dataOwner
    function addDataOwner() public notOracle notOwner onlyNotRegistered {
        Shared.DataOwner memory dataOwner;
        dataOwner.registered = true;
        dataOwners[msg.sender] = dataOwner;
    }
    
    // Add dataRequester
    function addDataRequester(bytes1[] memory _claims) public notOracle notOwner onlyNotRegistered {
        //Shared.DataRequester memory dataRequester = Shared.DataRequester(true, 0, new address[](0), _claims);
        Shared.DataRequester memory dataRequester;
        dataRequester.claims= _claims;
        dataRequester.registered= true;
        dataRequesters[msg.sender] = dataRequester;
    }
    
    function isDataRequesterRegistered(address _dataRequesterAddress) public view returns (bool) {
        return dataRequesters[_dataRequesterAddress].registered;
    }
    
    function getDataRequesterMPAAuthCount(address _dataRequesterAddress) public view returns (uint) {
        return dataRequesters[_dataRequesterAddress].MPAAuthCount;
    }
    
    function authenticateDataRequester(address _dataRequesterAddress) public onlyMPA {
        dataRequesters[_dataRequesterAddress].MPAAuthCount++;
        dataRequesters[_dataRequesterAddress].MPAAuthAddresses.push(msg.sender);
    }
    
    // Add oracles
    function addOracle() public notOracle notOwner onlyNotRegistered {
        Shared.Oracle memory oracle;
        oracle.registered = true;
        oracle.averageContractRating = 50;
        oracle.contractRatingCount = 0;
        oracle.averageDataRequesterRating = 50;
        oracle.dataRequesterRatingCount = 0;
        
        oracles[msg.sender] = oracle;
    }
    
    function isOracleRegistered(address _oracleAddress) public view returns (bool) {
        return oracles[_oracleAddress].registered;
    }
    
    function addMPA() public notOracle notOwner onlyNotRegistered {
        Shared.MPA memory MPA = Shared.MPA(true);
        MPAs[msg.sender] = MPA;
        MPACount++;
    }
    
    function isMPARegistered(address _MPAAddress) public view returns (bool) {
        return MPAs[_MPAAddress].registered;
    }
    
    // TODO: maybe add a modifier
    function getOracleReputations(address[] memory oracleAddresses) view public returns (uint16[] memory) {
        uint16[] memory reputations = new uint16[](oracleAddresses.length);

        // NOTE: we are assuming oracleAddresses 
        for (uint i = 0; i < oracleAddresses.length; i++) {
            Shared.Oracle memory oracle = oracles[oracleAddresses[i]];
            
            reputations[i] = (oracle.averageContractRating + oracle.averageDataRequesterRating) / 2;
        }
        
        return reputations;
    }
    
    function submitContractOracleRatings(address[] memory oracleAdresses, uint16[] memory ratings) public onlyNotRegistered {
        for (uint i = 0; i < oracleAdresses.length; i++) {
            Shared.Oracle storage oracle = oracles[oracleAdresses[i]];
            oracle.averageContractRating = (oracle.contractRatingCount * oracle.averageContractRating + ratings[i]) / (oracle.contractRatingCount + 1);
            oracle.contractRatingCount += 1;
        }
    }
    
     function submitDataRequesterToken(address dataRequesterAddress, bytes32 tokenID, address oracleAddress) public onlyNotRegistered {
        dataRequesters[dataRequesterAddress].tokenIDs.push(tokenID);
        dataRequesters[dataRequesterAddress].tokens[tokenID] = Shared.DataRequesterToken(true, oracleAddress);
    }
    
    function submitOracleToken(address oracleAddress, bytes32 tokenID, address dataRequesterAddress) public onlyNotRegistered {
        oracles[oracleAddress].tokenIDs.push(tokenID);
        oracles[oracleAddress].tokens[tokenID] = Shared.OracleToken(true, dataRequesterAddress);
    }
    
    // TODO: think about the correct modifier here
    function submitDataRequesterOracleRating(bytes32 tokenID, address oracleAddress, uint16 rating) public {
        require(oracles[oracleAddress].tokens[tokenID].exists &&
                dataRequesters[msg.sender].tokens[tokenID].exists,
                "Valid token required");
                
        require(oracles[oracleAddress].tokens[tokenID].dataRequesterAddress == msg.sender &&
                dataRequesters[msg.sender].tokens[tokenID].oracleAddress == oracleAddress,
                "Valid token required");
                
        Shared.Oracle storage oracle = oracles[oracleAddress];
        oracle.averageDataRequesterRating = (oracle.contractRatingCount * oracle.averageContractRating + rating) / (oracle.contractRatingCount + 1);
        oracle.dataRequesterRatingCount += 1;
    }
}