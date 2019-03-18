pragma solidity ^0.4.25;

import "../node_modules/zeppelin-solidity/contracts/token/ERC721/ERC721Token.sol";

contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}


contract DogToken is ERC721Token, Owned {
    uint public animalId;
    string public symbol;
    string public name;

    struct Animal{
        address owner;
        uint id;
        string name;
        string breed;
        uint genre;    // 0 for male, 1 for femelle
        uint weight;
        string color;
        bool isAlive;
    }
    mapping(uint => Animal) public allAnimals;
    mapping(address => bool) public whitelist;

    //for Auction's fonction
    uint public startAuction;
    uint public endAuction;
    uint public highestBid;
    uint public idSell; //id of the auction's animal
    address public highestBidder;
    address public auctionOwner;
    mapping(address => uint256) public fundsByBidder;

    //event for auctions to keep informations about all the transactions 
    event LogBid(address bidder, uint bid, address highestBidder, uint highestBid);
    event LogWithdrawal(address withdrawer, address withdrawalAccount, uint amount);

    constructor () public
    {
        name = "DogToken";
        symbol = "DTK";
    }

    /**
    * Custom accessor to create a unique token
    */
    function mintUniqueTokenTo(
        address _to,
        uint256 _tokenId,
        string  _tokenURI
    ) public
    {
        super._mint(_to, _tokenId);
        super._setTokenURI(_tokenId, _tokenURI);
    }

    function registerBreeder(address addr, bool whitelisted) public 
    {
        require (msg.sender == owner);
        whitelist[addr] = whitelisted;
    }

    function declareAnimal(string _name, string _breed, uint _genre, uint _weight, string _color, bool _isAlive) public {
        require (msg.sender == owner);
        allAnimals[animalId].owner = owner;
        allAnimals[animalId].id = animalId;
        allAnimals[animalId].name = _name;
        allAnimals[animalId].breed = _breed;
        allAnimals[animalId].genre = _genre;
        allAnimals[animalId].weight = _weight;
        allAnimals[animalId].color = _color;
        allAnimals[animalId].isAlive = _isAlive;
        animalId += 1;
    }

    function deadAnimal(uint animalId1) public {
        require (msg.sender == owner);
        require (msg.sender == allAnimals[animalId1].owner);
        allAnimals[animalId1].isAlive = false;
    }

    function compareString(string name1, string name2) private returns(bool){
        if (uint(keccak256(abi.encodePacked(name1))) == uint(keccak256(abi.encodePacked(name2)))) {
            return true;
	    }
        else{
            return false;
	    }
    }


    function breedAnimal (uint animalId1, uint animalId2) public {
        require (msg.sender == owner);
        require (allAnimals[animalId1].genre != allAnimals[animalId2].genre);
        require (compareString(allAnimals[animalId1].breed, allAnimals[animalId2].breed)==true);
        string childBreed = allAnimals[animalId1].breed;
        string childColor = allAnimals[animalId1].color;
        declareAnimal("bobby", childBreed, 0, 4, childColor, true);
    }

//////// This part is for Auction ///////

// Creation of an auction by initialize all parameters (idAnimal, address of the auction creator, timebank, etc ...)
    function createAuction (uint Id_animal) public {
        require (msg.sender == owner);
        require (msg.sender == allAnimals[Id_animal].owner);
        require (now > endAuction);                      // this line is to prevent a creation of a new auction while the previous one is not finished
        startAuction = now;
        endAuction = now + 2 * (1 days);
        auctionOwner = msg.sender;
        idSell = Id_animal;
    }

    function bidOnAuction() 
        public 
        payable
        onlyAfterStart
        onlyBeforeEnd 
        returns(bool success)
        {
        require (msg.sender == owner);
        
        // Allowed to increase the bid by putting more money in the contract
        uint newBid = fundsByBidder[msg.sender] + msg.value;
        fundsByBidder[msg.sender] = newBid;

        if (newBid <= highestBid)throw; // if the bidder put an amount of money which is not superior to the highest bid it's useless to record the transaction
        else {
            highestBid = newBid;
            highestBidder = msg.sender;
            emit LogBid(msg.sender, msg.value, highestBidder, highestBid); //record of the transaction in the event
            return true;
        } 
    }

    function receiveAuction() 
        public
        onlyAfterEnd
        returns (bool success)
        {
        require (msg.sender == owner);
        address receiveAccount;
        uint receiveAmount;
        if (msg.sender == highestBidder){
            receiveAmount = highestBid;
            receiveAccount = auctionOwner;
            //we put these variables to 0 to prevent recursive hack when the payment is made
            //then we log the amount and the address of the first owner of the animal for the trade
            highestBid = 0;
            fundsByBidder[msg.sender] = 0;
            allAnimals[idSell].owner = msg.sender;
        }
        else{
            //all the candidate who participate but didnt win the auction should be able to withdraw their money
            receiveAccount = msg.sender;
            receiveAmount = fundsByBidder[msg.sender];
            fundsByBidder[msg.sender] = 0;
        }
        receiveAccount.send(receiveAmount); //transaction is made
        emit LogWithdrawal (msg.sender, receiveAccount, receiveAmount); //the transaction is log in the event
        return true;
    }

    modifier onlyAfterStart {
        if (startAuction > now) throw;
        _;
    }

    modifier onlyBeforeEnd {
        if (endAuction < now) throw;
        _;
    }

    modifier onlyAfterEnd {
        if (now < endAuction) throw;
        _;
    }
}
