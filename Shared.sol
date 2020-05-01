pragma solidity <0.7.0;

library Shared {
    // Structs
    struct File {
        byte permissions; // Access rules
        
        mapping(uint => Request) requests;
        uint16 requestCount;
        
        uint8 MPAAuthRequiredCount;

        // TODO: uint bundleSize; // Can be requested from IPFS through oracles to measure throughput instead of latency
    }
    
    struct Request {
        address dataRequester; // Requester
        uint requestTime; // Time of receiving a request
        uint8 minOracleCount;
        uint8 maxOracleCount;
        
        bool granted;
        uint8 MPAAuthCount; // Decision of dataOwner to consent or not
        
        bool oraclesEvaluated;
        address[] oracleAddresses;
        mapping (address => uint16) oracleRatings;
        
    }
    
    struct DataOwner {
        bool registered;
    }
    
    struct DataRequester {
        bool registered;
        
        uint8 MPAAuthCount;
        address[] MPAAuthAddresses;
        bytes1[] claims;
        
        bytes32[] tokenIDs;
        mapping(bytes32 => DataRequesterToken) tokens;
    } 
    
    struct DataRequesterToken{
        bool exists;
        address oracleAddress;
    }
    
    struct Oracle {
        bool registered;

        uint16 averageContractRating;
        uint16 contractRatingCount;
        
        uint16 averageDataRequesterRating;
        uint16 dataRequesterRatingCount;
        
        bytes32[] tokenIDs;
        mapping (bytes32 => OracleToken) tokens;
    }
    
    struct MPA {
        bool registered;
        
    }
    
    struct OracleToken {
        bool exists;
        address dataRequesterAddress;
        // TODO: maybe here we should have info about the file
    }
    
    
}