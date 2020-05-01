pragma solidity <0.7.0;

import "./Shared.sol";
import "./Controller.sol";


// TODO: replace uint with more specific type
// TODO: make the events targeted if they are

contract DataOwnerFiles {
    // State variables
    address public dataOwner;
    // Shared.File[] public files; // TODO: better if it's something like mapping (ks_kPp# => Shared.File) files;
    bytes32[] bundleHashes;
    mapping(bytes32 => Shared.File) files;
    Controller controller;
    
    
    // Constructor
    // TODO: try to find more elegant solution
    constructor(address controllerAddress) public {
        dataOwner = msg.sender;
        controller = Controller(controllerAddress);
    }
    
    
    // Modifiers
    modifier onlyDataOwner {
        require(msg.sender == dataOwner, "DataOwner required");
        _;
    }
    
    modifier onlyDataRequester {
        require(controller.isDataRequesterRegistered(msg.sender));
        _;
    }
    
    modifier onlyOracle {
        require(controller.isOracleRegistered(msg.sender));
        _;
    }
    
    modifier onlyMPA {
        require(controller.isMPARegistered(msg.sender));
        _;
    }
    
    
    // Adding a file (done by dataOwner)
    event fileAddedDataOwner(); // Inform dataOwner // TODO: finish this // TODO: make sure this is correct (no timeout issues)
    event fileAddedMPA();
    function addFile(bytes32 _bundleHash, byte _permissions) public onlyDataOwner {
        bundleHashes.push(_bundleHash);
        
        Shared.File memory newFile;
        // newFile.bundleHash = _bundleHash;
        newFile.permissions = _permissions;
        files[_bundleHash] = newFile;
        
        emit fileAddedDataOwner();
        emit fileAddedMPA();
    }
    
    function setFileMPAAuthRequiredCount(uint16 _fileIndex, uint8 _MPAAuthRequiredCount) public onlyMPA {
        files[bundleHashes[_fileIndex]].MPAAuthRequiredCount = _MPAAuthRequiredCount;
    }
    
     
    // Request a file (done by dataRequester)
    // TODO: transaction fees related to _oracleCount
    // TODO: penalize if oracle responded to PRSC but didn't send to dataRequester
    event fileRequestedDataRequester();
    event fileRequestedDataOwner(bytes dataRequesterPublicKey); // Inform dataRequester about successful request, and inform dataOwner about new request (must contain dataRequester's public key)
    function requestFile(uint16 _fileIndex, bytes memory _publicKey, uint8 _minOracleCount, uint8 _maxOracleCount) public onlyDataRequester {
        // require(Shared.checkPublicKey(_publicKey), "Valid public key required");
        // require((uint(keccak256(_publicKey)) & (0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)) == uint(msg.sender), "Valid public key required");
        require(_minOracleCount <= _maxOracleCount, "_minOracleCount <= _maxOracleCount required");

        Shared.Request memory request;
        request.dataRequester = msg.sender;
        request.requestTime = block.timestamp;
        request.minOracleCount = _minOracleCount;
        request.maxOracleCount = _maxOracleCount;
        request.oraclesEvaluated = false;
        
        
        files[bundleHashes[_fileIndex]].requests[files[bundleHashes[_fileIndex]].requestCount] = request;
        files[bundleHashes[_fileIndex]].requestCount += 1;
        
        emit fileRequestedDataRequester();
        emit fileRequestedDataOwner(_publicKey);
    }
    
    
    // Respond to a pending request (done by dataOwner) // TODO: need more efficient way to track pending requests
    event requestRespondedDataRequester();
    event requestRespondedDataOwner();
    event requestRespondedOracles(); // TODO: must include bundle hash and so and so
    function respondRequest(uint16 _fileIndex, uint16 _requestIndex, bool _grant) public onlyMPA {
        if (_grant) {
            files[bundleHashes[_fileIndex]].requests[_requestIndex].MPAAuthCount++;
        }
        
        emit requestRespondedDataRequester();
        emit requestRespondedDataOwner();
        
        if (files[bundleHashes[_fileIndex]].requests[_requestIndex].MPAAuthCount >= files[bundleHashes[_fileIndex]].MPAAuthRequiredCount &&
            controller.getDataRequesterMPAAuthCount(files[bundleHashes[_fileIndex]].requests[_requestIndex].dataRequester) >= files[bundleHashes[_fileIndex]].MPAAuthRequiredCount) {
            emit requestRespondedOracles();
            files[bundleHashes[_fileIndex]].requests[_requestIndex].granted = true;
            // call function after 2 hours
        }
    }
    
    // Add oracle response (done by oracle)
    // TODO: to think about: what if dataOwner revoked after oracle participated?
    // TODO: maybe let dataRequester select 1 hours
    // NOTE:
    /* 
     * 3 cases:
     * - still waiting for min: reach min then evaluate
     * - got min but not max: evaluate on timeout
     * - got max: evaluate
     */
    function addOracleResponse(uint16 _fileIndex, uint16 _requestIndex, bytes32 _bundleHash) public onlyOracle {
        Shared.File storage file = files[bundleHashes[_fileIndex]];
        Shared.Request storage request = file.requests[_requestIndex];
        
        require(request.granted, "Granted request required");
        require(!request.oraclesEvaluated,"Request Already Evaluated");
        
        uint16 latency = uint16(block.timestamp - request.requestTime);
        
        if (request.oracleAddresses.length < request.minOracleCount ||
            request.oracleAddresses.length >= request.minOracleCount &&
            request.oracleAddresses.length < request.maxOracleCount &&
            latency <= 1 hours) {
            
            uint8 isHashCorrect = _bundleHash == bundleHashes[_fileIndex] ? 1 : 0;  // TODO: this should not be bundle hash but rather ks_kPp#

            uint16 input_start = 1;
            uint16 input_end = 3600;
            uint16 output_start = 2**16 - 1;
            uint16 output_end = 1;

            // TODO: make sure this is working correctly
            uint16 oracleRating = isHashCorrect;
            if (latency < 1)
                oracleRating *= 2**16 - 1;
                
            else if (latency > 1 hours)
                oracleRating *= 0;
                
            else
                oracleRating *= output_start + ((output_end - output_start) / (input_end - input_start)) * (latency - input_start);
          

            request.oracleAddresses.push(msg.sender);
            request.oracleRatings[msg.sender] = oracleRating; // TODO: shouldn't be in ledger, directly send to measure reputation
            
        } 
        
        if ((request.oracleAddresses.length >= request.minOracleCount && request.requestTime + 1 hours <= block.timestamp) ||
            request.oracleAddresses.length == request.maxOracleCount) {
            evaluateOracles(_fileIndex, _requestIndex);
            request.oraclesEvaluated = true;
            
        }
    }
    
    
    
    event tokenCreatedDataRequester(bytes32 tokenID, address oracleAddress); // oracle info
    event tokenCreatedOracle(bytes32 tokenID, address dataRequesterAddress); // dataRequester info
    function evaluateOracles(uint16 _fileIndex, uint16 _requestIndex) internal {
        Shared.File storage file = files[bundleHashes[_fileIndex]];
        Shared.Request storage request = file.requests[_requestIndex];
        
        uint16[] memory reputations = controller.getOracleReputations(request.oracleAddresses);
        uint16[] memory ratings = new uint16[](request.oracleAddresses.length);
        
        address bestOracleAddress;
        uint64 bestOracleScore = 0;
        
        for (uint16 i = 0; i < request.oracleAddresses.length; i++) {
            uint16 oracleRating = request.oracleRatings[request.oracleAddresses[i]];
            uint16 oracleReputation = reputations[i];
            
            // 64 > 48 = 16 + 16*2 ---> uint64
            uint64 oracleScore = oracleRating * (oracleReputation + 1)**2;
            
            if (oracleScore > bestOracleScore) {
                bestOracleScore = oracleScore;
                bestOracleAddress = request.oracleAddresses[i];
            }
            
            ratings[i] = oracleRating;
        }
        
        controller.submitContractOracleRatings(request.oracleAddresses, ratings);
        
        bytes32 tokenID = keccak256(abi.encodePacked(request.dataRequester, bestOracleAddress, block.timestamp));
        
        emit tokenCreatedDataRequester(tokenID, bestOracleAddress);
        emit tokenCreatedOracle(tokenID, request.dataRequester);

        controller.submitDataRequesterToken(request.dataRequester, tokenID, bestOracleAddress);
        controller.submitOracleToken(bestOracleAddress, tokenID, request.dataRequester);
        
        //emit tokenCreatedDataRequester(tokenID, bestOracleAddress);
        //request.selectedOracle= bestOracleAddress;
        //emit tokenCreatedDataRequester(tokenID, request.dataRequester);
    }
    
    
}